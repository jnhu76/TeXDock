# Phase 1: 沙箱编译启用实施计划

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**目标：** 启用 Docker 沙箱编译，提供安全的 LaTeX 编译环境

**架构：** 复用现有 `DockerRunner` 实现，通过配置激活

**技术栈：** Docker, Node.js, latexmk, Seccomp, Firejail

**预计工期：** 1-2 天（配置 + 验证）

---

### Task 1: 添加沙箱编译环境变量到 docker-compose.yml

**目标：** 在 docker-compose.yml 中启用沙箱编译配置

**文件：**
- 修改: `docker-compose.yml:96-110`

**步骤 1: 取消注释沙箱编译配置**

```yaml
      ## Community Edition 不支持沙箱编译，以下配置必须保持注释状态，否则会导致编译失败
      ##
      ## Sandboxed Compiles: https://docs.overleaf.com/on-premises/configuration/overleaf-toolkit/server-pro-only-configuration/sandboxed-compiles
      SANDBOXED_COMPILES: "true"
      ### Bind-mount source for /var/lib/overleaf/data/compiles inside the container.
      SANDBOXED_COMPILES_HOST_DIR_COMPILES: "${HOME}/sharelatex_data/data/compiles"
      ### Bind-mount source for /var/lib/overleaf/data/output inside the container.
      SANDBOXED_COMPILES_HOST_DIR_OUTPUT: "${HOME}/sharelatex_data/data/output"
      ### Backwards compatibility (before Server Pro 5.5)
      DOCKER_RUNNER: "true"
      SANDBOXED_COMPILES_SIBLING_CONTAINERS: "true"
```

**步骤 2: 挂载 Docker socket**

```yaml
    volumes:
      # 用户数据持久化（项目文件、编译输出等）
      - ~/sharelatex_data:/var/lib/overleaf
      # Docker socket（仅 Server Pro 沙箱编译需要，Community Edition 无需挂载）
      - /var/run/docker.sock:/var/run/docker.sock
```

**步骤 3: 验证配置语法**

Run: `docker compose config --quiet`
Expected: 无错误输出

**步骤 4: 提交**

```bash
git add docker-compose.yml
git commit -m "chore: enable sandboxed compiles in docker-compose"
```

---

### Task 2: 创建编译目录结构

**目标：** 创建沙箱编译所需的目录结构

**文件：**
- 创建: 脚本文件

**步骤 1: 创建初始化脚本**

```bash
#!/bin/bash
# scripts/init-sandbox-dirs.sh

set -e

DATA_DIR="${HOME}/sharelatex_data"
COMPILES_DIR="${DATA_DIR}/data/compiles"
OUTPUT_DIR="${DATA_DIR}/data/output"

echo "Creating sandbox compile directories..."

mkdir -p "${COMPILES_DIR}"
mkdir -p "${OUTPUT_DIR}"

# 设置权限（Docker 容器内用户 tex 需要访问）
chmod 777 "${COMPILES_DIR}"
chmod 777 "${OUTPUT_DIR}"

echo "Sandbox directories created successfully."
echo "  Compiles: ${COMPILES_DIR}"
echo "  Output:   ${OUTPUT_DIR}"
```

**步骤 2: 运行初始化脚本**

```bash
chmod +x scripts/init-sandbox-dirs.sh
./scripts/init-sandbox-dirs.sh
```

**步骤 3: 提交**

```bash
git add scripts/init-sandbox-dirs.sh
git commit -m "chore: add sandbox directory initialization script"
```

---

### Task 3: 编写沙箱编译部署文档

**目标：** 创建沙箱编译配置和部署指南

**文件：**
- 创建: `docs/plans/guides/sandbox-compiles-deployment.md`

**步骤 1: 创建文档**

