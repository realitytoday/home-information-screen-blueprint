#!/usr/bin/env bash
# Launches Chromium in kiosk mode pointed at the backend. Runs natively on
# the Pi (not in Docker): it needs direct GPU and touch access.
#
# The backend runs on the server, not the Pi. Override KIOSK_BACKEND_URL
# (host AND port live in this one variable) if that address changes.
#
# Rotation and touch are NOT handled here. Raspberry Pi OS Trixie runs
# labwc (Wayland), so the X11 tools xrandr/xinput do not just no-op, they
# fail outright, and with `set -e` they would kill this script before it
# reaches Chromium. Both are persistent desktop-session settings:
#   - rotation: Preferences > Control Center > Screens > Screen Orientation
#     (270 for a panel mounted rotated 90 degrees left)
#   - touch: ~/.config/labwc/rc.xml, see labwc-rc.xml.example
#     (mouseEmulation MUST be "no", otherwise finger-drag scrolling breaks)
set -euo pipefail

# Binary name varies by distro: Debian's own package is "chromium";
# Ubuntu/some Raspberry Pi OS builds use "chromium-browser" instead —
# see DEBIAN/control's `chromium-browser | chromium` Depends
# alternatives, which anticipates either. Confirmed on this household's
# actual Trixie install: it's "chromium", not "chromium-browser" — an
# earlier version of this script hardcoded the wrong one and failed
# with "exec: chromium-browser: not found" every launch.
CHROMIUM_BIN="$(command -v chromium || command -v chromium-browser || true)"
if [ -z "$CHROMIUM_BIN" ]; then
  echo "kiosk-autostart: neither chromium nor chromium-browser found on PATH" >&2
  exit 1
fi

BACKEND_URL="${KIOSK_BACKEND_URL:-http://{{SERVER_HOST}}:{{API_PORT}}}"
# The API key that gets the kiosk past RequireAPIKey (see
# internal/api/apikey.go) — provisioned onto the Pi as a plain file
# during setup (see ../INSTALL.md "Provision the Pi"), not baked into
# this script or checked into git. The frontend reads it once from this
# URL's query string and persists it itself from then on (see
# software/frontend/src/lib/api.ts), so it only needs to be here for the
# very first launch after a fresh flash.
API_KEY_FILE="${KIOSK_API_KEY_FILE:-/etc/home-info-screen/api-key}"
if [ ! -r "$API_KEY_FILE" ]; then
  echo "kiosk-autostart: $API_KEY_FILE not found — see ../INSTALL.md \"Provision the Pi\" to fetch the key from the backend first" >&2
  exit 1
fi
API_KEY="$(tr -d '[:space:]' < "$API_KEY_FILE")"

# --disable-gpu: CONFIRMED needed on this actual Pi 3
# (2026-09-13) — without it, Chromium's GPU process fails to init
# ("GLES3 is unsupported and ES version fallback is disabled" — the
# VideoCore IV/Mesa V3D driver on a Pi 3 doesn't meet what Chromium
# wants by default) and falls back to software rendering *without*
# this flag telling it to skip the attempt cleanly, which pegged a
# single core at ~93% CPU and made the UI completely unresponsive.
# This isn't a one-time startup cost — it recurs on every launch and
# stays bad during any active rendering. Our UI has no WebGL/3D, so a
# clean software-rendering path (what this flag goes straight to,
# skipping the failed GPU attempt) is entirely adequate.
# --disable-background-networking: this kiosk has no legitimate use for
# Chromium's background Google services (push notification/GCM
# registration, safe-browsing/variations fetches, etc.) — confirmed on
# real hardware (2026-09-13) these were retrying every 30-90s and
# eventually hit QUOTA_EXCEEDED from Google's own rate limiting, pure
# wasted background activity on an already CPU-constrained device.
#
# --window-size/--window-position: CONFIRMED needed on this household's
# actual hardware (2026-09-13), on top of --kiosk. --kiosk's own
# fullscreen negotiation (EWMH _NET_WM_STATE_FULLSCREEN) does not
# actually resize Chromium's content viewport under this labwc/
# Xwayland-rootless setup — the OUTER X11 window frame reports the
# correct 1080x1920 (confirmed via `wmctrl -l -G`), but Chromium's own
# `window.innerWidth`/`innerHeight` stayed stuck at its small ~1050x695
# startup default, so the app rendered tiny and top-left-anchored with
# the rest of the screen empty. Explicitly resizing the SAME window via
# `wmctrl -r ... -e` after launch (as a live test) fixed it immediately
# and correctly propagated a resize to the page — proving resize events
# do work here, --kiosk's own fullscreen path just never triggers one.
# KIOSK_WIDTH/KIOSK_HEIGHT default to this panel's native portrait
# canvas (see CLAUDE.md "Hardware target & constraints") — override if
# a future panel uses a different resolution.
KIOSK_WIDTH="${KIOSK_WIDTH:-1080}"
KIOSK_HEIGHT="${KIOSK_HEIGHT:-1920}"

