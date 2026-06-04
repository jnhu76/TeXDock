# TeXDock

TeXDock 是一个基于稳定 ShareLaTeX / Overleaf Docker 运行时镜像的自托管 LaTeX 运行环境定制项目。

TeXDock **不再把 `overleaf/overleaf` GitHub 仓库的 `main` 分支当作运行时上游**。

当前项目的事实源是已经验证过的 Docker 运行时镜像，例如：

```text
sharelatex/sharelatex:5.5.8
```

## 核心模型

TeXDock 当前采用 **runtime overlay** 模型：

```text
ShareLaTeX / Overleaf 官方运行时镜像
        ↓
sharelatex/sharelatex:5.5.8
        ↓
TeXDock overlays/overleaf/
        ↓
server-ce/Dockerfile-runtime
        ↓
自定义运行时镜像
        ↓
Docker Compose / 外部 Overleaf Toolkit 部署
```

含义很简单：

```text
未修改的文件继续来自官方 Docker 镜像；
TeXDock 只保存 overlays/overleaf/ 下被明确修改的文件；
开发时用 bind mount 挂载 overlay；
发布时用 Dockerfile-runtime COPY overlay。
```

## 项目目标

TeXDock 不是 Overleaf 的完整重写。

TeXDock 的目标是维护一个可控、可复现、易于局部定制的 ShareLaTeX / Overleaf Community Edition 风格运行环境。

第一阶段目标：

* 以稳定 Docker 镜像作为运行时基线；
* 避免依赖不稳定的 upstream source `main`；
* 不重建完整 Overleaf 源码；
* 不运行 Yarn / genScript / source-build 流程；
* 只覆盖确实需要修改的运行时文件；
* 支持单文件、小目录、整服务级别的运行时 overlay 开发；
* 构建轻量自定义 ShareLaTeX / Overleaf 兼容镜像；
* 使用 Docker Compose 或外部 Overleaf Toolkit 运行。

## 当前主线

当前主线是：

```text
FROM sharelatex/sharelatex:5.5.8
COPY overlays/overleaf/ /overleaf/
```

对应 Dockerfile：

```text
server-ce/Dockerfile-runtime
```

TeXDock 当前不做这些事情：

```text
不运行 yarn install
不运行 npm install / npm ci
不运行 node genScript compile
不恢复 upstream source-build 结构
不把完整 services/ 放进主分支
不挂载整个 overlays/overleaf 到 /overleaf
```

## 目录结构

当前推荐结构：

```text
TeXDock/
├── config/
│   └── overleaf.env.example
├── docs/
│   ├── development-workflow.md
│   ├── runtime-overlay-development.md
│   └── runtime-version.md
├── overlays/
│   └── overleaf/
├── scripts/
│   ├── build-runtime-image.sh
│   ├── check-image-runtime.sh
│   ├── extract-runtime-dir.sh
│   ├── extract-runtime-file.sh
│   ├── extract-runtime-service.sh
│   ├── restart-runtime-service.sh
│   └── sync-runtime-version.sh
├── server-ce/
│   └── Dockerfile-runtime
├── docker-compose.yml
├── docker-compose.override.example.yml
├── docker-compose.dev.web.example.yml
├── .nvmrc
├── .node-version
├── README.md
└── LICENSE
```

## 运行时基线

当前基线镜像：

```text
sharelatex/sharelatex:5.5.8
```

已从镜像中检测到的运行时版本：

```text
node: v22.15.1
npm:  10.9.2
yarn: not-found
```

规则：

* Node.js 版本以 Docker 镜像为准；
* `.nvmrc` 和 `.node-version` 只用于宿主机编辑器 / 工具链对齐；
* 不要从 upstream GitHub 仓库推断运行时版本；
* 不要假设镜像里有 Yarn；
* 运行时镜像是事实源。

同步宿主机版本提示文件：

```bash
./scripts/sync-runtime-version.sh
```

## 快速开始

### 1. 创建本地配置

```bash
cp config/overleaf.env.example config/overleaf.env
```

按需修改：

```text
config/overleaf.env
```

例如：

```env
OVERLEAF_SITE_URL=http://localhost:8080
OVERLEAF_APP_NAME=TeXDock

OVERLEAF_MONGO_URL=mongodb://mongo:27017/sharelatex
MONGO_URL=mongodb://mongo:27017/sharelatex

OVERLEAF_REDIS_HOST=redis
OVERLEAF_REDIS_PORT=6379
REDIS_HOST=redis
REDIS_PORT=6379
```

邮件配置也在这里设置：

