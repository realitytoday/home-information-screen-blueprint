#!/usr/bin/env bash
# UNVERIFIED SKETCH. This was described and planned in the original project
# but never automated or tested on hardware there. Treat it as a starting
# point and verify it with a hard power cut.
#
# Why: a wall appliance has no shutdown button, so unplugging IS "off".
# Chromium then shows a "Restore pages?" bubble on the next start.
# Fix: before launching Chromium, mark the previous exit as clean.
# Call this at the top of kiosk-autostart.sh, before the chromium line.
set -u
PROFILE="${KIOSK_PROFILE_DIR:-$HOME/.config/chromium/Default}"
PREFS="$PROFILE/Preferences"
if [ -f "$PREFS" ]; then
  sed -i \
    -e 's/"exited_cleanly":false/"exited_cleanly":true/' \
    -e 's/"exit_type":"Crashed"/"exit_type":"Normal"/' \
    "$PREFS" || true
fi
