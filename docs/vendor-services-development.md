# TeXDock 的 Vendor Services 开发模型

本文说明 TeXDock 如何基于 `sharelatex/sharelatex:5.5.8` 镜像中的 `services` 代码进行开发、导入、修改和构建。

## 1. 背景

TeXDock 不是直接 fork 整个 `sharelatex/sharelatex` 项目，也不是简单把 Docker 镜像里的全部文件混进主分支。

当前项目采用一种更可控的方式：

```text
main/master 分支
  保存 TeXDock 主项目骨架、构建脚本、Dockerfile、文档，以及被我们正式接管的 services。

vendor/sharelatex-image-5.5.8 分支
  保存从 sharelatex/sharelatex:5.5.8 Docker 镜像中抽取出来的原始 services 快照。

.build/context
  临时构建目录，用于把 main + vendor services 装配成最终 Docker 构建上下文。
```

核心原则：

> vendor 只保存原始材料，main 只保存我们真正接管和修改的内容，最终镜像通过构建脚本临时装配生成。

---

## 2. 为什么不直接把 services 全部放进 main？

`sharelatex/sharelatex:5.5.8` 镜像中的 `services` 目录很大，其中可能包含：

* 当前 TeXDock 并不需要的服务；
* 暂时没有审查过的代码；
* 历史遗留文件；
* 不确定是否会被运行时真正使用的内容。

如果直接把完整 `services` 拷贝进 `main`，会带来几个问题：

1. 主分支变得臃肿；
2. 很难区分哪些文件是原始代码，哪些文件是我们修改过的；
3. 后续更新 vendor 快照时容易互相覆盖；
4. 构建失败时难以判断问题来自原始代码、导入过程还是我们的修改；
5. Git diff 会变得非常混乱。

因此，TeXDock 不采用“一次性全部拷贝”的方式，而采用：

```text
原始 services 保存在 vendor 分支；
main 中的 services 默认为空；
需要修改哪个 service，就先显式导入哪个 service；
导入后再进行修改。
```

---

## 3. 分支职责

### 3.1 main/master 分支

`main/master` 是 TeXDock 的主开发分支。

它应该包含：

```text
README.md
docs/
scripts/
Dockerfile
services/
build/
```

其中：

```text
services/
```

默认不保存完整 ShareLaTeX services。

它只保存已经被 TeXDock 正式接管的服务。

例如：

```text
services/
├── README.md
└── clsi/
```

这表示：

```text
clsi 已经从 vendor 导入，并由 TeXDock 接管。
```

没有出现在 `main/services/` 里的服务，仍然从 vendor 快照中读取。

---

### 3.2 vendor/sharelatex-image-5.5.8 分支

`vendor/sharelatex-image-5.5.8` 是孤儿分支，用于保存从 Docker 镜像中抽取出来的原始服务代码。

它的内容大致是：

```text
overleaf/
└── services/
    ├── chat/
    ├── clsi/
    ├── contacts/
    ├── docstore/
    ├── document-updater/
    ├── filestore/
    ├── history-v1/
    ├── notifications/
    ├── project-history/
    └── real-time/
```

这个分支的规则：

```text
不要在 vendor 分支上开发。
不要在 vendor 分支上修改业务逻辑。
不要把 vendor 分支 merge 到 main。
```

vendor 分支只做一件事：

> 保存 sharelatex/sharelatex:5.5.8 镜像中抽取出来的原始 services 快照。

---

## 4. Worktree 布局

推荐目录结构：

```text
/home/hoo/Projects/
├── TeXDock/                         # main/master
│   ├── README.md
│   ├── docs/
│   ├── scripts/
│   ├── Dockerfile
│   ├── build/
│   └── services/
│
└── texdock-vendor/                  # vendor/sharelatex-image-5.5.8
    └── overleaf/
        └── services/
```

不要把 vendor worktree 放到主仓库里面。

不推荐：

```text
/home/hoo/Projects/TeXDock/textdock-vendor
```

推荐：

```text
/home/hoo/Projects/texdock-vendor
```

创建 vendor worktree：

```bash
cd /home/hoo/Projects/TeXDock

git worktree add ../texdock-vendor vendor/sharelatex-image-5.5.8
```

检查：

```bash
ls ../texdock-vendor/overleaf/services
```

---

## 5. Runtime 约束

当前基于镜像：

```text
sharelatex/sharelatex:5.5.8
```

镜像内运行时检查结果：

```text
node: v22.15.1
npm:  10.9.2
yarn: not-found

node path:
/usr/bin/node

npm path:
/usr/bin/npm

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

因此，TeXDock 当前规则是：

```text
使用 Node.js 22.15.1；
使用 npm 10.9.2；
不要默认使用 yarn；
不要从上游 GitHub 仓库猜测 Node 版本；
以 Docker 镜像内实际运行时为准。
```

如果后续需要引入 yarn，必须单独说明原因，并修改 Dockerfile 与文档。

---

## 6. services 的开发流程

### 6.1 修改某个 service 前，先接管它

例如要修改 `clsi`，不要直接改 vendor：

不要这样做：

```bash
cd ../texdock-vendor
vim overleaf/services/clsi/xxx.js
```

正确做法是先把 `clsi` 从 vendor 导入到 main：

```bash
cd /home/hoo/Projects/TeXDock

