> **Archived.** This document is for reference only. Canonical deployment files are maintained in [texdock-deploy](https://github.com/jnhu76/texdock-deploy). Commands and paths may be outdated.
# TeXDock 功能模块快速开始指南

## 概述

本文档提供 TeXDock 功能模块的快速开始指南，涵盖从配置启用到开发实施的各个阶段。

**本地部署约束：** 所有配置使用 HTTP 协议，无 HTTPS 证书。

---

## Phase 1: 配置启用（1-3 天）

### LDAP 启用

**前置条件：** LDAP 服务器已运行

**步骤 1: 修改 docker-compose.yml**

取消注释 LDAP 配置（第 112-121 行）：

```yaml
OVERLEAF_LDAP_URL: 'ldap://ldap:389'
OVERLEAF_LDAP_SEARCH_BASE: 'ou=people,dc=example,dc=com'
OVERLEAF_LDAP_SEARCH_FILTER: '(uid={{username}})'
OVERLEAF_LDAP_BIND_DN: 'cn=admin,dc=example,dc=com'
OVERLEAF_LDAP_BIND_CREDENTIALS: 'admin_password'
OVERLEAF_LDAP_EMAIL_ATT: 'mail'
OVERLEAF_LDAP_NAME_ATT: 'cn'
OVERLEAF_LDAP_LAST_NAME_ATT: 'sn'
OVERLEAF_LDAP_UPDATE_USER_DETAILS_ON_LOGIN: 'true'
```

**步骤 2: 重启服务**

```bash
docker compose down
docker compose up -d
```

**步骤 3: 验证**

访问 `http://localhost/login`，应该看到 "Login with LDAP" 选项。

---

### SSO/SAML 启用

**前置条件：** SAML Identity Provider (IdP) 已运行

**步骤 1: 修改 docker-compose.yml**

取消注释 SAML 配置：

```yaml
# 本地部署使用 HTTP 协议
OVERLEAF_SAML_ENABLED: "true"
OVERLEAF_SAML_ENTRY_POINT: "http://idp.example.com/sso/saml"
OVERLEAF_SAML_ISSUER: "http://localhost"
OVERLEAF_SAML_CERTIFICATE: "-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----"
OVERLEAF_SAML_USER_ID_ATTRIBUTE: "uid"
OVERLEAF_SAML_USER_FIRST_NAME_ATTRIBUTE: "cn"
OVERLEAF_SAML_USER_LAST_NAME_ATTRIBUTE: "sn"
```

**步骤 2: 配置 IdP**

在 IdP 中注册 TeXDock 作为 Service Provider (SP)：
- **ACS URL**：`http://localhost/saml/acs`
- **Entity ID**：`http://localhost`
- **ACS Binding**：HTTP-POST

**步骤 3: 重启服务**

```bash
docker compose down
docker compose up -d
```

**步骤 4: 验证**

访问 `http://localhost/login`，应该看到 "Login with SSO" 选项。

**已有组件复用：**
- `SSOLinkingWidget`：`features/settings/components/linking/sso-widget.tsx`
- `SSOProvider`：`features/settings/context/sso-context.tsx`
- `SSOAlert`：`features/settings/components/emails/sso-alert.tsx`

---

### 沙箱编译启用

**前置条件：** Docker daemon 运行

**步骤 1: 修改 docker-compose.yml**

取消注释沙箱编译配置（第 96-110 行）：

```yaml
SANDBOXED_COMPILES: "true"
SANDBOXED_COMPILES_HOST_DIR_COMPILES: "${HOME}/sharelatex_data/data/compiles"
SANDBOXED_COMPILES_HOST_DIR_OUTPUT: "${HOME}/sharelatex_data/data/output"
DOCKER_RUNNER: "true"
```

**步骤 2: 挂载 Docker socket**

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

**步骤 3: 创建编译目录**

```bash
mkdir -p ~/sharelatex_data/data/compiles
mkdir -p ~/sharelatex_data/data/output
chmod 777 ~/sharelatex_data/data/compiles
chmod 777 ~/sharelatex_data/data/output
```

**步骤 4: 重启服务**

```bash
docker compose down
docker compose up -d
```

**步骤 5: 验证**

创建一个 LaTeX 项目并编译，检查日志：`docker compose logs clsi`

**已有组件复用：**
- `DockerRunner`：`services/clsi/app/js/DockerRunner.js`
- `ImageNameSetting`：`features/ide-redesign/components/settings/compiler-settings/image-name-setting.tsx`

---

## Phase 2: PostgreSQL/history-v1（可选，3-5 天）

> **注意：** PostgreSQL 是可选增强。CE 版使用 MongoDB 后端存储版本历史，完全正常工作。只有需要更高性能的版本历史查询时才需要启用 PostgreSQL。

**前置条件：** 无

**步骤 1: 修改 docker-compose.yml**

添加 PostgreSQL 服务：

```yaml
postgres:
  restart: always
  image: postgres:16
  container_name: postgres
  volumes:
    - ~/postgres_data:/var/lib/postgresql/data
  environment:
    POSTGRES_DB: history
    POSTGRES_USER: overleaf
    POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-overleaf_password}"
  ports:
    - "127.0.0.1:5432:5432"
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U overleaf -d history"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**步骤 2: 添加依赖和环境变量**

```yaml
sharelatex:
  depends_on:
    postgres:
      condition: service_healthy
  environment:
    HISTORY_CONNECTION_STRING: "postgresql://overleaf:${POSTGRES_PASSWORD:-overleaf_password}@postgres/history"
```

**步骤 3: 安装 PostgreSQL 客户端**

在 `server-ce/Dockerfile-base` 中添加：

```dockerfile
apt-get install -y --no-install-recommends libpq-dev postgresql-client
```

**步骤 4: 运行迁移**

```bash
docker compose up -d postgres
docker compose run --rm sharelatex sh -c "cd /overleaf/services/history-v1 && npx knex migrate:latest"
```

**步骤 5: 重启服务**

```bash
docker compose down
docker compose up -d
```

**已有组件复用：**
- `knex`：`services/history-v1/storage/lib/knex.js`
- 双后端架构：`services/history-v1/storage/lib/chunk_store/index.js`

---

## Phase 3-5: 开发模块

这些模块需要编写代码，详细计划请参考：

- [Phase 3: 资源监控](./phase3-resource-monitor.md)
- [Phase 3: 编译结果缓存增强](./phase3-compile-cache.md)
- [Phase 4: GPU 加速](./phase4-gpu-acceleration.md)
- [Phase 4: 多语言包支持](./phase4-multilang-packages.md)
- [Phase 5: 编译队列](./phase5-compile-queue.md)
- [Phase 5: OIDC](./phase5-oidc.md)

---

## 常用命令

### 服务管理

```bash
# 启动所有服务
docker compose up -d

# 停止所有服务
docker compose down

# 查看日志
docker compose logs -f

# 查看特定服务日志
docker compose logs clsi
docker compose logs sharelatex
```

### 数据库操作

```bash
# 连接 PostgreSQL
docker compose exec postgres psql -U overleaf -d history

# 查看表结构
docker compose exec postgres psql -U overleaf -d history -c "\dt"

# 备份数据库
docker compose exec postgres pg_dump -U overleaf history > backup.sql

# 恢复数据库
docker compose exec -T postgres psql -U overleaf -d history < backup.sql
```

### 测试

```bash
# 运行 CLSI 测试
cd services/clsi && npm test

# 运行 Web 测试
cd services/web && npm test

# 运行 E2E 测试
cd server-ce && npm test
```

### 开发

```bash
# 安装依赖
yarn install

# 构建前端
cd services/web && npm run webpack:production

# 类型检查
cd services/web && npx tsc --noEmit
```

---

## 常见 API 端点

### 编译相关

```bash
# 编译项目
curl -X POST http://localhost/project/{project_id}/compile

# 停止编译
curl -X POST http://localhost/project/{project_id}/compile/stop

# 获取编译状态
curl http://localhost/project/{project_id}/status

# 字数统计
curl http://localhost/project/{project_id}/wordcount
```

### 用户相关

```bash
# 获取设置
curl http://localhost/user/settings

# 更新设置
curl -X POST http://localhost/user/settings -d '{"first_name":"test"}'

# 获取邮箱列表
curl http://localhost/user/emails
```

---

## 故障排除

### 服务无法启动

```bash
# 检查 Docker 状态
docker info

# 检查容器状态
docker compose ps

# 查看详细日志
docker compose logs --tail=100
```

### 数据库连接失败

```bash
# 检查 PostgreSQL 是否运行
docker compose exec postgres pg_isready

# 检查连接
docker compose exec postgres psql -U overleaf -d history -c "SELECT 1"
```

### 编译失败

```bash
# 检查 CLSI 日志
docker compose logs clsi

# 检查 Docker 容器
docker ps -a | grep compile

# 检查编译目录权限
ls -la ~/sharelatex_data/data/compiles
```

### SSO 登录失败

```bash
# 检查 SAML 日志
docker compose exec mongo mongo sharelatex --eval "db.samlLogs.find().sort({createdAt: -1}).limit(5)"

# 检查配置
docker compose exec sharelatex env | grep SAML
```

---

## 获取帮助

- 查看 `docs/plans/` 目录下的详细计划
- 查看各模块的部署指南
- 检查 GitHub Issues
- 查看 Overleaf 官方文档