```env
OVERLEAF_EMAIL_FROM_ADDRESS=no-reply@example.com
OVERLEAF_EMAIL_REPLY_TO=support@example.com
OVERLEAF_EMAIL_SMTP_HOST=smtp.example.com
OVERLEAF_EMAIL_SMTP_PORT=587
OVERLEAF_EMAIL_SMTP_SECURE=false
OVERLEAF_EMAIL_SMTP_USER=smtp-user
OVERLEAF_EMAIL_SMTP_PASS=smtp-password
OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH=true
```

`config/overleaf.env` 是本地文件，不应提交。

### 2. 构建 TeXDock runtime 镜像

```bash
./scripts/build-runtime-image.sh
```

默认构建：

```text
{USERNAME}/sharelatex:0.2.0
{USERNAME}/sharelatex:latest
```

也可以手动构建：

```bash
DOCKER_BUILDKIT=1 docker build \
  -f server-ce/Dockerfile-runtime \
  -t {USERNAME}/sharelatex:0.2.0 \
  -t {USERNAME}/sharelatex:latest \
  .
```

构建过程中不应该出现：

```text
yarn install
npm install
npm ci
genScript compile
```

### 3. 启动服务

```bash
docker compose up -d
```

查看状态：

```bash
docker compose ps
```

查看日志：

```bash
docker logs -f texdock-sharelatex
```

修改 `config/overleaf.env` 后，建议重新创建容器：

```bash
docker compose up -d --force-recreate
```

不要只依赖：

```bash
docker compose restart
```

因为环境变量变更通常需要重新创建容器。

## Runtime Overlay 开发模式

TeXDock 支持三种 overlay 开发方式：

```text
1. 单文件 overlay
2. 小目录 overlay
3. 整服务 overlay
```

### 模式 A：单文件 overlay

适合小改动，例如修改一个 JS 文件或配置文件。

从运行时镜像中抽取文件：

```bash
./scripts/extract-runtime-file.sh /overleaf/services/web/app.js
```

生成：

```text
overlays/overleaf/services/web/app.js
```

然后修改这个文件。

开发时挂载：

```yaml
services:
  sharelatex:
    volumes:
      - ./overlays/overleaf/services/web/app.js:/overleaf/services/web/app.js
```

启动开发 compose：

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

重启对应服务：

```bash
./scripts/restart-runtime-service.sh web
```

### 模式 B：小目录 overlay

适合一组相关文件。

```bash
./scripts/extract-runtime-dir.sh /overleaf/services/web/app/src
```

生成：

```text
overlays/overleaf/services/web/app/src/
```

然后在开发 compose 中挂载这个小目录。

### 模式 C：整服务 overlay

适合复杂服务调试，例如 `services/web`。

抽取完整运行时服务目录：

```bash
./scripts/extract-runtime-service.sh web
```

生成：

```text
overlays/overleaf/services/web/
```

开发时使用：

```bash
cp docker-compose.dev.web.example.yml docker-compose.dev.web.yml
```

启动：

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.web.yml up -d
```

重启 web 服务：

```bash
./scripts/restart-runtime-service.sh web
```

这种方式适合：

```text
bug 分布在多个文件；
改动范围暂时不清楚；
web 服务内部依赖关系复杂；
单文件挂载不现实。
```

但注意：

```text
可以挂载 /overleaf/services/web；
不要挂载整个 /overleaf；
不要挂载 ./overlays/overleaf:/overleaf。
```

## Overlay 规则

必须遵守：

```text
不要复制整个 /overleaf
不要复制整个 services/
不要挂载 ./overlays/overleaf:/overleaf
只覆盖 TeXDock 明确修改的文件或服务目录
```

推荐优先级：

```text
单文件 overlay
        ↓
小目录 overlay
        ↓
整 service overlay
        ↓
