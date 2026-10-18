# Admin interface

A second entry point (`admin.html`) from the same frontend build, for a laptop or phone, not the wall.
Same palette file as the kiosk but a light theme, denser type. One shared API key, entered once and kept in
the browser. No login system, no roles. All routes are in `reference/contract/api.md`.

| Panel | Purpose and behavior |
|---|---|
| **Restaurants** | Add, order and edit restaurants (name, cuisine, color, icon, delivery or pickup or self-cook, ETA, tracking link). Per restaurant: a menu editor (categories and items, pasted YAML is validated first), an optional numbered catalog, and each person's saved "usual" orders. |
| **Schedule** | Time-of-day rules (hour range to default screen) and the idle timeout. The kiosk falls back to a built-in table if this fetch fails. |
| **Calendar** | Server URL, username, write-only password, an allow-list of discovered calendars, and a **test connection** dry run. Saving swaps the live client with no restart. The password is never returned, only whether one is set. |
| **People** | Name, initials, color (used identically on avatars, calendar bars, chore checkboxes), optional NFC fob UID. Deleting a person warns that references elsewhere are not cleaned up. |
| **Chores** | The weekly rotation table (task, weekday, person), edited as validated YAML. |
| **Presence** | Devices per person (IP and/or MAC) with CRUD, and a seven-day home/away graph. A button clears today's history. |
| **Sensors** | Device MAC to room and type (door, leak, temperature, humidity, light), drag to reorder, manual dismiss of latched alerts. |
| **Security** | Reveal and rotate the API key. The four webhook URLs fully formed with tokens and a copy button, labelled by integration (door, motion, presence, sensor), not by which daemon calls them. |
| **Notifications** | Optional incoming-chat-webhook URL for "order is ready to pick up" messages, with a test button. |
| **Data** | Full backup and restore of the data volume, and a raw YAML file editor. This is the escape hatch for anything the panels do not cover. |
| **Activity** | Per-day counts (calendar and weather fetches, touch wake-ups, last motion) to see whether the system is alive. |

Rules that kept the admin code small: shared primitives (field, button, list item) live in one global
stylesheet, panels hold only what is specific to them, and older token names are aliased onto the shared
palette instead of defining a second one.

> Screenshots of the admin panels are not included yet. The kiosk screens are in `images/`.
