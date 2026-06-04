#!/usr/bin/env bash
set -Eeuo pipefail

VENDOR_ROOT="${VENDOR_ROOT:-../texdock-vendor}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.build/context}"
SERVICES_LIST="${SERVICES_LIST:-build/services.txt}"

echo "Preparing build context"
echo "  vendor:   $VENDOR_ROOT"
echo "  context:  $BUILD_CONTEXT"
echo "  services: $SERVICES_LIST"
echo

if ! command -v rsync >/dev/null 2>&1; then
  echo "ERROR: rsync is required but not found" >&2
  exit 1
fi

if [[ ! -d "$VENDOR_ROOT/overleaf/services" ]]; then
  echo "ERROR: vendor services directory not found: $VENDOR_ROOT/overleaf/services" >&2
  exit 1
fi

if [[ ! -f "$SERVICES_LIST" ]]; then
  echo "ERROR: services list not found: $SERVICES_LIST" >&2
  exit 1
fi

# Safety guard for rm -rf.
case "$BUILD_CONTEXT" in
  ""|"/"| "."|".." )
    echo "ERROR: unsafe BUILD_CONTEXT: $BUILD_CONTEXT" >&2
    exit 1
    ;;
esac

rm -rf "$BUILD_CONTEXT"
mkdir -p "$BUILD_CONTEXT"

echo "Copying main project skeleton..."

rsync -a ./ "$BUILD_CONTEXT/" \
  --exclude '.git' \
  --exclude '.build' \
  --exclude 'node_modules' \
  --exclude 'textdock-vendor' \
  --exclude 'texdock-vendor' \
  --exclude 'services' \
  --exclude '*.bak' \
  --exclude '*.backup' \
  --exclude '*.bakcup'

mkdir -p "$BUILD_CONTEXT/services"

echo
echo "Assembling services..."

while IFS= read -r service || [[ -n "$service" ]]; do
  # Trim CRLF and surrounding whitespace.
  service="${service//$'\r'/}"
  service="$(printf '%s' "$service" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  [[ -z "$service" ]] && continue
  [[ "$service" =~ ^# ]] && continue

  # Only allow simple service directory names.
  if [[ ! "$service" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "ERROR: invalid service name in $SERVICES_LIST: $service" >&2
    exit 1
  fi

  MAIN_SERVICE="services/$service"
  VENDOR_SERVICE="$VENDOR_ROOT/overleaf/services/$service"
  TARGET_SERVICE="$BUILD_CONTEXT/services/$service"

  if [[ -d "$MAIN_SERVICE" ]]; then
    echo "  using main service:   $service"
    rsync -a "$MAIN_SERVICE/" "$TARGET_SERVICE/" \
      --exclude 'node_modules' \
      --exclude '.git'
  elif [[ -d "$VENDOR_SERVICE" ]]; then
    echo "  using vendor service: $service"
    rsync -a "$VENDOR_SERVICE/" "$TARGET_SERVICE/" \
      --exclude 'node_modules' \
      --exclude '.git'
  else
    echo "ERROR: service not found in main or vendor: $service" >&2
    exit 1
  fi

  if [[ ! -f "$TARGET_SERVICE/package.json" ]]; then
    echo "ERROR: service missing package.json after copy: $service" >&2
    exit 1
  fi
done < "$SERVICES_LIST"

echo
echo "Build context ready: $BUILD_CONTEXT"
echo
echo "Services in build context:"
find "$BUILD_CONTEXT/services" -maxdepth 1 -mindepth 1 -type d -printf '  %f\n' | sort
