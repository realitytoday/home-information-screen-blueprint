#!/usr/bin/env bash
# Cross-compiles software/motion-agent for the Pi (linux/arm64 — the
# household's Pi 4B is aarch64) and, if PI_HOST is set, installs it +
# the systemd unit over SSH and restarts the service.
# Unlike the backend (see build-and-push.sh), this never goes through
# Docker/the registry — it's a single static Go binary running directly
# on the Pi, same "no Docker on the Pi" stance as the kiosk itself (see
# CLAUDE.md "Architecture").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$DEPLOY_DIR/.." && pwd)"
AGENT_DIR="$REPO_DIR/software/motion-agent"
OUT_DIR="${OUT_DIR:-$DEPLOY_DIR/motion-agent}"
BIN_NAME="motion-agent"

mkdir -p "$OUT_DIR"
echo "Cross-compiling $BIN_NAME for linux/arm64 ..."
(cd "$AGENT_DIR" && GOOS=linux GOARCH=arm64 go build -o "$OUT_DIR/$BIN_NAME" ./...)
echo "Built $OUT_DIR/$BIN_NAME"

if [ -z "${PI_HOST:-}" ]; then
  echo
  echo "PI_HOST not set — binary built locally only. To install manually:"
  echo "  scp $OUT_DIR/$BIN_NAME <PI_HOST>:/tmp/motion-agent"
  echo "  ssh <PI_HOST> 'sudo install -m 755 /tmp/motion-agent /opt/home-info-screen/motion-agent'"
  echo "  ssh <PI_HOST> 'sudo install -m 644 /etc/systemd/system/home-info-motion-agent.service -' < $DEPLOY_DIR/systemd/home-info-motion-agent.service"
  echo "  ssh <PI_HOST> 'sudo systemctl daemon-reload && sudo systemctl enable --now home-info-motion-agent'"
  echo "See deploy/motion-agent/motion-agent.env.example for the config file it also needs."
  exit 0
fi

echo "Installing to $PI_HOST ..."
ssh "$PI_HOST" "sudo mkdir -p /opt/home-info-screen /etc/home-info-screen"
scp "$OUT_DIR/$BIN_NAME" "$PI_HOST:/tmp/$BIN_NAME"
ssh "$PI_HOST" "sudo install -m 755 /tmp/$BIN_NAME /opt/home-info-screen/$BIN_NAME"
scp "$DEPLOY_DIR/systemd/home-info-motion-agent.service" "$PI_HOST:/tmp/home-info-motion-agent.service"
ssh "$PI_HOST" "sudo install -m 644 /tmp/home-info-motion-agent.service /etc/systemd/system/home-info-motion-agent.service"

if ssh "$PI_HOST" "test -f /etc/home-info-screen/motion-agent.env"; then
  echo "/etc/home-info-screen/motion-agent.env already exists on $PI_HOST — leaving it as-is."
else
  scp "$DEPLOY_DIR/motion-agent/motion-agent.env.example" "$PI_HOST:/tmp/motion-agent.env"
  ssh "$PI_HOST" "sudo install -m 600 /tmp/motion-agent.env /etc/home-info-screen/motion-agent.env"
  echo "Installed a blank config at /etc/home-info-screen/motion-agent.env on $PI_HOST — set MOTION_WEBHOOK_URL there (see the admin page's admin site Presence panel), then restart the service."
fi

ssh "$PI_HOST" "sudo systemctl daemon-reload && sudo systemctl enable --now home-info-motion-agent && sudo systemctl restart home-info-motion-agent"
echo "Done. Check: ssh $PI_HOST 'journalctl -u home-info-motion-agent -n 30 --no-pager'"
