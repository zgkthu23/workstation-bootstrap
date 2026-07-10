#!/usr/bin/env bash
# ==============================================================================
# 引导完成后验证工作站状态
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY_RUN=false
INVENTORY=""

log() {
    local level="$1" message="$2"
    local color=''
    case "$level" in
        ERROR) color='\033[0;31m' ;;
        WARN)  color='\033[0;33m' ;;
        PASS)  color='\033[0;32m' ;;
        *)     color='\033[0m' ;;
    esac
    printf "${color}[%s] [%s] %s\033[0m\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message"
}

usage() {
    cat <<EOF
用法: $(basename "$0") --inventory PATH [--dry-run]

选项:
  --inventory PATH  指向 inventory YAML 文件的路径（必填）
  --dry-run         仅展示将要验证的内容
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

ERRORS=0
WARNINGS=0

echo ''
echo '=== 工作站验证 ==='
echo ''

# 1. 操作系统信息
log 'INFO' "操作系统: $(uname -s)"
log 'INFO' "主机名: $(hostname)"

# 2. Inventory 文件
if [[ -f "$INVENTORY" ]]; then
    log 'PASS' "找到 inventory 文件: $INVENTORY"
else
    log 'ERROR' "未找到 inventory 文件: $INVENTORY"
    ((ERRORS++))
fi

# 3. Git
if command -v git &>/dev/null; then
    log 'PASS' "Git: $(git --version)"
else
    log 'ERROR' 'Git 未安装'
    ((ERRORS++))
fi

# 4. 包管理器
case "$(uname -s)" in
    Linux)
        if command -v apt &>/dev/null; then
            log 'PASS' 'apt 可用'
        else
            log 'WARN' '未找到 apt'
            ((WARNINGS++))
        fi
        ;;
    Darwin)
        if command -v brew &>/dev/null; then
            log 'PASS' "Homebrew: $(brew --version | head -1)"
        else
            log 'WARN' '未找到 Homebrew'
            ((WARNINGS++))
        fi
        ;;
esac

# 5. repos.yaml
REPOS_YAML="$PROJECT_ROOT/projects/repos.yaml"
if [[ -f "$REPOS_YAML" ]]; then
    log 'PASS' '找到 repos.yaml'
else
    log 'ERROR' "未找到 repos.yaml: $REPOS_YAML"
    ((ERRORS++))
fi

# 6. 密钥扫描
SECRETS_SCAN="$PROJECT_ROOT/tests/test_no_secrets.py"
if [[ -f "$SECRETS_SCAN" ]]; then
    log 'INFO' '正在运行密钥扫描...'
    if command -v uv &>/dev/null; then
        if uv run python "$SECRETS_SCAN" 2>&1; then
            log 'PASS' '密钥扫描: 未发现问题'
        else
            log 'WARN' '密钥扫描发现问题（见上方输出）'
            ((WARNINGS++))
        fi
    else
        if python3 "$SECRETS_SCAN" 2>&1; then
            log 'PASS' '密钥扫描: 未发现问题'
        else
            log 'WARN' '密钥扫描发现问题（见上方输出）'
            ((WARNINGS++))
        fi
    fi
fi

# 7. 汇总
echo ''
echo '=== 验证汇总 ==='
printf '错误  : %d\n' "$ERRORS"
printf '警告  : %d\n' "$WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
    echo '验证未通过'
    exit 1
else
    echo '验证通过'
    exit 0
fi