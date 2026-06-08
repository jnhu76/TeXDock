# TeXDock 镜像构建指南

镜像构建、字体策略、TeX Live 宏包安装。

> 当前版本 **0.2.0**。`latest` tag 等价于 `0.2.0`。正式部署推荐使用固定版本号 tag（如 `fred1653/sharelatex-full:0.2.0`），开发可以使用 `latest`。详见 [**版本策略**](version-policy.md)。

---

## 1. 构建流程

```text
第 1 级  Dockerfile-base   →  fred1653/sharelatex-base:latest
         Ubuntu + Node.js + TeX Live basic

第 2 级  Dockerfile        →  fred1653/sharelatex:latest
         Overleaf CE 应用代码（yarn install + 编译）

第 3 级  Dockerfile-full   →  fred1653/sharelatex-full:latest
         完整 TeX Live (scheme-full) + CJK 字体 + 辅助脚本 + 冒烟测试
```

日常 web 修改只需 rebuild `Dockerfile-full-web`（基于 `sharelatex-full`，仅覆盖 web 代码）：

```text
Dockerfile-full-web  →  fred1653/sharelatex-full:latest
  覆盖 web 代码（无需重新安装 TeX Live）
```

---

## 2. 构建命令

### 完整三级构建

```bash
VERSION=$(cat VERSION)

docker build -f server-ce/Dockerfile-base \
  --build-arg TEXDOCK_VERSION=$VERSION \
  -t fred1653/sharelatex-base:$VERSION \
  -t fred1653/sharelatex-base:latest .

docker build -f server-ce/Dockerfile \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg OVERLEAF_BASE_TAG=fred1653/sharelatex-base:$VERSION \
  -t fred1653/sharelatex:$VERSION \
  -t fred1653/sharelatex:latest .

docker build -f server-ce/Dockerfile-full \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg BASE_IMAGE=fred1653/sharelatex:$VERSION \
  -t fred1653/sharelatex-full:$VERSION \
  -t fred1653/sharelatex-full:latest .
```

> 每一级必须使用上一级的版本号 tag（`$VERSION`），不得使用 `latest`。详见 [**版本策略**](version-policy.md)。

### 日常 web 修改

```bash
docker build -f server-ce/Dockerfile-full-web -t fred1653/sharelatex-full:latest .
```

### 构建私有字体镜像

```bash
VERSION=$(cat VERSION)

docker build -f server-ce/Dockerfile-windows-fonts \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg BASE_IMAGE=fred1653/sharelatex-full:$VERSION \
  -t fred1653/sharelatex-full-private:$VERSION \
  -t fred1653/sharelatex-full-private:latest .
```

### 可选构建参数

| 参数 | 适用 Dockerfile | 默认值 | 说明 |
|------|----------------|--------|------|
| `TEXDOCK_VERSION` | 全部 | `dev` | 版本号，写入 OCI label |
| `UBUNTU_MIRROR` | base, full | `https://mirrors.tuna.tsinghua.edu.cn/ubuntu` | Ubuntu apt 镜像 |
| `TEXLIVE_MIRROR` | base | `https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet` | TeX Live 安装源 |
| `TEXLIVE_REPOSITORY` | full | `https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet` | CTAN 镜像（tlmgr） |
| `BASE_IMAGE` | windows-fonts | `fred1653/sharelatex-full:latest` | 私有字体基础镜像 |

---

## 3. 字体策略

### 3.1 已内置字体

`sharelatex-full` 镜像包含：

- **开源 CJK 字体**: Noto CJK SC、WenQuanYi Micro Hei、AR PL UKai/UMing
- **TeX Live 内置**: Fandol (Song/Hei/Kai/Fang)
- **西文字体**: Liberation、DejaVu、Carlito、Caladea

### 3.2 fontconfig 别名

镜像通过 `/etc/fonts/conf.d/64-chinese-latex-aliases.conf` 将 Windows 字体名映射到开源替代：

