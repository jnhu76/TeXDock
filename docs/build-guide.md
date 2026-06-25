# TeXDock Build Guide

Image building, font strategy, TeX Live package installation.

> Current version **0.2.1**. The `latest` tag is equivalent to `0.2.1`. For production, use a pinned version tag (e.g. `texdock/sharelatex-full:0.2.1`). See [Version Policy](version-policy.md).

---

## 1. Build Flow

```text
Level 1  Dockerfile-base   →  texdock/sharelatex-base:latest
         Ubuntu + Node.js + TeX Live basic

Level 2  Dockerfile        →  texdock/sharelatex:latest
         Overleaf CE application code (yarn install + compile)

Level 3  Dockerfile-full   →  texdock/sharelatex-full:latest
         Full TeX Live (scheme-full) + CJK fonts + helper scripts + smoke tests
```

For日常 web changes, rebuild `Dockerfile-full-web` only (no TeX Live reinstall):

```text
Dockerfile-full-web  →  texdock/sharelatex-full:latest
  Web code overlay (no TeX Live reinstall)
```

---

## 2. Build Commands

Set the image namespace first:

```bash
export IMAGE_NAMESPACE=texdock
export VERSION=$(cat VERSION)
```

### Full Three-Tier Build

```bash
docker build -f server-ce/Dockerfile-base \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-base:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-base:latest" .

docker build -f server-ce/Dockerfile \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  --build-arg OVERLEAF_BASE_TAG="$IMAGE_NAMESPACE/sharelatex-base:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex:latest" .

docker build -f server-ce/Dockerfile-full \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  --build-arg BASE_IMAGE="$IMAGE_NAMESPACE/sharelatex:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full:latest" .
```

> Each level must use the version tag of the previous level. See [Version Policy](version-policy.md).

### Daily Web Changes

```bash
docker build -f server-ce/Dockerfile-full-web \
  -t "$IMAGE_NAMESPACE/sharelatex-full:latest" .
```

### Private Font Image

```bash
docker build -f server-ce/Dockerfile-windows-fonts \
  --build-arg TEXDOCK_VERSION="$VERSION" \
  --build-arg BASE_IMAGE="$IMAGE_NAMESPACE/sharelatex-full:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full-private:$VERSION" \
  -t "$IMAGE_NAMESPACE/sharelatex-full-private:latest" .
```

### Optional Build Args

| Argument | Applies to | Default | Description |
|----------|-----------|---------|-------------|
| `TEXDOCK_VERSION` | All | `dev` | Version string, written to OCI label |
| `UBUNTU_MIRROR` | base, full | `https://mirrors.tuna.tsinghua.edu.cn/ubuntu` | Ubuntu apt mirror |
| `TEXLIVE_MIRROR` | base | `https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet` | TeX Live install source |
| `TEXLIVE_REPOSITORY` | full | `https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet` | CTAN mirror (tlmgr) |
| `BASE_IMAGE` | windows-fonts | `texdock/sharelatex-full:latest` | Base image for font overlay |

---

## 3. Font Strategy

### 3.1 Built-in Fonts

`sharelatex-full` includes:

- **Open-source CJK**: Noto CJK SC, WenQuanYi Micro Hei, AR PL UKai/UMing
- **TeX Live built-in**: Fandol (Song/Hei/Kai/Fang)
- **Western**: Liberation, DejaVu, Carlito, Caladea

### 3.2 fontconfig Aliases

`/etc/fonts/conf.d/64-chinese-latex-aliases.conf` maps Windows font names to open-source alternatives:

| Windows Font Name | → Alternative |
|-------------------|---------------|
| SimSun / NSimSun | Noto Serif CJK SC → FandolSong → AR PL UMing CN |
| SimHei | Noto Sans CJK SC → FandolHei → WenQuanYi Zen Hei |
| KaiTi | FandolKai → AR PL UKai CN |
| FangSong | FandolFang → Noto Serif CJK SC |
| Microsoft YaHei | Noto Sans CJK SC → WenQuanYi Micro Hei |
| Arial | Liberation Sans → Arimo |
| Times New Roman | Liberation Serif → Tinos |
| Courier New | Liberation Mono → Cousine |

