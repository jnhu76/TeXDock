# Overleaf Runtime Overlay 开发工作流

本仓库用于基于官方 `sharelatex/sharelatex` 运行时镜像，对 Overleaf Community Edition 进行本地定制、调试和轻量改造。

它的目标不是从源码完整重新构建 Overleaf，而是使用 **runtime image + overlay** 的方式，在官方镜像之上替换少量运行时文件，从而降低开发、测试和部署成本。

---

## 1. 项目目标

Overleaf CE 的完整源码构建链路较重，依赖多、耗时长、调试成本高。

本项目采用更轻量的方式：

```text
官方 sharelatex/sharelatex 镜像
  ↓
提取或定位运行时文件
  ↓
在 overlays/ 中修改目标文件
  ↓
构建自己的 runtime image
  ↓
使用 docker compose 启动验证
```

适合以下场景：

* 修改 Overleaf Web 页面或前端资源；
* 调整部分 service 的运行时代码；
* 快速验证小型 patch；
* 搭建可重复的本地 Overleaf 开发环境；
* 在不全量构建源码的前提下做定制化实验。

---

## 2. 核心思路

本项目把 Overleaf 当作一个已经构建好的运行时系统，而不是从源码重新编译。

核心模型：

```text
server-ce/Dockerfile-runtime
  基于官方 sharelatex/sharelatex 镜像构建自定义 runtime image

overlays/overleaf/
  存放要覆盖到容器 /overleaf 目录下的修改文件

config/overleaf.env
  本地运行所需配置

docker-compose.dev.web.example.yml
  本地开发用 compose overlay 示例

scripts/
  辅助脚本，例如从官方镜像提取运行时文件
```

也就是说，修改流程不是：

```text
clone Overleaf source
  → yarn install
  → 构建全部服务
  → 生成完整镜像
```

而是：

```text
从官方镜像拿到运行时文件
  → 修改少量目标文件
  → 放入 overlays/
  → 构建 runtime image
  → 启动验证
```

---

## 3. 目录结构

```text
.
├── config/
│   └── overleaf.env
│
├── docker-compose.dev.web.example.yml
│
├── overlays/
│   └── overleaf/
│       └── ...
│
├── scripts/
│   ├── find-missing-build-inputs-in-layers.sh
│   ├── patch-pdfjs-worker-wasm.sh
│   ├── reverse-copy-from-container.sh
│   └── reverse-copy-from-image.sh
│
└── server-ce/
    └── Dockerfile-runtime
```

### `server-ce/Dockerfile-runtime`

用于构建自定义 Overleaf runtime image。

它通常基于官方镜像：

```dockerfile
FROM sharelatex/sharelatex:<version>
```

然后将 `overlays/overleaf/` 中的文件复制到容器内对应路径。

---

### `overlays/overleaf/`

这里存放需要覆盖的运行时文件。

例如，如果容器内原始文件路径是：

```text
/overleaf/services/web/xxx/yyy.js
```

那么 overlay 中对应路径应该是：

```text
overlays/overleaf/services/web/xxx/yyy.js
```

构建 runtime image 时，该文件会覆盖官方镜像中的对应文件。

---

### `config/overleaf.env`

本地运行配置文件。

建议只提交 example 或无敏感信息版本。真实密钥、密码、token 不应提交到仓库。

---

### `scripts/reverse-copy-from-image.sh`

从官方 Overleaf 镜像中提取完整运行时文件树，还原为仓库目录结构。会自动排除 `node_modules`、`.cache`、`coverage`、`tmp` 等目录。

示例：

```bash
./scripts/reverse-copy-from-image.sh sharelatex/sharelatex:5.5.8
```

提取范围包括：

* `/overleaf/libraries`、`/overleaf/services` — 应用源码
* `/overleaf/tools/migrations` — 数据库迁移
* `/overleaf/.yarn/patches`、`yarn.lock`、`.yarnrc.yml` — 依赖锁与补丁
* `/etc/service` — runit 服务定义
* `/etc/nginx/` — Nginx 配置
* `/etc/overleaf/` — 环境变量与 settings
* `/etc/my_init.d`、`/etc/cron.d/` — 初始化与定时任务
* `/overleaf/bin/` — 辅助脚本

提取完成后可用 `git status --short` 查看变更。

---

### `scripts/reverse-copy-from-container.sh`

与 `reverse-copy-from-image.sh` 类似，但从**已运行的容器**中提取文件。适用于在容器中做过临时修改后，需要把改动同步回仓库的场景。

示例：

```bash
# 默认容器名 texdock-sharelatex
./scripts/reverse-copy-from-container.sh

# 指定容器名
./scripts/reverse-copy-from-container.sh my-sharelatex-container
```

提取范围与 `reverse-copy-from-image.sh` 相同。

---

### `scripts/find-missing-build-inputs-in-layers.sh`

在 Docker 镜像的各层 tar 中搜索指定的文件路径，用于排查构建输入是否存在于官方镜像中。

默认搜索以下路径：

* `overleaf/tools/migrations`
* `overleaf/.yarn/patches`
* `overleaf/yarn.lock`
* `overleaf/.yarnrc.yml`

示例：

