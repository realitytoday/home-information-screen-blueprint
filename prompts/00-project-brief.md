# Project brief (save as CLAUDE.md or AGENTS.md)

# Home Information Screen

A wall-mounted household dashboard for a Raspberry Pi driving a Full HD
touchscreen mounted portrait (rotated 90° left). It shows a calendar, weather,
a food-ordering board, household chores, sensors and notes, and sleeps the
display when nobody is around.

This file is project memory: the settled decisions that shape how code gets
written. Keep it short. Open work goes in `docs/TODO.md`; reasons and incidents
go in `docs/HISTORY.md` (dated entries).

## Architecture: the Pi displays, the server computes

- `{{PI_HOST}}`: Raspberry Pi. Chromium kiosk plus GPIO sensors. **No backend,
  no Docker.**
- `{{SERVER_HOST}}`: always-on server. One backend container plus whatever
  already hosts the household's calendar.
- The kiosk's REST calls cross the LAN. The API listens on all interfaces;
  `RequireAPIKey` is the only gate. Never bind it back to localhost.
- If the machines are on different network segments, a firewall rule for
  `{{API_PORT}}` and `{{WEBHOOK_PORT}}` is a hard prerequisite.
- Nothing runs `npm`, `vite` or a compiler in production. Build on a dev
  machine, ship images and binaries. Backend image targets the server's CPU
  architecture; Pi-side binaries cross-compile for linux/arm64.

## Tech stack (settled)

| Layer | Choice | Why |
|---|---|---|
| Backend | Go, standard library only | Single static binary, low memory |
| Frontend | Svelte 5 (runes) + Vite + TypeScript | Compiles away; static output |
| UI kit | shadcn-svelte + Tailwind v4, one icon set, one variable font | Touch primitives you own |
| Persistence | YAML, one file per store | Readable, diffable, fixable over SSH |
| Updates | Polling plus caching. **No WebSocket.** | Consistent everywhere |
| Calendar | CalDAV; recurring events expanded **server-side** | Do not write an RRULE engine |
| Weather | Open-Meteo | No API key |
| Packaging | Docker multi-stage, distroless runtime | Small, no shell |

TLS to internal services uses the household's private root CA, loaded into an
explicit cert pool and verified normally. **Never `InsecureSkipVerify`.**

## Hardware constraints

Raspberry Pi 4B (4 GB) on Raspberry Pi OS Trixie. Rotation and touch are
**Wayland/labwc settings, not X11.** `xrandr` and `xinput` must never appear in
launch scripts. Touch needs `mouseEmulation="no"`. Screen sleep uses `wlopm`,
never `wlr-randr --off` (it crashes the browser surface).

## Screens

Seven, via a bottom tab bar: Idle, Calendar, Food, Chores, Weather, Sensors,
Notes.

- The default screen follows a **time-of-day schedule** (admin-editable), not a
  fixed home tab. A manual tap overrides until the panel next sleeps.
- An active note outranks the schedule **only after the idle timer fires**,
  never the instant it appears. Only two places force the Notes tab: the idle
  timeout and initial page load.

## Presence is not authentication

"Who's home" feeds status chips; weak evidence is fine. "Authenticated at the
screen" would gate chore tick-off and is a strictly higher bar. Not built.

## Secrets

No plaintext credentials at rest on the backend host is the requirement. Today
credentials are environment variables. Operational data lives on the mounted
volume; **credentials never do.** Do not add new credential surfaces without
noting it in `docs/TODO.md`.

## Conventions

- `go build ./...` and `go vet ./...` before committing; `npm run check` for
  the frontend.
- Svelte 5 runes (`$state`, `$derived`, `$props`), not the old stores API.
- UI copy in `{{LANGUAGE}}`. Code identifiers, comments and commit messages in
  English.
- One line per HTTP request to stdout; rotation is Docker's job.
- **Every integration follows one shape:** TTL cache, stale-on-error fallback,
  fixture as last resort. Match it.
- **Design system "Ruhe":** one palette file is the only place a color is
  defined. No eyebrow labels, no cards, no translucent tints behind text, round
  everything, color means state/person/restaurant only, no monospace. A raw
  hex, pixel size or border in a kiosk component is a bug.
- The kiosk is a single-page app loaded once at boot. Redeploying the backend
  does not update the screen; restart the kiosk service after a frontend change.

## Comments

Default to none. Write one only when the code cannot say it: a non-obvious
constraint, a bug workaround, a reason a naive approach would fail. Never restate
the identifier, never write section banners.
