# Image Runtime Import Notes

Base image:

- `sharelatex/sharelatex:5.5.8`

This repository is materialized from the final Docker image runtime, not from
the upstream `overleaf/overleaf` source tree.

The following Dockerfile build-time inputs are not present in the final runtime
image and are intentionally not imported:

- `/overleaf/tools/migrations`
- `/overleaf/.yarn/patches`
- `/overleaf/yarn.lock`
- `/overleaf/.yarnrc.yml`

`/etc/service` is a symlink in the image:

- `/etc/service -> /etc/runit/runsvdir/current`
- resolved to `/etc/runit/runsvdir/default` during extraction

The extracted runit service tree is stored at:

- `server-ce/runit`
