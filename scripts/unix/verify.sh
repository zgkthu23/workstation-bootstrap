#!/usr/bin/env bash
# ==============================================================================
# Verify workstation state after bootstrap
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
Usage: $(basename "$0") --inventory PATH [--dry-run]

Options:
  --inventory PATH  Path to inventory YAML file (required)
  --dry-run         Show what would be verified
  --help            Show this help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
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

ERRORS=0
WARNINGS=0

echo ''
echo '=== Workstation Verification ==='
echo ''

# 1. OS info
log 'INFO' "OS: $(uname -s)"
log 'INFO' "Hostname: $(hostname)"

# 2. Inventory
if [[ -f "$INVENTORY" ]]; then
    log 'PASS' "Inventory found: $INVENTORY"
else
    log 'ERROR' "Inventory not found: $INVENTORY"
    ((ERRORS++))
fi

# 3. Git
if command -v git &>/dev/null; then
    log 'PASS' "Git: $(git --version)"
else
    log 'ERROR' 'Git is not installed'
    ((ERRORS++))
fi

# 4. Package manager
case "$(uname -s)" in
    Linux)
        if command -v apt &>/dev/null; then
            log 'PASS' 'apt available'
        else
            log 'WARN' 'apt not found'
            ((WARNINGS++))
        fi
        ;;
    Darwin)
        if command -v brew &>/dev/null; then
            log 'PASS' "Homebrew: $(brew --version | head -1)"
        else
            log 'WARN' 'Homebrew not found'
            ((WARNINGS++))
        fi
        ;;
esac

# 5. repos.yaml
REPOS_YAML="$PROJECT_ROOT/projects/repos.yaml"
if [[ -f "$REPOS_YAML" ]]; then
    log 'PASS' 'repos.yaml found'
else
    log 'ERROR' "repos.yaml not found: $REPOS_YAML"
    ((ERRORS++))
fi

# 6. Secret scan
SECRETS_SCAN="$PROJECT_ROOT/tests/test_no_secrets.py"
if [[ -f "$SECRETS_SCAN" ]]; then
    log 'INFO' 'Running secret scan...'
    if command -v uv &>/dev/null; then
        if uv run python "$SECRETS_SCAN" 2>&1; then
            log 'PASS' 'Secret scan: clean'
        else
            log 'WARN' 'Secret scan found issues (see above)'
            ((WARNINGS++))
        fi
    else
        if python3 "$SECRETS_SCAN" 2>&1; then
            log 'PASS' 'Secret scan: clean'
        else
            log 'WARN' 'Secret scan found issues (see above)'
            ((WARNINGS++))
        fi
    fi
fi

# 7. Summary
echo ''
echo '=== Verification Summary ==='
printf 'Errors  : %d\n' "$ERRORS"
printf 'Warnings: %d\n' "$WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
    echo 'VERIFICATION FAILED'
    exit 1
else
    echo 'VERIFICATION PASSED'
    exit 0
fi