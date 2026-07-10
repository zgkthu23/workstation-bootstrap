#!/usr/bin/env bash
# ==============================================================================
# Create workspace directory structure for Unix
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

usage() {
    cat <<EOF
Usage: $(basename "$0") --inventory PATH [--dry-run] [--force]

Options:
  --inventory PATH  Path to inventory YAML file (required)
  --dry-run         Show what directories would be created
  --force           No effect for directories (mkdir -p is safe)
  --help            Show this help
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --force)     : ;;  # no-op for directories
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

# ponytail: minimal YAML reader — grep for key: value, handles quoted/unquoted
read_yaml_value() {
    local key="$1" file="$2"
    grep -E "^\s*${key}:\s*" "$file" | head -1 | sed -E 's/^[^:]*:\s*"?([^"]*?)"?\s*$/\1/'
}

WORKSPACE_ROOT=$(read_yaml_value 'workspace_root' "$INVENTORY")
DATA_ROOT=$(read_yaml_value 'data_root' "$INVENTORY")
SCRATCH_ROOT=$(read_yaml_value 'scratch_root' "$INVENTORY")
CLOUD_ROOT=$(read_yaml_value 'cloud_root' "$INVENTORY")

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

log 'INFO' "Inventory: $INVENTORY"
log 'INFO' "Roots: ${ROOTS[*]}"

CREATED=0
EXISTED=0

for dir in "${ALL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        log 'INFO' "Exists: $dir"
        ((EXISTED++))
    else
        if $DRY_RUN; then
            echo "  [DRY-RUN] Would create: $dir"
        else
            mkdir -p "$dir"
            log 'INFO' "Created: $dir"
        fi
        ((CREATED++))
    fi
done

echo ''
log 'INFO' "Summary: $EXISTED already existed, $CREATED to create$($DRY_RUN && echo ' (dry-run)')"