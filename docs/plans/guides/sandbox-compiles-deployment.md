# 沙箱编译部署指南

> 本文档针对**新部署场景**。已运行 TeXDock 的服务器请先阅读 [从非沙箱迁移到沙箱](#从非沙箱迁移到沙箱)。

---

## 目录

- [简介](#简介)
- [前置条件](#前置条件)
- [架构概览](#架构概览)
- [Step 1: 构建镜像](#step-1-构建镜像)
- [Step 2: 配置环境变量](#step-2-配置环境变量)
- [Step 3: 初始化宿主机目录](#step-3-初始化宿主机目录)
- [Step 4: 启动服务](#step-4-启动服务)
- [Step 5: 验证沙箱编译](#step-5-验证沙箱编译)
- [从非沙箱迁移到沙箱](#从非沙箱迁移到沙箱)
- [安全说明](#安全说明)
- [故障排除](#故障排除)
- [运维参考](#运维参考)

---

## 简介

沙箱编译（Sandboxed Compiles）让每次 LaTeX 编译都在一个独立的 Docker 容器中执行，实现：

- **隔离安全**：编译代码无法访问主容器的文件系统、网络和环境变量
- **资源控制**：可独立限制每个编译的内存、CPU 和系统调用
- **清理保证**：编译容器用完即销毁，不留残留

TeXDock 的沙箱实现在 Overleaf CE 上配置激活，**无需修改代码**（`CommandRunner.js` 只看环境变量切换 runner，无许可证门控）。

---

## 前置条件

| 项目 | 要求 |
|------|------|
| Docker | 20.10+（推荐 Docker CE，不支持 snap 安装的 Docker） |
| 磁盘 | 额外 6-8 GB（sibling 镜像约 5 GB + 编译目录空间） |
| 网络 | 构建镜像时需访问 CTAN 镜像（安装 TeXLive） |
| 权限 | 宿主机用户需在 `docker` 组（可访问 `/var/run/docker.sock`） |

---

## 架构概览

### 镜像角色

沙箱模式引入两个新镜像，与现有镜像并存，互不干扰：

```
非沙箱链（原有，保持不动）：
  Dockerfile-base → Dockerfile → Dockerfile-full → Dockerfile-full-web
  用途：一体化镜像，编译在主容器内直接执行

沙箱链（新增）：
  Dockerfile-sandbox-web        ← web-only 主容器（不含 TeXLive）
  Dockerfile-sandbox-texlive    ← 独立 TeXLive 编译容器
```

### 编译流程

```
用户点击编译
     ↓
CLSI（主容器内）  ──→  写入源文件到 data/compiles/<project-id>
     │
     ├─ /var/run/docker.sock ──→ 请求宿主机 Docker daemon
     │                                │
     │                                └─ 创建 sibling 容器
     │                                    texdock/texlive:2026.1
     │                                       │
     │                                       ├─ bind-mount: data/compiles → /compile
     │                                       ├─ 执行 latexmk
     │                                       └─ 产物 → data/output
     │
     └─ 读取编译产物 → 返回给前端
```

---

## Step 1: 构建镜像

### 1.1 web-only 主镜像

```bash
cd /path/to/TeXDock

DOCKER_BUILDKIT=1 docker build \
  -f server-ce/Dockerfile-sandbox-web \
  -t texdock/sharelatex-web:latest .
```

构建内容：Ubuntu 系统依赖 + Node.js + Overleaf CE 全栈，不含 TeXLive。
预计时间：15-20 分钟。

### 1.2 TeXLive sibling 镜像

```bash
# 可选：使用清华镜像加速 TeXLive 下载
DOCKER_BUILDKIT=1 docker build \
  -f server-ce/Dockerfile-sandbox-texlive \
  --build-arg TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet \
  -t texdock/texlive:2026.1 .
```

构建内容：Ubuntu + TeXLive scheme-full + 中文字体包 + 冒烟测试。
预计时间：30-40 分钟（主要取决于 TeXLive 下载速度）。

> 镜像 tag 中的 `2026.1` 是 CLSI 要求的格式：
> `DockerRunner.js:235` 用正则 `/:([0-9]+)\.[0-9]+/` 推断 TeXLive 年份并拼出 PATH。

---

## Step 2: 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`，确保 `OVERLEAF_DATA_PATH` 为宿主机绝对路径：

```bash
OVERLEAF_DATA_PATH=/home/hoo/sharelatex_data
```

> 这个路径必须与 `docker-compose.yml` 中 sharelatex 服务的 volume 挂载源一致：
> `- ~/sharelatex_data:/var/lib/overleaf`
>
> 因为 `SANDBOXED_COMPILES_HOST_DIR_COMPILES` 在此路径下拼接子目录，
> 而 sibling 容器的 bind-mount 由宿主机 daemon 执行，它不认识容器内路径。

---

## Step 3: 初始化宿主机目录

```bash
./scripts/init-sandbox-dirs.sh
```

脚本会创建 `<OVERLEAF_DATA_PATH>/data/compiles` 和 `<OVERLEAF_DATA_PATH>/data/output`，
并将属主设为 `uid:gid 1000`（与主容器的 `node` 用户和 sibling 容器的 `tex` 用户同 uid）。

---

## Step 4: 启动服务

```bash
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml up -d
```

首次启动需等待 mongo 初始化副本集（约 10-30 秒）。

确认服务正常运行：

```bash
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml ps
# 应看到 sharelatex、mongo、redis 状态为 Up
```

---

## Step 5: 验证沙箱编译

### 5.1 检查 CLSI 选择了 DockerRunner

```bash
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml logs sharelatex | grep -i "docker runner\|DockerRunner"
# 应输出: selecting command runner for clsi ./DockerRunner
```

### 5.2 检查 Docker socket 可访问

```bash
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml exec sharelatex ls -l /var/run/docker.sock
```

### 5.3 编译一个 LaTeX 项目

1. 浏览器访问 `http://your-server/launchpad` 创建管理员
2. 登录后新建项目，输入以下内容，用 XeLaTeX 编译：

```latex
\documentclass{ctexart}
\begin{document}
你好，沙箱编译！$E = mc^2$
\end{document}
```

### 5.4 观察 sibling 容器

```bash
# 编译过程中，宿主机应看到 sibling 容器
docker ps | grep project-

# 命名格式: project-<projectId>-<md5>
# 编译完成后自动销毁（约 30-60 秒内消失）
```

### 5.5 检查编译日志

```bash
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml logs sharelatex | grep "running docker container"
# 应看到: running docker container
```

---

## 从非沙箱迁移到沙箱

如果服务器上已有 TeXDock 在运行，迁移步骤如下：

### 确认现有项目状态

```bash
# 备份数据
./scripts/backup.sh

# 检查现有项目的 imageName 字段（非沙箱项目可能没设置）
docker exec sharelatex mongo sharelatex --quiet \
  --eval 'db.projects.countDocuments({imageName: {$exists: false}})' \
  2>/dev/null || echo "mongo 不可用（未启动）"
```

### 构建新镜像

按 [Step 1](#step-1-构建镜像) 构建两个新镜像。

### 初始化目录

按 [Step 2-3](#step-2-配置环境变量) 配置 `.env` 并初始化目录。

### 重启服务

```bash
# 停止旧服务（数据卷不删除）
docker compose down

# 用沙箱 override 启动
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml up -d
```

### 验证

按 [Step 5](#step-5-验证沙箱编译) 验证沙箱编译。

---

## 安全说明

### 安全边界

沙箱编译的隔离范围：

| 保护范围 | 是否保护 | 说明 |
|---------|---------|------|
| 编译进程 ← 主容器文件系统 | ✅ | sibling 容器只读 bind-mount 编译目录 |
| 编译进程 ← 其他项目文件 | ✅ | 每个编译独立容器，看不到其他项目 |
| 编译进程 → 网络 | ✅ | `NetworkDisabled: true` |
| 主容器 → Docker socket | ⚠️ | socket 挂载使主容器能操作 Docker，这是设计使然 |
| 宿主机 → 主容器 | ⚠️ | socket 被攻破 → 宿主机 root 权限 |

> 沙箱解决的是「用户 LaTeX 编译之间的隔离」和「编译与主容器的隔离」。
> 它不是整体安全解决方案。Docker socket 挂载本身就是高权限操作。

### 推荐加固

1. **镜像白名单**：`ALLOWED_IMAGES: "texdock/texlive:2026.1"` 防止任意镜像注入
2. **限制编译超时**：`MAX_COMPILE_TIMEOUT_MINUTES: "10"`
3. **定期清理旧容器**：`DockerRunner.startContainerMonitor` 已启用，默认 1 小时清理

---

## 故障排除

### 编译失败：CLSI 日志显示 docker socket 连接错误

```bash
# 检查 socket 权限
ls -l /var/run/docker.sock
# 应显示 srw-rw---- root docker

# 检查主容器内 socket 可见
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml exec sharelatex ls -l /var/run/docker.sock
```

### 编译失败：sibling 容器创建后立即退出

```bash
# 查看已退出的容器
docker ps -a | grep project-

# 检查容器日志
docker logs <container-id>

# 常见原因：
# - TEXLIVE_IMAGE_USER 用户不存在于 sibling 镜像（应设为 "tex"）
# - 镜像 tag 格式不对导致 PATH 错误（应为 :<YEAR>.<n> 如 :2026.1）
```

### 编译超时

```bash
# 在 docker-compose.sandbox.yml 或 .env 中增加超时
COMPILE_TIMEOUT: "300"
MAX_COMPILE_TIMEOUT_MINUTES: "15"
```

### 宿主机目录权限错误

```bash
# 确认目录属主
ls -ld ~/sharelatex_data/data/compiles
# 应显示 uid=1000 gid=1000

# 修复
sudo chown -R 1000:1000 ~/sharelatex_data/data/compiles ~/sharelatex_data/data/output
```

### 构建镜像失败

```bash
# Dockerfile-sandbox-texlive 不使用 # syntax 指令，避免拉取 frontend 镜像超时
# 如果 TeXLive 下载慢，指定镜像源：
--build-arg TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet
```

---

## 运维参考

### 监控 sibling 容器

```bash
# 查看当前运行的编译容器
watch -n 1 'docker ps --filter name=project- --format "table {{.Names}}\t{{.CreatedAt}}\t{{.Status}}"'
```

### 清理残留容器

```bash
# CLSI 自动清理：startContainerMonitor 每小时检查一次
# 手动清理所有超过 1 小时的 project- 容器
docker ps -a --filter name=project- --format "{{.ID}} {{.CreatedAt}}" | \
  awk '{if (system("test $(date -d\""$2" \"$3\"\" +%s) -lt $(date -d \"-1 hour\" +%s)")) print $1}' | \
  xargs -r docker rm -f
```

### 查看编译资源使用

```bash
# 查看正在编译的容器资源占用
docker stats --filter name=project-
```
