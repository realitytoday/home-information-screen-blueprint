# 02 — Integrations

**Context.** Prompts 00 and 01 done. Add each integration as its own vertical
slice, verified against the real service before starting the next.

## 2a. Calendar (CalDAV)

Fetch events from `{{CALDAV_URL}}` and expose them as one merged list.

- Use a maintained CalDAV client library, or implement only what you need.
- Discover calendars. Skip collections that hold only to-dos.
- **Expand recurring events on the server** using the CalDAV `expand` request.
  Do not add an RRULE library.
- Tag each event with the matching person by case-insensitive calendar-name
  match against the people store. A shared calendar maps to a "family" person.
- Fetch each calendar's color with a raw WebDAV property request (the
  `calendar-color` property is a CalendarServer extension and the client library
  will not expose it). Feed it to the people store only if the person has no
  manual color.
- Cache: 5 minutes during the day, 15 overnight. A forced-refresh parameter
  bypasses the cache.
- TLS: trust the household private root CA via an explicit cert pool. Never skip
  verification. Credentials come from the environment; the admin site (prompt 06)
  can later replace them live without a restart.
- Wrap in the integration pattern: cache, stale-on-error, fixture.

**Checks:** recurring events appear on the right days; a to-do-only collection is
ignored; a wrong password returns the stale cache rather than an error.

## 2b. Weather (Open-Meteo)

For `{{LAT}}`, `{{LON}}` return: current conditions, the next 24 hours (temperature,
icon, rain probability, is-day), daily high/low and rain chance for the coming
days, and **hourly sunshine duration** as a real quantity (not derived from rain).
Add a second call for air quality and flag Saharan-dust events when the daily peak
crosses a threshold. Same integration pattern. Add `isDay` to the current
conditions; keep new payload fields optional for older clients.

**Checks:** sunshine is zero at night; killing the network shows the last data
with an age.

## 2c. Presence

Build a `Prober` that holds one `person → home` map updated by whichever signal
fired most recently:

1. **Ping polling** of each device with an IP.
2. **Router association:** if a device has a MAC, check the gateway's
   connected-client list instead (a device is home if its MAC is present with
   `last_seen` within a configurable window, default 10 minutes). This takes
   priority over ping.
3. **Push** via the generic presence webhook (see below).
4. **`SetHome`** direct assertions, used by the door webhook.

Details that cost time before:

- The gateway integration uses the **legacy session-cookie login** with a
  local-only read-only admin account created just for this, not the official API
  key. Re-login on 401 (tokens last about two hours). Use a cookie jar.
- **If the router credentials are missing from the environment, log one clear
  line at startup.** A silently nil client made every device fall through to a
  broken ping fallback once.
- A poll loop must not exit when it starts with zero devices.
- Raw ICMP does not work reliably in a non-root container on a NAS. Do not run
  as root to fix it; the Pi-side agent (prompt 04) covers this.
- Keep per-day presence history files for a 7-day graph.

**Checks:** a phone with a sleeping radio does not flap; removing a device while
running does not crash.

## 2d. Webhooks

On the separate webhook listener, add four endpoints: **door**, **motion**,
**presence**, **sensor**. Each is authenticated by an `X-Webhook-Token` header
(falling back to a `token` query parameter), compared with a constant-time compare
against **one token per endpoint**. An unset token disables that endpoint and logs
it at startup.

- **door:** trigger an immediate presence re-poll and a delayed follow-up
  (phones reconnect to WiFi after the door opens).
- **motion:** record a timestamp for the idle overlay.
- **presence:** accept `{"results": {"<personId>": true|false}}` and call
  `SetHome`. Keep it generic so any script can post to it.
- **sensor:** parse the alarm system's envelope (`alarm.triggers[].key`, plus the
  more specific event-key suffix and a high/low value) into the app's sensor
  model.

Add an admin endpoint returning all four webhook URLs, fully formed.

## 2e. Sensors

Read-only status per sensor: doors and windows, water leaks, temperature,
humidity, light.

- The alarm system fires on **threshold conditions**, not continuous readings.
  Model "normal / too warm / too cold / too humid..." as states, never a number.
- Key stored events by **device and trigger key**, not device alone, and use the
  event-key suffix to tell temperature from humidity from light.
- Normalize MAC addresses (lowercase, no separators) at every write and match.
- **Leaks latch** until dismissed (the vendor never sends "cleared"). Give the
  kiosk a dismiss action. Temperature-type alerts auto-expire after a timeout
  (default 6 hours).
- Dismissing one type must not clear sibling types on the same device.
- Do not rely on the first payload you see. Capture real payloads and read them.

**Checks:** replay a captured leak payload; the tile latches; dismissal clears
only that type.
