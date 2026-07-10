#!/usr/bin/env bash
# ==============================================================================
# 从 projects/repos.yaml 克隆 Git 仓库
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY_RUN=false
INVENTORY=""

log() {
    local level="$1" message="$2"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message"
}

read_yaml_value() {
    local key="$1" file="$2"
    grep -E "^\s*${key}:\s*" "$file" | head -1 | sed -E 's/^[^:]*:\s*"?([^"]*?)"?\s*$/\1/'
}

usage() {
    cat <<EOF
用法: $(basename "$0") --inventory PATH [--dry-run]

选项:
  --inventory PATH  指向 inventory YAML 文件的路径（必填）
  --dry-run         仅展示将要克隆的仓库
  --help            显示此帮助信息
EOF
    exit 0
}

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

REPOS_YAML="$PROJECT_ROOT/projects/repos.yaml"
WORKSPACE_ROOT=$(read_yaml_value 'workspace_root' "$INVENTORY")

if [[ ! -f "$REPOS_YAML" ]]; then
    log 'ERROR' "未找到 repos.yaml: $REPOS_YAML"
    exit 1
fi

log 'INFO' "仓库配置: $REPOS_YAML"
log 'INFO' "工作区根目录: $WORKSPACE_ROOT"
log 'INFO' '仓库克隆为第一阶段占位实现。'
log 'INFO' '完整实现将解析 repos.yaml 并为每个项目执行克隆。'
log 'INFO' '安全规则: 不覆盖已有仓库，不对有未提交更改的仓库强制拉取，支持模拟运行。'

if $DRY_RUN; then
    echo ''
    echo '[模拟运行] 将解析 repos.yaml 并为本机克隆仓库。'
    echo '[模拟运行] 目标路径: WORKSPACE_ROOT/repos/<分组>/<目录>'
fi