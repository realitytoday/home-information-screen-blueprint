#!/usr/bin/env bash
# Run on the dev machine, never on the server or the Pi. Cross-builds the
# backend image for the SERVER's CPU architecture with Docker Buildx and
# pushes it to your registry.
#
# PLATFORM defaults to linux/amd64. A different NAS or mini PC may need
# linux/arm64: check with `uname -m` on the server before building.
#
# If you run a private registry with a private CA, this dev machine must
# trust that CA for registry pushes (Docker reads ~/.docker/certs.d/<registry>/ca.crt
# only at daemon start, so restart Docker after adding it). Native Windows
# tools may report "revocation status unknown" for a small private CA;
# that is a Schannel quirk, Docker's own TLS stack is unaffected.
set -euo pipefail

REGISTRY="${REGISTRY:-{{SERVER_HOST}}:{{REGISTRY_PORT}}}"
TAG="${TAG:-latest}"
PLATFORM="${PLATFORM:-linux/amd64}"

cd "$(dirname "$0")/../.."

# Baked into the binary and surfaced on GET /api/health — see
# cmd/server/main.go's Version doc comment for why: "did the redeploy
# actually take" stopped being something to guess at from symptoms.
# -dirty means this build didn't come from a clean, pushed commit —
# still fine for local iteration, just worth knowing when comparing
# against what's actually on GitHub.
VERSION="${VERSION:-$(git rev-parse --short HEAD)}"
if ! git diff --quiet || ! git diff --cached --quiet; then
  VERSION="${VERSION}-dirty"
fi
echo "building version: $VERSION"

docker buildx build \
  --platform "$PLATFORM" \
  --build-arg VERSION="$VERSION" \
  -t "$REGISTRY/home-info-backend:$TAG" \
  -f software/backend/Dockerfile \
  --push \
  .
