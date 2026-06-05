#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-sharelatex/sharelatex:5.5.8}"

TMP="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

echo "== Save image =="
echo "IMAGE: $IMAGE"
docker save "$IMAGE" -o "$TMP/image.tar"

echo "== Unpack image tar =="
tar -C "$TMP" -xf "$TMP/image.tar"

echo
echo "== Search layer tar files =="
echo

patterns=(
  "overleaf/tools/migrations"
  "overleaf/.yarn/patches"
  "overleaf/yarn.lock"
  "overleaf/.yarnrc.yml"
)

found=0

while IFS= read -r layer; do
  echo "-- layer: ${layer#$TMP/}"

  for p in "${patterns[@]}"; do
    if tar -tf "$layer" 2>/dev/null | grep -F "$p" >/dev/null; then
      echo "  FOUND: $p"
      tar -tf "$layer" 2>/dev/null | grep -F "$p" | head -30
      found=1
    fi
  done

done < <(find "$TMP" -type f -name "layer.tar" -o -name "*.tar" | sort)

echo
if [[ "$found" -eq 0 ]]; then
  echo "No matching files found in saved image layers."
else
  echo "Some matching files were found in layers."
fi
