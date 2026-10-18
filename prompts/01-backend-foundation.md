# 01 — Backend foundation

**Context.** Project brief (00) is loaded. This builds the skeleton every later
prompt plugs into. No real integrations yet.

## Prompt

Build the backend for the Home Information Screen as a Go module using only the
standard library.

**Structure.** A server entry point that reads configuration from the
environment, constructs every store and handler, registers routes and starts two
HTTP listeners: the API on `{{API_PORT}}` and a separate webhook listener on
`{{WEBHOOK_PORT}}`. Packages for api, store, data and auth, plus one package per
integration to come.

**Auth.** A single shared `X-API-Key`. Generate it on first boot, persist it to
the data volume, require it on every `/api/...` route via one middleware. Add an
endpoint to reveal and regenerate it (itself behind the key). Provide a health
endpoint that does **not** require the key and returns a `version` field set at
build time.

**Persistence.** Each store is one type backed by one YAML file under a
configurable data directory. All stores share one shape: `load()` and `save()`
around a mutex, with seed-on-first-read where a fixture predates the store.
Time-series stores write one file per calendar day. Create a store for people,
restaurants, shops (one file per shop), tasks (one file per day), notes, and a
screen schedule. Every write error must be logged loudly.

**Data model.** A person has an id, name, initials and a hex color. Notes have a
normalized 0 to 1 x/y position, author, text and a "show until" time. Chores come
from a constant weekly table for now.

**Fixtures.** A `data` package with realistic fixtures for every resource. They
are the last-resort fallback whenever a real integration has failed and has no
cache yet.

**Routes.** CRUD for people, restaurants and notes; chores by day with tick-off
state; the schedule; the health endpoint. Use stdlib pattern routing.

**The integration pattern.** Write one small reusable helper for "TTL cache +
stale-on-error + fixture fallback" and use it as the template for prompt 02.

**Rules.**

- Standard library only; no router, no ORM.
- Request logging: one line per request to stdout.
- No credentials ever written to the data volume.
- Distroless-friendly: statically linked, nothing needing a shell.

**Out of scope.** Authentication per person, a database, WebSockets.

## Acceptance checks

- `go build ./...` and `go vet ./...` are clean.
- First start creates the data directory and a persisted API key; second start
  reuses it.
- `curl` without the key returns 401 on `/api/...` and 200 on health with a
  version.
- Delete a store's YAML file while running and the next read re-seeds it.
- Kill the process mid-write test (or simulate a failed write): the error is
  logged, the previous file is intact.
