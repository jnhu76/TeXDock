# TeXDock Version Policy

## Versioning

TeXDock follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking architectural changes (e.g. Overleaf major upgrade)
- **MINOR**: New features (fonts, macros, build improvements)
- **PATCH**: Bug fixes

The version is stored in the `VERSION` file at the project root.

## Docker Tag Strategy

| Tag | Description |
|-----|-------------|
| `latest` | Points to the latest build; use for development/testing |
| `0.2.1` | Pinned version; recommended for production |

- `latest` always tracks the latest build
- Each release pushes both the version tag and `latest`

## Production Deployment

Always use a **pinned version tag** (e.g. `0.2.1`) to avoid unexpected changes from `latest`.

```yaml
image: texdock/sharelatex-full:0.2.1
```

---

## Upgrade Compatibility

| Change | Compatibility | Notes |
|--------|--------------|-------|
| PATCH (0.2.0 → 0.2.1) | Fully compatible | No data format changes |
| MINOR (0.2.x → 0.3.x) | May have new config | Check docs; existing config usually works |
| MAJOR (0.x → 1.x) | Breaking changes possible | Read migration guide carefully |

### Upgrade Steps

```bash
# 1. Backup data
bash scripts/backup.sh

# 2. Pull new image and restart
docker compose pull sharelatex
docker compose up -d

# 3. Verify version
docker exec sharelatex cat /etc/texdock-version
```

> Full upgrade instructions (rollback, caveats) in [Deployment Guide → Upgrade](deployment-guide.md#upgrade-guide).

---

## Release Discipline

### 1. Version injected via `--build-arg TEXDOCK_VERSION`

All Dockerfiles accept `ARG TEXDOCK_VERSION=dev` and write it to OCI labels:

```dockerfile
ARG TEXDOCK_VERSION=dev
LABEL org.opencontainers.image.version="${TEXDOCK_VERSION}" \
      texdock.version="${TEXDOCK_VERSION}"
```

**Never hardcode version numbers in Dockerfiles.** The single source of truth is the `VERSION` file.

### 2. Pre-release Checklist

1. Update `VERSION` file
2. Confirm all tests pass
3. Execute the three-tier build (no skipping levels)
4. Update docs (README, build guide, version policy)
5. Write changelog entry below

### 3. Standard Build Commands

```bash
export IMAGE_NAMESPACE=texdock
export VERSION=$(cat VERSION)

# Level 1: base image
docker build -f server-ce/Dockerfile-base \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-base:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-base:latest" .

# Level 2: application code
docker build -f server-ce/Dockerfile \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  --build-arg OVERLEAF_BASE_TAG="$IMAGE_NAMESPACE/sharelatex-base:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex:latest" .

# Level 3: full TeX Live + fonts
docker build -f server-ce/Dockerfile-full \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  --build-arg BASE_IMAGE="$IMAGE_NAMESPACE/sharelatex:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full:latest" .
```

Key rules:

- Each level must use the **version tag** (`$VERSION`) of the previous level — never `latest`
- Push both version and `latest` tags
- `TEXDOCK_VERSION` is passed via `--build-arg`, matching the `VERSION` file

### 4. Private Font Image (optional)

```bash
docker build -f server-ce/Dockerfile-windows-fonts \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  --build-arg BASE_IMAGE="$IMAGE_NAMESPACE/sharelatex-full:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full-private:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full-private:latest" .
```

### 5. Push to Docker Hub

```bash
docker push "$IMAGE_NAMESPACE/sharelatex-base:$VERSION"
docker push "$IMAGE_NAMESPACE/sharelatex-base:latest"
docker push "$IMAGE_NAMESPACE/sharelatex:$VERSION"
docker push "$IMAGE_NAMESPACE/sharelatex:latest"
docker push "$IMAGE_NAMESPACE/sharelatex-full:$VERSION"
docker push "$IMAGE_NAMESPACE/sharelatex-full:latest"
```

### 6. Git Commit and Tag

```bash
git add VERSION
git commit -m "release $VERSION"
git tag "$VERSION"
git push --tags
```

---

## Changelog

| Version | Date | Notes |
|---------|------|-------|
| 0.2.1 | 2026-06 | Admin panel, audit log, Track Changes, review panel; LDAP docs; upgrade guide and backup strategy |
| 0.2.0 | 2026-06 | Based on Overleaf CE, TeX Live 2026, built-in CJK font support |
