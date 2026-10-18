#!/usr/bin/env bash
# Run on the dev machine. Pulls the latest pushed backend image on the
# NAS and restarts it — the backend runs there, not on the Pi
# (see CLAUDE.md "Architecture"). Only useful if the NAS has SSH enabled
# and you're managing the stack via `docker compose` rather than
# Container Manager's own UI (its "Add From File" / registry-pull flow
# does the equivalent without this script — see ../../INSTALL.md).
set -euo pipefail

NAS_HOST="${NAS_HOST:?set NAS_HOST, e.g. admin@{{SERVER_HOST}}}"
REMOTE_DIR="${REMOTE_DIR:-/volume1/docker/home-info-screen}"

# Sync deploy/ (compose file, .env) — not the software/ source, only the
# built image is ever pulled by the NAS.
rsync -az --delete --exclude kiosk --exclude systemd "$(dirname "$0")/.." "$NAS_HOST:$REMOTE_DIR/deploy"

ssh "$NAS_HOST" "cd $REMOTE_DIR/deploy && docker compose pull && docker compose up -d"
