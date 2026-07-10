#!/usr/bin/env bash
# ==============================================================================
# Install packages for Unix (apt / Homebrew)
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
Usage: $(basename "$0") --inventory PATH [--dry-run] [--list]

Options:
  --inventory PATH  Path to inventory YAML file (required)
  --dry-run         Show what packages would be installed
  --list            List packages for enabled features
  --help            Show this help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --list)      LIST=true ;;
        --inventory) INVENTORY="$2"; shift ;;
        --help|-h)   usage ;;
        *)           echo "Unknown option: $1"; usage ;;
    esac
    shift
done

if [[ -z "$INVENTORY" ]]; then
    log 'ERROR' '--inventory is required'
    exit 1
fi

OS="$(uname -s)"
log 'INFO' "OS: $OS"

case "$OS" in
    Linux)
        if command -v apt &>/dev/null; then
            log 'INFO' "Package manager: apt"
        else
            log 'ERROR' 'apt not found (only apt-based Linux is supported in Phase 1)'
            exit 1
        fi
        ;;
    Darwin)
        if command -v brew &>/dev/null; then
            log 'INFO' "Package manager: $(brew --version | head -1)"
        else
            log 'WARN' 'Homebrew not found — install it first: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        fi
        ;;
    *)
        log 'ERROR' "Unsupported OS: $OS"
        exit 1
        ;;
esac

log 'INFO' 'Package installation is a Phase 1 placeholder.'
log 'INFO' 'Full implementation will parse manifests and install via apt/brew.'
log 'INFO' "DryRun: $DRY_RUN, List: $LIST"

if $DRY_RUN || $LIST; then
    echo ''
    echo '[DRY-RUN] Would parse manifests and install packages for enabled features.'
    echo '[DRY-RUN] Packages would come from: manifests/common.yaml, manifests/<os>.yaml'
fi