# Phase 2: PostgreSQL/history-v1 启用实施计划（可选）

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

> **重要：** 此阶段是可选的。CE 版使用 MongoDB 后端存储版本历史，完全正常工作。只有需要更高性能的版本历史查询时才需要启用 PostgreSQL。

**目标：** 启用 PostgreSQL 存储版本历史，提升历史查询性能

**架构：** 双后端架构（MongoDB + PostgreSQL），数字 ID 使用 PG，hex ID 使用 MongoDB

**技术栈：** PostgreSQL, Knex.js, Node.js

**预计工期：** 3-5 天（可选）

**本地部署注意：**
- 无 HTTPS：数据库连接使用 HTTP
- 本地网络：PostgreSQL 使用 Docker 内部网络
- **可选性：** 不配置 `HISTORY_CONNECTION_STRING` 即可跳过此阶段

---

### 前置说明

**PostgreSQL 是可选的。** history-v1 服务在 CE 版中使用 MongoDB 后端存储版本历史，完全正常工作。

**工作原理：**
- 24 位 hex ID（如 `507f1f77bcf86cd799439011`）→ MongoDB 后端
- 数字 ID（如 `42`）→ PostgreSQL 后端
- CE 版项目全部使用 MongoDB ID，**永远走 MongoDB 后端**

**何时需要 PostgreSQL：**
1. 需要更高性能的版本历史查询
2. 项目数量非常大（>10万）
3. 需要 PostgreSQL 的高级查询功能

**如何跳过此阶段：**
- 不配置 `HISTORY_CONNECTION_STRING` 环境变量
- 不启动 PostgreSQL 容器
- 版本历史功能仍然正常工作

---

### Task 1: 添加 PostgreSQL 容器到 docker-compose.yml

**目标：** 在 docker-compose.yml 中添加 PostgreSQL 服务

**文件：**
- 修改: `docker-compose.yml`

**步骤 1: 添加 PostgreSQL 服务**

```yaml
  postgres:
    restart: always
    image: postgres:16
    container_name: postgres
    volumes:
      # 数据库数据持久化
      - ~/postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: history
      POSTGRES_USER: overleaf
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-overleaf_password}"
    ports:
      # 仅本地访问，不暴露到外部网络
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U overleaf -d history"]
      interval: 10s
      timeout: 5s
      retries: 5
```

**步骤 2: 添加 PostgreSQL 依赖到 sharelatex 服务**

```yaml
  sharelatex:
    restart: always
    image: fred1653/sharelatex-full:latest
    container_name: sharelatex
    depends_on:
      mongo:
        condition: service_healthy
      redis:
        condition: service_started
      postgres:
        condition: service_healthy
```

**步骤 3: 添加 PostgreSQL 环境变量**

```yaml
  sharelatex:
    environment:
      # PostgreSQL 配置
      HISTORY_CONNECTION_STRING: "postgresql://overleaf:${POSTGRES_PASSWORD:-overleaf_password}@postgres/history"
      DATABASE_URL: "postgresql://overleaf:${POSTGRES_PASSWORD:-overleaf_password}@postgres/history"
```

**步骤 4: 验证配置语法**

Run: `docker compose config --quiet`
Expected: 无错误输出

**步骤 5: 提交**

```bash
git add docker-compose.yml
git commit -m "chore: add PostgreSQL container for history-v1"
```

---

### Task 2: 安装 PostgreSQL 客户端库

**目标：** 在 Docker 镜像中安装 PostgreSQL 客户端库

**文件：**
- 修改: `server-ce/Dockerfile-base`

**步骤 1: 添加 PostgreSQL 客户端安装**

在 `server-ce/Dockerfile-base` 的 `apt-get install` 部分添加：

```dockerfile
apt-get install -y --no-install-recommends \
  ca-certificates \
  cabextract \
  curl \
  fontconfig \
  ghostscript \
  make \
  perl \
  unzip \
  xz-utils \
  zip \
  libpq-dev \
  postgresql-client
```

**步骤 2: 验证构建**

Run: `docker build -f server-ce/Dockerfile-base -t test-base .`
Expected: 构建成功

**步骤 3: 提交**

```bash
git add server-ce/Dockerfile-base
git commit -m "chore: add PostgreSQL client libraries to base image"
```

---

### Task 3: 运行数据库迁移

**目标：** 创建 PostgreSQL 表结构

**文件：**
- 无新增文件，使用现有迁移

**步骤 1: 启动服务**

```bash
docker compose up -d postgres
```

**步骤 2: 等待 PostgreSQL 就绪**

```bash
until docker compose exec postgres pg_isready -U overleaf -d history; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done
```

**步骤 3: 运行迁移**

```bash
docker compose run --rm sharelatex sh -c "cd /overleaf/services/history-v1 && npx knex migrate:latest"
```

**步骤 4: 验证迁移**

```bash
docker compose exec postgres psql -U overleaf -d history -c "\dt"
```

Expected: 看到以下表：
- chunks
- old_chunks
- pending_chunks
- project_blobs
- knex_migrations

**步骤 5: 提交**

```bash
git add .
git commit -m "chore: run history-v1 PostgreSQL migrations"
```

---

### Task 4: 编写 PostgreSQL 部署文档

**目标：** 创建 PostgreSQL/history-v1 配置和部署指南

**文件：**
- 创建: `docs/plans/guides/postgresql-history-deployment.md`

**步骤 1: 创建文档**

