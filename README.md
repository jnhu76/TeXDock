<div align="center">

# 📝 TeXDock

**基于 Overleaf CE 的中文本地化在线 LaTeX 编辑器**

内置完整 TeX Live + CJK 字体 · fontconfig 别名兼容 Windows 字体名 · 开箱即用

![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/license-AGPL--3.0-green)
![TeX Live](https://img.shields.io/badge/TeX%20Live-2026-blue)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20x86__64-lightgrey)

本项目基于 [Overleaf Community Edition](https://github.com/overleaf/overleaf) 修改，遵循 [AGPL-3.0](LICENSE) 许可证发布。

</div>

---

## 🚀 使用

直接使用预构建镜像，无需自己编译。镜像地址：[Docker Hub → fred1653/sharelatex-full](https://hub.docker.com/repository/docker/fred1653/sharelatex-full/general)

```bash
# 使用项目根目录的 docker-compose.yml 启动
docker compose -f docker-compose.yml up -d

# 创建管理员
# 🌐 浏览器访问 http://localhost/launchpad

# 停止
docker compose -f docker-compose.yml down
```

> `docker-compose.yml` 已配置好 `OVERLEAF_SITE_LANGUAGE: "zh-CN"`（中文界面），开箱即用。

### ⚙️ 配置

编辑 `docker-compose.yml` 的 environment 部分，按需取消注释：

```yaml
OVERLEAF_SITE_URL: http://your-server-ip           # 🌍 外网访问时必须设置
OVERLEAF_EMAIL_SMTP_HOST: smtp.example.com          # 📧 SMTP 邮件
OVERLEAF_EMAIL_SMTP_PORT: 587
OVERLEAF_EMAIL_SMTP_USER: user@example.com
OVERLEAF_EMAIL_SMTP_PASS: your-password
```

📖 完整配置说明见 [**部署指南**](docs/deployment-guide.md)。

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

## 🔨 构建

镜像分三级逐层构建，给后续维护者参考：

```text
Dockerfile-base  →  sharelatex-base    →  sharelatex       →  sharelatex-full
  Ubuntu+Node.js     + Overleaf CE代码     + 完整TeX Live+字体
```

```bash
docker build -f server-ce/Dockerfile-base -t fred1653/sharelatex-base:latest .
docker build -f server-ce/Dockerfile -t fred1653/sharelatex:latest .
docker build -f server-ce/Dockerfile-full -t fred1653/sharelatex-full:latest .
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

## 📂 目录结构

```text
docker-compose.yml                # 🚀 生产配置
docker-compose.dev.web.yml        # 💻 开发 overlay（挂载 web 源码）

scripts/tlmgr-in-container.sh     # 📦 在运行中的容器内安装 TeX Live 宏包

server-ce/
  Dockerfile-base                 # 1️⃣ Ubuntu + Node.js + TeX Live basic
  Dockerfile                      # 2️⃣ Overleaf CE 应用代码
  Dockerfile-full                 # 3️⃣ 完整 TeX Live + 字体 + 辅助脚本
  Dockerfile-full-web             # 3️⃣ web 代码覆盖（日常 rebuild）
  Dockerfile-windows-fonts        # 🔒 私有字体镜像（本地构建使用）
```
