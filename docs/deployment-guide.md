# TeXDock 部署指南

TeXDock 是基于 Overleaf Community Edition 的中文本地化版本，支持用户自注册、中文界面和中文邮件通知。

## 目录

- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [docker-compose.yml 配置详解](#docker-composeyml-配置详解)
  - [基础配置](#基础配置必填)
  - [界面与品牌](#界面与品牌可选)
  - [语言设置](#语言设置)
  - [邮件配置](#邮件配置)
  - [安全设置](#安全设置可选)
  - [高级配置](#高级配置可选)
- [启动与初始化](#启动与初始化)
- [创建管理员账户](#创建管理员账户)
- [用户使用流程](#用户使用流程)
- [常见问题](#常见问题)

---

## 系统要求

| 项目 | 最低要求 |
|------|---------|
| OS | Linux (推荐 Ubuntu 22.04+) |
| Docker | 20.10+ |
| Docker Compose | v2+ |
| RAM | 4 GB（推荐 8 GB） |
| 磁盘 | 20 GB（取决于项目数量） |
| CPU | 2 核+ |

---

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/jnhu76/TeXDock.git
cd TeXDock

# 2. 编辑配置
cp docker-compose.yml docker-compose.override.yml
# 编辑 docker-compose.override.yml，按下方说明填写配置

# 3. 启动服务
docker compose up -d

# 4. 创建管理员账户
# 访问 http://your-server/launchpad
```

---

## docker-compose.yml 配置详解

以下是 `docker-compose.yml` 中 `sharelatex` 服务的 `environment` 部分所有可配置项。**推荐做法是复制一份为 `docker-compose.override.yml`**，在其中覆盖需要修改的值，避免直接修改原始文件。

### 基础配置（必填）

```yaml
environment:
  # 应用名称，显示在页面标题和邮件中
  OVERLEAF_APP_NAME: "TeXDock"

  # MongoDB 连接地址
  OVERLEAF_MONGO_URL: "mongodb://mongo/sharelatex"

  # Redis 连接（两组变量都要设置）
  OVERLEAF_REDIS_HOST: "redis"
  REDIS_HOST: "redis"
  # 如 Redis 有密码：
  # OVERLEAF_REDIS_PASS: "your_redis_password"
```

### 界面与品牌（可选）

```yaml
  # 浏览器标签页标题（不设置则使用 OVERLEAF_APP_NAME）
  OVERLEAF_NAV_TITLE: "TeXDock 在线 LaTeX 编辑器"

  # 站点完整 URL（影响邮件中的链接、Cookie 等）
  OVERLEAF_SITE_URL: "http://your-server-ip"
  # 如使用域名：
  # OVERLEAF_SITE_URL: "https://texdock.example.com"

  # 管理员邮箱（显示在错误页面和系统邮件中）
  OVERLEAF_ADMIN_EMAIL: "admin@example.com"

  # 自定义 Logo 图片 URL
  # OVERLEAF_HEADER_IMAGE_URL: "https://example.com/logo.png"

  # 页脚自定义 HTML（JSON 数组格式）
  # OVERLEAF_LEFT_FOOTER: '[{"text": "链接 <a href=\\"https://example.com\\">这里</a>"}]'
  # OVERLEAF_RIGHT_FOOTER: '[{"text": "&copy; 2025 TeXDock"}]'

  # 登录页面自定义文字
  # OVERLEAF_LOGIN_SUPPORT_TITLE: "需要帮助？"
  # OVERLEAF_LOGIN_SUPPORT_TEXT: "请联系管理员 admin@example.com"
```

### 语言设置

```yaml
  # 站点默认语言
  # zh-CN = 简体中文（推荐）
  # en     = English
  OVERLEAF_SITE_LANGUAGE: "zh-CN"
```

> 当设为 `zh-CN` 时，界面文字、邮件模板均自动切换为中文。

### 邮件配置

邮件功能用于：注册确认、密码重置、项目邀请等。**不配置邮件也能使用系统**，但无法发送邮件通知。

#### 方式一：SMTP（推荐）

```yaml
  # 发件人地址
  OVERLEAF_EMAIL_FROM_ADDRESS: "texdock@example.com"

  # SMTP 服务器配置
  OVERLEAF_EMAIL_SMTP_HOST: "smtp.example.com"
  OVERLEAF_EMAIL_SMTP_PORT: "587"
  OVERLEAF_EMAIL_SMTP_SECURE: "false"        # 465端口设为 true，587端口设为 false
  OVERLEAF_EMAIL_SMTP_USER: "texdock@example.com"
  OVERLEAF_EMAIL_SMTP_PASS: "your_smtp_password"
  OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH: "true"
  OVERLEAF_EMAIL_SMTP_IGNORE_TLS: "false"
```

常见 SMTP 服务器配置示例：

| 服务商 | HOST | PORT | SECURE |
|--------|------|------|--------|
| QQ 邮箱 | smtp.qq.com | 587 | false |
| 163 邮箱 | smtp.163.com | 465 | true |
| 阿里企业邮 | smtp.qiye.aliyun.com | 465 | true |
| Gmail | smtp.gmail.com | 587 | false |
| 腾讯企业邮 | smtp.exmail.qq.com | 465 | true |

#### 方式二：AWS SES

```yaml
  OVERLEAF_EMAIL_AWS_SES_ACCESS_KEY_ID: "AKIAIOSFODNN7EXAMPLE"
  OVERLEAF_EMAIL_AWS_SES_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  OVERLEAF_EMAIL_AWS_SES_REGION: "ap-northeast-1"
```

#### 方式三：不配置邮件

注释掉或删除所有 `OVERLEAF_EMAIL_*` 变量即可。系统会正常运行，日志中会出现 SMTP 连接失败的警告（可忽略）。

### 安全设置（可选）

```yaml
  # 会话密钥（生产环境务必设置，否则每次重启会丢失所有登录状态）
  OVERLEAF_SESSION_SECRET: "一个随机的长字符串"

  # 安全 Cookie（使用 HTTPS 时启用）
  # OVERLEAF_SECURE_COOKIE: "true"

  # 反向代理（使用 nginx/caddy 等前置代理时设置）
  # OVERLEAF_BEHIND_PROXY: "true"
```

### 高级配置（可选）

```yaml
  # 允许匿名用户读写共享链接（默认关闭）
  # OVERLEAF_ALLOW_ANONYMOUS_READ_AND_WRITE_SHARING: "true"

  # 限制邀请仅限已有账户的用户
  # OVERLEAF_RESTRICT_INVITES_TO_EXISTING_ACCOUNTS: "true"

  # 启用文件格式转换（缩略图等）
  ENABLE_CONVERSIONS: "true"

  # 允许的链接文件类型
  ENABLED_LINKED_FILE_TYPES: "project_file,project_output_file"

  # 禁用注册时的邮箱确认（默认已禁用）
  EMAIL_CONFIRMATION_DISABLED: "true"

  # 资源删除安全阀：cron 触发后是否真的执行项目清理/过期删除操作。
  # 不控制 cron 是否运行，仅控制是否执行破坏性操作。默认关闭更安全。
  # 仅在明确需要自动清理旧项目时设为 true。
  # ENABLE_CRON_RESOURCE_DELETION: "true"
```

---

## 启动与初始化

### 1. 启动服务

```bash
docker compose up -d
```

### 2. 查看启动日志

```bash
docker compose logs -f sharelatex
```

等待出现 `ready to handle connections` 或 `listening on 0.0.0.0:3000` 表示启动成功。

### 3. 验证服务状态

```bash
# 检查容器状态
docker compose ps

# 应看到 sharelatex、mongo、redis 三个容器均为 running
```

---

## 创建管理员账户

### 方式一：通过 Launchpad（推荐）

1. 浏览器访问 `http://your-server-ip/launchpad`
2. 填写管理员邮箱和密码
3. 点击「Create Admin」
4. 自动跳转到登录页面，使用刚创建的账户登录

> Launchpad 仅在系统没有任何用户时可用。创建管理员后该页面会自动禁用。

### 方式二：通过命令行

```bash
# 进入容器
docker exec -it sharelatex bash

# 创建管理员用户（会输出一个设置密码的 URL）
cd /overleaf/services/web
node modules/user-creator/js/user-creator.js --email=admin@example.com --admin

# 退出容器
exit
```

---

## 用户使用流程

### 注册

1. 访问 `http://your-server-ip/register`
2. 填写邮箱和密码
3. 注册成功后自动登录

### 登录

1. 访问 `http://your-server-ip/login`
2. 输入邮箱和密码

### 创建项目

1. 登录后点击「New Project」
2. 选择空白项目或模板
3. 开始编辑

### 协作

1. 在项目中点击「Share」
2. 输入协作者的邮箱地址
3. 协作者会收到邮件邀请（需配置 SMTP）

---

## 常见问题

### Q: 界面显示为英文？

确保 `docker-compose.yml` 中设置了：
```yaml
OVERLEAF_SITE_LANGUAGE: "zh-CN"
```
修改后需要重启容器：`docker compose restart sharelatex`

### Q: 邮件发送失败？

1. 检查 SMTP 配置是否正确
2. 部分邮箱（QQ、163）需要使用授权码而非登录密码
3. 查看日志：`docker compose logs sharelatex | grep -i email`

### Q: 忘记管理员密码？

```bash
# 进入容器重置密码
docker exec -it sharelatex bash
cd /overleaf/services/web
node modules/user-creator/js/reset-password.js --email=admin@example.com
```

### Q: 如何备份数据？

```bash
# 备份 MongoDB
docker exec mongo mongodump --db sharelatex --out /tmp/backup
docker cp mongo:/tmp/backup ./mongodb-backup

# 备份用户文件（在宿主机上）
tar -czf sharelatex-data-backup.tar.gz ~/sharelatex_data
```

### Q: 如何更新镜像？

```bash
docker compose pull sharelatex
docker compose up -d
# 数据保存在 volume 中不会丢失
```

---

## 完整配置示例

以下是一个典型的中文部署配置：

```yaml
services:
  sharelatex:
    restart: always
    image: fred1653/sharelatex-full:latest
    container_name: sharelatex
    depends_on:
      mongo:
        condition: service_healthy
      redis:
        condition: service_started
    ports:
      - "80:80"
    volumes:
      - ~/sharelatex_data:/var/lib/overleaf
    environment:
      OVERLEAF_APP_NAME: "TeXDock"
      OVERLEAF_SITE_URL: "http://your-server-ip"
      OVERLEAF_ADMIN_EMAIL: "admin@example.com"
      OVERLEAF_SITE_LANGUAGE: "zh-CN"
      OVERLEAF_MONGO_URL: "mongodb://mongo/sharelatex"
      OVERLEAF_REDIS_HOST: "redis"
      REDIS_HOST: "redis"
      OVERLEAF_SESSION_SECRET: "change-this-to-a-random-string"
      ENABLED_LINKED_FILE_TYPES: "project_file,project_output_file"
      ENABLE_CONVERSIONS: "true"
      EMAIL_CONFIRMATION_DISABLED: "true"
      # 邮件配置（按需启用）
      # OVERLEAF_EMAIL_FROM_ADDRESS: "texdock@example.com"
      # OVERLEAF_EMAIL_SMTP_HOST: "smtp.example.com"
      # OVERLEAF_EMAIL_SMTP_PORT: "587"
      # OVERLEAF_EMAIL_SMTP_SECURE: "false"
      # OVERLEAF_EMAIL_SMTP_USER: "texdock@example.com"
      # OVERLEAF_EMAIL_SMTP_PASS: "your-password"

  mongo:
    restart: always
    image: mongo:8.0
    container_name: mongo
    command: "--replSet overleaf"
    volumes:
      - ~/mongo_data:/data/db
      - ./bin/shared/mongodb-init-replica-set.js:/docker-entrypoint-initdb.d/mongodb-init-replica-set.js
    environment:
      MONGO_INITDB_DATABASE: sharelatex
    extra_hosts:
      - mongo:127.0.0.1
    healthcheck:
      test: echo 'db.stats().ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 10s
      retries: 5

  redis:
    restart: always
    image: redis:6.2
    container_name: redis
    volumes:
      - ~/redis_data:/data
```
