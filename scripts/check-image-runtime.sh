#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-sharelatex/sharelatex:5.5.8}"

echo "🔍 Inspect runtime in image: $IMAGE"
echo

docker run --rm --entrypoint sh "$IMAGE" -lc '
set -e

echo "== OS =="
cat /etc/os-release || true

echo
echo "== Node runtime =="
echo "node: $(node -v 2>/dev/null || echo not-found)"
echo "npm:  $(npm -v 2>/dev/null || echo not-found)"
echo "yarn: $(yarn -v 2>/dev/null || echo not-found)"

echo
echo "== Binary paths =="
command -v node || true
command -v npm || true
command -v yarn || true

echo
echo "== PATH =="
echo "$PATH"

echo
echo "== Node binary detail =="
if command -v node >/dev/null 2>&1; then
  ls -l "$(command -v node)"
fi

echo
echo "== Installed packages =="
if command -v dpkg >/dev/null 2>&1; then
  dpkg -l | grep -E "node|npm|yarn" || true
fi

if command -v apt-cache >/dev/null 2>&1; then
  echo
  echo "== apt policy =="
  apt-cache policy nodejs 2>/dev/null || true
fi
'