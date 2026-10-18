# Multi-stage build: frontend assets + Go binary → one minimal image.
# Template — activate each stage as the corresponding module exists
# (`software/frontend/package.json`, `software/backend/go.mod`).
# Built via `docker buildx build --platform linux/arm/v7 ...` from the
# repo root; see ../../deploy/scripts/build-and-push.sh.

# ---- stage 1: frontend assets ----
FROM node:22-alpine AS frontend
WORKDIR /app
COPY software/frontend/package*.json ./
RUN npm ci
COPY software/frontend/ ./
RUN npm run build

# ---- stage 2: go binary ----
FROM golang:1.23-alpine AS backend
WORKDIR /app
COPY software/backend/go.* ./
RUN go mod download
COPY software/backend/ ./
# VERSION is computed on the host (the git short SHA — see
# deploy/scripts/build-and-push.sh) and baked into the binary, not
# derived from .git inside the build context — keeps the builder image
# from needing git installed, and works the same whether or not the
# build context even includes .git. Surfaced on GET /api/health so a
# deploy can be confirmed by its actual running version instead of
# guessed at from symptoms (see main.go's Version doc comment).
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -ldflags "-X main.Version=${VERSION}" -o /out/server ./cmd/server
# File capability, not root, not relying on Docker's ambient-capability
# propagation to a non-root USER — confirmed on this household's real
# NAS deployment (2026-09-14) that the latter doesn't work
# (docker-compose.yml's `cap_add: [NET_RAW]` showed up correctly in
# `docker inspect`'s HostConfig, but internal/presence's raw ICMP socket
# still failed with "operation not permitted" as the nonroot UID 65532
# process). A file capability is baked directly into the binary and
# applies at exec() regardless of the runtime UID — the standard fix for
# exactly this "non-root process needs one specific capability"
# scenario, and deliberately NOT switching this image to run as root
# (declined explicitly — running the whole server as root for the sake
# of one socket call is a much bigger blast-radius trade than granting
# just NET_RAW to just this one binary). Still needs
# docker-compose.yml's `cap_add: [NET_RAW]` too — a file capability can
# only grant what's already in the container's bounding set.
# Unconfirmed: whether BuildKit's COPY --from= below preserves this
# xattr across stages on every builder/storage-driver combination —
# verify via `getcap /server` inside the running container if presence
# pinging still fails after this change.
RUN apk add --no-cache libcap && setcap cap_net_raw+ep /out/server
# Pre-create /data owned by distroless's standard nonroot UID (65532) —
# an empty named volume mounted over this at runtime inherits both the
# directory *and* its ownership from what was already in the image, so
# this is what makes /data writable by the nonroot stage 3 runs as.
# distroless has no shell to `mkdir`/`chown` in directly, hence doing it
# here in a stage that has one and copying the result across.
RUN mkdir -p /data && chown 65532:65532 /data

# ---- stage 3: runtime ----
FROM gcr.io/distroless/static-debian12:nonroot
# Explicit, not relying on the base image's default (learned the hard
# way: the plain static-debian12 image defaults to "/", but :nonroot
# defaults to "/home/nonroot" — silently changing where every relative
# path below resolves, including cmd/server/main.go's own env-var
# defaults for FRONTEND_DIST_DIR and the data-store paths).
WORKDIR /
COPY --from=backend /out/server /server
COPY --from=backend --chown=65532:65532 /app/data /data
# cmd/server/main.go defaults FRONTEND_DIST_DIR to "../frontend/dist",
# which resolves to /frontend/dist against this image's WORKDIR (/) —
# the extra /dist here isn't decorative, it has to match that default or
# the server logs "no frontend build ... yet" and falls back to
# API-only mode.
COPY --from=frontend /app/dist /frontend/dist
# The NAS's self-signed CalDAV cert (see CLAUDE.md "Real CalDAV
# integration") — a pinned public cert, not a secret, so it's fine baked
# into the image rather than fetched at boot like real credentials.
COPY software/backend/certs /certs
VOLUME /data
EXPOSE {{API_PORT}}
ENTRYPOINT ["/server"]