cp -a ../texdock-vendor/overleaf/services/clsi services/clsi
```

然后立刻提交一个“纯导入 commit”：

```bash
git add services/clsi
git commit -m "services: adopt clsi from sharelatex 5.5.8"
```

这个 commit 不应该包含业务修改。

它只表示：

```text
TeXDock 正式接管 clsi 服务。
```

---

### 6.2 再进行实际修改

导入之后，再修改代码：

```bash
vim services/clsi/xxx.js
```

提交修改：

```bash
git add services/clsi
git commit -m "services: customize clsi for texdock"
```

这样 Git 历史会很清楚：

```text
commit A: 原样导入 clsi
commit B: 修改 clsi
```

以后 review 时，可以明确看出：

```text
哪些是原始代码；
哪些是 TeXDock 自己改的代码。
```

---

## 7. 构建模型

最终 Docker 镜像不是直接来自 main，也不是直接来自 vendor。

它来自一个临时装配目录：

```text
.build/context
```

装配逻辑：

```text
1. 复制 main 项目骨架；
2. 读取 build/services.txt；
3. 对每个 service：
   - 如果 main/services/<service> 存在，使用 main 中的版本；
   - 否则使用 vendor 中的原始版本；
4. 生成完整构建上下文；
5. 使用 .build/context 构建镜像。
```

也就是说：

```text
被 TeXDock 接管的服务：
  来自 main/services/

未接管的服务：
  来自 ../texdock-vendor/overleaf/services/
```

---

## 8. services 清单

建议使用：

```text
build/services.txt
```

声明最终镜像需要包含哪些服务。

示例：

```text
chat
clsi
contacts
docstore
document-updater
filestore
history-v1
notifications
project-history
real-time
```

这个文件的意义是：

> 最终镜像包含哪些 services，不靠目录扫描猜测，而靠清单显式声明。

---

## 9. 构建上下文装配脚本

建议使用：

```text
scripts/prepare-build-context.sh
```

它负责生成：

```text
.build/context
```

推荐行为：

```text
- 清理旧的 .build/context；
- 复制 main 项目骨架；
- 排除 .git、.build、node_modules、vendor worktree；
- 根据 build/services.txt 装配 services；
- main/services 中存在的服务优先；
- main 中不存在的服务从 vendor 读取；
- 如果某个 service 在 main 和 vendor 都不存在，直接失败。
```

构建流程：

```bash
cd /home/hoo/Projects/TeXDock

./scripts/prepare-build-context.sh

docker build -t texdock:dev .build/context
```

---

## 10. Dockerfile 修改原则

Dockerfile 修改要和 services 导入分开提交。

推荐提交顺序：

```text
commit 1:
  chore: import sharelatex project skeleton without services

commit 2:
  docs: document vendor services development model

commit 3:
  scripts: add build context assembler

commit 4:
  build: use China mirrors in Dockerfile

commit 5:
  services: adopt clsi from sharelatex 5.5.8

commit 6:
  services: customize clsi for texdock
```

不要把这些事情混在一个 commit 里：

```text
- 拷贝项目骨架；
- 修改 Dockerfile 源；
- 导入 services；
- 修改业务代码；
- 修构建错误。
```

否则出问题时很难回滚和定位。

---

## 11. 中国境内源修改

如果需要提高 Docker build 成功率，可以在 Dockerfile 中切换源。

但要注意：

```text
换源是构建优化；
不是业务修改；
不要和 services 导入混在一起提交。
```

npm 当前应使用 npm，而不是 yarn：

```dockerfile
RUN npm config set registry https://registry.npmmirror.com
```

如果基础系统是 Debian/Ubuntu，可以按实际系统版本选择合适的软件源。

注意：

```text
不要盲目替换 sources.list；
先确认镜像里的 /etc/os-release；
再决定使用 Debian 源还是 Ubuntu 源。
```

---

## 12. 禁止事项

### 12.1 不要 merge vendor 分支

不要执行：

```bash
git merge vendor/sharelatex-image-5.5.8 --allow-unrelated-histories
```

这样会把 vendor 原始快照整坨合并进 main，导致主分支污染。

---

### 12.2 不要直接修改 vendor

不要在这里开发：

```text
../texdock-vendor/overleaf/services/
```

vendor 是原始快照，不是开发目录。

---

### 12.3 不要无脑覆盖 services

不要执行：

```bash
cp -r ../texdock-vendor/overleaf/services/* services/
```

也不要执行会覆盖已有服务的同步命令：

```bash
rsync -a ../texdock-vendor/overleaf/services/ services/
```

因为这会把未审查的服务混入 main，也可能覆盖已经被 TeXDock 修改过的服务。

---

## 13. 推荐开发步骤

以修改 `docstore` 为例：

```bash
cd /home/hoo/Projects/TeXDock

# 1. 从 vendor 接管 docstore
cp -a ../texdock-vendor/overleaf/services/docstore services/docstore

# 2. 提交原始导入
git add services/docstore
git commit -m "services: adopt docstore from sharelatex 5.5.8"

# 3. 修改 docstore
vim services/docstore/xxx.js

# 4. 提交实际修改
git add services/docstore
git commit -m "services: customize docstore for texdock"

# 5. 装配构建上下文
./scripts/prepare-build-context.sh

# 6. 构建镜像
docker build -t texdock:dev .build/context
```

---

## 14. 一句话总结

TeXDock 的开发模型是：

```text
vendor 保存原始 services；
main 保存项目骨架和已接管 services；
build/services.txt 声明最终镜像需要哪些 services；
.prepare-build-context 脚本负责临时装配；
Docker 镜像从 .build/context 构建。
```

最重要的原则：

> 不在 vendor 上开发，不把 vendor 整体 merge 到 main，不无脑覆盖 services。需要修改哪个服务，就先接管哪个服务，再修改哪个服务。
