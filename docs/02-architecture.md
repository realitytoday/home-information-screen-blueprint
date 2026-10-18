# Architecture

## The core decision: the Pi displays, the server computes

```
  Kiosk (Raspberry Pi)                   Backend (NAS / mini PC, Docker)
  ─────────────────────────              ────────────────────────────────
  Chromium, native, full screen          One binary serving REST API
  Frontend fetched from backend,         and the built frontend assets
  never built on the Pi                  Talks outward to:
        │                                  - CalDAV server
        │  REST, polled                    - weather API (no key)
        └─────────────────────►            - router/gateway (presence)
                                           - private CA for TLS to both
  Two small native daemons (systemd):
    - motion agent   PIR → screen sleep/wake + report
    - (optional) presence agent: LAN ping  Persistence: plain YAML files
```

The backend does **not** run on the Pi. Two machines, ideally on two network
segments. The Pi only displays and reads GPIO; everything that polls, caches,
stores or integrates lives on the server. Nothing is built in production: images
and binaries are built on a dev machine and shipped.

Why: a Pi has little headroom next to a browser, and splitting the roles means
the display can be reflashed or replaced without touching any data.

A consequence worth planning for: the kiosk's calls cross your LAN, so the API
listens on all interfaces and a shared API key is the only gate. If the two
machines are on different VLANs, **a firewall rule between them is a hard
prerequisite**, for the API port *and* for the webhook port the Pi reports to.
A webhook that silently times out with `context deadline exceeded` is almost
always a firewall drop, not a code bug.

## Technology choices and why

| Layer | Choice | Reason |
|---|---|---|
| Backend | Go, standard library only | Single static binary, small memory, easy concurrency for polling. HTTP pattern routing in the stdlib is enough; no router dependency. |
| Frontend | Svelte 5 + Vite, TypeScript | The framework compiles away; nothing heavy ships to a small device. Static output the backend serves directly. |
| UI kit | shadcn-svelte (bits-ui) + Tailwind v4, an icon set, one variable font | Touch-sized primitives you own and tune. |
| Persistence | YAML files, one per store | Human-readable, diffable, fixable over SSH. Data volume is tiny; a database would be ceremony. |
| Updates | Polling with caching, no WebSocket | Consistent everywhere. A realtime layer for one feature is not worth it. |
| Calendar | CalDAV, recurring events expanded **server-side** | Do not implement RRULE yourself; ask the server to expand. |
| Weather | Open-Meteo | No API key. For German locations it blends the national weather service's model. |
| Packaging | One multi-stage Docker image, distroless runtime | Stage one builds the frontend, stage two the binary. |
| Security | Private root CA baked into the image, verified normally | Never skip TLS verification. |

## Backend shape

A handful of packages, each with one job:

- **server entry point:** reads configuration, constructs everything, registers
  routes, starts two listeners. The only place that knows about all the others.
- **api:** HTTP handlers, one file per resource, the webhook handlers, the key gate.
- **store:** one type per YAML resource, all with the same shape: load and save
  around a mutex, seed on first read where a fixture predates the store.
- **data:** shared types plus **fixture fallbacks**.
- **integrations:** calendar, weather, presence, router client, optional school timetable.
- **auth:** one shared API key, generated on first boot and persisted to the data volume.

### The integration pattern (use it for every new integration)

1. A **TTL cache** in front of the remote service.
2. **Stale-on-error:** if the call fails, serve the last good cache.
3. A **fixture** as the last resort when there is no cache yet.

The screen is therefore never blank and never shows a raw error. A stale
indicator in a distinct semantic color tells people the data is old.

## Persistence

No database. Each store is a YAML file in a bind-mounted volume:

- **One file per resource:** restaurants, people, presence config, schedule,
  calendar config, sensor config, one file per shop, one file per day of chores.
- **One file per calendar day** for time series such as presence history. A bad
  day is then one file to delete instead of a value buried in a growing blob.

Operational data lives on the volume. Credentials never do.

## Presence: four signals, layered