| Windows 字体名 | → 替代字体 |
|----------------|-----------|
| SimSun / NSimSun | Noto Serif CJK SC → FandolSong → AR PL UMing CN |
| SimHei | Noto Sans CJK SC → FandolHei → WenQuanYi Zen Hei |
| KaiTi | FandolKai → AR PL UKai CN |
| FangSong | FandolFang → Noto Serif CJK SC |
| Microsoft YaHei | Noto Sans CJK SC → WenQuanYi Micro Hei |
| Arial | Liberation Sans → Arimo |
| Times New Roman | Liberation Serif → Tinos |
| Courier New | Liberation Mono → Cousine |

使用 `\setCJKmainfont{SimSun}` 的 LaTeX 模板即使在没有 Windows 字体的环境下也能编译。

### 3.3 构建私有字体镜像

由于中文字体（SimSun、SimHei、KaiTi、FangSong 等）存在版权限制，公开镜像通过 fontconfig 别名映射到开源替代字体。如需使用真实 Windows 字体，可通过 `Dockerfile-windows-fonts` 构建私有镜像。

1. 在项目根目录准备 `fonts.zip`，内含 `.ttf` / `.ttc` / `.otf` / `.otc` 字体文件
2. 构建私有镜像：

```bash
docker build -f server-ce/Dockerfile-windows-fonts \
  --build-arg BASE_IMAGE=fred1653/sharelatex-full:latest \
  -t fred1653/sharelatex-full-private:latest .
```

3. 修改 `docker-compose.yml` 使用私有镜像：

```yaml
image: fred1653/sharelatex-full-private:latest
```

> **注意**: `fonts.zip` 不应提交到公开仓库。构建产物仅限本地或私有环境使用，不可公开发布。

也可以在运行中的容器内临时导入字体（容器重建后丢失）：

```bash
docker cp fonts.zip sharelatex:/tmp/fonts.zip
docker exec sharelatex import-private-fonts-zip /tmp/fonts.zip
```

导入后 fontconfig 优先匹配真实字体（精确 family 名优先于别名）。

### 3.4 刷新字体缓存

手动添加字体后运行：

```bash
docker exec sharelatex refresh-texlive-font-cache
```

该脚本会刷新 fontconfig、TeX filename database、font maps 和 luaotfload 缓存。

---

## 4. 安装 TeX Live 宏包

当 LaTeX 编译报错缺少 `.sty` / `.cls` / `.bst` 文件时，使用 `scripts/tlmgr-in-container.sh` 在运行中的容器内临时安装。

> **注意**: 容器重建后安装的包会丢失。如需永久生效，请将包添加到 `server-ce/Dockerfile-full` 后重新构建镜像。

### 搜索缺少的包

```bash
# LaTeX Error: File `enumitem.sty' not found.
scripts/tlmgr-in-container.sh search enumitem.sty

# LaTeX Error: File `ctexart.cls' not found.
scripts/tlmgr-in-container.sh search ctexart.cls
```

### 安装包

```bash
scripts/tlmgr-in-container.sh install enumitem
scripts/tlmgr-in-container.sh install minted fvextra upquote
```

安装后自动刷新 TeX 缓存，可立即重新编译。

### 环境变量

```bash
# 指定容器名（默认 sharelatex）
CONTAINER=my-sharelatex scripts/tlmgr-in-container.sh install enumitem

# 指定 CTAN 镜像
TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet \
  scripts/tlmgr-in-container.sh install enumitem
```

### 典型流程

```bash
# 1. LaTeX 报错: File `minted.sty' not found
# 2. 搜索
scripts/tlmgr-in-container.sh search minted.sty
# 3. 安装
scripts/tlmgr-in-container.sh install minted
# 4. 在页面上重新编译
```

---

## 5. 构建验证

构建完成后验证：

```bash
# 检查 ctex 是否可用
docker exec sharelatex kpsewhich ctex.sty

# 检查中文字体
docker exec sharelatex fc-list | grep -i "Noto Sans CJK" | head

# 检查 xelatex
docker exec sharelatex xelatex --version

# 检查 Windows 字体别名
docker exec sharelatex fc-match SimSun
docker exec sharelatex fc-match SimHei
```
