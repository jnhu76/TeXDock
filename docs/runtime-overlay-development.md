# Runtime Overlay Development

## 1. Why source-build was paused

The previous approach attempted to rebuild the entire Overleaf application from source using Yarn Berry, genScript compile, and the `overleaf/overleaf` monorepo workspace.

This proved unreliable:

- `sharelatex/sharelatex:5.5.8` already contains a working runtime at `/overleaf`.
- The source-build pipeline requires complex Yarn workspace setup.
- genScript compile depends on upstream build tooling that changes frequently.
- Domestic npm mirror differences cause lockfile and metadata mismatches.

The current project uses the Docker image runtime as the source of truth.

## 2. What is the runtime overlay model

```text
Unmodified files come from the official image.
Modified files live in overlays/overleaf/.
During development, bind mount individual files.
During release, COPY overlays/overleaf/ to /overleaf/.
```

## 3. What it can do

- Modify runtime code files (server-side JS, configs).
- Modify configuration files.
- Modify templates or static files read at runtime.
- Quick bind mount testing without rebuilding.
- Build lightweight custom images.

## 4. What it cannot directly do

- Add new npm dependencies.
- Auto-install after modifying `package.json`.
- Rebuild webpack frontend bundles.
- Full Overleaf source upgrade.
- Rebuild the entire source-build app.

For those cases, the paused source-build path (`server-ce/Dockerfile`) may be revisited later.

## 5. Development flow

### Extract a file

```bash
./scripts/extract-runtime-file.sh /overleaf/services/web/app.js
```

### Extract a small directory

```bash
./scripts/extract-runtime-dir.sh /overleaf/services/web/modules
```

### Modify

```bash
vim overlays/overleaf/services/web/app.js
```

### Test with bind mount

Create `docker-compose.override.yml` (gitignored):

```yaml
services:
  sharelatex:
    image: sharelatex/sharelatex:5.5.8
    volumes:
      - ./overlays/overleaf/services/web/app.js:/overleaf/services/web/app.js
```

**Important**: mount individual files or small directories only.

```text
BAD:  - ./overlays/overleaf:/overleaf
GOOD: - ./overlays/overleaf/services/web/app.js:/overleaf/services/web/app.js
```

Mounting the whole `overlays/overleaf` as `/overleaf` hides everything the image provides.

### Restart

```bash
docker compose restart sharelatex
```

Or inside the container:

```bash
sv restart web
```

### Build release image

```bash
./scripts/build-runtime-image.sh
```

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `IMAGE_NAME` | `fred1653/sharelatex` | Target image name |
| `IMAGE_VERSION` | `0.2.0` | Target image tag |
| `BASE_IMAGE` | `sharelatex/sharelatex:5.5.8` | Base image to overlay onto |
| `DOCKERFILE` | `server-ce/Dockerfile-runtime` | Dockerfile to use |

### Commit

```bash
git add overlays/overleaf/services/web/app.js
git commit -m "feat: customize web service app entry"
```

## 6. Legacy source-build files (paused)

These files are preserved for reference but are **not** part of the current mainline:

```text
server-ce/Dockerfile              # source-build experimental path (paused)
server-ce/Dockerfile-base         # custom base-image rebuild (paused)
scripts/prepare-build-context.sh  # source-build context assembly (paused)

server-ce/Dockerfile-runtime      # current mainline path
```
