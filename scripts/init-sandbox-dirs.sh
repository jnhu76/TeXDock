#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.sandbox}"
MODE="${2:-normal}"

if [ ! -f "$ENV_FILE" ]; then
  echo "error: env file not found: $ENV_FILE" >&2
  echo "usage: $0 .env.sandbox [normal|permissive]" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_vars=(
  TEXDOCK_OVERLEAF_DATA_DIR
  TEXDOCK_MONGO_DATA_DIR
  TEXDOCK_REDIS_DATA_DIR
)

for var in "${required_vars[@]}"; do
  value="${!var:-}"
  if [ -z "$value" ]; then
    echo "error: $var is not set in $ENV_FILE" >&2
    exit 1
  fi

  case "$value" in
    /*) ;;
    *)
      echo "error: $var must be an absolute path, got: $value" >&2
      exit 1
      ;;
  esac

  if [ "$value" = "/" ]; then
    echo "error: $var must not be /" >&2
    exit 1
  fi
done

OVERLEAF_COMPILES_DIR="$TEXDOCK_OVERLEAF_DATA_DIR/data/compiles"
OVERLEAF_OUTPUT_DIR="$TEXDOCK_OVERLEAF_DATA_DIR/data/output"
OVERLEAF_TMP_DIR="$TEXDOCK_OVERLEAF_DATA_DIR/tmp"

echo "== Create host directories =="

sudo mkdir -p \
  "$TEXDOCK_OVERLEAF_DATA_DIR" \
  "$OVERLEAF_COMPILES_DIR" \
  "$OVERLEAF_OUTPUT_DIR" \
  "$OVERLEAF_TMP_DIR" \
  "$TEXDOCK_MONGO_DATA_DIR" \
  "$TEXDOCK_REDIS_DATA_DIR"

echo "== Set Overleaf compile/output permissions =="

# www-data in the web container and TeXLive sibling compile user both use uid/gid 33.
sudo chown -R 33:33 \
  "$OVERLEAF_COMPILES_DIR" \
  "$OVERLEAF_OUTPUT_DIR" \
  "$OVERLEAF_TMP_DIR"

if [ "$MODE" = "permissive" ]; then
  echo "== chmod 777 for debugging =="
  sudo chmod -R 777 \
    "$OVERLEAF_COMPILES_DIR" \
    "$OVERLEAF_OUTPUT_DIR" \
    "$OVERLEAF_TMP_DIR"
else
  echo "== chmod 775 =="
  sudo chmod -R 775 \
    "$OVERLEAF_COMPILES_DIR" \
    "$OVERLEAF_OUTPUT_DIR" \
    "$OVERLEAF_TMP_DIR"
fi

echo
echo "OK."
echo "Overleaf data: $TEXDOCK_OVERLEAF_DATA_DIR"
echo "Compiles:      $OVERLEAF_COMPILES_DIR"
echo "Output:        $OVERLEAF_OUTPUT_DIR"
echo "Mongo data:    $TEXDOCK_MONGO_DATA_DIR"
echo "Redis data:    $TEXDOCK_REDIS_DATA_DIR"