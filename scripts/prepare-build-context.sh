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

echo
echo "Normalizing local workspace dependencies..."

python3 - "$BUILD_CONTEXT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])

workspace_names = set()

# Collect workspace package names.
for base in ["libraries", "services", "tools"]:
    base_dir = root / base
    if not base_dir.exists():
        continue

    for package_json in base_dir.glob("*/package.json"):
        try:
            data = json.loads(package_json.read_text())
        except Exception:
            continue

        name = data.get("name")
        if name:
            workspace_names.add(name)

# Also handle known unscoped internal package names.
# They should already be collected if their package.json is present.
sections = [
    "dependencies",
    "devDependencies",
    "peerDependencies",
    "optionalDependencies",
]

changed_files = []

for package_json in root.glob("**/package.json"):
    if "node_modules" in package_json.parts:
        continue

    try:
        data = json.loads(package_json.read_text())
    except Exception as exc:
        raise SystemExit(f"ERROR: failed to parse {package_json}: {exc}")

    changed = False

    for section in sections:
        deps = data.get(section)
        if not isinstance(deps, dict):
            continue

        for dep_name, dep_range in list(deps.items()):
            if dep_name in workspace_names and dep_range == "*":
                deps[dep_name] = "workspace:*"
                changed = True

    if changed:
        package_json.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n"
        )
        changed_files.append(str(package_json.relative_to(root)))

print("Workspace packages:")
for name in sorted(workspace_names):
    print(f"  {name}")

print()
if changed_files:
    print("Normalized package.json files:")
    for path in changed_files:
        print(f"  {path}")
else:
    print("No package.json files needed normalization.")
PY
