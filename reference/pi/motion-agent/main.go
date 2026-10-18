// Command motion-agent runs on the Raspberry Pi itself (NOT the NAS —
// see the main repo's CLAUDE.md "Architecture": the backend moved off
// the Pi, but GPIO is physically only reachable from the Pi, so this is
// a separate, minimal daemon living on the display device). It watches
// the PIR motion sensor's data pin and:
//
//  1. Controls the physical screen's power directly and locally (the
//     thing that actually matters — the browser itself has no way to
//     touch hardware backlight/DPMS), via a configurable shell command
//     (default: wlopm, the dedicated wlr-output-power-management-v1
//     protocol tool — NOT wlr-randr, which is used elsewhere for this
//     Pi's display rotation but was confirmed on real hardware
//     (2026-09-14) to crash Chromium's rendering surface outright when
//     used to disable/re-enable the output for sleep/wake).
//  2. Best-effort reports each motion event to the backend's webhook
//     (see internal/api/motion.go) so the kiosk browser's own idle
//     overlay and the admin Activity panel can also reflect real
//     presence — this is a nice-to-have layered on top, never a
//     dependency: if the network/backend is unreachable, screen
//     power still works correctly from GPIO alone.
//
// Wiring on this household's Pi (confirmed 2026-09-14): PIR VCC → header
// pin 2 (5V), PIR GND → pin 6, PIR data (OUT) → pin 12 (BCM GPIO18).
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/stianeikeland/go-rpio/v4"
)

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvDuration(key string, fallback time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		log.Printf("invalid %s=%q, using default %s: %v", key, v, fallback, err)
		return fallback
	}
	return d
}

func getenvInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		log.Printf("invalid %s=%q, using default %d: %v", key, v, fallback, err)
		return fallback
	}
	return n
}

// runCommand shells out (via `sh -c`) rather than exec'ing an argv
// directly, so SLEEP_CMD/WAKE_CMD stay simple, single-string, easily
// overridden env vars (matching kiosk-autostart.sh's own convention of
// shell-script-level hardware control with env overrides) instead of
// needing shell-quoting-aware argv splitting for something this
// low-stakes. Backgrounded with a short timeout so a hung command
// (e.g. wlr-randr blocking on a dead Wayland socket) can't wedge the
// whole daemon and leave GPIO polling stuck.
func runCommand(cmdline string) {
	if cmdline == "" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "sh", "-c", cmdline)
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("command failed: %s: %v (output: %s)", cmdline, err, strings.TrimSpace(string(out)))
	}
}

// reportMotion best-effort POSTs to the backend's motion webhook — see
// internal/api.MotionHandlers.Report. Never blocks the caller for long
// (short client timeout) and never treated as fatal; this whole daemon
// works correctly for its primary job (screen power) with no backend
// reachable at all.
func reportMotion(client *http.Client, webhookURL string) {
	if webhookURL == "" {
		return
	}
	req, err := http.NewRequest(http.MethodPost, webhookURL, nil)
	if err != nil {
		log.Printf("motion webhook: bad URL: %v", err)
		return
	}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("motion webhook: request failed: %v", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		log.Printf("motion webhook: unexpected status %d", resp.StatusCode)
	}
}

func main() {
	gpioPin := getenvInt("GPIO_PIN", 18) // BCM numbering — physical pin 12 on this household's wiring
	idleTimeout := getenvDuration("IDLE_TIMEOUT", 5*time.Minute)
	pollInterval := getenvDuration("POLL_INTERVAL", 200*time.Millisecond)
	checkInterval := getenvDuration("CHECK_INTERVAL", 5*time.Second)
	screenOutput := getenv("SCREEN_OUTPUT", "HDMI-A-1")
	// wlopm (wlr-output-power-management-v1), not wlr-randr --off/--on —
	// confirmed on real hardware (2026-09-14) that toggling the output
	// fully off via wlr-randr kills Chromium's rendering surface outright
	// (crashed with a zygote "Broken pipe" and needed a manual restart +
	// a few auto-restart cycles to recover). wlopm blanks the physical
	// backlight/power via the dedicated DPMS-style protocol instead of
	// disabling the output altogether, so the compositor and Chromium's
	// surface should stay intact across a sleep/wake cycle.
	sleepCmd := getenv("SLEEP_CMD", "wlopm --off "+screenOutput)
	wakeCmd := getenv("WAKE_CMD", "wlopm --on "+screenOutput)
	webhookURL := getenv("MOTION_WEBHOOK_URL", "") // full URL incl. ?token=... — see the admin page's admin site Presence panel
	webhookMinInterval := getenvDuration("MOTION_WEBHOOK_MIN_INTERVAL", 30*time.Second)
	webhookTimeout := getenvDuration("MOTION_WEBHOOK_TIMEOUT", 3*time.Second)

	if err := rpio.Open(); err != nil {
		log.Fatalf("rpio.Open failed (are you root, or in the 'gpio' group with /dev/gpiomem readable?): %v", err)
	}
	defer rpio.Close()

	pin := rpio.Pin(gpioPin)
	pin.Input()
	// PIR modules (HC-SR501 and similar) actively drive their output
	// pin both idle-low and high-on-motion — PullDown here is just a
	// defined-state safety net for the moment before/if the sensor is
	// ever disconnected, not load-bearing for normal operation.
	pin.PullDown()

	httpClient := &http.Client{Timeout: webhookTimeout}

	log.Printf("motion-agent starting: GPIO%d, idle timeout %s, screen output %q", gpioPin, idleTimeout, screenOutput)
	if webhookURL == "" {
		log.Print("MOTION_WEBHOOK_URL not set — screen power still works, just no backend reporting")
	}

	// Force a wake on every start (service start OR restart), not just
	// when a motion edge later transitions `asleep` true->false — this
	// process holds no memory of whatever the physical screen's actual
	// power state was before it started (e.g. left blanked by a prior
	// run's idle timeout), and `asleep` always starts false regardless.
	// Confirmed as a real bug on real hardware (2026-09-14): a restart
	// while the screen happened to be off left it stuck off indefinitely
	// — real motion kept refreshing lastMotion and successfully posting
	// to the webhook, but the wake command was never called because the
	// in-memory state already (wrongly) said "awake". Unconditionally
	// waking on startup makes every restart leave the screen in a known,
	// visible state instead of an ambiguous one.
	runCommand(wakeCmd)

	var (
		// Seeded to "now" rather than the zero value, so a Pi that boots
		// with nobody around still sleeps after idleTimeout instead of
		// staying awake indefinitely until the first-ever motion event.
		lastMotion      = time.Now()
		lastWebhookSent time.Time
		asleep          bool
	)

	pollTicker := time.NewTicker(pollInterval)
	defer pollTicker.Stop()
	checkTicker := time.NewTicker(checkInterval)
	defer checkTicker.Stop()

	for {
		select {
		case <-pollTicker.C:
			if pin.Read() == rpio.High {
				now := time.Now()
				lastMotion = now
				if asleep {
					log.Print("motion detected — waking screen")
					runCommand(wakeCmd)
					asleep = false
				}
				if webhookURL != "" && now.Sub(lastWebhookSent) >= webhookMinInterval {
					lastWebhookSent = now
					go reportMotion(httpClient, webhookURL)
				}
			}
		case <-checkTicker.C:
			if !asleep && time.Since(lastMotion) >= idleTimeout {
				log.Print("idle timeout reached — sleeping screen")
				runCommand(sleepCmd)
				asleep = true
			}
		}
	}
}
