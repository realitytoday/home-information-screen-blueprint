# AGENTS.md

Instructions for AI coding agents (Claude Code, Codex, Cursor, Copilot and similar) that read this repository.

## What this repository is

A **blueprint**, not an application. It describes a wall-mounted family information display (Raspberry Pi
kiosk plus a small home server) well enough for you to build a local version. It holds documentation,
build prompts, and sanitized reference material. It does **not** contain the backend or frontend source code.

If a user points you here and asks you to build it, you are the builder. Build it in the user's own
project folder, never inside this repository.

## How to read it

Read in this order before writing any code:

1. `README.md`: what the system does and what is included.
2. `docs/01-concept.md`, then `docs/02-architecture.md`: the settled decisions and the reasons.
3. `docs/03-design-system.md`: the UI rules. `reference/design/theme.css` is the only palette.
4. `docs/04-hardware.md` and `docs/05-lessons-learned.md`: wiring, Wayland setup, and failures that
   already cost hours. Do not rediscover them.
5. `reference/README.md`: what each reference folder is for.
6. `prompts/README.md`, then the prompts in order.

## How to build from it

- **One prompt per session, in order** (`prompts/01` to `06`). Later prompts assume earlier slices work.
- **Start the user's project with the brief:** copy `prompts/00-project-brief.md` into the user's project
  root as `CLAUDE.md` or `AGENTS.md` and fill in the `{{placeholders}}` with the user. Do not guess hostnames,
  ports, calendar URLs or locations.
- **Propose a plan first**, wait for approval, then build. Run each prompt's acceptance checks and report
  the results honestly. A check you could not run is not a pass.
- **Prefer the prompt's rules over your habits.** Several rules look unusual and exist because of a past
  failure (standard library only, YAML instead of a database, polling instead of WebSockets, `wlopm` not
  `wlr-randr --off`, `mouseEmulation="no"`, never skip TLS verification).
- **Treat `reference/` as the target behavior, not a drop-in install.** Adapt GPIO pins, output names,
  device names, ports and paths to the user's hardware.
- **Match the UI visually.** Use `docs/images/` as the visual target. Screenshot each screen at 1080x1920,
  compare against the matching image, and adjust until it is close. Use only the colors in `theme.css`.
- **Verify on the real hardware** wherever a prompt says so. A kiosk that works in your sandbox may not
  work on the Pi.

## Hard rules for anything you generate

- No credentials, tokens or API keys in code, prompts or commits. Use git-ignored environment files with a
  committed `.example`.
- Never disable TLS verification. Use the user's private CA through an explicit certificate pool.
- Keep the user's real names, addresses and network details out of anything they will publish.
- Do not add features the prompts mark as out of scope (per-person authentication, chore editing in the UI,
  NFC and LED hardware are documented as not built).

## Gaps you should say out loud

- Screenshots of the admin panels are not included.
- The Chromium exit-state patch under `reference/pi/kiosk/` is an unverified sketch.
- The presence agent is optional and was switched off in the reference setup.
- UI fidelity beyond the palette, rules and screenshots depends on your own judgment.

## If you are editing this repository

- Keep the repo free of application code, real names, hostnames, IPs, ports, tokens and certificates.
  The demo household is Tom, Lena, Ben, Paul and Mia; use only those.
- Keep `README.md` and `README.de.md` in step, and the placeholders in `prompts/README.md` complete.
- Code under `reference/` is MIT, text under `docs/`, `prompts/` and the READMEs is CC BY 4.0.
- Search the diff for forbidden details before committing.
