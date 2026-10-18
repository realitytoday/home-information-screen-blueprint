# Lessons learned

Each of these cost real debugging time. They are ordered roughly by how much
time they cost and how likely you are to meet them.

## Process

- **Keep a decision log from day one.** One file with dated entries: what was
  decided, why, the symptom of each failure, and the dead ends. Your future self
  and your coding agent both read it. It is the most valuable artifact of the
  project.
- **Keep the project brief short.** A one-page brief of settled decisions that
  the agent reads at the start of every session beats a long wiki it ignores.
- **Vertical slices, verified on the real hardware.** One working end-to-end
  slice, then the next. Admin screens, integrations and hardware each got
  committed and checked live before the next began.
- **Write "known gaps" down.** An honest list of what is not built stops you
  trusting a feature that does not exist.

## Networking and deployment

- **"Redeploy did nothing."** The first image build pinned `TAG=v1` in the
  environment file while the build script pushed `latest`. Every later pull
  faithfully fetched the same stale image. Fix: default to `latest` everywhere,
  and expose a **version field on a health endpoint** so the running binary can
  tell you which build it is.
- **Cross-VLAN firewall.** If the Pi and the server are on different segments,
  you need rules for both the API port and the webhook port. A direct request
  that returns code 000 after about six seconds is a firewall drop, not a
  refused connection.
- **A host protecting itself blocked itself.** The NAS's login auto-block locked
  out the backend after it tried a missing password, and because the container
  used host networking, requests came from the NAS's own address. Every symptom
  (a 404 serving the NAS login page, then a 401 with the right password) was the
  NAS portal intercepting the request, not a real protocol response. Lesson:
  when "a service works for every client but this one", suspect the host's
  protection mechanism.
- **Distroless images have no shell.** `docker exec ... ls` fails. Mount the
  data volume into a throwaway Alpine container to inspect it.
- **Volume permissions.** Three data subfolders ended up read-only and every
  write under them failed silently with `permission denied` until fixed. Log
  write errors loudly.
- **Self-hosted registry TLS.** The NAS's Docker daemon ignored the standard
  per-registry certificate directory and validated against the system-wide CA
  bundle instead. Appending the private root to that bundle fixed it.

## TLS and private CAs

- The NAS's factory default certificate predates the SAN extension, so there was
  no name to match regardless of trust. Issue a proper certificate from a small
  private CA with the right DNS SAN, trust only that root explicitly in the
  client's cert pool, and **never skip verification**.
- A private CA that publishes no revocation info makes Windows' native tools
  complain about "revocation status unknown". Docker's Go TLS stack is not
  affected; it is a harmless Windows-side quirk.

## Presence

- **Raw ICMP in a container.** On this NAS, the container manager did not
  propagate the raw-socket capability to a non-root process, even with the
  capability explicitly added. Running as root was considered and declined.
  A file capability on the binary may or may not survive a multi-stage image
  build. The robust answer was a small agent on the Pi that does the pinging.
- **Missing environment variables fail silently.** The router credentials existed
  in a developer's local environment file but never in the server's. The client
  stayed null and every device fell through to the broken ping fallback. Always
  log a clear startup line when an integration is not configured.
- **Ping-only presence flaps.** A phone's WiFi radio sleeps and stops answering
  ICMP while still connected. Using the router's connected-client list (MAC plus
  `last_seen`) fixed it.
- **Legacy session login versus the official API key.** The official integration
  API's key needs a cloud-linked admin account, and the menu was missing even for
  eligible accounts on some versions. For an isolated local-only read-only
  account, the legacy session-cookie login is the reliable path (about two hours
  per token, log in again on 401).
- **Isolation, not restriction.** You cannot scope an integration credential to
  least privilege. Create a separate local admin account for it so it is
  independently revocable and has a clear "what is this for" trail.

## Kiosk and display

- **Rotation and touch are not X11.** See the hardware doc. The first launch
  script used X11-only tools that abort the script under Wayland.
- **`mouseEmulation="yes"` breaks touch scrolling.** Set it to `"no"`.
- **`wlr-randr --off` crashes the browser.** Use `wlopm`.
- **Moving the USB cable or board changes the touch device name** and touch
  silently stops working.
- **`.deb` packaging gotchas on first install:** a hardcoded service user that
  did not match the Pi's randomized account (use a documented drop-in override);
  a config directory created root-only while the service ran as a normal user;
  the browser binary name differing between distributions; `Restart=on-failure`
  not catching a clean exit.
- **No shutdown button means hard power cuts.** Patch the browser profile's exit
  state to "normal" at startup to avoid the restore-pages prompt.
- **Svelte compiled bundle stays in memory.** The kiosk loads the app once at
  boot and keeps running that bundle indefinitely. Redeploying the backend does
  not update the screen. Restart the kiosk service after any frontend change.

## Sensors

- **Alarm systems send thresholds, not readings.** Design for "too warm", not a
  number.
- **Leaks latch.** The vendor never sends "cleared". Provide a dismiss on the
  kiosk itself.
- **Per device and trigger key.** One physical unit reports several event types.
  Key events by both, and clear only the type being dismissed, or you wipe the
  sibling tiles' state.
- **MAC format.** Normalize on every write and match.
- **Do not trust the first payload you see.** The generic trigger key looked like
  it carried no detail until a live payload showed the more specific event-key
  suffix and a high/low value.

## Calendar

- **Expand recurring events on the server** with the CalDAV expand request, not
  with an RRULE library.
- **Calendar colors** are an Apple/CalendarServer extension, not core CalDAV. A
  raw property request per calendar fetches them.
- **To-do lists in the same collection** (VTODO only) are not calendars; skip them.

## Design

- **A mockup is not a source of truth for long.** The original design came from
  an interactive HTML mockup that went stale as screens were added. The fix was a
  single palette file plus written rules. Delete the stale reference rather than
  update it, or you recreate the "which one is current?" ambiguity.
- **A second near-duplicate token file** appeared for the admin site and every
  panel had its own copy of card, label and button styles. Consolidate early.
- **Font-size inflation.** Raising the root size to get "panel-sized" steps
  doubled everything. Keep 16 px and pick the right steps.
- **Hand-rolled UI grew unmanageable.** Large per-component style blocks,
  custom icons and translucent tints were rebuilt on a component kit with one
  palette. Start on the kit.

## Hardware

- **A custom enclosure was not worth it.** A cyberdeck-style case with PIR pod,
  RFID pad and LED ring was dropped for the official case on a printed magnetic
  mount. Fit-check before printing; retailer dimensions are not measurements.
- **Plan power.** See the hardware doc.
- **Do not hand-write Wi-Fi and SSH files** to the boot partition; the Pi
  imager's advanced settings do it.
- **Legacy display-power tooling is gone.** The old `tvservice` approach was
  removed on current Raspberry Pi OS; use the compositor's tooling.