LaTeX templates using `\setCJKmainfont{SimSun}` compile even without Windows fonts.

### 3.3 Private Font Image

Real Windows fonts (SimSun, SimHei, KaiTi, FangSong) have copyright restrictions. The public image uses fontconfig aliases. For real fonts, build a private image:

1. Place `fonts.zip` in the project root (contains `.ttf`/`.ttc`/`.otf`/`.otc` files)
2. Build:

```bash
docker build -f server-ce/Dockerfile-windows-fonts \
  --build-arg BASE_IMAGE=texdock/sharelatex-full:latest \
  -t texdock/sharelatex-full-private:latest .
```

3. Update compose to use the private image:

```yaml
image: texdock/sharelatex-full-private:latest
```

> **Note**: `fonts.zip` must NOT be committed to a public repository.

也可以在运行中的容器内临时导入字体（容器重建后丢失）：

```bash
docker cp fonts.zip sharelatex:/tmp/fonts.zip
docker exec sharelatex import-private-fonts-zip /tmp/fonts.zip
```

### 3.4 Refresh Font Cache

After manually adding fonts:

```bash
docker exec sharelatex refresh-texlive-font-cache
```

Refreshes fontconfig, TeX filename database, font maps, and luaotfload cache.

---

## 4. Installing TeX Live Packages

When LaTeX compilation fails with missing `.sty`/`.cls`/`.bst` files, use `scripts/tlmgr-in-container.sh`:

> **Note**: Packages installed this way are lost on container rebuild. For permanent additions, add them to `server-ce/Dockerfile-full` and rebuild.

### Search for Missing Packages

```bash
scripts/tlmgr-in-container.sh search enumitem.sty
scripts/tlmgr-in-container.sh search ctexart.cls
```

### Install Packages

```bash
scripts/tlmgr-in-container.sh install enumitem
scripts/tlmgr-in-container.sh install minted fvextra upquote
```

### Environment Variables

```bash
# Custom container name (default: sharelatex)
CONTAINER=my-sharelatex scripts/tlmgr-in-container.sh install enumitem

# Custom CTAN mirror
TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet \
  scripts/tlmgr-in-container.sh install enumitem
```

---

## 5. Upstream Sync Strategy

TeXDock is based on Overleaf Community Edition and needs periodic upstream sync.

### 5.1 Sync Flow

```text
Upstream Overleaf CE releases new version
        ↓
1. Update Dockerfile-base with new Overleaf version
        ↓
2. Rebuild three-tier chain
        ↓
3. Run smoke tests
        ↓
4. Update VERSION file
        ↓
5. Release new version
```

### 5.2 Patch Management

TeXDock customizations are concentrated in:

| File | Changes |
|------|---------|
| `Dockerfile-base` | Ubuntu base image, TeX Live install |
| `Dockerfile` | Overleaf CE code integration |
| `Dockerfile-full` | Fonts, helper scripts, smoke tests |
| `docker-compose.yml` | Default config, environment variables |
| `services/web/` | Localization, feature customization |

### 5.3 Checking for Upstream Updates

```bash
git remote add upstream https://github.com/overleaf/overleaf.git
git fetch upstream
git log HEAD..upstream/master --oneline
```

---

## 6. Build Verification

After building, verify:

```bash
docker exec sharelatex kpsewhich ctex.sty
docker exec sharelatex fc-list | grep -i "Noto Sans CJK" | head
docker exec sharelatex xelatex --version
docker exec sharelatex fc-match SimSun
docker exec sharelatex fc-match SimHei
docker exec sharelatex cat /etc/texdock-version
```

### Smoke Tests

```bash
docker exec sharelatex texdock-smoke-test
```

Includes:

- TeX Live basic compilation
- Chinese compilation (XeLaTeX + ctex)
- Font alias tests
- Helper script availability
