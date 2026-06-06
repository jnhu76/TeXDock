#!/usr/bin/env bash
set -Eeuo pipefail

# tlmgr-in-container.sh
#
# 在运行中的 sharelatex 容器内搜索或安装 TeX Live / CTAN 宏包。
#
# 用法:
#   scripts/tlmgr-in-container.sh search enumitem.sty
#   scripts/tlmgr-in-container.sh install enumitem minted latexmk
#
# 环境变量:
#   CONTAINER          容器名 (默认: sharelatex)
#   TEXLIVE_REPOSITORY CTAN 镜像地址 (默认: 空，使用容器内已配置的源)
#
# 注意:
#   - 这些修改直接作用于运行中的容器文件系统。
#   - 容器重建后安装的包会丢失，需要重新安装。
#   - 如需永久生效，请将包添加到 server-ce/Dockerfile-full 后重新构建镜像。

CONTAINER="${CONTAINER:-sharelatex}"
ACTION="${1:-}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/tlmgr-in-container.sh search <missing-file>
  scripts/tlmgr-in-container.sh install <pkg> [pkg...]

Examples:
  scripts/tlmgr-in-container.sh search enumitem.sty
  scripts/tlmgr-in-container.sh search ctexart.cls
  scripts/tlmgr-in-container.sh install enumitem
  scripts/tlmgr-in-container.sh install minted fvextra upquote

Environment:
  CONTAINER=sharelatex
  TEXLIVE_REPOSITORY=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlnet
USAGE
}

if [ -z "${ACTION}" ]; then
  usage
  exit 1
fi

shift || true

check_container() {
  if ! docker inspect "${CONTAINER}" >/dev/null 2>&1; then
    echo "ERROR: container not found: ${CONTAINER}"
    echo
    echo "Current containers:"
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
    exit 1
  fi
}

validate_token() {
  local token="$1"
  if [[ ! "${token}" =~ ^[A-Za-z0-9_.+:-]+$ ]]; then
    echo "ERROR: unsafe token: ${token}"
    exit 1
  fi
}

check_container

case "${ACTION}" in
  search)
    MISSING_FILE="${1:-}"

    if [ -z "${MISSING_FILE}" ]; then
      echo "ERROR: missing file name."
      echo
      usage
      exit 1
    fi

    validate_token "${MISSING_FILE}"

    docker exec \
      -u root \
      -e MISSING_FILE="${MISSING_FILE}" \
      -e TEXLIVE_REPOSITORY="${TEXLIVE_REPOSITORY:-}" \
      -it "${CONTAINER}" \
      bash -lc '
        set -eux

        if [ -n "${TEXLIVE_REPOSITORY:-}" ]; then
          tlmgr option repository "${TEXLIVE_REPOSITORY}"
        fi

        tlmgr option repository

        echo "Searching package for missing file: ${MISSING_FILE}"
        tlmgr search --global --file "/${MISSING_FILE}" || true
      '
    ;;

  install)
    if [ "$#" -eq 0 ]; then
      echo "ERROR: no package names provided."
      echo
      usage
      exit 1
    fi

    for pkg in "$@"; do
      validate_token "${pkg}"
    done

    PACKAGES="$*"

    docker exec \
      -u root \
      -e PACKAGES="${PACKAGES}" \
      -e TEXLIVE_REPOSITORY="${TEXLIVE_REPOSITORY:-}" \
      -it "${CONTAINER}" \
      bash -lc '
        set -eux

        if [ -n "${TEXLIVE_REPOSITORY:-}" ]; then
          tlmgr option repository "${TEXLIVE_REPOSITORY}"
        fi

        tlmgr option repository

        echo "Installing TeX Live packages: ${PACKAGES}"
        # shellcheck disable=SC2086
        tlmgr install ${PACKAGES}

        tlmgr path add || true

        if command -v mktexlsr >/dev/null 2>&1; then
          mktexlsr || true
        fi

        if command -v updmap-sys >/dev/null 2>&1; then
          updmap-sys || true
        fi

        if command -v refresh-texlive-font-cache >/dev/null 2>&1; then
          refresh-texlive-font-cache || true
        else
          fc-cache -r -v || true
          if command -v luaotfload-tool >/dev/null 2>&1; then
            luaotfload-tool --update --force || true
          fi
        fi

        echo "Installed TeX Live packages: ${PACKAGES}"
      '
    ;;

  *)
    echo "ERROR: unknown action: ${ACTION}"
    echo
    usage
    exit 1
    ;;
esac
