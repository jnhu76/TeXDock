#!/bin/bash
# TeXDock data backup
#
# Usage:
#   bash scripts/backup.sh [TARGET_DIR] [--tar]
#
# Environment variables (or pass via .env):
#   TEXDOCK_OVERLEAF_DATA_DIR  - Overleaf data directory
#   TEXDOCK_MONGO_DATA_DIR     - MongoDB data directory
#   TEXDOCK_REDIS_DATA_DIR     - Redis data directory
#
# Examples:
#   bash scripts/backup.sh                          # backup to ~/texdock-backups/
#   bash scripts/backup.sh /mnt/usb/texdock         # backup to specified dir
#   bash scripts/backup.sh /mnt/usb/texdock --tar   # backup + tar.gz

set -eo pipefail

DEST="${1:-$HOME/texdock-backups}"
TAR_MODE=false
if [ "$2" = "--tar" ] || [ "$1" = "--tar" ]; then
  TAR_MODE=true
fi

# If --tar is the first argument, use default backup dir
[ "$1" = "--tar" ] && DEST="$HOME/texdock-backups"

# Load env file if present
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . .env
  set +a
fi

# Require data directory env vars
OVERLEAF_DATA="${TEXDOCK_OVERLEAF_DATA_DIR:?Set TEXDOCK_OVERLEAF_DATA_DIR in .env or environment}"
MONGO_DATA="${TEXDOCK_MONGO_DATA_DIR:?Set TEXDOCK_MONGO_DATA_DIR in .env or environment}"
REDIS_DATA="${TEXDOCK_REDIS_DATA_DIR:?Set TEXDOCK_REDIS_DATA_DIR in .env or environment}"

LATEST="$DEST/latest"
SNAPSHOT="$DEST/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$DEST/backup.log"

mkdir -p "$DEST"

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Starting backup -> $DEST" >> "$LOG_FILE"

# rsync incremental sync with --link-dest for hardlinks (no extra space for unchanged files)
LINK_OPT=""
[ -d "$LATEST" ] && LINK_OPT="--link-dest=$LATEST"

rsync -av --delete $LINK_OPT \
  "$MONGO_DATA/"       "$SNAPSHOT/mongo_data/" \
  "$REDIS_DATA/"       "$SNAPSHOT/redis_data/" \
  "$OVERLEAF_DATA/"    "$SNAPSHOT/sharelatex_data/" \
  2>&1 | tee -a "$LOG_FILE"

# Update latest symlink
rm -f "$LATEST"
ln -s "${SNAPSHOT##*/}" "$LATEST"

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Snapshot complete" >> "$LOG_FILE"
echo "Snapshot -> $SNAPSHOT"

# --tar: create tar.gz archive (for offsite/cold backup)
if $TAR_MODE; then
  TAR_FILE="$DEST/texdock-${SNAPSHOT##*/}.tar.gz"
  tar -czf "$TAR_FILE" -C "$SNAPSHOT" mongo_data redis_data sharelatex_data
  echo "Archive -> $TAR_FILE"
fi
