#!/usr/bin/env bash
# extract_services.sh - 从 Overleaf Docker 镜像提取 /overleaf/services 目录
#
# 特点：
# 1. 不使用 docker export，避免导出整个容器文件系统
# 2. 在容器内部 tar /overleaf/services
# 3. 在容器内部排除 node_modules，减少 Docker Desktop / WSL 大 IO 压力
# 4. 先提取到临时目录，成功后再替换目标目录，避免半成品污染

set -Eeuo pipefail

IMAGE="${1:-sharelatex/sharelatex:5.5.8}"
OUTPUT_DIR="${2:-./extracted_services}"
FORCE="${3:-}"

TARGET_ROOT="$OUTPUT_DIR/overleaf"
TARGET_DIR="$TARGET_ROOT/services"

SCRIPT_NAME="$(basename "$0")"

echo "📦 从镜像提取 services"
echo "   IMAGE      : $IMAGE"
echo "   OUTPUT_DIR : $OUTPUT_DIR"
echo "   TARGET     : $TARGET_DIR"
echo

usage() {
    cat <<EOF
用法:
  $SCRIPT_NAME [IMAGE] [OUTPUT_DIR] [--force]

示例:
  $SCRIPT_NAME
  $SCRIPT_NAME sharelatex/sharelatex:5.5.8 ./extracted_services
  $SCRIPT_NAME sharelatex/sharelatex:5.5.8 ./extracted_services --force
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ -n "$FORCE" ] && [ "$FORCE" != "--force" ]; then
    echo "❌ 未知参数: $FORCE"
    echo
    usage
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ 未找到 docker 命令"
    echo "   请先安装 Docker Desktop 或 Docker Engine。"
    exit 1
fi

echo "🔍 检查 Docker daemon..."

if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker CLI 存在，但无法连接 Docker daemon。"
    echo
    echo "常见原因："
    echo "  1. Docker Desktop 没启动"
    echo "  2. Docker Desktop 没开启 WSL Integration"
    echo "  3. 当前 WSL 分发没有挂载 Docker socket"
    echo "  4. Docker context 指向了错误的 daemon"
    echo
    echo "建议检查："
    echo "  Docker Desktop → Settings → Resources → WSL Integration"
    echo "  确认当前 Ubuntu 分发已启用"
    echo
    echo "可运行以下诊断命令："
    echo "  docker context ls"
    echo "  echo \$DOCKER_HOST"
    echo "  ls -l /var/run/docker.sock"
    echo "  ls -l /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.sock 2>/dev/null || true"
    echo
    echo "如果 Windows PowerShell 里 docker info 正常，但 WSL 里失败，通常就是 WSL Integration 没接上。"
    exit 1
fi

echo "✅ Docker daemon 可用"
echo

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "⚠️ 本地未找到镜像，尝试拉取: $IMAGE"
    docker pull "$IMAGE"
fi

if [ -e "$TARGET_DIR" ] && [ "$FORCE" != "--force" ]; then
    echo "❌ 目标目录已存在: $TARGET_DIR"
    echo "   如需覆盖，请使用:"
    echo "   $SCRIPT_NAME \"$IMAGE\" \"$OUTPUT_DIR\" --force"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

TMP_DIR="$(mktemp -d "$OUTPUT_DIR/.extract_services_tmp.XXXXXX")"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

TMP_ROOT="$TMP_DIR/overleaf"
TMP_TARGET="$TMP_ROOT/services"

mkdir -p "$TMP_ROOT"

echo "⏳ 在容器内部打包 /overleaf/services，并排除 node_modules..."
echo

docker run --rm \
    --entrypoint /bin/sh \
    "$IMAGE" \
    -c '
        set -eu

        if [ ! -d /overleaf/services ]; then
            echo "❌ 镜像中不存在 /overleaf/services" >&2
            exit 2
        fi

        cd /overleaf

        tar \
          --exclude="*/node_modules" \
          --exclude="*/node_modules/*" \
          --exclude="*/.git" \
          --exclude="*/.git/*" \
          -cf - services
    ' | tar -xf - -C "$TMP_ROOT"

if [ ! -d "$TMP_TARGET" ]; then
    echo "❌ 提取失败，临时目录中未生成 services: $TMP_TARGET"
    exit 1
fi

echo "🔍 检查 node_modules 是否残留..."

if find "$TMP_TARGET" -type d -name node_modules -print -quit | grep -q .; then
    echo "⚠️ 仍发现 node_modules，说明 tar exclude 规则没有完全生效。"
    find "$TMP_TARGET" -type d -name node_modules | head -10
    exit 3
fi

echo "✅ 未发现 node_modules"
echo

mkdir -p "$TARGET_ROOT"

if [ -e "$TARGET_DIR" ]; then
    echo "🧹 删除已有目录: $TARGET_DIR"
    rm -rf "$TARGET_DIR"
fi

mv "$TMP_TARGET" "$TARGET_DIR"

echo "✅ 提取成功！"
echo "📁 文件位于: $TARGET_DIR"
echo
echo "📁 第一层子目录:"
ls -1 "$TARGET_DIR" | head -20
