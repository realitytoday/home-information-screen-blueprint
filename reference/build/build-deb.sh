#!/usr/bin/env bash
# Builds a .deb for the Pi kiosk (NOT rpm — Raspberry Pi OS/Raspbian is
# Debian-based, dpkg/apt, not rpm/yum). Run on the dev machine (or any
# machine with dpkg-deb — that's Debian/Ubuntu/WSL/most Linux; on
# Windows, run this from WSL or the Pi itself). Packages
# deploy/kiosk/kiosk-autostart.sh and deploy/systemd/home-info-kiosk.service
# — the source of truth for both stays those two files, this script just
# assembles them into an installable package rather than requiring a
# manual copy (see provision-pi.sh for that manual fallback).
set -euo pipefail

VERSION="${VERSION:-1.0.0}"
ARCH="all" # shell script + systemd unit, no compiled code — architecture-independent
PKG_NAME="home-info-screen-kiosk"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

PKG_ROOT="$BUILD_DIR/${PKG_NAME}_${VERSION}_${ARCH}"
mkdir -p "$PKG_ROOT/DEBIAN"
mkdir -p "$PKG_ROOT/opt/home-info-screen"
mkdir -p "$PKG_ROOT/etc/systemd/system"
mkdir -p "$PKG_ROOT/etc/home-info-screen"
mkdir -p "$PKG_ROOT/usr/share/applications"

install -m 755 "$DEPLOY_DIR/kiosk/kiosk-autostart.sh" "$PKG_ROOT/opt/home-info-screen/kiosk-autostart.sh"
install -m 644 "$DEPLOY_DIR/systemd/home-info-kiosk.service" "$PKG_ROOT/etc/systemd/system/home-info-kiosk.service"
# Desktop launcher entry so the kiosk can be started manually from the
# desktop's application menu (e.g. after a crash, or for testing)
# without needing SSH — pkexec prompts for auth since the systemd unit
# is a system-level service. Source of truth is the .desktop file
# itself, this script just installs it, same as the two lines above.
install -m 644 "$DEPLOY_DIR/kiosk/home-info-screen-kiosk.desktop" "$PKG_ROOT/usr/share/applications/home-info-screen-kiosk.desktop"

cat > "$PKG_ROOT/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: misc
Priority: optional
Architecture: ${ARCH}
Depends: chromium-browser | chromium, xserver-xorg, xinit, wmctrl, fonts-noto-color-emoji
Maintainer: HomeInformationScreen household <noreply@example.invalid>
Description: HomeInformationScreen kiosk client
 Chromium kiosk-mode launcher and systemd unit for the wall-mounted
 touchscreen — display-only, points at the backend running on the
 NAS. Does not include the backend itself; see the project's
 deploy/docker-compose.yml for that half.
EOF

# conffiles: apt won't silently overwrite an admin's edits to these on
# upgrade/reinstall, since kiosk-autostart.sh is meant to be tweaked
# per-household (KIOSK_OUTPUT, KIOSK_TOUCH_DEVICE, KIOSK_BACKEND_URL).
cat > "$PKG_ROOT/DEBIAN/conffiles" <<EOF
/opt/home-info-screen/kiosk-autostart.sh
EOF

cat > "$PKG_ROOT/DEBIAN/postinst" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p /etc/home-info-screen
# 755, not 700 — the kiosk service runs as a non-root user (see the
# User= warning below), which needs to at least traverse this
# directory to read api-key. The key itself is world-readable (644,
# set where it's written below / in INSTALL.md) rather than
# group-managed, since the service's actual username isn't known at
# package-build time (same reason User= can't be hardcoded reliably —
# see below) and the key is already treated as a low-sensitivity
# access gate elsewhere in this design (passed in a URL query string
# on first kiosk launch). A real secret would need a proper per-user
# group instead; this one doesn't warrant that complexity.
chmod 755 /etc/home-info-screen
systemctl daemon-reload || true

# home-info-kiosk.service hardcodes User=kiosk — if your Pi's real
# account is named anything else (e.g. a randomly-generated username
# from Raspberry Pi Imager's advanced options), the service fails
# immediately with status=217/USER and crash-loops with no window ever
# opening, no obvious error short of `journalctl -u home-info-kiosk`.
# Catch it here instead of leaving it to be discovered that way.
if ! id kiosk >/dev/null 2>&1; then
  echo
  echo "WARNING: no 'kiosk' user exists on this system, but"
  echo "  /etc/systemd/system/home-info-kiosk.service hardcodes User=kiosk."
  echo "  The service WILL fail to start (status=217/USER) until you override it:"
  echo "    sudo systemctl edit home-info-kiosk"
  echo "  and add:"
  echo "    [Service]"
  echo "    User=<your actual username>"
  echo
fi

if [ ! -s /etc/home-info-screen/api-key ]; then
  echo
  echo "home-info-screen-kiosk installed, but not started yet:"
  echo "  1. Get the backend's API key (see deploy/INSTALL.md \"Provision the Pi\")"
  echo "     and write it, with no trailing newline, to:"
  echo "       /etc/home-info-screen/api-key"
  echo "     then: chmod 600 /etc/home-info-screen/api-key"
  echo "  2. sudo systemctl enable --now home-info-kiosk"
  echo
fi
EOF
chmod 755 "$PKG_ROOT/DEBIAN/postinst"

cat > "$PKG_ROOT/DEBIAN/prerm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
systemctl disable --now home-info-kiosk 2>/dev/null || true
EOF
chmod 755 "$PKG_ROOT/DEBIAN/prerm"

OUT_DIR="${OUT_DIR:-$DEPLOY_DIR}"
dpkg-deb --build --root-owner-group "$PKG_ROOT" "$OUT_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"

echo "Built $OUT_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
echo "Install on the Pi with: sudo apt install ./${PKG_NAME}_${VERSION}_${ARCH}.deb"
