# TeXDock 部署指南

TeXDock 是基于 Overleaf Community Edition 的中文本地化版本，支持用户自注册、中文界面和中文邮件通知。

## 目录

- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [docker-compose.yml 配置详解](#docker-composeyml-配置详解)
  - [基础配置](#基础配置必填)
  - [界面与品牌](#界面与品牌可选)
  - [语言设置](#语言设置)
  - [时区与编译](#时区与编译)
  - [管理面板](#管理面板)
  - [邮件配置](#邮件配置)
  - [LDAP 登录](#ldap-登录可选)
  - [沙箱编译](#沙箱编译可选)
  - [安全设置](#安全设置可选)
  - [高级配置](#高级配置可选)
- [启动与初始化](#启动与初始化)
- [创建管理员账户](#创建管理员账户)
- [管理面板与审计日志](#管理面板与审计日志)
- [Track Changes 修订跟踪](#track-changes-修订跟踪)
- [审阅面板](#审阅面板)
- [用户使用流程](#用户使用流程)
- [升级指南](#升级指南)
- [备份策略](#备份策略)
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

### 时区与编译

```yaml
  # 时区设置：控制 Node.js 进程的时区，影响 toLocaleString() 等时间显示
  # 默认 UTC。中国用户可设为 Asia/Shanghai。
  TZ: "Asia/Shanghai"

  # 编译看门狗超时（分钟）：超过此时间的编译进程会被自动终止
  # 默认 10 分钟。设为 0 可禁用看门狗。
  MAX_COMPILE_TIMEOUT_MINUTES: "10"
```

### 管理面板

```yaml
  # 启用管理面板（/admin），允许管理员管理用户、项目、查看审计日志
  # 默认关闭。启用后可通过 /admin 访问。
  ADMIN_PRIVILEGE_AVAILABLE: "true"

  # 管理员独立域名（可选，用于多域名部署）
  # ADMIN_URL: "https://admin.example.com"
```

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
  # OVERLEAF_EMAIL_SMTP_NAME: "127.0.0.1"    # SMTP 客户端主机名
  # OVERLEAF_EMAIL_SMTP_LOGGER: "true"       # 启用 SMTP 日志
```

> ⚠️ **TLS 证书问题**：如果遇到邮件发送失败（尤其是自建邮件服务器），建议将 `OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH` 设为 `false` 或注释掉。

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

### LDAP 登录（可选）

需要配合 LDAP 服务器使用，如 OpenLDAP 或 Active Directory：

```yaml
  OVERLEAF_LDAP_URL: "ldap://ldap:389"
  OVERLEAF_LDAP_SEARCH_BASE: "ou=people,dc=example,dc=com"
  OVERLEAF_LDAP_SEARCH_FILTER: "(uid={{username}})"
  OVERLEAF_LDAP_BIND_DN: "cn=admin,dc=example,dc=com"
  OVERLEAF_LDAP_BIND_CREDENTIALS: "your_ldap_password"
  OVERLEAF_LDAP_EMAIL_ATT: "mail"
  OVERLEAF_LDAP_NAME_ATT: "cn"
  OVERLEAF_LDAP_LAST_NAME_ATT: "sn"
  OVERLEAF_LDAP_UPDATE_USER_DETAILS_ON_LOGIN: "true"
```

> 启用 LDAP 后，用户可通过 LDAP 账户登录，首次登录时自动创建本地账户。

### 沙箱编译（可选）

沙箱编译让每次 LaTeX 编译都在一个独立的 Docker 容器（sibling container）中执行，提供编译隔离。详见 [**沙箱编译部署指南**](docs/plans/guides/sandbox-compiles-deployment.md)。

**快速启用（需先构建镜像）：**

```yaml
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  environment:
    SANDBOXED_COMPILES: "true"
    DOCKER_RUNNER: "true"
    SANDBOXED_COMPILES_SIBLING_CONTAINERS: "true"
    TEXLIVE_IMAGE: "texdock/texlive:2026.1"
    TEX_LIVE_DOCKER_IMAGE: "texdock/texlive:2026.1"
    TEXLIVE_IMAGE_USER: "tex"
    SANDBOXED_COMPILES_HOST_DIR_COMPILES: "${OVERLEAF_DATA_PATH}/data/compiles"
    SANDBOXED_COMPILES_HOST_DIR_OUTPUT: "${OVERLEAF_DATA_PATH}/data/output"
```

推荐使用 `docker-compose.sandbox.yml` override 文件而非直接修改 `docker-compose.yml`，方便在两模式间切换。

> 沙箱编译在 TeXDock 的 Community Edition 代码中可正常启用（无许可证门控），但无官方支持。沙箱解决的是「编译与主容器的隔离」，不提供整体安全。

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

  # 自定义邮件页脚文字
  # OVERLEAF_CUSTOM_EMAIL_FOOTER: "This system is run by department x"

  # 项目模板用户 ID（用于新项目模板列表）
  # OVERLEAF_TEMPLATES_USER_ID: "578773160210479700917ee5"

  # 自定义新项目模板链接
  # OVERLEAF_NEW_PROJECT_TEMPLATE_LINKS: '[ {"name":"All Templates","url":"/templates/all"}]'

  # Learn 功能代理
  # OVERLEAF_PROXY_LEARN: "true"
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

## 管理面板与审计日志

### 启用管理面板

在 `docker-compose.yml` 中设置：

```yaml
ADMIN_PRIVILEGE_AVAILABLE: "true"
```

重启容器后生效：

```bash
docker compose restart sharelatex
```

### 访问管理面板

浏览器访问 `http://your-server-ip/admin`，使用管理员账户登录。

管理面板提供：

- **用户管理**：查看、禁用、删除用户账户
- **项目管理**：查看所有项目、管理项目所有权
- **审计日志**：查看系统操作记录

### 审计日志

审计日志记录以下事件：

| 事件类型 | 说明 |
|---------|------|
| 用户注册 | 新用户创建账户 |
| 用户登录 | 登录成功/失败记录 |
| 项目创建 | 新建项目 |
| 项目删除 | 删除项目 |
| 协作者管理 | 添加/移除协作者 |
| 设置变更 | 管理员修改系统设置 |

审计日志可在管理面板的「Audit Log」页面查看，支持按时间和事件类型筛选。

---

## Track Changes 修订跟踪

Track Changes 功能允许协作者在编辑文档时标记修改，便于审阅和追踪变更历史。

### 使用方法

1. 打开项目，进入编辑器
2. 点击工具栏中的 **Track Changes** 按钮启用修订模式
3. 启用后，所有编辑操作会被标记为修订
4. 其他协作者可以看到谁在何时做了什么修改

### 修订操作

- **接受修订**：点击修订标记，选择「Accept」
- **拒绝修订**：点击修订标记，选择「Reject」
- **接受所有**：工具栏菜单 → Accept All Changes
- **拒绝所有**：工具栏菜单 → Reject All Changes

> Track Changes 默认启用，无需额外配置。

---

## 审阅面板

审阅面板提供了集中管理评论和讨论的功能。

### 功能

- **评论线程**：在文档任意位置添加评论
- **讨论回复**：团队成员可回复评论形成讨论
- **解决线程**：讨论完毕后标记为已解决
- **重新打开**：已解决的线程可重新打开

### 使用方法

1. 在编辑器中选中文本，点击评论按钮添加评论
2. 点击右侧面板的「Review」标签查看所有评论
3. 在审阅面板中回复、解决或删除评论

### 权限说明

| 操作 | 权限要求 |
|------|---------|
| 查看评论 | 项目任何成员 |
| 添加评论 | 项目任何成员 |
| 编辑自己的评论 | 评论作者 |
| 删除任何人的评论 | 项目写入权限 |
| 删除评论线程 | 项目写入权限 |

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

## 升级指南

### 从 0.2.0 升级到 0.2.1

0.2.1 是向后兼容的增量更新，数据格式无变化，可直接升级。

```bash
# 1. 备份数据（推荐）
bash scripts/backup.sh

# 2. 拉取新镜像
docker compose pull sharelatex

# 3. 重启服务
docker compose up -d

# 4. 验证版本
docker exec sharelatex cat /etc/texdock-version
# 应输出 0.2.1
```

### 升级注意事项

- **数据兼容**：PATCH 版本保证数据格式兼容，升级不会丢失数据
- **配置兼容**：现有环境变量无需修改
- **新功能**：管理面板需手动启用 `ADMIN_PRIVILEGE_AVAILABLE: "true"`
- **回滚**：如需回滚，修改 `docker-compose.yml` 中镜像 tag 为旧版本号即可

> 版本兼容性承诺（PATCH / MINOR / MAJOR）详见 [**版本策略 → 升级兼容性**](version-policy.md#升级兼容性)。

---

## 备份策略

### 需要备份的内容

`docker-compose.yml` 中暴露了三个 volume 目录：

| 目录 | 容器路径 | 说明 |
|------|---------|------|
| `~/mongo_data` | `/data/db` | MongoDB 数据库 |
| `~/redis_data` | `/data` | Redis 持久化数据 |
| `~/sharelatex_data` | `/var/lib/overleaf` | 用户项目文件、编译输出 |

### 使用 rsync 硬链接增量备份

项目提供 `scripts/backup.sh`，通过 rsync + `--link-dest` 硬链接实现增量快照。每次备份只占用变更文件的额外空间，且每个快照都可以直接浏览和恢复。

#### 参数说明

```bash
bash scripts/backup.sh [目标目录] [--tar]
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `目标目录` | `~/texdock-backups/` | 备份存储位置，支持本地路径或挂载的外部存储 |
| `--tar` | 不启用 | 额外打 tar.gz 压缩包，适合拷贝到异地/U盘/NAS |

#### 使用示例

```bash
# 备份到默认目录 ~/texdock-backups/
bash scripts/backup.sh

# 备份到外部硬盘
bash scripts/backup.sh /mnt/usb/texdock

# 备份到 NAS 挂载点 + 打压缩包
bash scripts/backup.sh /mnt/nas/texdock --tar

# 只打压缩包（备份到默认目录）
bash scripts/backup.sh --tar
```

#### 备份目录结构

```text
/mnt/usb/texdock/
  latest → 20260614_030000/       # 软链接，始终指向最新快照
  20260614_030000/                 # 今天的快照
    mongo_data/                    # MongoDB 数据
    redis_data/                    # Redis 数据
    sharelatex_data/               # 用户项目文件
  20260613_030000/                 # 昨天的快照
    ...                            # 未变更文件是硬链接，不额外占空间
  texdock-20260614.tar.gz          # --tar 生成的压缩包
```

#### 存储空间预估

- 首次全量快照：约等于三个目录的实际大小
- 后续增量快照：仅占用变更文件的空间
- 建议备份目标分区至少有 **2 倍** 数据量的可用空间

### 定时自动备份

添加 crontab 定时任务：

```bash
# 每天凌晨 3 点执行增量快照（备份到外部硬盘）
0 3 * * * /path/to/scripts/backup.sh /mnt/usb/texdock >> /var/log/texdock-backup.log 2>&1

# 每周日凌晨 4 点额外打 tar.gz 包（用于异地冷备）
0 4 * * 0 /path/to/scripts/backup.sh /mnt/usb/texdock --tar >> /var/log/texdock-backup.log 2>&1
```

### 恢复数据

```bash
# 停止服务
docker compose stop

# 从最新快照恢复
rsync -av /mnt/usb/texdock/latest/mongo_data/ ~/mongo_data/
rsync -av /mnt/usb/texdock/latest/redis_data/ ~/redis_data/
rsync -av /mnt/usb/texdock/latest/sharelatex_data/ ~/sharelatex_data/

# 从 tar.gz 包恢复（异地备份场景）
# tar -xzf texdock-20260614.tar.gz -C /tmp/restore
# rsync -av /tmp/restore/mongo_data/ ~/mongo_data/
# rsync -av /tmp/restore/redis_data/ ~/redis_data/
# rsync -av /tmp/restore/sharelatex_data/ ~/sharelatex_data/

# 重启服务
docker compose up -d
```

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

参考上方 [备份策略](#备份策略) 章节。

### Q: 如何更新镜像？

```bash
docker compose pull sharelatex
docker compose up -d
# 数据保存在 volume 中不会丢失
```

### Q: 管理面板无法访问？

1. 确认已设置 `ADMIN_PRIVILEGE_AVAILABLE: "true"`
2. 重启容器：`docker compose restart sharelatex`
3. 使用管理员账户登录
4. 访问 `http://your-server-ip/admin`

### Q: Track Changes 不显示？

Track Changes 需要项目所有协作者都使用支持该功能的编辑器版本。确保：
1. 所有用户使用最新版本的 TeXDock
2. 在编辑器工具栏中手动启用 Track Changes

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
      ADMIN_PRIVILEGE_AVAILABLE: "true"
      TZ: "Asia/Shanghai"
      MAX_COMPILE_TIMEOUT_MINUTES: "10"
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
