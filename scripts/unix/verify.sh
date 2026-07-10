#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-verify
# description: Verifies host prerequisites plus the project contract and repository secret scan.
# platform: ubuntu, macos
# inputs: --inventory PATH, --output-format text|json, --help
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: 0=success, 1=verification-error, 2=skipped-or-not-applicable
# END-SCRIPT-METADATA
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/lib/common.bash
source "$PROJECT_ROOT/scripts/lib/common.bash"

INVENTORY=''
OUTPUT_FORMAT="${BOOTSTRAP_OUTPUT_FORMAT:-text}"

usage() {
    printf '%s\n' \
        'Usage: verify.sh --inventory PATH [options]' \
        '  --inventory PATH          Inventory YAML file (required).' \
        '  --output-format text|json Emit text records (default) or NDJSON records.' \
        '  --help, -h                Show this help.'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inventory|--output-format)
            if [[ $# -lt 2 ]]; then
                bootstrap_init 'verify' "$OUTPUT_FORMAT" || true
                bootstrap_write_record 'ERROR' 'verify' "Missing value for $1."
                exit 1
            fi
            if [[ "$1" == '--inventory' ]]; then INVENTORY="$2"; else OUTPUT_FORMAT="$2"; fi
            shift
            ;;
        --help|-h) usage; exit 0 ;;
        *)
            bootstrap_init 'verify' "$OUTPUT_FORMAT" || true
            bootstrap_write_record 'ERROR' 'verify' "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

bootstrap_init 'verify' "$OUTPUT_FORMAT" || exit 1
bootstrap_enable_error_trap
if [[ -z "$INVENTORY" ]]; then
    bootstrap_write_record 'ERROR' 'verify' '--inventory is required.'
    exit 1
fi

ERRORS=0
WARNINGS=0
bootstrap_write_record 'INFO' 'verify' "Operating system: $(uname -s)"
bootstrap_write_record 'INFO' 'verify' "Hostname: $(hostname)"

if [[ -f "$INVENTORY" ]]; then
    bootstrap_write_record 'SUCCESS' 'verify' "Inventory found: $INVENTORY"
else
    bootstrap_write_record 'ERROR' 'verify' "Inventory not found: $INVENTORY"
    ERRORS=$((ERRORS + 1))
fi

if command -v git >/dev/null 2>&1; then
    bootstrap_write_record 'SUCCESS' 'verify' "Git available: $(git --version)"
else
    bootstrap_write_record 'ERROR' 'verify' 'Git is not installed.'
    ERRORS=$((ERRORS + 1))
fi

case "$(uname -s)" in
    Linux)
        if command -v apt >/dev/null 2>&1; then
            bootstrap_write_record 'SUCCESS' 'verify' 'apt is available.'
        else
            bootstrap_write_record 'WARN' 'verify' 'apt was not found.'
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;
    Darwin)
        if command -v brew >/dev/null 2>&1; then
            bootstrap_write_record 'SUCCESS' 'verify' "Homebrew available: $(brew --version | head -1)"
        else
            bootstrap_write_record 'WARN' 'verify' 'Homebrew was not found.'
            WARNINGS=$((WARNINGS + 1))
        fi
        ;;
esac

REPOS_YAML="$PROJECT_ROOT/projects/repos.yaml"
if [[ -f "$REPOS_YAML" ]]; then
    bootstrap_write_record 'SUCCESS' 'verify' "Repository manifest found: $REPOS_YAML"
else
    bootstrap_write_record 'ERROR' 'verify' "Repository manifest not found: $REPOS_YAML"
    ERRORS=$((ERRORS + 1))
fi

PYTHON_COMMAND=''
if command -v uv >/dev/null 2>&1 && uv run --quiet python --version >/dev/null 2>&1; then
    PYTHON_COMMAND='uv'
elif command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
    PYTHON_COMMAND='python3'
elif command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
    PYTHON_COMMAND='python'
fi

if [[ -n "$PYTHON_COMMAND" ]]; then
    for validation_id in project-contract secret-scan; do
        validation_status=0
        if [[ "$validation_id" == 'project-contract' ]]; then
            validation_script="$PROJECT_ROOT/tests/validate_manifests.py"
            validation_args=(--root "$PROJECT_ROOT" --output-format "$OUTPUT_FORMAT")
        else
            validation_script="$PROJECT_ROOT/tests/test_no_secrets.py"
            validation_args=(--path "$PROJECT_ROOT" --output-format "$OUTPUT_FORMAT")
        fi
        if [[ ! -f "$validation_script" ]]; then
            bootstrap_write_record 'WARN' 'verify' "Validation script not found: $validation_script"
            WARNINGS=$((WARNINGS + 1))
            continue
        fi
        bootstrap_write_record 'INFO' 'verify' "Running $validation_id validation."
        if [[ "$PYTHON_COMMAND" == 'uv' ]]; then
            uv run --quiet python "$validation_script" "${validation_args[@]}" || validation_status=$?
        else
            "$PYTHON_COMMAND" "$validation_script" "${validation_args[@]}" || validation_status=$?
        fi
        if [[ "$validation_status" -eq 0 ]]; then
            bootstrap_write_record 'SUCCESS' 'verify' "$validation_id validation passed."
        else
            bootstrap_write_record 'WARN' 'verify' "$validation_id validation returned exit code $validation_status."
            WARNINGS=$((WARNINGS + 1))
        fi
    done
else
    bootstrap_write_record 'WARN' 'verify' 'Python is unavailable; Python repository validations were not run.'
    WARNINGS=$((WARNINGS + 1))
fi

if [[ "$ERRORS" -gt 0 ]]; then
    bootstrap_write_record 'ERROR' 'verify' "Verification failed: errors=$ERRORS, warnings=$WARNINGS."
    exit 1
fi
bootstrap_write_record 'SUCCESS' 'verify' "Verification passed: errors=0, warnings=$WARNINGS."
exit 0
