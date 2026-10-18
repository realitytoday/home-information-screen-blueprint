# 05 — Deploy and operations

**Context.** Backend and kiosk exist. This makes shipping repeatable. Read
`docs/05-lessons-learned.md` (networking and deployment) first.

## Prompt

**Image.** One multi-stage Dockerfile: stage one builds the frontend, stage two
the Go binary (static, targeting the server's CPU architecture), the final stage
is distroless and non-root. Bake in the household private root CA (a public cert,
not a secret). Use host networking only if you truly need it, and prefer not to.

**Compose.** A compose file with a bind-mounted data volume, a log cap (rotate in
Docker, not in the app), a committed `.env.example`, and **`TAG` defaulting to
`latest`**, matching what the build script pushes.

**Build and push.** `build-and-push` pushes the backend image to a private
registry. A separate `deploy` script pulls and recreates on the server. Keep them
separate: pushing does not touch the running container.

**Version visibility.** Stamp the build with a version string, expose it on the
health endpoint, and print it at startup. This is how you detect "redeploy did
nothing".

**Private registry.** If you run `registry:2` on the NAS, put it behind the
NAS's reverse proxy with a certificate from your private CA. The NAS's Docker
daemon may ignore the per-registry certificate directory and validate against
the system-wide CA bundle instead; append your root there if so.

**Pi artefacts.** Scripts to build the kiosk package and cross-compile both Pi
agents. Each is runnable on its own whenever that piece changes.

**Secrets.** Environment variables only for now. List every credential in a
single table in the docs. Do not add new credential surfaces without noting it.
A secrets manager is the planned replacement.

**Operations notes to write into the docs as you go.**

- How to inspect the data volume of a distroless container (mount it into a
  throwaway Alpine container).
- The firewall rules between segments.
- That the kiosk must be restarted after a frontend change.

## Acceptance checks

- A clean build on a fresh dev machine produces a running container from the
  documented commands only.
- Change a visible string, build, push, deploy: the health endpoint's version
  changes and the screen shows the change after a kiosk restart.
- `docker exec ... ls` is expected to fail (no shell); the documented volume
  inspection works.
