#!/usr/bin/env bash
# ==============================================================================
# Clone Git repositories from projects/repos.yaml
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
Usage: $(basename "$0") --inventory PATH [--dry-run]

Options:
  --inventory PATH  Path to inventory YAML file (required)
  --dry-run         Show what repos would be cloned
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

REPOS_YAML="$PROJECT_ROOT/projects/repos.yaml"
WORKSPACE_ROOT=$(read_yaml_value 'workspace_root' "$INVENTORY")

if [[ ! -f "$REPOS_YAML" ]]; then
    log 'ERROR' "repos.yaml not found: $REPOS_YAML"
    exit 1
fi

log 'INFO' "Repos config: $REPOS_YAML"
log 'INFO' "Workspace root: $WORKSPACE_ROOT"
log 'INFO' 'Repository cloning is a Phase 1 placeholder.'
log 'INFO' 'Full implementation will parse repos.yaml and clone each project.'
log 'INFO' 'Safety rules: no overwrite, no force-pull on dirty repos, dry-run support.'

if $DRY_RUN; then
    echo ''
    echo '[DRY-RUN] Would parse repos.yaml and clone repos for this host.'
    echo '[DRY-RUN] Target: WORKSPACE_ROOT/repos/<group>/<directory>'
fi