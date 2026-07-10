#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-install-packages
# description: Validates the native package manager and reports the retained Phase-1 package plan placeholder.
# platform: ubuntu, macos
# inputs: --inventory PATH, --dry-run, --list, --output-format text|json, --help
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
LIST=false
OUTPUT_FORMAT="${BOOTSTRAP_OUTPUT_FORMAT:-text}"

usage() {
    printf '%s\n' \
        'Usage: install-packages.sh --inventory PATH [options]' \
        '  --inventory PATH          Inventory YAML file (required).' \
        '  --dry-run                 Report the package plan without changes.' \
        '  --list                    Report the package source files.' \
        '  --output-format text|json Emit text records (default) or NDJSON records.' \
        '  --help, -h                Show this help.'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inventory|--output-format)
            if [[ $# -lt 2 ]]; then
                bootstrap_init 'install-packages' "$OUTPUT_FORMAT" || true
                bootstrap_write_record 'ERROR' 'install-packages' "Missing value for $1."
                exit 1
            fi
            if [[ "$1" == '--inventory' ]]; then INVENTORY="$2"; else OUTPUT_FORMAT="$2"; fi
            shift
            ;;
        --dry-run) DRY_RUN=true ;;
        --list) LIST=true ;;
        --help|-h) usage; exit 0 ;;
        *)
            bootstrap_init 'install-packages' "$OUTPUT_FORMAT" || true
            bootstrap_write_record 'ERROR' 'install-packages' "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

bootstrap_init 'install-packages' "$OUTPUT_FORMAT" || exit 1
bootstrap_enable_error_trap
if [[ -z "$INVENTORY" ]]; then
    bootstrap_write_record 'ERROR' 'install-packages' '--inventory is required.'
    exit 1
fi
bootstrap_require_file "$INVENTORY" 'Inventory' || exit 1
bootstrap_require_file "$PROJECT_ROOT/manifests/common.yaml" 'Common package manifest' || exit 1

case "$(uname -s)" in
    Linux)
        bootstrap_require_file "$PROJECT_ROOT/manifests/ubuntu.yaml" 'Ubuntu package manifest' || exit 1
        if ! command -v apt >/dev/null 2>&1; then
            bootstrap_write_record 'WARN' 'install-packages' \
                'apt was not found; the Phase-1 placeholder will still be reported.'
        else
            bootstrap_write_record 'INFO' 'install-packages' 'Package manager: apt'
        fi
        ;;
    Darwin)
        bootstrap_require_file "$PROJECT_ROOT/manifests/macos.yaml" 'macOS package manifest' || exit 1
        if command -v brew >/dev/null 2>&1; then
            bootstrap_write_record 'INFO' 'install-packages' "Package manager: $(brew --version | head -1)"
        else
            bootstrap_write_record 'WARN' 'install-packages' 'Homebrew is not installed.'
        fi
        ;;
    *)
        bootstrap_write_record 'WARN' 'install-packages' "Package task is not applicable to $(uname -s)."
        exit 2
        ;;
esac

bootstrap_write_record 'INFO' 'install-packages' "Inventory: $INVENTORY"
bootstrap_write_record 'INFO' 'install-packages' \
    'Package sources: manifests/common.yaml and manifests/<os>.yaml.'
if $DRY_RUN || $LIST; then
    bootstrap_write_record 'INFO' 'install-packages' \
        "Plan requested: dry_run=$DRY_RUN, list=$LIST; no packages will be changed."
fi
bootstrap_write_record 'WARN' 'install-packages' \
    'Package installation remains the original Phase-1 placeholder and is not applicable yet.'
exit 2
