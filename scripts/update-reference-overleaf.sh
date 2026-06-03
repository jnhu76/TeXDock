#!/usr/bin/env bash
set -euo pipefail

REMOTE="reference-overleaf"
URL="https://github.com/overleaf/overleaf.git"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not inside a git repository"
  exit 1
fi

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "Adding reference remote: $REMOTE"
  git remote add "$REMOTE" "$URL"
else
  echo "Reference remote already exists: $REMOTE"
fi

# Avoid importing Overleaf tags into this repository.
git config "remote.${REMOTE}.tagOpt" --no-tags

echo "Fetching latest reference code from $URL ..."
git fetch --prune "$REMOTE"

echo
echo "Latest commits on ${REMOTE}/main:"
git log --oneline --decorate -n 10 "${REMOTE}/main"

echo
echo "Done."
echo "This script only fetches reference code. It does not merge anything."
echo
echo "Useful commands:"
echo "  git show ${REMOTE}/main:path/to/file"
echo "  git diff master..${REMOTE}/main -- path/to/file"
echo "  git switch --detach ${REMOTE}/main"

