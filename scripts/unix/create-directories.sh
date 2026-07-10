#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-create-directories
# description: Idempotently creates inventory-defined roots and the standard workspace layout.
# platform: ubuntu, macos
# inputs: --inventory PATH, --dry-run, --output-format text|json, --help
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
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
        'Usage: create-directories.sh --inventory PATH [options]' \
        '  --inventory PATH          Inventory YAML file (required).' \
        '  --dry-run                 Report planned directories without creating them.' \
        '  --output-format text|json Emit text records (default) or NDJSON records.' \
        '  --help, -h                Show this help.'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inventory|--output-format)
            if [[ $# -lt 2 ]]; then
                bootstrap_init 'create-directories' "$OUTPUT_FORMAT" || true
                bootstrap_write_record 'ERROR' 'create-directories' "Missing value for $1."
                exit 1
            fi
            if [[ "$1" == '--inventory' ]]; then INVENTORY="$2"; else OUTPUT_FORMAT="$2"; fi
            shift
            ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h) usage; exit 0 ;;
        *)
            bootstrap_init 'create-directories' "$OUTPUT_FORMAT" || true
            bootstrap_write_record 'ERROR' 'create-directories' "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

bootstrap_init 'create-directories' "$OUTPUT_FORMAT" || exit 1
bootstrap_enable_error_trap
if [[ -z "$INVENTORY" ]]; then
    bootstrap_write_record 'ERROR' 'create-directories' '--inventory is required.'
    exit 1
fi
bootstrap_require_file "$INVENTORY" 'Inventory' || exit 1

WORKSPACE_ROOT="$(bootstrap_read_yaml_scalar 'workspace_root' "$INVENTORY")"
DATA_ROOT="$(bootstrap_read_yaml_scalar 'data_root' "$INVENTORY")"
SCRATCH_ROOT="$(bootstrap_read_yaml_scalar 'scratch_root' "$INVENTORY")"
CLOUD_ROOT="$(bootstrap_read_yaml_scalar 'cloud_root' "$INVENTORY")"

if [[ -z "$WORKSPACE_ROOT" || -z "$DATA_ROOT" || -z "$SCRATCH_ROOT" ]]; then
    bootstrap_write_record 'ERROR' 'create-directories' \
        'Inventory is missing required scalar(s): workspace_root, data_root, scratch_root.'
    exit 1
fi

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

bootstrap_write_record 'INFO' 'create-directories' "Inventory: $INVENTORY"
$DRY_RUN && bootstrap_write_record 'INFO' 'create-directories' 'Dry-run mode enabled.'

CREATED=0
EXISTED=0
for directory in "${ALL_DIRS[@]}"; do
    if [[ -d "$directory" ]]; then
        bootstrap_write_record 'INFO' 'create-directories' "Already exists: $directory"
        EXISTED=$((EXISTED + 1))
    elif $DRY_RUN; then
        bootstrap_write_record 'INFO' 'create-directories' "Would create: $directory"
        CREATED=$((CREATED + 1))
    else
        mkdir -p "$directory"
        bootstrap_write_record 'INFO' 'create-directories' "Created: $directory"
        CREATED=$((CREATED + 1))
    fi
done

bootstrap_write_record 'SUCCESS' 'create-directories' \
    "Directory task complete: existing=$EXISTED, created_or_planned=$CREATED, dry_run=$DRY_RUN."
exit 0
