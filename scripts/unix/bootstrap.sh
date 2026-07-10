#!/usr/bin/env bash
# ==============================================================================
# workstation-bootstrap — Unix 编排器
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY_RUN=false
SKIP_PACKAGES=false
SKIP_REPOS=false
INVENTORY=""

log() {
    local level="$1" message="$2"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message"
}

step() {
    printf '\n=== %s ===\n' "$1"
}

usage() {
    cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --dry-run          仅展示将要执行的操作，不做实际修改
  --skip-packages    跳过软件包安装步骤
  --skip-repos       跳过仓库克隆步骤
  --inventory PATH   指向 inventory YAML 文件的路径（默认：自动检测）
  --help             显示此帮助信息
EOF
    exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --skip-packages) SKIP_PACKAGES=true ;;
        --skip-repos)    SKIP_REPOS=true ;;
        --inventory) INVENTORY="$2"; shift ;;
        --help)      usage ;;
        -h)          usage ;;
        *)           echo "未知选项: $1"; usage ;;
    esac
    shift
done

# 横幅
echo ''
echo '╔══════════════════════════════════════════════════╗'
echo '║     workstation-bootstrap — Unix                ║'
echo '╚══════════════════════════════════════════════════╝'
echo ''

if $DRY_RUN; then
    log 'INFO' '模拟运行模式 — 不会做任何实际修改'
fi

log 'INFO' "项目根目录: $PROJECT_ROOT"

# ── 预检 ──────────────────────────────────────────────────────────────────
step '预检'

log 'INFO' "操作系统: $(uname -s)"
log 'INFO' "主机名: $(hostname)"

# 检查 bash 版本
log 'INFO' "Bash: ${BASH_VERSION}"

# 检查 git
if command -v git &>/dev/null; then
    log 'INFO' "Git: $(git --version)"
else
    log 'ERROR' 'Git 未安装。请先安装 Git。'
    exit 1
fi

# 解析 inventory 文件路径
if [[ -z "$INVENTORY" ]]; then
    case "$(uname -s)" in
        Linux)  INVENTORY="$PROJECT_ROOT/inventory/ubuntu-main.yaml" ;;
        Darwin) INVENTORY="$PROJECT_ROOT/inventory/macos-main.yaml" ;;
        *)      log 'ERROR' "未知操作系统: $(uname -s)"; exit 1 ;;
    esac
fi

if [[ ! -f "$INVENTORY" ]]; then
    log 'ERROR' "未找到 inventory 文件: $INVENTORY"
    log 'INFO' '请从模板创建 inventory 文件，或使用 --inventory 指定路径'
    exit 1
fi
log 'INFO' "Inventory 文件: $INVENTORY"

# ── 步骤 1: 创建目录 ─────────────────────────────────────────────────────
step '步骤 1: 创建目录结构'
create_args=(--inventory "$INVENTORY")
$DRY_RUN && create_args+=(--dry-run)
"$SCRIPT_DIR/create-directories.sh" "${create_args[@]}" || {
    log 'ERROR' '目录创建失败'
    exit 1
}

# ── 步骤 2: 安装软件包 ───────────────────────────────────────────────────
if ! $SKIP_PACKAGES; then
    step '步骤 2: 安装软件包'
    install_args=(--inventory "$INVENTORY")
    $DRY_RUN && install_args+=(--dry-run)
    "$SCRIPT_DIR/install-packages.sh" "${install_args[@]}" || {
        log 'WARN' '软件包安装出现错误（请查看上方输出）'
    }
else
    log 'INFO' '跳过软件包安装（--skip-packages）'
fi

# ── 步骤 3: 克隆仓库 ─────────────────────────────────────────────────────
if ! $SKIP_REPOS; then
    step '步骤 3: 克隆仓库'
    clone_args=(--inventory "$INVENTORY")
    $DRY_RUN && clone_args+=(--dry-run)
    "$SCRIPT_DIR/clone-repositories.sh" "${clone_args[@]}" || {
        log 'WARN' '仓库克隆出现错误（请查看上方输出）'
    }
else
    log 'INFO' '跳过仓库克隆（--skip-repos）'
fi

# ── 步骤 4: 验证 ─────────────────────────────────────────────────────────
step '步骤 4: 验证'
verify_args=(--inventory "$INVENTORY")
# 用 if 捕获退出码，避免 set -e 下 verify 失败导致后续代码不可达
if "$SCRIPT_DIR/verify.sh" "${verify_args[@]}"; then
    VERIFY_EXIT=0
else
    VERIFY_EXIT=$?
fi

step '引导完成'
if $DRY_RUN; then
    log 'INFO' '模拟运行结束。请查看上方输出，确认无误后去掉 --dry-run 重新执行。'
else
    log 'INFO' "引导完成。验证退出码: $VERIFY_EXIT"
fi

exit $VERIFY_EXIT