禁止整个 /overleaf overlay
```

## 前端改动边界

Runtime overlay 不等于 source-build。

如果修改的是后端 JS、配置、模板，通常重启服务即可。

如果修改的是需要 webpack 重新打包的前端源码，runtime overlay 不一定直接生效。你需要先确认运行时实际读取的是：

```text
源码文件
```

还是：

```text
编译后的静态产物
```

如果运行时读取的是编译产物，应覆盖对应产物，而不是直接改源码。

新增 npm 依赖、修改 package.json、完整重建 web bundle，不属于当前 runtime overlay 主线，需要单独设计。

## 常用脚本

### 检查镜像运行时

```bash
./scripts/check-image-runtime.sh sharelatex/sharelatex:5.5.8
```

用于查看：

```text
OS 信息
Node.js / npm / yarn 版本
二进制路径
PATH
已安装包
nodejs apt policy
```

### 同步宿主机 Node 版本提示

```bash
./scripts/sync-runtime-version.sh
```

会更新：

```text
.nvmrc
.node-version
docs/runtime-version.md
```

### 抽取运行时文件

```bash
./scripts/extract-runtime-file.sh /overleaf/services/web/app.js
```

### 抽取运行时目录

```bash
./scripts/extract-runtime-dir.sh /overleaf/services/web/app/src
```

### 抽取完整服务

```bash
./scripts/extract-runtime-service.sh web
```

### 重启服务

```bash
./scripts/restart-runtime-service.sh web
```

默认容器名：

```text
texdock-sharelatex
```

如需覆盖：

```bash
CONTAINER=texdock-sharelatex ./scripts/restart-runtime-service.sh web
```

### 构建 runtime 镜像

```bash
./scripts/build-runtime-image.sh
```

## Docker Compose

TeXDock 提供一个最小 runtime compose：

```text
docker-compose.yml
```

它负责启动：

```text
sharelatex app
MongoDB
Redis
```

本地配置来自：

```text
config/overleaf.env
```

开发挂载示例：

```text
docker-compose.override.example.yml
docker-compose.dev.web.example.yml
```

生产部署也可以继续使用外部 Overleaf Toolkit。TeXDock 不 vendor 完整 Toolkit。

## 配置文件

提交的模板：

```text
config/overleaf.env.example
```

本地实际配置：

```text
config/overleaf.env
```

`config/overleaf.env` 已加入 `.gitignore`，不要提交真实 SMTP 密码、域名密钥或生产环境凭据。

## 旧 source-build 路线

TeXDock 曾经尝试过基于 upstream source / vendor services / build context 的源码构建路线。

该路线现在已经暂停。

历史上涉及的内容包括：

```text
Yarn workspace
genScript compile
server-ce/Dockerfile
server-ce/Dockerfile-base
vendor service snapshot
build/services.txt
prepare-build-context.sh
```

当前主线不再使用这些内容。

如果未来确实需要完整 source-build，应单独开分支重新设计，不要混入 runtime overlay 主线。

## 重要规则

### 不要把 upstream source 当 runtime upstream

不要把 `overleaf/overleaf` GitHub `main` 当作当前运行时事实源。

当前事实源是：

```text
sharelatex/sharelatex:5.5.8
```

### 不要运行 source-build 命令

不要运行：

```bash
yarn install
npm install
npm ci
node genScript install
node genScript compile
```

### 不要整坨覆盖 `/overleaf`

错误示例：

```yaml
volumes:
  - ./overlays/overleaf:/overleaf
```

正确做法：

```yaml
volumes:
  - ./overlays/overleaf/services/web:/overleaf/services/web
```

或者：

```yaml
volumes:
  - ./overlays/overleaf/services/web/app.js:/overleaf/services/web/app.js
```

### 不要提交真实配置

不要提交：

```text
config/overleaf.env
```

只提交：

```text
config/overleaf.env.example
```

## 推荐开发流程

### 小改动

```text
extract-runtime-file
        ↓
修改 overlays/overleaf/...
        ↓
docker compose + dev override
        ↓
restart-runtime-service
        ↓
验证
        ↓
提交 overlay 文件
        ↓
build-runtime-image
```

### 大服务调试

```text
extract-runtime-service web
        ↓
挂载 overlays/overleaf/services/web
        ↓
修改多个文件
        ↓
restart web
        ↓
验证
        ↓
提交实际修改
        ↓
build-runtime-image
```

## 推荐提交顺序

```text
1. dev: extract web runtime service
2. fix(web): patch specific runtime behavior
3. docs: document observed runtime behavior
4. build: rebuild runtime overlay image
```

如果只是抽取服务用于本地调试，不一定要提交整个服务目录。
提交时应尽量只提交真正修改过、需要长期维护的 overlay 文件。

## 总结

TeXDock 当前模型：

```text
官方 Docker runtime image 提供完整 Overleaf 运行时；
TeXDock overlays/overleaf/ 保存局部覆盖；
开发时通过 bind mount 验证；
发布时通过 Dockerfile-runtime COPY 覆盖；
docker-compose.yml 提供最小本地运行编排；
config/overleaf.env 保存本地运行配置。
```

最重要的规则：

```text
不要重建完整 Overleaf；
不要恢复 Yarn/source-build；
不要整坨挂载 /overleaf；
改哪里，抽哪里；
复杂服务可以整 service overlay；
最终镜像只 COPY overlays。
```
