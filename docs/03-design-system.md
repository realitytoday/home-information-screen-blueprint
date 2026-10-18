# Design system: "Ruhe" (calm)

A wall panel hangs there sixteen hours a day with nobody looking. It must be
legible in two seconds from four steps away and restful the rest of the time.
Both point the same way: **big type, few colors, nothing drawn that does not
need to be.**

## The rules

1. **No eyebrows.** No small uppercase label above a block. A group that needs a
   name gets a plain sentence-case heading at readable size. A screen never
   names itself.
2. **No cards.** Content sits directly on the page background. Space and type
   weight separate things. The only raised surfaces are the floating tab bar,
   dialogs and sticky notes. No borders around anything.
3. **No translucent tints.** Never a half-transparent colored fill behind text
   or an icon. A thing is either solid or sits on the page with colored text.
4. **Round.** Buttons, pills, avatars and the tab bar are fully round; tiles and
   dialogs use large radii. Nothing square.
5. **Color is information.** Chrome is neutral (the primary action is near-white
   on near-black). Color means exactly one of:
   - **State:** destructive, warning, success, info, plus a sun/rain pair for
     weather. Calm states stay neutral; only the abnormal one gets color.
   - **Person:** an admin-picked color per household member, used identically on
     avatars, calendar bars and chore checkboxes. Choose the ink color of the
     initials per background for contrast.
   - **Restaurant:** the tile color, same idea.
6. **No monospace.** One typeface everywhere; tabular numerals where digits must
   line up.
7. **Touch first.** Nothing tappable under roughly 66 px. Main actions 64 to
   80 px tall. Feedback is a press-scale, never hover.

## One palette file

Exactly one file defines colors; the kiosk and the admin site both load it. A raw
hex value, pixel size or border in a kiosk component is a bug. Dark theme for the
kiosk (pinned, because it is a wall fixture and must not follow a laptop's
light preference), a light theme for the admin site, same token names.

| Token | Value | Use |
|---|---|---|
| background | `#111215` | the page |
| foreground | `#f4f4f5` | text |
| muted-foreground | `#a8a8b0` | secondary text |
| faint | `#74747c` | tertiary text, the past part of a chart line |
| secondary | `#2a2b30` | resting buttons, keys, inputs |
| popover | `#1d1e22` | tab bar, dialogs |
| primary | `#f4f4f5` on `#111215` | the one main action, the active tab |
| state colors | red / amber / green / blue, 400 weight | state only |

## Scale

Stock Tailwind at the browser's 16 px root. Row titles 24 px, section headings
30 px, body 18 to 20 px, the idle clock about 176 px, main buttons 64 px.

> A pass that raised the root font size to 22 px "so stock steps would be panel
> sized" made everything about twice as big. Do not. Nothing in a kiosk
> component uses raw px.

## Global chrome

- **Floating tab bar:** a fully round pill above the bottom edge with seven
  icon-only buttons. The active one is a solid light circle. Screens pad their
  bottom so content scrolls clear of it.
- **Top bar** on every screen except Idle: time and date stacked on the left;
  weather and presence avatars on the right. An avatar is solid in the person's
  color when home and an outline ring when away.

## Screen details worth copying

**Calendar.** A rolling seven days starting today (not Monday to Sunday), each a
date in a circle with up to four dots in the colors of whoever has something that
day. "Next up" shows the running event ("until 14:30") or the next timed one
("in 25 min", "tomorrow at 14:00"). One continuous list, not a day/week toggle.
Finished events go grey; a red now-line marks the time. An empty day is one faint
line. A reload button forces a fetch past the cache.

**Weather.** Animated canvas sky behind the top (sun glow or stars, drifting
clouds, rain streaks and droplets, snow, fog, lightning), capped at 30 fps,
paused when hidden, a still frame under reduced-motion, faded into the page with
an eased gradient. A large thin temperature, a swipeable 24-hour strip, a chart
of rain probability against **actual sunshine duration** (a real forecast
quantity, not 100 % minus rain; the nearly square-wave hourly data is smoothed
before a spline goes through it), a stat row, then range bars for the week on one
shared scale colored by a temperature ramp. Dust events can override the icon.

**Chores.** Grouped by person; today's chores in a two-column grid. Completed
chores stay visible (struck through, checkbox filled with the person's color)
until day rollover, so the whole day reads at a glance.

**Sensors.** Normal states neutral, abnormal states colored. Water leaks get a
solid red banner at the top of the screen.

**Notes.** A freeform board. Each note is draggable at a normalized 0 to 1 x/y
persisted to the backend and tilted a few degrees *deterministically from its
ID* so the board looks hand-placed without jittering on every render. A note
looks like paper: the author's color mixed toward paper so dark ink always reads,
a darker glue strip along the top, a lifted bottom corner. Composing is
full-screen on a large note that recolors live as you pick the author, with
"show until" presets (30 min, 1 h, 2 h, tonight, tomorrow morning) instead of a
calendar widget.

**Drag versus tap** is decided by distance: movement past a small threshold
commits a new position, below it the note reopens for editing. The dismiss
control must stop its pointer events from reaching the drag handler.

**On-screen keyboard.** The OS keyboard is deliberately not used (it only reaches
native-Wayland browsers, and the kiosk runs under Xwayland). Build a docked,
full-width keyboard with big keys in the local layout, a one-shot Shift that
re-arms at each sentence start, backspace that repeats while held, and quick-fill
suggestion strips that insert at the caret. Mark text fields `inputmode="none"`.
A real input (not `readonly`, which suppresses the caret) with real keystrokes
blocked, so tapping still places the caret.

## Interaction principles

- Default screen by time of day; manual tap overrides until sleep.
- Wake returns to what the schedule says, not what was open.
- A falling-back-to-Notes switch is immediate when a note fires after idle,
  because that is always someone standing at the screen.
- Pull-to-refresh has a single cap and spins for a full second so it feels real.

## Logos and trademarks

If you show restaurant brand marks, that is fine privately and a problem in
anything you distribute. Use geometric icons in anything public.
