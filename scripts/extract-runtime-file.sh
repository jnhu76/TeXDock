#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${IMAGE:-sharelatex/sharelatex:5.5.8}"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 /overleaf/path/to/file [--force]" >&2
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

mkdir -p "$(dirname "$DST")"

CID="$(docker create "$IMAGE")"
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' EXIT

docker cp "$CID:$SRC" "$DST"

echo "Extracted:"
echo "  image: $IMAGE"
echo "  from:  $SRC"
echo "  to:    $DST"