"$CHROMIUM_BIN" \
  --kiosk \
  --disable-gpu \
  --disable-background-networking \
  --window-size="${KIOSK_WIDTH},${KIOSK_HEIGHT}" \
  --window-position=0,0 \
  --disable-features=Translate \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --overscroll-history-navigation=0 \
  --disable-pinch \
  --check-for-update-interval=31536000 \
  "${BACKEND_URL}/?apikey=${API_KEY}" &
CHROMIUM_PID=$!

# Belt-and-suspenders: --window-size alone may also lose to --kiosk's
# own fullscreen negotiation (same underlying bug), so force the
# geometry again once the window actually exists via wmctrl, which is
# confirmed to correctly trigger a real resize event on this compositor
# where --kiosk's own request doesn't. wmctrl isn't a declared package
# Depends (see DEBIAN/control) — skip quietly if it's missing rather
# than fail the whole kiosk launch over a fallback measure.
if command -v wmctrl >/dev/null; then
  for _ in $(seq 1 20); do
    # The trailing `|| true` is load-bearing, separately from the `if`
    # fix below: `wmctrl -l` genuinely fails outright on this Pi's
    # actual compositor (labwc's Xwayland-rootless bridge) — confirmed
    # live (2026-09-14) via `wmctrl -l` printing "Cannot get client
    # list properties (_NET_CLIENT_LIST or _WIN_CLIENT_LIST)" and
    # exiting 1, every single time, not merely "no window yet". Under
    # `set -eo pipefail`, that nonzero exit propagates through the pipe
    # into this assignment's own exit status, which — unlike the `&&`
    # case below — `set -e` DOES treat as fatal (a failing command
    # substitution inside a plain assignment is not exempt). Without
    # `|| true` here, the script dies on the very first loop iteration
    # regardless of the `if` fix, since this line runs first.
    WIN_ID="$(wmctrl -l 2>/dev/null | awk '/HomeInformationScreen/{print $1; exit}')" || true
    # NOT `[ -n "$WIN_ID" ] && break` — under `set -e`, a top-level
    # "&&" list whose left-hand test is false makes the WHOLE list's
    # exit status 1 (bash only exempts non-final commands in a list,
    # and here the test IS non-final, but the compound statement's own
    # overall exit status is still fatal to `set -e` when it's false).
    # WIN_ID is empty on effectively every first check (Chromium's
    # window doesn't exist yet the instant it's launched), so this
    # killed kiosk-autostart.sh — silently, no error message, since
    # nothing failed loudly, `set -e` just exited — on every single
    # real launch. Confirmed via `bash -x` on the actual Pi
    # (2026-09-14): the trace stops dead right after `+ WIN_ID=`
    # (empty), matching a real, 100%-reproducible crash loop.
    if [ -n "$WIN_ID" ]; then
      break
    fi
    sleep 0.5
  done
  if [ -n "${WIN_ID:-}" ]; then
    wmctrl -i -r "$WIN_ID" -e "0,0,0,${KIOSK_WIDTH},${KIOSK_HEIGHT}" || true
  fi
fi

wait "$CHROMIUM_PID"
