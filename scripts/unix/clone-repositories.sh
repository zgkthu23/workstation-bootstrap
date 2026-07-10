#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-clone-repositories
# description: Validates repository inputs and reports the retained Phase-1 clone placeholder.
# platform: ubuntu, macos
# inputs: --inventory PATH, --dry-run, --output-format text|json, --help
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: 0=success, 1=error, 2=phase-1-placeholder-not-applicable
# END-SCRIPT-METADATA
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/lib/common.bash
source "$PROJECT_ROOT/scripts/lib/common.bash"

INVENTORY=''
DRY_RUN=false
OUTPUT_FORMAT="${BOOTSTRAP_OUTPUT_FORMAT:-text}"

usage() {
    printf '%s\n' \
        'Usage: clone-repositories.sh --inventory PATH [options]' \
        '  --inventory PATH          Inventory YAML file (required).' \
        '  --dry-run                 Report the clone plan without changes.' \
        '  --output-format text|json Emit text records (default) or NDJSON records.' \
        '  --help, -h                Show this help.'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inventory|--output-format)
            if [[ $# -lt 2 ]]; then
                bootstrap_init 'clone-repositories' "$OUTPUT_FORMAT" || true
                bootstrap_write_record 'ERROR' 'clone-repositories' "Missing value for $1."
                exit 1
            fi
            if [[ "$1" == '--inventory' ]]; then INVENTORY="$2"; else OUTPUT_FORMAT="$2"; fi
            shift
            ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h) usage; exit 0 ;;
        *)
            bootstrap_init 'clone-repositories' "$OUTPUT_FORMAT" || true
            bootstrap_write_record 'ERROR' 'clone-repositories' "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

bootstrap_init 'clone-repositories' "$OUTPUT_FORMAT" || exit 1
bootstrap_enable_error_trap
if [[ -z "$INVENTORY" ]]; then
    bootstrap_write_record 'ERROR' 'clone-repositories' '--inventory is required.'
    exit 1
fi
bootstrap_require_file "$INVENTORY" 'Inventory' || exit 1
REPOS_YAML="$PROJECT_ROOT/projects/repos.yaml"
bootstrap_require_file "$REPOS_YAML" 'Repository manifest' || exit 1

WORKSPACE_ROOT="$(bootstrap_read_yaml_scalar 'workspace_root' "$INVENTORY")"
if [[ -z "$WORKSPACE_ROOT" ]]; then
    bootstrap_write_record 'ERROR' 'clone-repositories' 'Inventory is missing workspace_root.'
    exit 1
fi

bootstrap_write_record 'INFO' 'clone-repositories' "Repository manifest: $REPOS_YAML"
bootstrap_write_record 'INFO' 'clone-repositories' "Workspace root: $WORKSPACE_ROOT"
$DRY_RUN && bootstrap_write_record 'INFO' 'clone-repositories' \
    'Dry-run plan: targets would use WORKSPACE_ROOT/repos/<group>/<directory>.'
bootstrap_write_record 'INFO' 'clone-repositories' \
    'Safety policy: never overwrite an existing repository or force-update a dirty worktree.'
bootstrap_write_record 'WARN' 'clone-repositories' \
    'Repository cloning remains the original Phase-1 placeholder and is not applicable yet.'
exit 2
