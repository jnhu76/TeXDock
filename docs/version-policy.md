# TeXDock 版本策略与发布纪律

## 版本号规则

TeXDock 使用 [语义化版本](https://semver.org/lang/zh-CN/)（SemVer）：`MAJOR.MINOR.PATCH`

- **MAJOR**: 不兼容的架构变更（如 Overleaf 大版本升级）
- **MINOR**: 新增功能（如新增字体、宏包、构建流程改进）
- **PATCH**: 问题修复

版本号记录在项目根目录的 `VERSION` 文件中。

## Docker Tag 策略

| Tag | 说明 |
|-----|------|
| `latest` | 跟随最新开发版本，适合本地开发和测试 |
| `0.2.0` | 固定版本，适合生产部署 |

- `latest` 始终指向最新构建
- 每次发布新版本时同步推送版本号 tag（如 `0.2.0`）

## 生产部署建议

正式部署**推荐使用固定版本号 tag**（如 `0.2.0`），避免 `latest` 带来的不可预期变更。

```yaml
# docker-compose.yml 示例
image: fred1653/sharelatex-full:0.2.0
```

---

## 发布纪律

### 1. 版本号由 `--build-arg TEXDOCK_VERSION` 注入

所有 Dockerfile 通过 `ARG TEXDOCK_VERSION=dev` 接收版本号，写入 OCI label：

```dockerfile
ARG TEXDOCK_VERSION=dev
LABEL org.opencontainers.image.version="${TEXDOCK_VERSION}" \
      texdock.version="${TEXDOCK_VERSION}"
```

**禁止在 Dockerfile 中硬编码版本号。** 版本号的唯一来源是 `VERSION` 文件。

### 2. 发布前检查清单

发布新版本前，按顺序完成：

1. **更新 `VERSION` 文件** — 写入新版本号（如 `0.3.0`）
2. **确认所有测试通过** — 冒烟测试、中文编译测试
3. **按顺序执行三级构建** — 不得跳级、不得用 `latest` 做中间 tag

### 3. 标准构建命令

每次发布使用以下命令（以 `0.3.0` 为例）：

```bash
VERSION=0.3.0

# 第 1 级：基础镜像
docker build -f server-ce/Dockerfile-base \
  --build-arg TEXDOCK_VERSION=$VERSION \
  -t fred1653/sharelatex-base:$VERSION \
  -t fred1653/sharelatex-base:latest .

# 第 2 级：应用代码
docker build -f server-ce/Dockerfile \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg OVERLEAF_BASE_TAG=fred1653/sharelatex-base:$VERSION \
  -t fred1653/sharelatex:$VERSION \
  -t fred1653/sharelatex:latest .

# 第 3 级：完整 TeX Live + 字体
docker build -f server-ce/Dockerfile-full \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg BASE_IMAGE=fred1653/sharelatex:$VERSION \
  -t fred1653/sharelatex-full:$VERSION \
  -t fred1653/sharelatex-full:latest .
```

关键规则：

- **每一级必须使用上一级的版本号 tag**（`$VERSION`），不得使用 `latest`
- **同时打版本号 tag 和 `latest` tag** — 双 tag 推送到 Docker Hub
- `TEXDOCK_VERSION` 通过 `--build-arg` 传入，与 `VERSION` 文件保持一致

### 4. 私有字体镜像（可选）

```bash
docker build -f server-ce/Dockerfile-windows-fonts \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg BASE_IMAGE=fred1653/sharelatex-full:$VERSION \
  -t fred1653/sharelatex-full-private:$VERSION \
  -t fred1653/sharelatex-full-private:latest .
```

### 5. 推送到 Docker Hub

```bash
docker push fred1653/sharelatex-base:$VERSION
docker push fred1653/sharelatex-base:latest
docker push fred1653/sharelatex:$VERSION
docker push fred1653/sharelatex:latest
docker push fred1653/sharelatex-full:$VERSION
docker push fred1653/sharelatex-full:latest
```

### 6. Git 提交与 tag

```bash
git add VERSION
git commit -m "release $VERSION"
git tag "$VERSION"
git push --tags
```

---

## 版本变更记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.2.0 | 2026-06 | 基于 Overleaf CE，TeX Live 2026，内置 CJK 字体支持 |
