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

if [[ ! -d "$VENDOR_ROOT/overleaf/services" ]]; then
  echo "ERROR: vendor services directory not found: $VENDOR_ROOT/overleaf/services" >&2
  exit 1
fi

if [[ ! -f "$SERVICES_LIST" ]]; then
  echo "ERROR: services list not found: $SERVICES_LIST" >&2
  exit 1
fi

rm -rf "$BUILD_CONTEXT"
mkdir -p "$BUILD_CONTEXT"

echo "Copying main project skeleton..."

rsync -a ./ "$BUILD_CONTEXT/" \
  --exclude '.git' \
  --exclude '.build' \
  --exclude 'node_modules' \
  --exclude 'textdock-vendor' \
  --exclude 'services'

mkdir -p "$BUILD_CONTEXT/services"

echo "Assembling services..."

while IFS= read -r service; do
  [[ -z "$service" ]] && continue
  [[ "$service" =~ ^# ]] && continue

  MAIN_SERVICE="services/$service"
  VENDOR_SERVICE="$VENDOR_ROOT/overleaf/services/$service"
  TARGET_SERVICE="$BUILD_CONTEXT/services/$service"

  if [[ -d "$MAIN_SERVICE" ]]; then
    echo "  using main service:   $service"
    cp -a "$MAIN_SERVICE" "$TARGET_SERVICE"
  elif [[ -d "$VENDOR_SERVICE" ]]; then
    echo "  using vendor service: $service"
    cp -a "$VENDOR_SERVICE" "$TARGET_SERVICE"
  else
    echo "ERROR: service not found in main or vendor: $service" >&2
    exit 1
  fi
done < "$SERVICES_LIST"

echo
echo "Build context ready: $BUILD_CONTEXT"

