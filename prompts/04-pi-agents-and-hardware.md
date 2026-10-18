# 04 — Pi agents and hardware

**Context.** Prompts 00 to 03 done. This is the Pi side. Read
`docs/04-hardware.md` first. Wire the PIR to a 5 V pin, a ground pin and one
GPIO input yourself; the agent writes software only.

## 4a. Kiosk setup

Reference files: `reference/pi/kiosk/` (launcher, `labwc-rc.xml.example`, desktop entry),
`reference/pi/systemd/home-info-kiosk.service`, `reference/build/build-deb.sh`.
The exit-state patch is only a sketch there (`chromium-exit-state-patch.sh`): verify it with a hard power cut.

Produce a Debian package (architecture-independent) that installs a systemd
service launching Chromium full screen against the backend URL, plus a config
file containing the API key.

- **Wayland only.** The Pi runs labwc. Never call `xrandr` or `xinput`. Rotation
  and touch are desktop-session settings, documented, not scripted.
- Detect the browser binary as `chromium` or `chromium-browser`.
- `Restart=always`, because Chromium can exit cleanly after handing a URL to an
  existing instance.
- Do not hardcode a service username; use a documented systemd drop-in override.
- Create config directories with permissions the service user can read.
- Enable the service at boot.
- Patch the browser profile's exit state to "normal" before launch so a hard
  power cut does not show a restore prompt.

**Checks:** reboot with the screen unplugged and replugged; hard-cut power;
confirm the kiosk comes back to the right screen with no prompt.

## 4b. Motion agent

Reference implementation: `reference/pi/motion-agent/` (about 200 lines of Go), its env example and
`reference/pi/systemd/home-info-motion-agent.service`. Give your agent the file as the target behavior,
then let it adapt GPIO line, output name and webhook to your hardware.

A tiny standalone Go module, cross-compiled for linux/arm64, run as a systemd
unit.

- Read the PIR on a GPIO input. Treat the first minute after start as warm-up.
- No motion for 5 minutes: dim, then blank the backlight with **`wlopm`**. Any
  motion or touch wakes it.
- **Never use `wlr-randr --output ... --off`.** It crashes the browser's rendering
  surface.
- Sleep and wake must work with no network. Reporting to the backend's motion
  webhook is best effort and must not block.
- Configuration (GPIO line, timeouts, sleep and wake commands, webhook URL,
  token) comes from an environment file, with a committed `.example` and the real
  file git-ignored.

**Checks:** unplug the network cable and confirm sleep and wake still work; the
browser survives a sleep cycle with its renderer processes intact.

## 4c. Presence agent (optional)

Skip this if your router or gateway exposes a connected-client list and your alarm system can send door
events: that combination replaced the agent in the original system. Build it only when you have neither.
Reference: `reference/pi/presence-agent-optional/`.

A second small Go module, same shape.

- Fetch the device list from the backend, ping each device locally with a real
  raw-socket capability, POST `{"results": {...}}` to the presence webhook.
- Grant the capability to the binary or unit, not by running as root.
- Interval and timeouts from the environment file.

**Checks:** a phone that leaves the WiFi flips to away within two cycles; the
agent keeps running if the backend is down.

## Out of scope

NFC fob reading, status LEDs and BLE beacons. Designed, not built.