```markdown
# PostgreSQL/history-v1 配置指南

## 架构说明

history-v1 服务使用双后端架构：

- **MongoDB 后端**：存储 24 位 hex ID 的旧项目
- **PostgreSQL 后端**：存储数字 ID 的新项目

ID 格式决定使用哪个后端：
- PostgreSQL 项目：数字 ID（如 `"42"`）
- MongoDB 项目：24 位 hex ID（如 `"507f1f77bcf86cd799439011"`）

## 前置条件

- PostgreSQL 16+
- 足够的磁盘空间（版本历史可能较大）

## 配置步骤

### 1. 添加 PostgreSQL 容器

修改 docker-compose.yml，添加 postgres 服务：

\`\`\`yaml
postgres:
  restart: always
  image: postgres:16
  container_name: postgres
  volumes:
    - ~/postgres_data:/var/lib/postgresql/data
  environment:
    POSTGRES_DB: history
    POSTGRES_USER: overleaf
    POSTGRES_PASSWORD: "your_password"
  ports:
    - "127.0.0.1:5432:5432"
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U overleaf -d history"]
    interval: 10s
    timeout: 5s
    retries: 5
\`\`\`

### 2. 配置连接字符串

在 sharelatex 服务中添加环境变量：

\`\`\`yaml
HISTORY_CONNECTION_STRING: "postgresql://overleaf:your_password@postgres/history"
DATABASE_URL: "postgresql://overleaf:your_password@postgres/history"
\`\`\`

### 3. 安装 PostgreSQL 客户端

在 Dockerfile-base 中添加：

\`\`\`dockerfile
apt-get install -y --no-install-recommends libpq-dev postgresql-client
\`\`\`

### 4. 运行迁移

\`\`\`bash
docker compose up -d postgres
docker compose run --rm sharelatex sh -c "cd /overleaf/services/history-v1 && npx knex migrate:latest"
\`\`\`

### 5. 重启服务

\`\`\`bash
docker compose down
docker compose up -d
\`\`\`

### 6. 验证

1. 检查 PostgreSQL 日志：`docker compose logs postgres`
2. 检查 history-v1 日志：`docker compose logs history-v1`
3. 创建新项目并编辑，检查版本历史功能

## 数据库表结构

### chunks

\`\`\`sql
CREATE TABLE chunks (
  id SERIAL PRIMARY KEY,
  doc_id INTEGER NOT NULL,
  start_version INTEGER NOT NULL,
  end_version INTEGER NOT NULL,
  end_timestamp TIMESTAMP,
  closed BOOLEAN DEFAULT FALSE,
  UNIQUE(doc_id, end_version),
  UNIQUE(doc_id, start_version)
);
\`\`\`

### old_chunks

\`\`\`sql
CREATE TABLE old_chunks (
  chunk_id INTEGER PRIMARY KEY,
  doc_id INTEGER NOT NULL,
  start_version INTEGER NOT NULL,
  end_version INTEGER NOT NULL,
  end_timestamp TIMESTAMP,
  deleted_at TIMESTAMP
);
\`\`\`

### pending_chunks

\`\`\`sql
CREATE TABLE pending_chunks (
  id SERIAL PRIMARY KEY,
  doc_id INTEGER NOT NULL,
  start_version INTEGER NOT NULL,
  end_version INTEGER NOT NULL,
  end_timestamp TIMESTAMP
);
\`\`\`

### project_blobs

\`\`\`sql
CREATE TABLE project_blobs (
  project_id INTEGER NOT NULL,
  hash_bytes BYTEA NOT NULL,
  byte_length INTEGER NOT NULL,
  string_length INTEGER NOT NULL,
  PRIMARY KEY (project_id, hash_bytes)
);
\`\`\`

## 备份策略

### 自动备份

使用 cron 定期备份：

\`\`\`bash
# 每天凌晨 3 点备份
0 3 * * * docker compose exec postgres pg_dump -U overleaf history > ~/backups/history-$(date +\%Y\%m\%d).sql
\`\`\`

### 恢复

\`\`\`bash
docker compose exec -T postgres psql -U overleaf -d history < backup.sql
\`\`\`

## 性能优化

### 连接池

默认连接池配置：

\`\`\`javascript
{
  databasePoolMin: 2,
  databasePoolMax: 10
}
\`\`\`

可通过环境变量调整：

\`\`\`yaml
DATABASE_POOL_MIN: "5"
DATABASE_POOL_MAX: "20"
\`\`\`

### 索引

已创建的索引：
- `chunks(doc_id, end_version)` - 版本查询
- `chunks(doc_id, start_version)` - 版本查询
- `old_chunks(chunk_id)` - 旧块查询

## 故障排除

### 连接失败

1. 检查 PostgreSQL 是否运行：`docker compose ps postgres`
2. 检查连接字符串是否正确
3. 检查 PostgreSQL 日志：`docker compose logs postgres`

### 迁移失败

1. 检查 PostgreSQL 权限
2. 检查表是否已存在
3. 手动运行迁移：`npx knex migrate:latest`

### 性能问题

1. 检查连接池配置
2. 检查查询慢日志
3. 考虑增加 PostgreSQL 资源限制
```

**步骤 2: 提交**

```bash
git add docs/plans/guides/postgresql-history-deployment.md
git commit -m "docs: add PostgreSQL/history-v1 deployment guide"
```

---

## 验证清单

- [ ] docker-compose.yml 包含 PostgreSQL 配置
- [ ] PostgreSQL 客户端库已安装
- [ ] 数据库迁移已运行
- [ ] 部署文档完整且准确
- [ ] 配置语法验证通过
