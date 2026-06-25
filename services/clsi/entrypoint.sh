#!/bin/sh

# add the node user to the docker group on the host
if [ -S /var/run/docker.sock ]; then
  DOCKER_GROUP=$(stat -c '%g' /var/run/docker.sock)

  if getent group dockeronhost >/dev/null 2>&1; then
    CURRENT_GID="$(getent group dockeronhost | cut -d: -f3)"
    if [ "$CURRENT_GID" != "$DOCKER_GROUP" ]; then
      groupmod --non-unique --gid "$DOCKER_GROUP" dockeronhost 2>/dev/null || true
    fi
  else
    groupadd --non-unique --gid "$DOCKER_GROUP" dockeronhost
  fi

  usermod -aG dockeronhost node 2>/dev/null || true
fi

# compatibility: initial volume setup
mkdir -p /overleaf/services/clsi/cache && chown node:node /overleaf/services/clsi/cache
mkdir -p /overleaf/services/clsi/compiles && chown node:node /overleaf/services/clsi/compiles
mkdir -p /overleaf/services/clsi/output && chown node:node /overleaf/services/clsi/output

exec runuser -u node -- "$@"
