# Development Workflow

TeXDock supports two development modes for modifying runtime code.

## Mode A: Single-file overlay

For small changes to individual files.

```bash
./scripts/extract-runtime-file.sh /overleaf/services/web/app.js
cp docker-compose.override.example.yml docker-compose.override.yml
# Edit docker-compose.override.yml to mount your file
docker compose up -d --force-recreate
```

Inside the container, restart the affected service:

```bash
docker compose exec texdock-sharelatex sv restart web
```

## Mode B: Whole-service overlay

For complex service work such as `services/web`.

```bash
./scripts/extract-runtime-service.sh web
cp docker-compose.dev.web.example.yml docker-compose.dev.web.yml
docker compose -f docker-compose.yml -f docker-compose.dev.web.yml up -d --force-recreate
```

Whole-service bind mount replaces `/overleaf/services/<name>` in the container with your local overlay directory. The overlay directory must come from the same runtime image.

**Rules:**

- `overlays/overleaf/services/web` must be extracted from the same image (`sharelatex/sharelatex:5.5.8`).
- Do not mount an empty or hand-written directory.
- Do not mount `./overlays/overleaf:/overleaf`.

## About dependencies

If a service directory contains `node_modules`, whole-service bind mount may hide image dependencies. The extraction script excludes `node_modules` by default and warns if the image contains them.

In `sharelatex/sharelatex:5.5.8`, dependencies primarily live in `/overleaf/node_modules` (shared), so excluding per-service `node_modules` usually does not cause issues. Verify with:

```bash
./scripts/check-image-runtime.sh sharelatex/sharelatex:5.5.8
```

## Building a release image

After modifying overlay files:

```bash
./scripts/build-runtime-image.sh
```

## Configuration

```bash
cp config/overleaf.env.example config/overleaf.env
# Edit config/overleaf.env
docker compose up -d --force-recreate
```

Do not only `docker compose restart` after changing env vars. Use `--force-recreate`.
