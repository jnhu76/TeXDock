#!/usr/bin/env bash
set -euo pipefail

REMOTE="reference-overleaf"
URL="https://github.com/overleaf/overleaf.git"

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "Adding reference remote: $REMOTE"
  git remote add "$REMOTE" "$URL"
fi

echo "Fetching latest reference code..."
git fetch --prune "$REMOTE"

echo
echo "Latest reference-overleaf/main:"
git log --oneline --decorate -n 10 "$REMOTE/main"

echo
echo "Done. This script only fetches reference code. It does not merge anything."

