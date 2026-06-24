#!/bin/bash
# init-sandbox-dirs.sh
#
# 创建沙箱编译（Sandboxed Compiles）所需的宿主机目录并设置权限。
#
# 用法：
#   ./scripts/init-sandbox-dirs.sh [DATA_PATH]
#
# 若不传 DATA_PATH，则从同目录的 .env 读取 OVERLEAF_DATA_PATH，
# 再不行则回退到 ${HOME}/sharelatex_data。
#
# 权限策略：
#   主容器内 node 用户 uid=1000，sibling TeXLive 镜像 tex 用户也 uid=1000。
#   因此把编译目录属主设为 uid/gid 1000，两者都能读写，无需 world-writable。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# 1. 确定 DATA_PATH
if [ "${1:-}" != "" ]; then
  DATA_PATH="${1}"
elif [ -f "${PROJECT_DIR}/.env" ]; then
  # shellcheck disable=SC1090
  DATA_PATH="$(set -a; . "${PROJECT_DIR}/.env"; echo "${OVERLEAF_DATA_PATH}")"
  if [ -z "${DATA_PATH}" ]; then
    echo "ERROR: .env 中 OVERLEAF_DATA_PATH 为空" >&2
    exit 1
  fi
else
  DATA_PATH="${HOME}/sharelatex_data"
  echo "WARN: 未找到 .env，回退到 ${DATA_PATH}" >&2
fi

# 展开波浪号/环境变量
DATA_PATH="$(eval echo "${DATA_PATH}")"

if [ ! -d "${DATA_PATH}" ]; then
  echo "ERROR: 数据目录不存在: ${DATA_PATH}" >&2
  echo "       请先创建主数据目录（docker-compose 的 volume 挂载点）。" >&2
  exit 1
fi

COMPILES_DIR="${DATA_PATH}/data/compiles"
OUTPUT_DIR="${DATA_PATH}/data/output"

echo "创建沙箱编译目录..."
echo "  数据根目录: ${DATA_PATH}"
echo "  编译目录:   ${COMPILES_DIR}"
echo "  输出目录:   ${OUTPUT_DIR}"
echo ""

mkdir -p "${COMPILES_DIR}"
mkdir -p "${OUTPUT_DIR}"

# 2. 设置属主为 uid:gid 1000（node / tex 用户）
#    需要 sudo。若当前用户已是 uid 1000 则部分操作无需 sudo。
echo "设置属主为 1000:1000（对齐主容器 node 与 sibling tex 用户）..."
if [ "$(id -u)" -eq 0 ]; then
  chown -R 1000:1000 "${COMPILES_DIR}" "${OUTPUT_DIR}"
elif sudo -n true 2>/dev/null; then
  sudo chown -R 1000:1000 "${COMPILES_DIR}" "${OUTPUT_DIR}"
else
  echo "需要 sudo 权限来设置属主，请输入密码（或自行执行）："
  sudo chown -R 1000:1000 "${COMPILES_DIR}" "${OUTPUT_DIR}"
fi

echo ""
echo "完成。验证："
ls -ldn "${COMPILES_DIR}" "${OUTPUT_DIR}"
echo ""
echo "属主应为 uid=1000 gid=1000。"
