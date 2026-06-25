<div align="center">

# 📝 TeXDock

**A Chinese-localized Overleaf Community Edition distribution with TeX Live and CJK support**

基于 Overleaf Community Edition 的非官方发行与实验性扩展版本。
提供中文界面、完整 TeX Live 镜像、CJK 字体兼容、full image 部署模式，以及可选的 sibling TeXLive sandbox 编译模式。

![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker\&logoColor=white)
![License](https://img.shields.io/badge/license-AGPL--3.0-green)
![TeX Live](https://img.shields.io/badge/TeX%20Live-2026-blue)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20x86__64-lightgrey)

本项目基于 [Overleaf Community Edition](https://github.com/overleaf/overleaf) 修改，遵循 [AGPL-3.0](LICENSE) 许可证发布。
TeXDock 不是 Overleaf 官方项目。

</div>

---

## Overview

TeXDock provides two deployment modes:

| Mode         | Image                                        | TeX Live location         | Docker socket | Use case                      |
| ------------ | -------------------------------------------- | ------------------------- | ------------- | ----------------------------- |
| Full image   | `texdock/sharelatex-full`                    | Inside the main container | Not required  | Simple local/LAN deployment   |
| Sandbox mode | `texdock/sharelatex-web` + `texdock/texlive` | Sibling compile container | Required      | Compile isolation experiments |

For deployment examples, see the separate deploy repository:

```text
texdock-deploy/
  full/      # full image deployment
  sandbox/   # web-only + sibling TeXLive deployment
```

Do not mix the two modes in one Compose stack.

---

## Images

### Full image

The full image contains Overleaf CE, TeX Live, CJK fonts, and helper scripts in one container:

```text
texdock/sharelatex-full:<version>
texdock/sharelatex-full:latest
```

Use this mode if you want the simplest deployment.

### Sandbox images

Sandbox mode uses two images:

```text
texdock/sharelatex-web:latest
texdock/texlive:2026.1
```

The web image does not contain TeX Live. Each LaTeX compile runs in a short-lived sibling TeXLive container.

---

## Deployment

Deployment files are maintained outside this source repository.

Recommended:

```bash
git clone https://github.com/<your-org>/texdock-deploy.git
```

Full image mode:

```bash
cd texdock-deploy/full
cp .env.example .env
# edit .env
docker compose --env-file .env up -d
```

Sandbox mode:

```bash
cd texdock-deploy/sandbox
cp .env.example .env
# edit .env
./scripts/init-host-dirs.sh .env
docker compose --env-file .env up -d
```

The source repository may contain example Compose files for reference, but production deployment should use `texdock-deploy`.

---

## Features

* Chinese UI defaults
* Full TeX Live image
* CJK font support
* Fontconfig aliases for common Windows font names
* SMTP configuration support
* LDAP configuration support
* Optional admin-related extensions
* Optional review / track-changes related extensions
* Optional sandbox compile mode with sibling TeXLive containers

Some features are project-specific modifications or experimental enablement based on Overleaf CE. They are not guaranteed to be identical to Overleaf Server Pro implementations.

---

## Build

Set the image namespace first:

```bash
export IMAGE_NAMESPACE=texdock
export VERSION=$(cat VERSION)
```

Build the full image chain:

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

Build the sandbox images:

```bash
docker build -f server-ce/Dockerfile-sandbox-web \
  -t "$IMAGE_NAMESPACE/sharelatex-web:latest" .

docker build -f server-ce/Dockerfile-sandbox-texlive \
  --build-arg TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet \
  -t "$IMAGE_NAMESPACE/texlive:2026.1" .
```

---

## License

This project is based on Overleaf Community Edition and is distributed under AGPL-3.0.

See [LICENSE](LICENSE) for details.
