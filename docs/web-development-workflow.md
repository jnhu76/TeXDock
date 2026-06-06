# TeXDock Web 开发、重启与镜像固化流程

本文档用于记录 TeXDock 在开发 `services/web` 时的推荐流程。

目标是：

1. 在宿主机 / WSL 中使用 VS Code 修改源码；
2. 通过 Docker volume 将本地 `services/web` 挂载进 `sharelatex` 容器；
3. 修改后重启容器内部的 `web-overleaf` 服务验证；
4. 功能稳定后重新构建 image；
5. 最后用新 image 启动，不依赖本地 volume。

---

## 1. 基本结构说明

TeXDock / Overleaf CE 的运行结构不是"每个服务一个容器"。

Compose 层面主要是：

```
docker compose
├── sharelatex
├── mongo
└── redis
```

其中 `sharelatex` 容器内部由 runit 管理多个内部服务：

```
sharelatex 容器内部
├── nginx
├── web-overleaf
├── web-api-overleaf
├── clsi-overleaf
├── docstore-overleaf
├── document-updater-overleaf
├── real-time-overleaf
├── filestore-overleaf
├── contacts-overleaf
├── notifications-overleaf
├── project-history-overleaf
└── history-v1-overleaf
```

开发 `services/web` 时，主要关注：

```
web-overleaf
nginx
/var/log/overleaf/web.log
/var/log/nginx/error.log
```

---

## 2. 推荐分支

开始 web 定制前，新建开发分支：

```bash
git checkout master
git pull
git checkout -b dev/web-customization
```

也可以使用更明确的分支名：

```bash
git checkout -b feat/web-branding-admin-email
```

---

## 3. Web 开发 overlay compose

在项目根目录创建 `docker-compose.dev.web.yml`：

```yaml
services:
  sharelatex:
    volumes:
      - ~/sharelatex_data:/var/lib/overleaf
      - ./services/web:/overleaf/services/web
      - ./libraries:/overleaf/libraries
```

如果当前使用自己的 image（例如 `texdock:dev`），可以写成：

```yaml
services:
  sharelatex:
    image: texdock:dev
    volumes:
      - ~/sharelatex_data:/var/lib/overleaf
      - ./services/web:/overleaf/services/web
      - ./libraries:/overleaf/libraries
```

这个文件的含义是：

> 继续使用原 compose 的 mongo / redis / sharelatex，但把宿主机源码覆盖到容器里的 `/overleaf/services/web`

---

## 4. 启动开发态环境

使用基础 compose 加 dev overlay 启动：

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.dev.web.yml \
  up -d
