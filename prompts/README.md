# Prompts

Seven briefs to give your coding agent, in order. They describe *what* and *why*
and give *acceptance checks*. They deliberately do not dictate code, so the agent
adapts to your setup.

| # | File | Builds |
|---|---|---|
| 00 | [00-project-brief.md](00-project-brief.md) | The drop-in `CLAUDE.md` / `AGENTS.md`: settled decisions, read every session |
| 01 | [01-backend-foundation.md](01-backend-foundation.md) | API, stores, auth, the cache pattern, fixtures |
| 02 | [02-integrations.md](02-integrations.md) | Calendar, weather, presence, sensors, webhooks |
| 03 | [03-kiosk-ui.md](03-kiosk-ui.md) | The seven screens and the design system |
| 04 | [04-pi-agents-and-hardware.md](04-pi-agents-and-hardware.md) | Kiosk setup, motion sleep, presence agent |
| 05 | [05-deploy-and-ops.md](05-deploy-and-ops.md) | Image, registry, packaging, redeploy discipline |
| 06 | [06-admin-site.md](06-admin-site.md) | Configuration UI for everything above |

## Placeholders

Replace before use:

- `{{PI_HOST}}` — the Pi's hostname
- `{{SERVER_HOST}}` — the server's hostname
- `{{API_PORT}}` / `{{WEBHOOK_PORT}}` — two free ports
- `{{LANGUAGE}}` — UI language for on-screen copy
- `{{HOUSEHOLD}}` — your people, with a color each
- `{{CALDAV_URL}}` — your calendar server
- `{{LAT}}`, `{{LON}}` — your location for weather

## How to work with an agent on this

1. **One prompt per session.** Start each with the brief (00) loaded.
2. **Ask for a plan first**, then approve it.
3. **Make the agent verify.** Every prompt ends with acceptance checks. Run them
   yourself on the real hardware, not just in the agent's sandbox.
4. **Log decisions** into a `HISTORY.md` as you go. Tell the agent to.
5. **Do not skip a slice.** Later prompts assume the earlier ones exist.
6. **Never paste real credentials into a prompt.** Use environment files that are
   git-ignored, with a committed `.env.example`.

## Prompting style that worked

- State constraints as rules with reasons ("never skip TLS verification: the
  gateway chains to our private root").
- Name the failure mode you already know about. Agents repeat known mistakes
  unless told.
- Say what is out of scope. "Read-only calendar" prevents an agent from
  building event editing.
- Ask for the smallest vertical slice that proves the next layer.
