# 06 — Admin site

**Context.** Everything else works but is configured by editing files. This adds
a second entry point so a household member can change settings without SSH.

## Prompt

Build `admin.html` from the same frontend project, sharing the palette file with
the kiosk but in a **light** theme. The admin site may use a compact, denser
scale than the kiosk. It is for a laptop, not the wall.

**Access.** Everything behind the shared API key, entered once in a prompt,
verified against a real endpoint, kept in the browser. No login system, no roles.
Say so in the UI docs.

**Sections.**

1. **Restaurants and menus:** CRUD plus a per-shop menu editor, and per-person
   "usual" orders.
2. **Security and API key:** reveal and regenerate the key; show the four webhook
   URLs fully formed with a copy button, labelled by integration, not by which
   daemon calls them.
3. **Screen schedule:** time-of-day default screens and the idle timeout. The
   kiosk falls back to the built-in table if this fetch fails.
4. **Calendar:** server URL, credentials, an allow-list of calendars, a
   test-connection dry run. A save takes effect with **no restart** (swap the
   service pointer live). The password is write-only: the server never returns it,
   only whether one is set.
5. **Presence:** devices (person to IP and/or MAC) with CRUD and the 7-day graph.
6. **People:** name, initials, color, optional fob UID. Deleting a person warns
   that references elsewhere are not cleaned up; do not fake a cascade.
7. **Sensors:** device MAC to room and type, drag to reorder, manual dismiss.

**Rules.**

- Shared primitives (field, button, list item) live in one global stylesheet so a
  panel's own style block contains only what is specific to it.
- No per-panel copies of card, label or button styles.
- Aliasing the older token names onto the shared palette is fine; defining a
  second palette is not.

**Out of scope.** Per-person login or roles, chore-definition editing, a real
fob reader.

## Acceptance checks

- Change the calendar password in the UI; the next fetch uses it with no restart;
  the browser never receives it back.
- Add a presence device in the UI and see it in the next poll.
- Search the admin source: no second palette file, no duplicated button style.
