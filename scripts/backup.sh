#!/bin/bash
# TeXDock 数据备份
#
# 用法:
#   bash scripts/backup.sh                          # 备份到 ~/texdock-backups/
#   bash scripts/backup.sh /mnt/usb/texdock         # 备份到指定目录
#   bash scripts/backup.sh /mnt/usb/texdock --tar   # 备份 + 打 tar.gz 包
#
# 参数:
#   $1  备份目标目录（默认 ~/texdock-backups/）
#   $2  --tar   额外打 tar.gz 压缩包，适合拷贝到异地/U盘/NAS

set -eo pipefail

DEST="${1:-$HOME/texdock-backups}"
TAR_MODE=false
if [ "$2" = "--tar" ] || [ "$1" = "--tar" ]; then
  TAR_MODE=true
fi

# 如果 --tar 是第一个参数，备份目录用默认值
[ "$1" = "--tar" ] && DEST="$HOME/texdock-backups"

LATEST="$DEST/latest"
SNAPSHOT="$DEST/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$DEST/backup.log"

mkdir -p "$DEST"

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] 开始备份 → $DEST" >> "$LOG_FILE"

# rsync 增量同步，--link-dest 对未变更文件创建硬链接（不额外占空间）
LINK_OPT=""
[ -d "$LATEST" ] && LINK_OPT="--link-dest=$LATEST"

rsync -av --delete $LINK_OPT \
  ~/mongo_data/       "$SNAPSHOT/mongo_data/" \
  ~/redis_data/       "$SNAPSHOT/redis_data/" \
  ~/sharelatex_data/  "$SNAPSHOT/sharelatex_data/" \
  2>&1 | tee -a "$LOG_FILE"

# 更新 latest 软链接
rm -f "$LATEST"
ln -s "${SNAPSHOT##*/}" "$LATEST"

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] 快照完成" >> "$LOG_FILE"
echo "✅ 快照 → $SNAPSHOT"

# --tar: 打 tar.gz 压缩包（适合异地/冷备/U盘拷贝）
if $TAR_MODE; then
  TAR_FILE="$DEST/texdock-${SNAPSHOT##*/}.tar.gz"
  tar -czf "$TAR_FILE" -C "$SNAPSHOT" mongo_data redis_data sharelatex_data
  echo "📦 压缩包 → $TAR_FILE"
fi