```

检查容器：

```bash
docker ps
```

应该至少看到 `sharelatex`、`mongo`、`redis`。

检查内部服务：

```bash
docker exec sharelatex bash -lc 'sv status /etc/service/web-overleaf /etc/service/nginx'
```

正常情况下应该类似：

```
run: /etc/service/web-overleaf: (pid xxxx) xxxs
run: /etc/service/nginx: (pid xxxx) xxxs
```

如果 `web-overleaf` 一直是 `1s`、`2s`，说明它在反复崩溃重启。

---

## 5. 验证 volume 是否生效

在宿主机创建测试文件：

```bash
echo "web overlay test" > services/web/.overlay-test
```

在容器内查看：

```bash
docker exec sharelatex bash -lc 'cat /overleaf/services/web/.overlay-test'
```

如果能看到 `web overlay test`，说明本地 `services/web` 已经成功挂载到容器内部。

---

## 6. 修改 web 后如何重启

### 6.1 后端代码修改

如果修改了：

```
services/web/app/...
services/web/modules/...
services/web/app.mjs
services/web/app/src/router.mjs
```

通常只需要重启 `web-overleaf`：

```bash
docker exec sharelatex bash -lc 'sv restart /etc/service/web-overleaf'
```

查看状态：

```bash
docker exec sharelatex bash -lc 'sv status /etc/service/web-overleaf'
```

如果服务稳定运行，状态中的秒数会持续增长。

### 6.2 前端页面 / 样式 / React 修改

如果修改了：

```
services/web/frontend/...
services/web/public/...
services/web/modules/*/frontend/...
*.jsx
*.tsx
*.scss
```

需要重新打包前端：

```bash
docker exec sharelatex bash -lc 'cd /overleaf/services/web && npm run webpack:production'
```

然后重启 web：

```bash
docker exec sharelatex bash -lc 'sv restart /etc/service/web-overleaf'
```

浏览器强刷：`Ctrl + F5`

### 6.3 不要随便重启 nginx

一般 web 代码修改不需要重启 nginx。不要优先执行：

```bash
sv restart /etc/service/nginx
```

如果 nginx 已经在运行，手动重复启动可能出现：

```
bind() to 0.0.0.0:80 failed (98: Address already in use)
```

这通常不是根因。

---

## 7. 常用检查命令

### 查看 web 日志

```bash
docker exec sharelatex bash -lc 'tail -n 120 /var/log/overleaf/web.log'
```

### 查看 nginx 错误日志

```bash
docker exec sharelatex bash -lc 'tail -n 120 /var/log/nginx/error.log'
```

### 查看 web 服务状态

```bash
docker exec sharelatex bash -lc 'sv status /etc/service/web-overleaf'
```

### 一条命令查看常用诊断信息

```bash
docker exec sharelatex bash -lc "
echo '===== web status ====='
sv status /etc/service/web-overleaf
echo
echo '===== web log ====='
tail -n 120 /var/log/overleaf/web.log
echo
echo '===== nginx error log ====='
tail -n 80 /var/log/nginx/error.log
"
```

---

## 8. 502 排查流程

如果浏览器出现 502，优先判断：nginx 还活着，但 `web-overleaf` 没有正常监听 `127.0.0.1:4000`。

检查状态：

```bash
docker exec sharelatex bash -lc 'sv status /etc/service/web-overleaf /etc/service/nginx'
```

如果看到 `run: /etc/service/web-overleaf: (pid xxxx) 1s`，说明 `web-overleaf` 可能在反复崩溃。

继续看日志：

```bash
docker exec sharelatex bash -lc 'tail -n 160 /var/log/overleaf/web.log'
```

常见错误包括：

- `SyntaxError`
- `TypeError`
- `ReferenceError`
- `Cannot find module`
- `ERR_MODULE_NOT_FOUND`
- `Route.post() requires a callback function`
- `Failed to lookup view`

如果 nginx 日志中出现：

```
connect() failed (111: Connection refused) while connecting to upstream
upstream: "http://127.0.0.1:4000/..."
```

说明 nginx 访问 web 后端失败，根因仍然通常在 `web.log`。

---

## 9. 容器内检查命令

进入容器：

```bash
docker exec -it sharelatex bash
```

进入 web 目录：

```bash
cd /overleaf/services/web
```

运行 lint：

```bash
npm run lint
```

运行类型检查：

```bash
npm run type-check
```

运行前端构建：

```bash
npm run webpack:production
```

运行 web 单元测试：

```bash
npm run test:unit:app
```

更完整的单元测试：

```bash
npm run test:unit:all
```

---

## 10. 开发态循环

推荐日常循环：

1. VS Code 修改 `services/web`
2. 如果是前端修改，执行 `npm run webpack:production`
3. 重启 `web-overleaf`
4. 浏览器验证
5. 查看 `web.log`
6. 跑 lint / type-check / test
7. commit

命令版：

```bash
# 前端改动时需要
docker exec sharelatex bash -lc 'cd /overleaf/services/web && npm run webpack:production'

# 重启 web
docker exec sharelatex bash -lc 'sv restart /etc/service/web-overleaf'

# 看状态
docker exec sharelatex bash -lc 'sv status /etc/service/web-overleaf'

# 看日志
docker exec sharelatex bash -lc 'tail -n 120 /var/log/overleaf/web.log'
```

---

## 11. 提交代码

查看改动：

```bash
git status
git diff
```

建议按功能拆 commit，例如：

```bash
git add services/web
git commit -m "feat(register): customize registration flow"
```

---

## 12. 镜像固化：不要用 export / commit

> **结论：不要用 `docker export` 或 `docker commit` 做正式版本。**
>
> 正式路线：
> ```
> 源码修改 → docker build 生成新 image → compose 使用新 image
> ```

### 为什么不建议导出？

**`docker export`** 问题最大：

- 只导出容器文件系统，不保留 image 的 `CMD` / `ENTRYPOINT` / `ENV` / `EXPOSE` / `HEALTHCHECK` / history
- 导出来再 `docker import`，容易变成"能看到文件，但启动逻辑丢了"的镜像

**`docker commit`** 比 export 好一点，但也不推荐正式用：

- 能保留部分容器状态，但修改来源不可复现
- 以后你不知道这个 image 里到底手工改过什么

现在已经有源码仓库了，应该让 image 从源码构建出来。

---

## 13. 多层镜像架构

TeXDock 采用三层镜像结构，避免每次改 web 都重新安装完整 TeX Live：

```
1. fred1653/sharelatex-base:latest
   ← Ubuntu + Node.js + TeX Live basic
   ← 对应 Dockerfile: server-ce/Dockerfile-base

2. fred1653/sharelatex:latest
   ← Overleaf CE 应用代码
   ← 对应 Dockerfile: server-ce/Dockerfile

3. fred1653/sharelatex-full:latest
   ← 完整 TeX Live + CJK 字体 + 辅助脚本
   ← 对应 Dockerfile: server-ce/Dockerfile-full
   ← 日常 web 修改后可通过 Dockerfile-full-web 只覆盖 web 代码
```

### 构建 sharelatex-full（TeX Live 变更时才需要）

```bash
docker build \
  -f server-ce/Dockerfile-full \
  -t fred1653/sharelatex-full:latest \
  .
```

可选指定 TeX Live 镜像源加速：

```bash
docker build \
  --build-arg TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet \
  -f server-ce/Dockerfile-full \
  -t fred1653/sharelatex-full:latest \
  .
```

### 日常 web 修改后，只覆盖 web 代码

```bash
docker build \
  -f server-ce/Dockerfile-full-web \
  -t fred1653/sharelatex-full:latest \
  .
```

这样以后改 web，只需要跑这一条命令，不用每次重新安装 TeX Live。

---

## 14. 镜像固化流程

开发态验证通过后，将修改固化进 image。

先停止开发态容器：

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.dev.web.yml \
  down
```

### 方案 A：仅更新 web 层（推荐日常使用）

```bash
docker build \
  -f server-ce/Dockerfile-full-web \
  -t fred1653/sharelatex-full:latest \
  .
```

### 方案 B：重新构建基础 web 镜像

如果修改了 web 之外的内容（如 libraries）：

```bash
docker build -f server-ce/Dockerfile -t fred1653/sharelatex:latest .
```

然后需要重新构建 full 和 full-web。

### 方案 C：完整重建（含 TeX Live）

```bash
docker build -f server-ce/Dockerfile-full -t fred1653/sharelatex-full:latest .
```

如果想带版本号：

```bash
docker build \
  -f server-ce/Dockerfile-full-web \
  -t fred1653/sharelatex-full:$(date +%Y%m%d-%H%M) \
  .
```

---

## 15. 使用新 image 启动

确认 `docker-compose.yml` 中 `sharelatex` 使用新 image：

```yaml
services:
  sharelatex:
    image: fred1653/sharelatex-full:latest
```

然后**不带** dev overlay 启动：

```bash
docker compose up -d --force-recreate
```

> 注意，这一步不要带 `-f docker-compose.dev.web.yml`，因为这次要验证：不依赖本地 volume，新 image 自己就包含修改后的 web 代码。

检查状态：

```bash
docker exec sharelatex bash -lc 'sv status /etc/service/web-overleaf /etc/service/nginx'
```

查看日志：

```bash
docker exec sharelatex bash -lc 'tail -n 120 /var/log/overleaf/web.log'
```

验证中文 LaTeX 支持：

```bash
docker exec sharelatex bash -lc 'kpsewhich ctex.sty'
docker exec sharelatex bash -lc 'fc-list | grep -i "Noto Sans CJK" | head'
docker exec sharelatex bash -lc 'xelatex --version'
```

浏览器访问：

- `http://localhost/`
- `http://localhost/login`
- `http://localhost/register`

---

## 16. 最终验证清单

构建 image 后，至少验证：

- [ ] 首页能打开
- [ ] `/login` 能打开
- [ ] `/register` 能打开
- [ ] 注册流程不会 502
- [ ] 登录页面样式正常
- [ ] admin 页面能打开
- [ ] 邮件相关逻辑不会导致服务崩溃
- [ ] `web-overleaf` 状态稳定，不再反复 1s 重启
- [ ] `/var/log/overleaf/web.log` 没有启动级别异常
- [ ] 不挂载 `docker-compose.dev.web.yml` 时功能仍然存在
- [ ] `kpsewhich ctex.sty` 能找到 ctex（full 镜像）
- [ ] `xelatex` 可用（full 镜像）

---

## 17. 回滚方式

如果新 image 有问题，可以先恢复原 image。

查看本地 image：

```bash
docker images | grep -E 'sharelatex|texdock'
```

切回旧 image，例如：

```yaml
services:
  sharelatex:
    image: fred1653/sharelatex-full:previous
```

然后：

```bash
docker compose up -d --force-recreate
```

如果只是开发态代码改坏了，可以在 git 中回滚：

```bash
git diff
git checkout -- services/web/path/to/file
```

然后重启：

```bash
docker exec sharelatex bash -lc 'sv restart /etc/service/web-overleaf'
```

---

## 18. 命令速查

| 操作 | 命令 |
|------|------|
| 开发态启动 | `docker compose -f docker-compose.yml -f docker-compose.dev.web.yml up -d` |
| 重启 web | `docker exec sharelatex bash -lc 'sv restart /etc/service/web-overleaf'` |
| 查看 web 状态 | `docker exec sharelatex bash -lc 'sv status /etc/service/web-overleaf'` |
| 查看 web 日志 | `docker exec sharelatex bash -lc 'tail -n 120 /var/log/overleaf/web.log'` |
| 前端构建 | `docker exec sharelatex bash -lc 'cd /overleaf/services/web && npm run webpack:production'` |
| lint | `docker exec sharelatex bash -lc 'cd /overleaf/services/web && npm run lint'` |
| type-check | `docker exec sharelatex bash -lc 'cd /overleaf/services/web && npm run type-check'` |
| 构建 full（少做） | `docker build -f server-ce/Dockerfile-full -t fred1653/sharelatex-full:latest .` |
| 构建 full-web（常用） | `docker build -f server-ce/Dockerfile-full-web -t fred1653/sharelatex-full:latest .` |
| 使用新 image 启动 | `docker compose up -d --force-recreate` |

---

## 19. 推荐原则

**开发时：**

> 本地源码 + volume overlay + 容器运行环境

**发布 / 固化时：**

> 本地源码 + docker build + 新 image（不要 export / commit）

**日常 web 修改固化：**

> 只 rebuild `Dockerfile-full-web`，不重建 TeX Live 层

不要长期在容器内部直接改代码。容器内手改无法稳定复现，也不方便 git diff、测试和重新构建。