```bash
# 默认镜像 sharelatex/sharelatex:5.5.8
./scripts/find-missing-build-inputs-in-layers.sh

# 指定镜像
./scripts/find-missing-build-inputs-in-layers.sh sharelatex/sharelatex:5.5.8
```

输出每层中是否包含目标路径，便于诊断 runtime image 构建失败的原因。

---

### `scripts/patch-pdfjs-worker-wasm.sh`

修补容器内 `pdfjs-dist` 的 worker 文件，为 WASM 动态导入添加 `/* webpackIgnore: true */` 注释，防止 webpack 尝试解析 `.wasm` 文件路径。

此脚本需要在**容器内部**运行：

```bash
docker exec -it sharelatex bash
/path/to/scripts/patch-pdfjs-worker-wasm.sh
```

修补目标：

* `qcms_bg.wasm` — 颜色管理模块
* `openjpeg.wasm` — JPEG2000 解码模块

修改后需重新构建 runtime image 以持久化补丁。

---

## 4. 快速开始

### 4.1 准备配置

复制配置文件：

```bash
cp config/overleaf.env.example config/overleaf.env
```

根据本地环境修改：

```bash
vim config/overleaf.env
```

---

### 4.2 构建 runtime image

```bash
docker build \
  -f server-ce/Dockerfile-runtime \
  -t overleaf-runtime:dev \
  .
```

---

### 4.3 启动服务

使用 docker compose 启动 Overleaf、MongoDB、Redis 等服务：

```bash
docker compose up -d
```

如果需要使用开发 overlay compose：

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.dev.web.example.yml \
  up -d
```

---

### 4.4 查看服务状态

```bash
docker compose ps
```

查看 Overleaf 日志：

```bash
docker logs -f sharelatex
```

---

## 5. 修改 Web 或 Service 文件

### 5.1 先定位容器内文件

进入运行中的容器：

```bash
docker exec -it sharelatex bash
```

查看 Overleaf 运行时目录：

```bash
cd /overleaf
ls
```

通常服务代码位于：

```text
/overleaf/services/
```

---

### 5.2 将目标文件复制到 overlay

例如要修改：

```text
/overleaf/services/web/app/src/xxx.js
```

则在仓库中建立对应路径：

```text
overlays/overleaf/services/web/app/src/xxx.js
```

修改 overlay 文件后，重新构建 image：

```bash
docker build \
  -f server-ce/Dockerfile-runtime \
  -t overleaf-runtime:dev \
  .
```

重启服务：

```bash
docker compose up -d --force-recreate sharelatex
```

---

## 6. 验证方式

每次修改后，至少执行以下检查。

### 6.1 Compose 配置检查

```bash
docker compose config
```

### 6.2 Runtime image 构建检查

```bash
docker build \
  -f server-ce/Dockerfile-runtime \
  -t overleaf-runtime:dev \
  .
```

### 6.3 容器启动检查

```bash
docker compose up -d
docker compose ps
```

### 6.4 日志检查

```bash
docker logs -f sharelatex
```

确认没有明显启动错误。

---

## 7. 开发原则

本项目采用“小步 overlay”的方式修改 Overleaf。

### 推荐做法

* 一次只修改一个功能点；
* 每个 overlay 文件都要知道原始路径；
* 修改前保留原始文件来源；
* 每次修改后重新构建 runtime image；
* 每次提交都说明修改了哪个运行时文件；
* 优先做可回滚的小 patch。

### 不推荐做法

* 不要一次性替换大量服务文件；
* 不要直接改容器内文件后不记录；
* 不要把本地数据目录提交到仓库；
* 不要把真实 `.env`、密码、token 提交到仓库；
* 不要在一个分支里同时做 runtime、Web UI、文档和脚本大改。

---

## 8. Git 分支建议

建议按任务拆分分支：

```text
chore/runtime-image-baseline
  runtime image 与 overlay 基线

feat/web-overlay-workflow
  Web 文件 overlay 开发流程

feat/web-ui-small-cleanup
  小范围 Web UI 优化

docs/runtime-development-guide
  开发文档与使用说明

research/collabst-latex-prototype
  协同 LaTeX Web IDE 原型研究
```

---

## 9. 当前状态

已完成：

* 基于官方 `sharelatex/sharelatex` 镜像的 runtime image 工作流；
* overlay 目录结构；
* 本地 docker compose 运行方式；
* runtime 文件提取脚本；
* image 构建验证。

未完成：

* 完整 Web UI 定制；
* Web overlay 自动 diff 工具；
* 编译链路深度改造；
* 协同 LaTeX 工作台原型；
* 版本化与审议系统设计。

---

## 10. 后续方向

短期目标：

* 完善 runtime overlay 开发体验；
* 增加 overlay 文件来源说明；
* 增加一键 rebuild / restart 脚本；
* 增加 overlay diff 检查脚本；
* 做一个最小 Web UI patch 验证流程。

中期目标：

* 梳理 Overleaf Web 运行时结构；
* 提取可替换的编译服务边界；
* 探索 TeX Live Docker compile worker；
* 建立 source/build/review 的文档项目模型。

长期方向：

* 参考 Collabst 的协同文档工作台结构；
* 构建轻量级协同 LaTeX Web IDE；
* 保留协同编辑、审议、PDF 预览；
* 使用 TeX Live Docker image 作为编译后端；
* 避免复刻 Overleaf 的历史包袱。