```markdown
# 沙箱编译配置指南

## 架构说明

沙箱编译使用 Docker 容器隔离 LaTeX 编译过程，提供以下安全特性：

- **网络隔离**：容器无网络访问
- **能力移除**：移除所有 Linux capabilities
- **Seccomp 白名单**：限制系统调用
- **内存限制**：默认 1GB
- **非 root 用户**：以 `tex` 用户运行

## 前置条件

- Docker daemon 运行
- Docker socket 可访问
- 足够的磁盘空间（TeX Live 镜像约 5-10GB）

## 配置步骤

### 1. 启用沙箱编译

修改 docker-compose.yml：

\`\`\`yaml
services:
  sharelatex:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      SANDBOXED_COMPILES: "true"
      SANDBOXED_COMPILES_HOST_DIR_COMPILES: "${HOME}/sharelatex_data/data/compiles"
      SANDBOXED_COMPILES_HOST_DIR_OUTPUT: "${HOME}/sharelatex_data/data/output"
      DOCKER_RUNNER: "true"
      TEXLIVE_IMAGE: "quay.io/sharelatex/texlive-full:2024.1"
\`\`\`

### 2. 创建编译目录

\`\`\`bash
./scripts/init-sandbox-dirs.sh
\`\`\`

### 3. 重启服务

\`\`\`bash
docker compose down
docker compose up -d
\`\`\`

### 4. 验证

1. 创建一个简单的 LaTeX 项目
2. 点击编译
3. 检查日志：`docker compose logs clsi`
4. 应该看到 Docker 容器创建和执行的日志

## 安全配置

### Seccomp 配置

默认 Seccomp 配置位于 `services/clsi/seccomp/clsi-profile.json`，包含：

- 允许的系统调用：~130 个
- 默认动作：阻止（SCMP_ACT_ERRNO）
- 阻止的能力：网络、ptrace、mount 等

### 自定义 Seccomp

如需自定义，设置环境变量：

\`\`\`yaml
SECCOMP_PROFILE: "/path/to/custom-profile.json"
\`\`\`

### AppArmor

如需 AppArmor 支持：

\`\`\`yaml
APPARMOR_PROFILE: "docker-default"
\`\`\`

## 编译组

| 编译组 | 说明 | 自动编译限制 |
|--------|------|--------------|
| `standard` | 默认 | 25 次/20 秒 |
| `priority` | 高级用户 | 无限制 |
| `alpha` | 管理员 | 无限制 + CLSI 缓存 |

## 资源限制

| 资源 | 默认值 | 配置方式 |
|------|--------|----------|
| 内存 | 1GB | Docker 容器限制 |
| CPU | 无限制 | 可通过 COMPILE_GROUP_DOCKER_CONFIGS 配置 |
| 编译超时 | 180 秒 | `COMPILE_TIMEOUT` 环境变量 |
| 看门狗超时 | 10 分钟 | `MAX_COMPILE_TIMEOUT_MINUTES` 环境变量 |

## TeX Live 镜像

### 默认镜像

\`\`\`
quay.io/sharelatex/texlive-full:2024.1
\`\`\`

### 自定义镜像

\`\`\`yaml
TEXLIVE_IMAGE: "your-registry/texlive-custom:latest"
\`\`\`

### 允许的镜像列表

\`\`\`yaml
ALLOWED_IMAGES: "quay.io/sharelatex/texlive-full:2024.1 your-registry/texlive-custom:latest"
\`\`\`

## 故障排除

### 编译失败

1. 检查 Docker socket 权限：`ls -la /var/run/docker.sock`
2. 检查 CLSI 日志：`docker compose logs clsi`
3. 检查 Docker 容器：`docker ps -a | grep compile`

### 权限错误

确保编译目录权限正确：

\`\`\`bash
chmod -R 777 ~/sharelatex_data/data/compiles
chmod -R 777 ~/sharelatex_data/data/output
\`\`\`

### 超时

增加编译超时：

\`\`\`yaml
COMPILE_TIMEOUT: "300"  # 5 分钟
MAX_COMPILE_TIMEOUT_MINUTES: "15"
\`\`\`

## 性能优化

### 启用 CLSI 缓存

\`\`\`yaml
COMPILE_GROUP_DOCKER_CONFIGS: '{"priority": {"OptimiseInDocker": true}}'
\`\`\`

### 启用 PDF 优化

\`\`\`yaml
OPTIMISE_PDF: "true"
\`\`\`
```

**步骤 2: 提交**

```bash
git add docs/plans/guides/sandbox-compiles-deployment.md
git commit -m "docs: add sandboxed compiles deployment guide"
```

---

## 验证清单

- [ ] docker-compose.yml 包含沙箱编译配置
- [ ] Docker socket 已挂载
- [ ] 编译目录已创建
- [ ] 部署文档完整且准确
- [ ] 配置语法验证通过
