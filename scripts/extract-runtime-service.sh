#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${IMAGE:-sharelatex/sharelatex:5.5.8}"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <service-name> [--force]" >&2
  echo "example: $0 web" >&2
  exit 1
fi

SERVICE="$1"
FORCE="${2:-}"

if [[ ! "$SERVICE" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ERROR: invalid service name: $SERVICE" >&2
  exit 1
fi

SRC="/overleaf/services/$SERVICE"
DST="overlays/overleaf/services/$SERVICE"

if [[ -e "$DST" && "$FORCE" != "--force" ]]; then
  echo "ERROR: target already exists: $DST" >&2
  echo "Use --force to overwrite." >&2
  exit 1
fi

TMP="$(mktemp -d)"
CID="$(docker create "$IMAGE")"
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

echo "Extracting runtime service:"
echo "  image:   $IMAGE"
echo "  service: $SERVICE"
echo "  from:    $SRC"
echo "  to:      $DST"
echo

if ! docker cp "$CID:$SRC" "$TMP/service"; then
  echo "ERROR: service not found in image: $SRC" >&2
  exit 1
fi

if [[ -d "$TMP/service/node_modules" ]]; then
  echo "WARNING: $SRC contains node_modules."
  echo "Whole-service bind mount may hide image dependencies if node_modules is excluded."
  echo "This script excludes node_modules by default."
  echo
fi

rm -rf "$DST"
mkdir -p "$DST"

rsync -a "$TMP/service/" "$DST/" \
  --exclude node_modules \
  --exclude .git

echo "Extracted service overlay:"
echo "  $DST"
