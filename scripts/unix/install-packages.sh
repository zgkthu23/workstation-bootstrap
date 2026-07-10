#!/usr/bin/env bash
# ==============================================================================
# 为 Unix 安装软件包（apt / Homebrew）
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
LIST=false
INVENTORY=""

log() {
    local level="$1" message="$2"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message"
}

usage() {
    cat <<EOF
用法: $(basename "$0") --inventory PATH [--dry-run] [--list]

选项:
  --inventory PATH  指向 inventory YAML 文件的路径（必填）
  --dry-run         仅展示将要安装的软件包
  --list            列出已启用的功能所需的软件包
  --help            显示此帮助信息
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --list)      LIST=true ;;
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

OS="$(uname -s)"
log 'INFO' "操作系统: $OS"

case "$OS" in
    Linux)
        if command -v apt &>/dev/null; then
            log 'INFO' "包管理器: apt"
        else
            log 'ERROR' '未找到 apt（第一阶段仅支持基于 apt 的 Linux 发行版）'
            exit 1
        fi
        ;;
    Darwin)
        if command -v brew &>/dev/null; then
            log 'INFO' "包管理器: $(brew --version | head -1)"
        else
            log 'WARN' '未找到 Homebrew — 请先安装: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        fi
        ;;
    *)
        log 'ERROR' "不支持的操作系统: $OS"
        exit 1
        ;;
esac

log 'INFO' '软件包安装为第一阶段占位实现。'
log 'INFO' '完整实现将解析 manifest 文件并通过 apt/brew 安装。'
log 'INFO' "模拟运行: $DRY_RUN, 列表模式: $LIST"

if $DRY_RUN || $LIST; then
    echo ''
    echo '[模拟运行] 将解析 manifest 并为已启用的功能安装软件包。'
    echo '[模拟运行] 软件包来源: manifests/common.yaml, manifests/<os>.yaml'
fi