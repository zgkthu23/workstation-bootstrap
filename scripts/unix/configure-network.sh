#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-configure-network
# description: Configures HTTP/HTTPS proxy for GFW environments. Sets env vars in shell rc and current session.
# platform: ubuntu, macos
# inputs: --inventory PATH, --dry-run, --output-format text|json, --help
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
# END-SCRIPT-METADATA
# =============================================================================
# configure-network.sh — 配置网络代理（GFW 环境）
#
# 这是整个引导流程的第一步（order: 5），必须在安装软件包、克隆仓库之前执行。
# 职责：确保当前 shell 和后续步骤都能通过代理访问外网。
#
# 退出码：0 成功，1 失败，2 跳过
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
    --help) bootstrap_help "$0"; exit 0 ;;
    *) bootstrap_log ERROR "configure-network" "未知参数: $1"; exit 1 ;;
  esac
done

bootstrap_init "configure-network" "$OUTPUT_FORMAT"

# ---- 加载清单 -----------------------------------------------------------
bootstrap_require_file "$INVENTORY" || exit 1
INVENTORY_DIR="$(dirname "$INVENTORY")"
OS="$(uname -s)"

# 读取代理配置
PROXY_HTTP=""
PROXY_HTTPS=""
NO_PROXY=""

# 从 inventory 读取 proxy 块
if [[ "$OS" == "Darwin" ]]; then
  MANIFEST="${INVENTORY_DIR}/../manifests/macos.yaml"
else
  MANIFEST="${INVENTORY_DIR}/../manifests/ubuntu.yaml"
fi

if [[ -f "$MANIFEST" ]]; then
  PROXY_HTTP="$(bootstrap_read_yaml_scalar "$MANIFEST" "HTTP_PROXY" 2>/dev/null || true)"
  PROXY_HTTPS="$(bootstrap_read_yaml_scalar "$MANIFEST" "HTTPS_PROXY" 2>/dev/null || true)"
  NO_PROXY="$(bootstrap_read_yaml_scalar "$MANIFEST" "NO_PROXY" 2>/dev/null || true)"
fi

# 如果清单里没配，用默认值
PROXY_HTTP="${PROXY_HTTP:-http://127.0.0.1:10808}"
PROXY_HTTPS="${PROXY_HTTPS:-http://127.0.0.1:10808}"
NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,*.local}"

# ---- 检查代理可达性 -----------------------------------------------------
bootstrap_log INFO "configure-network" "代理地址: $PROXY_HTTP"
bootstrap_log INFO "configure-network" "NO_PROXY: $NO_PROXY"

if $DRY_RUN; then
  bootstrap_log SUCCESS "configure-network" "[DRY-RUN] 将设置 HTTP_PROXY/HTTPS_PROXY 环境变量"
  exit 0
fi

# 测试代理是否可达（curl 5 秒超时）
if command -v curl >/dev/null 2>&1; then
  if curl -s --max-time 5 -x "$PROXY_HTTP" "https://www.google.com" -o /dev/null 2>/dev/null; then
    bootstrap_log SUCCESS "configure-network" "代理可达 — Google 连通"
  else
    bootstrap_log WARN "configure-network" "代理不可达 — 请确认 v2rayN 已启动"
  fi
else
  bootstrap_log WARN "configure-network" "curl 不可用，跳过代理连通性测试"
fi

# ---- 写入 shell 配置 -----------------------------------------------------
SHELL_RC=""
if [[ "$OS" == "Darwin" ]]; then
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_RC="$HOME/.bashrc"
  [[ "${SHELL:-}" == */zsh ]] && SHELL_RC="$HOME/.zshrc"
fi

# 检查是否已有代理配置
if [[ -f "$SHELL_RC" ]] && grep -q "HTTP_PROXY" "$SHELL_RC" 2>/dev/null; then
  bootstrap_log INFO "configure-network" "$SHELL_RC 中已有代理配置，跳过写入"
else
  {
    echo ""
    echo "# === GFW 代理（workstation-bootstrap 自动配置）==="
    echo "export HTTP_PROXY=\"$PROXY_HTTP\""
    echo "export HTTPS_PROXY=\"$PROXY_HTTPS\""
    echo "export NO_PROXY=\"$NO_PROXY\""
    echo "export http_proxy=\"$PROXY_HTTP\""
    echo "export https_proxy=\"$PROXY_HTTPS\""
    echo "export no_proxy=\"$NO_PROXY\""
  } >> "$SHELL_RC"
  bootstrap_log SUCCESS "configure-network" "代理配置已写入 $SHELL_RC"
fi

# ---- 当前 shell 生效 -----------------------------------------------------
export HTTP_PROXY="$PROXY_HTTP"
export HTTPS_PROXY="$PROXY_HTTPS"
export NO_PROXY="$NO_PROXY"
export http_proxy="$PROXY_HTTP"
export https_proxy="$PROXY_HTTPS"
export no_proxy="$NO_PROXY"

bootstrap_log SUCCESS "configure-network" "网络配置完成 — 当前 shell 已生效"