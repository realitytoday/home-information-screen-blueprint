# Reference material

Concrete artifacts extracted from the working system and sanitized: hostnames, ports, credentials, touch
device names and the household's real names are replaced. They show an AI agent the *exact* behavior to aim
for where prose is too vague. They are **not** a drop-in install: adapt them to your hardware and network.

| Folder | What it holds | Used by prompt |
|---|---|---|
| `pi/motion-agent/` | PIR to screen sleep/wake daemon (Go), env example | 04b |
| `pi/kiosk/` | Chromium kiosk launcher, `labwc` touch config example, desktop entry, exit-state patch sketch | 04a |
| `pi/systemd/` | Units for kiosk, motion agent and the optional presence agent | 04 |
| `pi/presence-agent-optional/` | LAN-ping presence daemon. **Switched off in the reference setup** (router client list plus door events replaced it). Keep for setups without a router API | 04c |
| `build/` | Dockerfile, compose file, build/push/deploy scripts, `.deb` builder | 05 |
| `contract/api.md` | Every REST route, JSON shapes, webhook envelope, data-volume layout | 01, 02, 06 |
| `design/theme.css` | The one palette file: light admin theme, pinned dark kiosk theme, sky gradients, weather colors | 03, 06 |
| `fixtures/` | A complete invented household (Tom, Lena, Ben, Paul, Mia) as YAML test data | 01, 03 |

Screenshots of all seven screens are in `../docs/images/`.

## Placeholders

`{{SERVER_HOST}}`, `{{API_PORT}}`, `{{WEBHOOK_PORT}}`, `{{REGISTRY_PORT}}`, `{{GATEWAY_HOST}}` stand for your own
values. Touch device names must come from `libinput list-devices` on your Pi.

## Adapting it to your setup

Each external dependency is replaceable behind the same cache, stale-on-error and fixture pattern.

- **Calendar:** any CalDAV server (Nextcloud, Synology, iCloud, Baikal). Different protocol (Google, Microsoft
  Graph)? Keep the output shape in `contract/api.md` and swap only the fetcher.
- **Presence:** the backend only needs `person -> home?`. Router client lists (UniFi shown), a DHCP lease file,
  phone pings or any script POSTing to `/webhook/presence` all fit.
- **Sensors:** only the webhook envelope in `contract/api.md` is vendor-specific. Another alarm system needs a
  different parser that produces the same stored events.
- **Language:** all on-screen copy is German in the reference system. Put UI strings in one module from day one.
- **Server:** any always-on machine with Docker. Set `PLATFORM` in `build/build-and-push.sh` to its CPU.
- **Pi:** a Pi 4 on Raspberry Pi OS Trixie (labwc). On X11 or another compositor, screen power and touch
  mapping differ and must be re-derived. Do not reuse the `wlopm` and `labwc` pieces blindly.

## What is verified and what is not

Verified on real hardware in the original system: the motion agent behavior, the kiosk launcher, the systemd
units, the labwc touch settings. **Not** automated or tested there: the Chromium exit-state patch (a sketch
here), NFC fobs and status LEDs. The `build/` scripts target a NAS with a private registry: simplify if you
do not need one.
