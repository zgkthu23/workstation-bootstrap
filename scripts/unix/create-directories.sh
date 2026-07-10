#!/usr/bin/env bash
# ==============================================================================
# 为 Unix 创建工作区目录结构
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=false
INVENTORY=""

log() {
    local level="$1" message="$2"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message"
}

usage() {
    cat <<EOF
用法: $(basename "$0") --inventory PATH [--dry-run]

选项:
  --inventory PATH  指向 inventory YAML 文件的路径（必填）
  --dry-run         仅展示将要创建的目录
  --help            显示此帮助信息
EOF
    exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --inventory) INVENTORY="$2"; shift ;;
        --help|-h)   usage ;;
        *)           echo "未知选项: $1"; usage ;;
    esac
    shift
done

if [[ -z "$INVENTORY" ]]; then
    log 'ERROR' '--inventory 参数为必填项'
    exit 1
fi

# ponytail: 最小化 YAML 读取器 — 用 grep 匹配 key: value，先剥离行内注释再解析
read_yaml_value() {
    local key="$1" file="$2"
    grep -E "^\s*${key}:\s*" "$file" | head -1 | sed -E 's/\s*#.*$//' | sed -E 's/^[^:]*:\s*"?([^"]*?)"?\s*$/\1/'
}

WORKSPACE_ROOT=$(read_yaml_value 'workspace_root' "$INVENTORY")
DATA_ROOT=$(read_yaml_value 'data_root' "$INVENTORY")
SCRATCH_ROOT=$(read_yaml_value 'scratch_root' "$INVENTORY")
CLOUD_ROOT=$(read_yaml_value 'cloud_root' "$INVENTORY")

# 验证必填根目录
if [[ -z "$WORKSPACE_ROOT" || -z "$DATA_ROOT" || -z "$SCRATCH_ROOT" ]]; then
    log 'ERROR' "inventory 文件缺少必填字段: workspace_root, data_root, scratch_root"
    exit 1
fi

ROOTS=("$WORKSPACE_ROOT" "$DATA_ROOT" "$SCRATCH_ROOT")
[[ -n "$CLOUD_ROOT" ]] && ROOTS+=("$CLOUD_ROOT")

WORKSPACE_DIRS=(
    "$WORKSPACE_ROOT/repos/work"
    "$WORKSPACE_ROOT/repos/personal"
    "$WORKSPACE_ROOT/repos/research"
    "$WORKSPACE_ROOT/repos/tools"
    "$WORKSPACE_ROOT/repos/experiments"
    "$WORKSPACE_ROOT/artifacts/releases"
    "$WORKSPACE_ROOT/artifacts/reports"
    "$WORKSPACE_ROOT/artifacts/exports"
    "$WORKSPACE_ROOT/shared/templates"
    "$WORKSPACE_ROOT/shared/scripts"
)

ALL_DIRS=("${ROOTS[@]}" "${WORKSPACE_DIRS[@]}")

log 'INFO' "Inventory 文件: $INVENTORY"
log 'INFO' "根目录: ${ROOTS[*]}"

CREATED=0
EXISTED=0

for dir in "${ALL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        log 'INFO' "已存在: $dir"
        ((++EXISTED))
    else
        if $DRY_RUN; then
            echo "  [模拟运行] 将创建: $dir"
        else
            mkdir -p "$dir"
            log 'INFO' "已创建: $dir"
        fi
        ((++CREATED))
    fi
done

echo ''
log 'INFO' "汇总: $EXISTED 个已存在，$CREATED 个待创建$($DRY_RUN && echo '（模拟运行）')"