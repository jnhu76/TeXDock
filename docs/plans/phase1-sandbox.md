> **Archived.** This document is for reference only. Canonical deployment files are maintained in [texdock-deploy](https://github.com/jnhu76/texdock-deploy). Commands and paths may be outdated.
# Phase 1: 沙箱编译启用实施计划

**目标：** 启用 Docker 沙箱编译（Sandboxed Compiles），为 TeXDock 提供安全的 LaTeX 编译隔离环境

**架构：** Sibling Containers（兄弟容器）模式，主容器通过宿主机 Docker socket 拉起独立的 TeXLive 容器执行编译，而非 Docker-in-Docker。

**涉及新文件：**
- `server-ce/Dockerfile-sandbox-web` — web-only 主容器镜像（不含 TeXLive）
- `server-ce/Dockerfile-sandbox-texlive` — 独立 TeXLive sibling 镜像（不含 web 栈）
- `docker-compose.sandbox.yml` — 沙箱 override compose 文件
- `.env.example` / `.env` — 路径变量配置
- `scripts/init-sandbox-dirs.sh` — 宿主机编译目录初始化

**预计工期：** 1-2 天（构建镜像 + 验证）

---

## 架构说明

### 非沙箱模式（现有，保持不动）

```
主容器 sharelatex-full (web + TeXLive scheme-full)
  └─ LocalCommandRunner → 直接在容器内执行 latexmk
```

### 沙箱模式（新增）

```
宿主机 Docker daemon
  ├─ 主容器 texdock/sharelatex-web (仅 web 全栈，无 TeXLive)
  │    └─ CLSI 通过 /var/run/docker.sock 请求 daemon
  │         └─ daemon 创建 sibling 容器
  │              └─ texdock/texlive:2026.1 (独立 TeXLive)
  │                   └─ 执行 latexmk 编译
  └─ ... (其他服务：mongo, redis)
```

### 工作流程（一次编译）

1. CLSI 把项目源文件写入 `/var/lib/overleaf/data/compiles/<projectId-userId>`（容器内）
2. CLSI 通过宿主机 Docker socket 创建新 sibling 容器
3. 宿主机路径 `<OVERLEAF_DATA_PATH>/data/compiles/<projectId-userId>` bind-mount 到 sibling 容器的 `/compile`
4. sibling 容器内执行 `latexmk`，产物落到 output 目录
5. 容器用完即销毁（过期清理由 `DockerRunner.startContainerMonitor` 处理）

> ⚠️ 关键：`SANDBOXED_COMPILES_HOST_DIR_*` 必须是宿主机绝对路径，因为 bind-mount 由宿主机 daemon 执行。

---

## 文件说明

### Dockerfile-sandbox-web

自包含的 web-only 主镜像，FROM `phusion/baseimage:noble-1.0.3`。

- **合并自** `Dockerfile-base`（系统依赖部分）+ `Dockerfile`（web 全栈部分）
- **去掉了** TeXLive 安装段（scheme-basic 和 scheme-full 都不装）
- 编译全部委托给 sibling 容器，主容器不需要 TeXLive

构建：
```bash
DOCKER_BUILDKIT=1 docker build \
  -f server-ce/Dockerfile-sandbox-web \
  -t texdock/sharelatex-web:latest .
```

### Dockerfile-sandbox-texlive

独立 TeXLive 镜像，FROM `ubuntu:24.04`。

- 用 `install-tl` 网络安装器装 `scheme-full`
- 安装中文字体包（与 `Dockerfile-full` 字体层保持一致）
- 创建 `tex` 用户（uid 1000，与主容器 `node` 用户同 uid，权限对齐）
- 通过冒烟测试 `smoke-test-texlive-core.sh`（中文 XeLaTeX 编译验证）

Tag 约定 `texdock/texlive:<YEAR>.1`（如 `texdock/texlive:2026.1`），`.1` 后缀匹配 `DockerRunner.js:235` 的年份推断正则 `/:([0-9]+)\.[0-9]+/`。

构建：
```bash
DOCKER_BUILDKIT=1 docker build \
  -f server-ce/Dockerfile-sandbox-texlive \
  -t texdock/texlive:2026.1 .
```

### docker-compose.sandbox.yml

Override 文件，叠加在 `docker-compose.yml` 之上使用：

```bash
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml up -d
```

覆盖点：
1. 主容器镜像 → `texdock/sharelatex-web:latest`
2. volumes 增加 `/var/run/docker.sock`
3. 注入沙箱环境变量（`SANDBOXED_COMPILES`、`TEXLIVE_IMAGE`、`ALLOWED_IMAGES` 等）

### scripts/init-sandbox-dirs.sh

创建编译目录并设置 uid 1000 权限：
```bash
./scripts/init-sandbox-dirs.sh
```

### .env

设置 `OVERLEAF_DATA_PATH` 为宿主机数据目录绝对路径。

---

## 实施步骤

### Step 1: 构建两个新镜像

```bash
cd TeXDock

# web-only 主镜像（~1.5GB，约 15-20 分钟）
DOCKER_BUILDKIT=1 docker build \
  -f server-ce/Dockerfile-sandbox-web \
  -t texdock/sharelatex-web:latest .

# TeXLive sibling 镜像（~5GB，约 30-40 分钟，取决于网络）
DOCKER_BUILDKIT=1 docker build \
  -f server-ce/Dockerfile-sandbox-texlive \
  -t texdock/texlive:2026.1 .
```

> 构建时间主要在 TeXLive scheme-full 网络下载。可复用 `Dockerfile-base` / `Dockerfile-full` 的镜像源 `--build-arg TEXLIVE_REPOSITORY`。

### Step 2: 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，确认 OVERLEAF_DATA_PATH 是宿主机绝对路径
# 必须与 docker-compose.yml 的 volume 挂载源 ~/sharelatex_data 一致
```

### Step 3: 初始化宿主机目录

```bash
./scripts/init-sandbox-dirs.sh
```

### Step 4: 启动

```bash
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml up -d
```

### Step 5: 验证

```bash
# 1. 查看日志，确认 CLSI 启动时选择 DockerRunner
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml logs sharelatex | grep -i "docker runner\|DockerRunner"

# 2. 新建一个 LaTeX 项目，编译
# 3. 观察 sibling 容器
docker ps | grep project-

# 4. 检查编译日志
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml logs sharelatex | grep "running docker container"
```

---

## 安全特性

Sibling 容器每次编译都有以下限制（由 `DockerRunner._getContainerOptions` 配置）：

| 特性 | 配置值 | 说明 |
|------|--------|------|
| 网络 | `NetworkDisabled: true` | 容器无网络访问 |
| Linux capabilities | `CapDrop: ALL` | 移除所有 capabilities |
| 非特权 | `SecurityOpt: ['no-new-privileges']` | 禁止提权 |
| 内存 | 1GB | 默认限制 |
| CPU | Ulimit: timeout + 5/10s | 编译超时 CPU 限制 |
| Seccomp | 自定义 profile（~130 syscalls） | 限制系统调用 |
| 用户 | `tex`（非 root） | 最小权限原则 |

---

## 故障排除

### 编译失败

1. 检查 Docker socket 可访问：
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.sandbox.yml exec sharelatex ls -l /var/run/docker.sock
   ```
2. 检查 sibling 镜像存在：
   ```bash
   docker images texdock/texlive
   ```
3. 检查 CLSI 日志：
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.sandbox.yml logs sharelatex | grep clsi
   ```

### 权限错误

确保编译目录属主为 uid 1000：
```bash
ls -ld ~/sharelatex_data/data/compiles
# 应为 uid=1000 gid=1000
sudo chown -R 1000:1000 ~/sharelatex_data/data/compiles ~/sharelatex_data/data/output
```

### 容器启动超时

增加编译超时：
```bash
COMPILE_TIMEOUT: "300"
MAX_COMPILE_TIMEOUT_MINUTES: "15"
```

---

## 验证清单

- [ ] `docker-compose.sandbox.yml` 配置正确（语法验证通过）
- [ ] `.env` 中 `OVERLEAF_DATA_PATH` 为宿主机绝对路径
- [ ] Docker socket 已挂载（`/var/run/docker.sock`）
- [ ] 编译目录已创建且属主正确（uid 1000）
- [ ] `texdock/sharelatex-web:latest` 镜像已构建
- [ ] `texdock/texlive:2026.1` 镜像已构建
- [ ] 新项目编译能成功创建 sibling 容器
- [ ] 编译日志显示 `running docker container`
