#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${IMAGE:-sharelatex/sharelatex:5.5.8}"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 /overleaf/path/to/dir [--force]" >&2
  exit 1
fi

SRC="$1"
FORCE="${2:-}"

if [[ "$SRC" != /overleaf/* ]]; then
  echo "ERROR: source path must start with /overleaf/: $SRC" >&2
  exit 1
fi

REL="${SRC#/overleaf/}"
DST="overlays/overleaf/$REL"

if [[ -e "$DST" && "$FORCE" != "--force" ]]; then
  echo "ERROR: target already exists: $DST" >&2
  echo "Use --force to overwrite." >&2
  exit 1
fi

TMP="$(mktemp -d)"
CID="$(docker create "$IMAGE")"
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

docker cp "$CID:$SRC" "$TMP/extracted"

rm -rf "$TMP/extracted/node_modules"

rm -rf "$DST"
mkdir -p "$DST"

rsync -a "$TMP/extracted/" "$DST/" \
  --exclude node_modules \
  --exclude .git

echo "Extracted directory:"
echo "  image: $IMAGE"
echo "  from:  $SRC"
echo "  to:    $DST"
