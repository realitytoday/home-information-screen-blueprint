# 03 — Kiosk UI

**Context.** Prompts 00 to 02 done; the API serves real or fixture data. This
builds the screen people see. Read `docs/03-design-system.md` before starting.

## Prompt

Build the kiosk frontend with Svelte 5 (runes) + Vite + TypeScript, using
shadcn-svelte primitives, Tailwind v4, one icon set and one variable font. Two
entry points from one build: `index.html` (kiosk) and `admin.html` (admin, built
in prompt 06).

**Design system.** One palette file defines every color; the kiosk loads it
through Tailwind's theme mapping. Rules, all binding:

1. No eyebrow labels. Headings are plain sentence case. A screen never names
   itself.
2. No cards and no borders. Content sits on the page background.
3. No translucent colored fills behind text or icons.
4. Everything round.
5. Color means state, person or restaurant. Nothing else.
6. No monospace.
7. Touch first: nothing tappable under about 66 px; feedback is press-scale,
   never hover.

Use stock Tailwind at a 16 px root. Do not set a larger root size. Pin the dark
theme.

**Shell.** A floating, fully round, icon-only tab bar with seven buttons and a
top bar (time and date left; weather and presence avatars right) on every screen
except Idle. Avatars are solid in the person's color when home and an outline when
away.

**Screens.** Build them in this order, verifying each on the real panel:

1. **Idle:** huge clock and date, a one-line weather summary, presence chips.
2. **Calendar:** rolling 7-day strip with colored dots, a large "next up", one
   continuous list with a red now-line. Read-only. A reload button.
3. **Weather:** animated canvas sky (30 fps cap, paused when hidden, still frame
   under reduced motion), large thin temperature, swipeable 24-hour strip, a chart
   of rain against actual sunshine (smooth the near-square-wave hourly series
   before fitting a spline), stat row, range bars for the week on one shared scale.
4. **Food:** restaurant tiles, random pick, a modal with usuals, cart and status.
   Ordering and payment happen on the restaurant's own site; the screen only tracks.
5. **Chores:** grouped by person, today's chores in a two-column grid, completed
   ones stay visible until rollover.
6. **Sensors:** four sections; abnormal states colored; a solid red banner for any
   active leak with a dismiss button on the row.
7. **Notes:** freeform board of draggable sticky notes. Position normalized 0 to
   1, tilt derived deterministically from the note's ID. Drag versus tap decided
   by distance. Full-screen composer on a large note that recolors live as you
   pick the author, with "show until" presets.

**On-screen keyboard.** Docked, full width, large keys in the local layout, a
one-shot Shift that re-arms at sentence start, backspace that repeats while held,
suggestion strips that insert at the caret. Do **not** use the OS keyboard. Mark
fields `inputmode="none"`. Use a real input (not `readonly`) with real keystrokes
and paste blocked so tapping still places the caret.

**Behaviour.**

- Default screen follows an admin-editable time-of-day schedule; a manual tap
  overrides until the next sleep; wake re-evaluates for the current time.
- An active note outranks the schedule only after the idle timer fires. Only the
  idle timeout and initial page load may force the Notes tab.
- If the backend is unreachable, show last good data with an age indicator in a
  distinct stale color.
- If the schedule fetch fails, fall back to the built-in default table.

## Acceptance checks

- `npm run check` is clean.
- No raw hex, raw pixel size or border in any kiosk component (grep for it).
- Every tappable target is at least 66 px.
- On the real panel: legible from four steps away; finger-drag scrolling works;
  nothing overlaps the tab bar at the bottom.
- Pull the network cable: the screen shows stale data, not an error.
