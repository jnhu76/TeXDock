#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-sharelatex/sharelatex:5.5.8}"
CONTAINER_NAME="texdock_reverse_extract_$$"

echo "== Reverse copy Dockerfile-mapped files from image =="
echo "IMAGE: $IMAGE"
echo

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "❌ image not found locally: $IMAGE" >&2
  echo "Run:" >&2
  echo "  docker pull $IMAGE" >&2
  exit 1
fi

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

docker run -d \
  --name "$CONTAINER_NAME" \
  --entrypoint sh \
  "$IMAGE" \
  -lc 'sleep infinity' >/dev/null

resolve_path() {
  local image_path="$1"

  docker exec "$CONTAINER_NAME" sh -lc "
    if [ ! -e '$image_path' ]; then
      exit 42
    fi

    if command -v readlink >/dev/null 2>&1; then
      readlink -f '$image_path' 2>/dev/null || printf '%s\n' '$image_path'
    else
      printf '%s\n' '$image_path'
    fi
  "
}

path_kind() {
  local resolved_path="$1"

  docker exec "$CONTAINER_NAME" sh -lc "
    if [ -d '$resolved_path' ]; then
      echo dir
    elif [ -f '$resolved_path' ] || [ -L '$resolved_path' ]; then
      echo file
    else
      echo other
    fi
  "
}

copy_dir_contents() {
  local image_dir="$1"
  local repo_dir="$2"

  rm -rf "$repo_dir"
  mkdir -p "$repo_dir"

  docker exec "$CONTAINER_NAME" sh -lc "
    tar \
      --exclude='node_modules' \
      --exclude='*/node_modules' \
      --exclude='*/node_modules/*' \
      --exclude='.cache' \
      --exclude='*/.cache' \
      --exclude='*/.cache/*' \
      --exclude='coverage' \
      --exclude='*/coverage' \
      --exclude='*/coverage/*' \
      --exclude='tmp' \
      --exclude='*/tmp' \
      --exclude='*/tmp/*' \
      -C '$image_dir' \
      -cf - .
  " | tar -C "$repo_dir" -xf -

  chown -R "$(id -u):$(id -g)" "$repo_dir" 2>/dev/null || true
}

copy_file() {
  local image_file="$1"
  local repo_file="$2"

  local tmp
  tmp="$(mktemp -d)"

  local image_dir
  local image_base
  image_dir="$(dirname "$image_file")"
  image_base="$(basename "$image_file")"

  mkdir -p "$(dirname "$repo_file")"

  docker exec "$CONTAINER_NAME" sh -lc "
    tar -C '$image_dir' -cf - '$image_base'
  " | tar -C "$tmp" -xf -

  if [[ ! -e "$tmp/$image_base" ]]; then
    echo "  ⚠️ skip: unexpected file tar result"
    rm -rf "$tmp"
    return 0
  fi

  rm -rf "$repo_file"
  mv "$tmp/$image_base" "$repo_file"

  chown -R "$(id -u):$(id -g)" "$repo_file" 2>/dev/null || true

  rm -rf "$tmp"
}

copy_path() {
  local image_path="$1"
  local repo_path="$2"

  echo "← $image_path"
  echo "  -> $repo_path"

  local resolved_path
  if ! resolved_path="$(resolve_path "$image_path" 2>/dev/null)"; then
    echo "  ⚠️ skip: not found in image"
    return 0
  fi

  if [[ "$resolved_path" != "$image_path" ]]; then
    echo "  resolved: $resolved_path"
  fi

  local kind
  kind="$(path_kind "$resolved_path")"

  case "$kind" in
    dir)
      copy_dir_contents "$resolved_path" "$repo_path"
      ;;
    file)
      copy_file "$resolved_path" "$repo_path"
      ;;
    *)
      echo "  ⚠️ skip: unsupported path kind: $kind"
      ;;
  esac
}

echo "== Extract application runtime tree =="
echo

copy_path "/overleaf/libraries" "libraries"
copy_path "/overleaf/services" "services"
copy_path "/overleaf/tools/migrations" "tools/migrations"

copy_path "/overleaf/.yarn/patches" ".yarn/patches"
copy_path "/overleaf/package.json" "package.json"
copy_path "/overleaf/yarn.lock" "yarn.lock"
copy_path "/overleaf/.yarnrc.yml" ".yarnrc.yml"

copy_path "/overleaf/genScript.js" "server-ce/genScript.js"
copy_path "/overleaf/services.js" "server-ce/services.js"

echo
echo "== Extract server-ce runtime files =="
echo

# Dockerfile:
#   ADD server-ce/runit /etc/service
#
# In the final image:
#   /etc/service -> /etc/runit/runsvdir/current
#
# So we resolve the symlink and copy the real directory contents back to:
#   server-ce/runit
copy_path "/etc/service" "server-ce/runit"

copy_path "/etc/overleaf/env.sh" "server-ce/config/env.sh"

copy_path "/etc/nginx/templates/nginx.conf.template" \
  "server-ce/nginx/nginx.conf.template"

copy_path "/etc/nginx/sites-enabled/overleaf.conf" \
  "server-ce/nginx/overleaf.conf"

copy_path "/etc/nginx/sites-enabled/clsi-nginx.conf" \
  "server-ce/nginx/clsi-nginx.conf"

copy_path "/etc/logrotate.d/overleaf" \
  "server-ce/logrotate/overleaf"

copy_path "/overleaf/cron" \
  "server-ce/cron"

copy_path "/etc/cron.d/crontab-history" \
  "server-ce/config/crontab-history"

copy_path "/etc/cron.d/crontab-deletion" \
  "server-ce/config/crontab-deletion"

copy_path "/etc/my_init.d" \
  "server-ce/init_scripts"

copy_path "/etc/my_init.pre_shutdown.d" \
  "server-ce/init_preshutdown_scripts"

copy_path "/etc/overleaf/settings.js" \
  "server-ce/config/settings.js"

copy_path "/overleaf/services/history-v1/config/production.json" \
  "server-ce/config/production.json"

copy_path "/overleaf/services/history-v1/config/custom-environment-variables.json" \
  "server-ce/config/custom-environment-variables.json"

copy_path "/usr/local/bin/grunt" \
  "server-ce/bin/grunt"

copy_path "/overleaf/bin/flush-history-queues" \
  "server-ce/bin/flush-history-queues"

copy_path "/overleaf/bin/force-history-resyncs" \
  "server-ce/bin/force-history-resyncs"

copy_path "/usr/local/share/latexmk/LatexMk" \
  "server-ce/config/latexmkrc"

chmod +x server-ce/bin/grunt 2>/dev/null || true
chmod +x server-ce/bin/flush-history-queues 2>/dev/null || true
chmod +x server-ce/bin/force-history-resyncs 2>/dev/null || true

echo
echo "✅ reverse copy completed."
echo
echo "Check node_modules:"
echo "  find . -type d -name node_modules -prune -print"
echo
echo "Check git status:"
echo "  git status --short"
