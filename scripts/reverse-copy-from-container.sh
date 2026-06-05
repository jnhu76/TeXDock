#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER="${1:-texdock-sharelatex}"

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "❌ container not found: $CONTAINER" >&2
  echo "usage: $0 <container-name-or-id>" >&2
  exit 1
fi

copy_path() {
  local image_path="$1"
  local repo_path="$2"

  echo "← $image_path"
  echo "  -> $repo_path"

  if ! docker exec "$CONTAINER" sh -lc "test -e '$image_path'"; then
    echo "  ⚠️ skip: not found in container"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"

  local image_dir
  local image_base
  image_dir="$(dirname "$image_path")"
  image_base="$(basename "$image_path")"

  mkdir -p "$(dirname "$repo_path")"

  docker exec "$CONTAINER" tar -C "$image_dir" -cf - "$image_base" \
    | tar -C "$tmp" -xf -

  rm -rf "$repo_path"
  mv "$tmp/$image_base" "$repo_path"

  rm -rf "$tmp"
}

echo "== Reverse copy from container: $CONTAINER =="
echo

# ------------------------------------------------------------
# /overleaf application source
# ------------------------------------------------------------

copy_path "/overleaf/libraries" "libraries"
copy_path "/overleaf/services" "services"
copy_path "/overleaf/tools/migrations" "tools/migrations"

copy_path "/overleaf/.yarn/patches" ".yarn/patches"
copy_path "/overleaf/package.json" "package.json"
copy_path "/overleaf/yarn.lock" "yarn.lock"
copy_path "/overleaf/.yarnrc.yml" ".yarnrc.yml"

copy_path "/overleaf/genScript.js" "server-ce/genScript.js"
copy_path "/overleaf/services.js" "server-ce/services.js"

# ------------------------------------------------------------
# runit / service / env / nginx
# ------------------------------------------------------------

copy_path "/etc/service" "server-ce/runit"

copy_path "/etc/overleaf/env.sh" "server-ce/config/env.sh"

copy_path "/etc/nginx/templates/nginx.conf.template" "server-ce/nginx/nginx.conf.template"
copy_path "/etc/nginx/sites-enabled/overleaf.conf" "server-ce/nginx/overleaf.conf"
copy_path "/etc/nginx/sites-enabled/clsi-nginx.conf" "server-ce/nginx/clsi-nginx.conf"

copy_path "/etc/logrotate.d/overleaf" "server-ce/logrotate/overleaf"

# ------------------------------------------------------------
# cron / init scripts
# ------------------------------------------------------------

copy_path "/overleaf/cron" "server-ce/cron"

copy_path "/etc/cron.d/crontab-history" "server-ce/config/crontab-history"
copy_path "/etc/cron.d/crontab-deletion" "server-ce/config/crontab-deletion"

copy_path "/etc/my_init.d" "server-ce/init_scripts"
copy_path "/etc/my_init.pre_shutdown.d" "server-ce/init_preshutdown_scripts"

# ------------------------------------------------------------
# app settings
# ------------------------------------------------------------

copy_path "/etc/overleaf/settings.js" "server-ce/config/settings.js"

# ------------------------------------------------------------
# history-v1 config
# ------------------------------------------------------------

copy_path "/overleaf/services/history-v1/config/production.json" \
  "server-ce/config/production.json"

copy_path "/overleaf/services/history-v1/config/custom-environment-variables.json" \
  "server-ce/config/custom-environment-variables.json"

# ------------------------------------------------------------
# helper scripts / latexmk
# ------------------------------------------------------------

copy_path "/usr/local/bin/grunt" "server-ce/bin/grunt"

copy_path "/overleaf/bin/flush-history-queues" \
  "server-ce/bin/flush-history-queues"

copy_path "/overleaf/bin/force-history-resyncs" \
  "server-ce/bin/force-history-resyncs"

copy_path "/usr/local/share/latexmk/LatexMk" \
  "server-ce/config/latexmkrc"

echo
echo "✅ reverse copy completed."
echo "Run:"
echo "  git status --short"
