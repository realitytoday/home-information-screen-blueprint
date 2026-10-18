// Command presence-agent runs on the Raspberry Pi itself (NOT the NAS
// — see software/motion-agent's doc comment for the same reasoning:
// GPIO is Pi-only, but this one isn't inherently Pi-only, it's here
// because it needed to be). This backend's own local-network presence
// pinging (internal/presence) needs a raw ICMP socket, which requires
// CAP_NET_RAW — confirmed unreliable on this household's NAS
// Container Manager deployment even with an explicit `cap_add` and a
// `setcap` file capability (see internal/presence/presence.go and the
// Dockerfile's doc comments for the full story). The Pi runs natively,
// not containerized, so this same capability is trivial to grant
// reliably via systemd's AmbientCapabilities — sidestepping the whole
// Docker/dockerd inconsistency.
//
// This is the PRIMARY presence-detection path as of 2026-09-14, not a
// replacement for the backend's own blind polling — that keeps running
// too, as the fallback for exactly the case this daemon can't cover:
// the Pi itself being down or unreachable (see
// internal/presence.Prober's doc comment — "ping polling is the
// fallback... not the only source of truth", which is exactly the
// intended shape here, just with two ping sources instead of one).
//
// Each cycle: fetch the current device list from the backend's own
// GET /api/presence (so the Pi never needs its own separate copy of
// personId->IP config — one source of truth, admin-editable via the
// admin site Presence panel same as always), ping each IP locally, POST the
// results to the backend's presence webhook (see
// internal/api/presencewebhook.go).
package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
	"time"

	"golang.org/x/net/icmp"
	"golang.org/x/net/ipv4"
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

type device struct {
	PersonID string `json:"personId"`
	IP       string `json:"ip"`
}

func fetchDevices(client *http.Client, backendURL, apiKey string) ([]device, error) {
	req, err := http.NewRequest(http.MethodGet, backendURL+"/api/presence", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-API-Key", apiKey)
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, &httpStatusError{resp.StatusCode}
	}
	var devices []device
	if err := json.NewDecoder(resp.Body).Decode(&devices); err != nil {
		return nil, err
	}
	return devices, nil
}

type httpStatusError struct{ code int }

func (e *httpStatusError) Error() string {
	return "unexpected HTTP status " + strconv.Itoa(e.code)
}

// ping sends one ICMP echo and waits briefly for a reply. Same shape as
// the backend's own internal/presence.ping — duplicated rather than
// shared, since this is a fully standalone module (no shared dependency
// between it and the backend, matching software/motion-agent's same
// self-contained precedent) — but running here on bare Linux with
// AmbientCapabilities=CAP_NET_RAW (see the systemd unit), not inside a
// container fighting Docker's ambient-capability propagation.
func ping(ip string, timeout time.Duration) bool {
	dst, err := net.ResolveIPAddr("ip4", ip)
	if err != nil {
		return false
	}

	conn, err := icmp.ListenPacket("ip4:icmp", "0.0.0.0")
	if err != nil {
		log.Printf("ping %s: can't open raw ICMP socket (missing CAP_NET_RAW?): %v", ip, err)
		return false
	}
	defer conn.Close()

	msg := icmp.Message{
		Type: ipv4.ICMPTypeEcho,
		Code: 0,
		Body: &icmp.Echo{
			ID:   os.Getpid() & 0xffff,
			Seq:  1,
			Data: []byte("home-info-screen-presence-agent"),
		},
	}
	b, err := msg.Marshal(nil)
	if err != nil {
		return false
	}
	if _, err := conn.WriteTo(b, dst); err != nil {
		return false
	}
	if err := conn.SetReadDeadline(time.Now().Add(timeout)); err != nil {
		return false
	}

	reply := make([]byte, 512)
	n, _, err := conn.ReadFrom(reply)
	if err != nil {
		return false // timeout = no reply in time = "not home right now"
	}
	parsed, err := icmp.ParseMessage(1, reply[:n]) // protocol 1 = ICMP
	if err != nil {
		return false
	}
	return parsed.Type == ipv4.ICMPTypeEchoReply
}

type reportBody struct {
	Results map[string]bool `json:"results"`
}

func reportResults(client *http.Client, webhookURL string, results map[string]bool) {
	if webhookURL == "" || len(results) == 0 {
		return
	}
	body, err := json.Marshal(reportBody{Results: results})
	if err != nil {
		log.Printf("presence webhook: marshal failed: %v", err)
		return
	}
	req, err := http.NewRequest(http.MethodPost, webhookURL, bytes.NewReader(body))
	if err != nil {
		log.Printf("presence webhook: bad URL: %v", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("presence webhook: request failed: %v", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		log.Printf("presence webhook: unexpected status %d", resp.StatusCode)
	}
}

func main() {
	backendURL := getenv("BACKEND_URL", "http://{{SERVER_HOST}}:{{API_PORT}}")
	apiKeyFile := getenv("BACKEND_API_KEY_FILE", "/etc/home-info-screen/api-key")
	webhookURL := getenv("PRESENCE_WEBHOOK_URL", "")
	pollInterval := getenvDuration("POLL_INTERVAL", 60*time.Second)
	pingTimeout := getenvDuration("PING_TIMEOUT", 1500*time.Millisecond)
	httpTimeout := getenvDuration("HTTP_TIMEOUT", 5*time.Second)

	apiKeyBytes, err := os.ReadFile(apiKeyFile)
	if err != nil {
		log.Fatalf("can't read %s: %v", apiKeyFile, err)
	}
	apiKey := string(apiKeyBytes)
	for len(apiKey) > 0 && (apiKey[len(apiKey)-1] == '\n' || apiKey[len(apiKey)-1] == '\r' || apiKey[len(apiKey)-1] == ' ') {
		apiKey = apiKey[:len(apiKey)-1]
	}

	client := &http.Client{Timeout: httpTimeout}

	log.Printf("presence-agent starting: backend %s, poll interval %s", backendURL, pollInterval)
	if webhookURL == "" {
		log.Print("PRESENCE_WEBHOOK_URL not set — pings will run locally but results won't reach the backend")
	}

	for {
		devices, err := fetchDevices(client, backendURL, apiKey)
		if err != nil {
			log.Printf("fetch device list failed: %v", err)
		} else {
			results := make(map[string]bool, len(devices))
			for _, d := range devices {
				if d.IP == "" {
					// MAC-only device (see internal/presence.Device's
					// doc comment) — this agent only pings, it has no
					// way to check a MAC. Omit it from the results
					// entirely rather than pinging an empty address
					// (net.ResolveIPAddr("ip4", "") resolves to the
					// same destination for every such device, which
					// silently produced identical, wrong results for
					// every MAC-only person — the actual root cause of
					// a real 2026-09-15 bug where all household
					// members showed byte-identical presence history).
					// The webhook already treats an omitted person as
					// "no update this round," not "away" — the UniFi
					// path in the backend's own pollAll() is what
					// covers MAC-only devices.
					continue
				}
				results[d.PersonID] = ping(d.IP, pingTimeout)
			}
			reportResults(client, webhookURL, results)
		}
		time.Sleep(pollInterval)
	}
}
