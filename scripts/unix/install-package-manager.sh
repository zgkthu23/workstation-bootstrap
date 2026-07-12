#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-install-package-manager
# description: Ensures the platform package manager is installed (brew on macOS, apt on Ubuntu).
# platform: ubuntu, macos
# inputs: --inventory PATH, --dry-run, --output-format text|json, --help
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
# END-SCRIPT-METADATA
# =============================================================================
# install-package-manager.sh — 确保包管理器可用
#
# macOS: 安装 Homebrew（如果缺失）
# Ubuntu: apt 已自带，直接跳过
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.bash"

# ---- 解析参数 -----------------------------------------------------------
INVENTORY=""
DRY_RUN=false
OUTPUT_FORMAT="${BOOTSTRAP_OUTPUT_FORMAT:-text}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --inventory) INVENTORY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --output-format) OUTPUT_FORMAT="$2"; shift 2 ;;
    --help) printf '%s\n' "Usage: install-package-manager.sh [--inventory PATH] [--dry-run] [--output-format text|json] [--help]"; exit 0 ;;
    *) echo "ERROR: 未知参数: $1" >&2; exit 1 ;;
  esac
done

bootstrap_init "install-package-manager" "$OUTPUT_FORMAT"

OS="$(uname -s)"

# ---- Ubuntu — apt 自带，直接跳过 --------------------------------
if [[ "$OS" == "Linux" ]]; then
  if command -v apt-get >/dev/null 2>&1; then
    bootstrap_write_record SUCCESS "install-package-manager" "apt 已可用（Ubuntu 自带）"
  else
    bootstrap_write_record ERROR "install-package-manager" "apt-get 不可用 — 非 Ubuntu 系统？"
    exit 1
  fi
  exit 0
fi

# ---- macOS — 安装 Homebrew ------------------------------------
if [[ "$OS" != "Darwin" ]]; then
  bootstrap_write_record ERROR "install-package-manager" "不支持的操作系统: $OS"
  exit 1
fi

if command -v brew >/dev/null 2>&1; then
  BREW_VER="$(timeout 5 brew --version 2>/dev/null | head -1 || echo 'unknown')"
  bootstrap_write_record SUCCESS "install-package-manager" "Homebrew 已安装: $BREW_VER"
  exit 0
fi

if $DRY_RUN; then
  bootstrap_write_record SUCCESS "install-package-manager" "[DRY-RUN] 将安装 Homebrew"
  exit 0
fi

bootstrap_write_record INFO "install-package-manager" "正在安装 Homebrew..."

# 先下载安装脚本，再执行——避免 curl 失败时被静默吞掉
BREW_SH="/tmp/brew-install.sh"
if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$BREW_SH"; then
  bootstrap_write_record ERROR "install-package-manager" "Homebrew 安装脚本下载失败"
  exit 1
fi

if ! /bin/bash "$BREW_SH" </dev/null; then
  bootstrap_write_record ERROR "install-package-manager" "Homebrew 安装失败"
  rm -f "$BREW_SH"
  exit 1
fi
rm -f "$BREW_SH"

# 将 brew 加入 PATH（当前进程 + 写入 shell rc 供后续步骤使用）
BREW_PREFIX=""
if [[ -f /opt/homebrew/bin/brew ]]; then
  BREW_PREFIX="/opt/homebrew"
elif [[ -f /usr/local/bin/brew ]]; then
  BREW_PREFIX="/usr/local"
fi

if [[ -n "$BREW_PREFIX" ]]; then
  eval "$($BREW_PREFIX/bin/brew shellenv)"
  # 写入 shell rc，确保新终端和后续脚本能看到 brew
  SHELL_RC="$HOME/.zshrc"
  if ! grep -q "brew shellenv" "$SHELL_RC" 2>/dev/null; then
    echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> "$SHELL_RC"
  fi
fi

if command -v brew >/dev/null 2>&1; then
  BREW_VER="$(timeout 5 brew --version 2>/dev/null | head -1 || echo 'unknown')"
  bootstrap_write_record SUCCESS "install-package-manager" "Homebrew 安装成功: $BREW_VER"
else
  bootstrap_write_record WARN "install-package-manager" "Homebrew 已安装但未在 PATH 中 — 请重新打开终端"
fi