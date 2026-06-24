<div align="center">

# 📝 TeXDock

**基于 Overleaf CE 的中文本地化在线 LaTeX 编辑器**

内置完整 TeX Live + CJK 字体 · fontconfig 别名兼容 Windows 字体名 · 开箱即用

![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/license-AGPL--3.0-green)
![TeX Live](https://img.shields.io/badge/TeX%20Live-2026-blue)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20x86__64-lightgrey)
![Version](https://img.shields.io/badge/version-0.2.1-orange)

本项目基于 [Overleaf Community Edition](https://github.com/overleaf/overleaf) 修改，遵循 [AGPL-3.0](LICENSE) 许可证发布。

</div>

---

## 🚀 使用

直接使用预构建镜像，无需自己编译。镜像地址：[Docker Hub → fred1653/sharelatex-full](https://hub.docker.com/repository/docker/fred1653/sharelatex-full/general)

> 当前版本 **0.2.1**。`latest` tag 等价于 `0.2.1`。正式部署推荐使用固定版本号 tag。详见 [**版本策略**](docs/version-policy.md)。

```bash
# 使用项目根目录的 docker-compose.yml 启动
docker compose -f docker-compose.yml up -d

# 创建管理员
# 🌐 浏览器访问 http://localhost/launchpad

# 停止
docker compose -f docker-compose.yml down
```

> `docker-compose.yml` 已配置好 `OVERLEAF_SITE_LANGUAGE: "zh-CN"`（中文界面），开箱即用。

### 🆕 新增功能（0.2.1）

- **Admin 管理面板**：设置 `ADMIN_PRIVILEGE_AVAILABLE: "true"` 启用，支持用户管理、项目管理
- **审计日志**：管理面板内置审计日志，记录用户操作和系统事件
- **Track Changes 修订跟踪**：默认启用，编辑器工具栏可切换修订模式
- **审阅面板**：支持评论线程、解决讨论、实时同步

### ⚙️ 配置

编辑 `docker-compose.yml` 的 environment 部分，按需取消注释：

```yaml
OVERLEAF_SITE_URL: http://your-server-ip           # 🌍 外网访问时必须设置
ADMIN_PRIVILEGE_AVAILABLE: "true"                   # 🔧 启用管理面板（/admin）
TZ: "Asia/Shanghai"                                 # 🕐 时区（影响时间显示）
MAX_COMPILE_TIMEOUT_MINUTES: "10"                   # ⏱️ 编译超时（分钟）
```

#### 📧 邮件配置（SMTP）

邮件功能用于注册确认、密码重置、项目邀请等。在 `docker-compose.yml` 中取消注释以下变量并填入你的 SMTP 信息：

```yaml
OVERLEAF_EMAIL_FROM_ADDRESS: "noreply@example.com"  # 发件人地址
OVERLEAF_EMAIL_SMTP_HOST: smtp.example.com          # SMTP 服务器
OVERLEAF_EMAIL_SMTP_PORT: 587                       # 端口（465 或 587）
OVERLEAF_EMAIL_SMTP_SECURE: false                   # 465→true, 587→false
OVERLEAF_EMAIL_SMTP_USER: user@example.com
OVERLEAF_EMAIL_SMTP_PASS: your-password
```

> ⚠️ **TLS 证书问题**：如果遇到邮件发送失败（尤其是自建邮件服务器），建议将 `OVERLEAF_EMAIL_SMTP_TLS_REJECT_UNAUTH` 设为 `false` 或注释掉。

#### 🔐 LDAP 登录（可选）

支持 LDAP 统一认证（OpenLDAP / Active Directory），启用后用户可通过 LDAP 账户登录：

```yaml
OVERLEAF_LDAP_URL: "ldap://ldap:389"
OVERLEAF_LDAP_SEARCH_BASE: "ou=people,dc=example,dc=com"
OVERLEAF_LDAP_SEARCH_FILTER: "(uid={{username}})"
OVERLEAF_LDAP_BIND_DN: "cn=admin,dc=example,dc=com"
OVERLEAF_LDAP_BIND_CREDENTIALS: "your_ldap_password"
```

📖 完整配置说明见 [**部署指南**](docs/deployment-guide.md)。

### 🪟 沙箱编译（Sandboxed Compiles）

沙箱编译让每次 LaTeX 编译都在一个独立的 Docker 容器（sibling container）中执行，实现编译隔离：

- **隔离安全**：编译代码无法访问主容器的文件系统、网络和环境变量
- **资源控制**：独立限制每个编译的内存、CPU 和系统调用
- **清理保证**：编译容器用完即销毁，不留残留

启用沙箱需要额外构建两个镜像，详见 [**沙箱编译部署指南**](docs/plans/guides/sandbox-compiles-deployment.md)。

```bash
# 构建 web-only 主镜像 + 独立 TeXLive 镜像
DOCKER_BUILDKIT=1 docker build -f server-ce/Dockerfile-sandbox-web -t texdock/sharelatex-web:latest .
DOCKER_BUILDKIT=1 docker build -f server-ce/Dockerfile-sandbox-texlive -t texdock/texlive:2026.1 .

# 配置 + 初始化 + 启动（叠加 override）
cp .env.example .env
./scripts/init-sandbox-dirs.sh
docker compose -f docker-compose.yml -f docker-compose.sandbox.yml up -d
```

> 沙箱模式与默认的非沙箱模式**可共存**，切换只需在启动时是否叠加 `docker-compose.sandbox.yml`。两个模式使用完全不同的镜像链。默认的 `docker-compose.yml` 保持不动。

---

### 📦 安装缺少的 LaTeX 宏包

LaTeX 编译报错 `File 'xxx.sty' not found` 时：

```bash
scripts/tlmgr-in-container.sh search xxx.sty       # 🔍 搜索哪个包包含该文件
scripts/tlmgr-in-container.sh install enumitem      # 📥 安装
```

> ⚠️ 容器重建后安装的包会丢失。详见 [**构建指南 → 安装宏包**](docs/build-guide.md#4-install-tex-live-macropackages)。

### 🧪 测试中文编译

项目提供两个测试文件，上传到 Overleaf 用 XeLaTeX 编译即可验证中文支持：

| 文件 | 说明 |
|------|------|
| [windows字体测试-1.tex](docs/windows字体测试-1.tex) | 简单版：宋体 + 仿宋 + 数学公式 |
| [windows字体测试-2.tex](docs/windows字体测试-2.tex) | 完整版：宋体/仿宋/黑体/楷体 + 加粗/斜体 + 数学混排 |

> 测试使用 `\setCJKmainfont{SimSun}` 等 Windows 字体名，公开镜像通过 fontconfig 别名映射到开源替代字体，无需安装真实 Windows 字体即可编译。

### 🔤 安装私有字体

公开镜像通过 fontconfig 别名兼容 Windows 字体名（SimSun → Noto Serif CJK SC）。如需真实 Windows 字体：

```bash
# 临时导入（容器重建后丢失）
docker cp fonts.zip sharelatex:/tmp/fonts.zip
docker exec sharelatex import-private-fonts-zip /tmp/fonts.zip

# 🔒 或构建私有字体镜像（永久）
docker build -f server-ce/Dockerfile-windows-fonts \
  --build-arg BASE_IMAGE=fred1653/sharelatex-full:latest \
  -t fred1653/sharelatex-full-private:latest .
```

---

## 📊 功能对比

| 功能 | TeXDock | Overleaf CE | Overleaf Server Pro |
|------|:-------:|:-----------:|:-------------------:|
| 中文界面 (zh-CN) | ✅ | ❌ | ❌ |
| 完整 TeX Live | ✅ | ❌ | ❌ |
| Windows 字体兼容 | ✅ | ❌ | ❌ |
| Track Changes 修订跟踪 | ✅ | ❌ | ✅ |
| 审阅面板 | ✅ | ❌ | ✅ |
| 评论线程 | ✅ | ❌ | ✅ |
| 审计日志 | ✅ | ❌ | ✅ |
| Admin 管理面板 | ✅ | ❌ | ✅ |
| LDAP 登录 | ✅ | ❌ | ✅ |
| SMTP 邮件 | ✅ | ✅ | ✅ |
| 沙箱编译 | ✅ | ❌ | ✅ |
| SSO / SAML / OIDC | ❌ | ❌ | ✅ |

---

## 🔨 构建

镜像分两条链构建，互不干扰：

### 非沙箱链（一体化，编译在主容器内）

```text
Dockerfile-base  →  sharelatex-base    →  sharelatex       →  sharelatex-full
  Ubuntu+Node.js     + Overleaf CE代码     + 完整TeX Live+字体
```

```bash
VERSION=$(cat VERSION)

docker build -f server-ce/Dockerfile-base \
  --build-arg TEXDOCK_VERSION=$VERSION \
  -t fred1653/sharelatex-base:$VERSION -t fred1653/sharelatex-base:latest .
docker build -f server-ce/Dockerfile \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg OVERLEAF_BASE_TAG=fred1653/sharelatex-base:$VERSION \
  -t fred1653/sharelatex:$VERSION -t fred1653/sharelatex:latest .
docker build -f server-ce/Dockerfile-full \
  --build-arg TEXDOCK_VERSION=$VERSION \
  --build-arg BASE_IMAGE=fred1653/sharelatex:$VERSION \
  -t fred1653/sharelatex-full:$VERSION -t fred1653/sharelatex-full:latest .
```

### 沙箱链（分离式，编译在 sibling 容器）

```text
Dockerfile-sandbox-web          Dockerfile-sandbox-texlive
  web-only（不含 TeXLive）       独立 TeXLive（不含 web）
```

```bash
docker build -f server-ce/Dockerfile-sandbox-web \
  -t texdock/sharelatex-web:latest .
docker build -f server-ce/Dockerfile-sandbox-texlive \
  --build-arg TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet \
  -t texdock/texlive:2026.1 .
```

📖 完整构建说明、字体策略、私有字体镜像见 [**构建指南**](docs/build-guide.md)。

---

## 💻 开发

修改 Web 前端/后端代码时，用 `docker-compose.dev.web.yml` 挂载本地源码：

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.web.yml up -d
```

这会将 `./services/web` 和 `./libraries` 挂载进容器，修改后重启 web 服务即可验证：

```bash
# 🎨 前端修改需重新打包
docker exec sharelatex bash -lc 'cd /overleaf/services/web && npm run webpack:production'

# 🔄 重启 web 服务
docker exec sharelatex bash -lc 'sv restart /etc/service/web-overleaf'
```

功能稳定后通过 `Dockerfile-full-web` 固化到镜像：

```bash
docker build -f server-ce/Dockerfile-full-web -t fred1653/sharelatex-full:latest .
docker compose up -d --force-recreate
```

📖 完整开发流程、调试方法、镜像固化见 [**Web 开发流程**](docs/web-development-workflow.md)。

---

## 📚 文档

| 场景 | 文档 |
|:----:|------|
| 🚀 部署使用 | [**部署指南**](docs/deployment-guide.md) — 系统要求、配置详解、启动初始化、常见问题 |
| 🔨 镜像构建 | [**构建指南**](docs/build-guide.md) — 三级构建、字体策略、宏包安装 |
| 💻 Web 开发 | [**Web 开发流程**](docs/web-development-workflow.md) — volume overlay、调试、镜像固化 |
| 📌 版本策略 | [**版本策略**](docs/version-policy.md) — 版本号规则、Docker tag 策略 |

## 📂 目录结构

```text
docker-compose.yml                # 🚀 生产配置（非沙箱，默认）
docker-compose.dev.web.yml        # 💻 开发 overlay（挂载 web 源码）
docker-compose.sandbox.yml        # 🪟 沙箱编译 overlay（叠加使用）

scripts/init-sandbox-dirs.sh      # 🪟 沙箱编译目录初始化
scripts/tlmgr-in-container.sh     # 📦 在运行中的容器内安装 TeX Live 宏包

server-ce/
  ├── Dockerfile-base             # 1️⃣ [非沙箱] Ubuntu + Node.js + TeX Live basic
  ├── Dockerfile                  # 2️⃣ [非沙箱] Overleaf CE 应用代码
  ├── Dockerfile-full             # 3️⃣ [非沙箱] 完整 TeX Live + 字体 + 辅助脚本
  ├── Dockerfile-full-web         #    [非沙箱] web 代码覆盖（日常 rebuild）
  ├── Dockerfile-windows-fonts    # 🔒 私有字体镜像（本地构建使用）
  ├── Dockerfile-sandbox-web      # 🪟 [沙箱] web-only 主镜像（无 TeX Live）
  └── Dockerfile-sandbox-texlive  # 🪟 [沙箱] 独立 TeX Live 编译镜像
```

---

## 🗺️ 路线图

### 0.2.x

- ✅ **沙箱编译支持（Sandboxed Compiles）** — 已完成，独立镜像链
- 管理面板功能增强

### 0.3.x

- 认证改进（SSO 研究）
- 企业级部署特性
- 沙箱编译性能优化（缓存、并行编译）

### 未来

- 更好的可观测性（日志、监控）
- 升级自动化工具
- SAML / OIDC 集成

> 不承诺具体交付日期。