One map `person → home?` is updated by whichever signal fired most recently. In the running system the
primary sources are signal 2 (router association) and signal 4 (door events from the alarm system);
signal 3, the Pi ping agent, was built first and later switched off once the router and door events
proved sufficient. It stays in `reference/pi/presence-agent-optional/` for setups without a router API.

1. **Ping polling** from the backend. Fragile in containers (see lessons).
2. **Router association:** is the phone's MAC in the gateway's connected-client list with a recent `last_seen`? Takes priority over ping, and is far more reliable because a sleeping phone radio still shows as associated.
3. **Presence agent push:** the Pi pings locally with proper raw-socket rights and POSTs results.
4. **Direct pushes:** any script may assert presence. A door-open event triggers an immediate re-check plus a delayed one, because the door usually opens before the phone reconnects to WiFi.

The webhook for signal 3 is a **fully generic push API**: any script or device
that POSTs `{"results": {"<personId>": true|false}}` with the right token works,
with no coupling to the agent. Remember this before assuming a new signal needs
new backend code.

Practical requirements for ping or MAC presence: a DHCP reservation per phone and
"private WiFi address" turned off for that network, or the MAC (and IP) will not
stay stable.

## Webhooks: one separate listener

A second listener (default all interfaces, a different port) takes webhook POSTs
so devices that only POST never need the API key. All endpoints share one auth
shape: an `X-Webhook-Token` header (falling back to a query parameter) compared
with a constant-time compare against **one token per endpoint**. An unset token
disables that single endpoint and logs it at startup.

| Endpoint | Caller | Effect |
|---|---|---|
| door | router/camera alarm system | Immediate presence re-poll plus a delayed follow-up |
| motion | Pi motion agent | Records a timestamp for the idle overlay and admin activity view |
| presence | Pi presence agent or any script | Sets presence per person |
| sensor | alarm system | Maps the vendor envelope into the app's sensor-event model |

An admin endpoint returns all webhook URLs fully formed so you can copy them.

## Pi-side agents

All three are optional from the backend's point of view; each degrades gracefully.

| Piece | Why it is not in the backend | Job |
|---|---|---|
| Kiosk (`.deb`, Chromium) | Needs direct GPU and touch | Render the frontend full screen, no chrome |
| Motion agent | GPIO is Pi-only | Poll the PIR; sleep and wake the screen **locally** (works with no network); best-effort report to the backend |
| Presence agent (optional, switched off in the reference setup) | Needs a real raw-ICMP socket | Fetch the device list, ping locally, POST results |

Screen sleep uses the compositor's output-power-management tool, **not** an
output-disable command. See lessons learned for why.

## Admin site

A second entry point from the same frontend build, behind the same shared key
(entered once, kept in the browser). No login system. Sections: restaurants and
menus, security and API key plus webhook URLs, screen schedule and idle timeout,
calendar connection with a test button, presence devices plus a history graph,
household roster (name, initials, color), sensors with drag-to-reorder.

Credentials are write-only: the server never returns a stored password to the
browser, only whether one is set.

## Sensors

Read-only status from the gateway's alarm manager via webhooks. Realities worth
knowing before you design the screen:

- The alarm system fires on **threshold conditions**, not a continuous feed. You
  get "too warm", not 23.4 °C. Design for status, not readings.
- Events carry a generic trigger key plus a more specific event-key suffix and
  a high/low value. Use the suffix to tell temperature from humidity from light.
- **Leaks never clear on their own.** Latch them and put the dismiss button on
  the kiosk row itself: whoever is physically checking the leak must clear it
  where they stand. Temperature-type alerts auto-expire after a timeout.
- Normalize device MAC addresses (lowercase, no separators) at every write and
  match point.
- Store the latest event per **device and trigger key**, not per device: one
  physical unit reports several things.

## Known gaps, stated plainly

- No per-person authentication at the screen (designed around RFID fobs, not built).
- No chore **definition** editing; only tick-off state. The weekly schedule is a constant.
- Secrets are plain environment variables today. A secrets manager is the decided answer and is not wired.
- No test suite.
- No per-token rotation for the webhook tokens.
