<h1 align="center">
  <br>
  TeXDock
</h1>

<h4 align="center">基于 Overleaf Community Edition 的中文本地化构建</h4>

<p align="center">
  <a href="https://github.com/jnhu76/TeXDock">GitHub</a> •
  <a href="https://github.com/overleaf/overleaf">Upstream</a> •
  <a href="#license">License</a>
</p>

<img src="doc/screenshot.png" alt="A screenshot of a project being edited in Overleaf Community Edition">
<p align="center">
  Figure 1: A screenshot of a project being edited in Overleaf Community Edition.
</p>

## TeXDock

TeXDock 是 [Overleaf Community Edition](https://github.com/overleaf/overleaf) 的中文本地化构建，主要改动：

- apt 源切换为清华镜像（`mirrors.tuna.tsinghua.edu.cn`）
- npm/yarn registry 切换为 `registry.npmmirror.com`
- CTAN/TexLive 镜像切换为清华镜像
- Docker 构建优化，适配国内网络环境

## 快速开始

```bash
docker compose up -d
```

首次启动后需要初始化 MongoDB 副本集：

```bash
docker compose exec mongo mongosh --eval "rs.initiate({ _id: 'overleaf', members: [{ _id: 0, host: 'localhost:27017' }] })"
```

然后重启服务：

```bash
docker compose restart
```

访问 `http://localhost` 即可使用。

## 构建

```bash
# 构建基础镜像
cd server-ce && make build-base

# 构建社区版镜像
cd server-ce && make build-community
```

## Upstream

[Overleaf](https://www.overleaf.com) is an open-source online real-time collaborative LaTeX editor. We run a hosted version at [www.overleaf.com](https://www.overleaf.com), but you can also run your own local version, and contribute to the development of Overleaf.

> [!CAUTION]
> Overleaf Community Edition is intended for use in environments where **all** users are trusted. Community Edition is **not** appropriate for scenarios where isolation of users is required due to Sandbox Compiles not being available. When not using Sandboxed Compiles, users have full read and write access to the `sharelatex` container resources (filesystem, network, environment variables) when running LaTeX compiles.

For more information on Sandbox Compiles check out our [documentation](https://docs.overleaf.com/on-premises/configuration/overleaf-toolkit/server-pro-only-configuration/sandboxed-compiles).

## Enterprise

If you want help installing and maintaining Overleaf in your lab or workplace, we offer an officially supported version called [Overleaf Server Pro](https://www.overleaf.com/for/enterprises). It also includes more features for security (SSO with LDAP or SAML), administration and collaboration (e.g. tracked changes). [Find out more!](https://www.overleaf.com/for/enterprises)

## Keeping up to date

Sign up to the [mailing list](https://mailchi.mp/overleaf.com/community-edition-and-server-pro) to get updates on Overleaf releases and development.

## Installation

We have detailed installation instructions in the [Overleaf Toolkit](https://github.com/overleaf/toolkit/).

## Upgrading

If you are upgrading from a previous version of Overleaf, please see the [Release Notes section on the Wiki](https://github.com/overleaf/overleaf/wiki#release-notes) for all of the versions between your current version and the version you are upgrading to.

## Overleaf Docker Image

This repo contains two dockerfiles, [`Dockerfile-base`](server-ce/Dockerfile-base), which builds the
`sharelatex/sharelatex-base` image, and [`Dockerfile`](server-ce/Dockerfile) which builds the
`sharelatex/sharelatex` (or "community") image.

The Base image generally contains the basic dependencies like `wget`, plus `texlive`.
We split this out because it's a pretty heavy set of
dependencies, and it's nice to not have to rebuild all of that every time.

The `sharelatex/sharelatex` image extends the base image and adds the actual Overleaf code
and services.

Use `make build-base` and `make build-community` from `server-ce/` to build these images.

We use the [Phusion base-image](https://github.com/phusion/baseimage-docker)
(which is extended by our `base` image) to provide us with a VM-like container
in which to run the Overleaf services. Baseimage uses the `runit` service
manager to manage services, and we add our init-scripts from the `server-ce/runit`
folder.

[Overleaf](https://www.overleaf.com) 是一个开源的在线实时协作 LaTeX 编辑器。

> [!CAUTION]
> Overleaf Community Edition 适用于所有用户可信的环境，不支持沙箱编译。

## License

The code in this repository is released under the GNU AFFERO GENERAL PUBLIC LICENSE, version 3. A copy can be found in the [`LICENSE`](LICENSE) file.

Copyright (c) Overleaf, 2014-2025.
