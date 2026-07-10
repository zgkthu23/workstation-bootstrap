#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-orchestrator
# description: Reads MANIFEST.yaml and executes one task or the ordered Unix bootstrap workflow.
# platform: ubuntu, macos
# inputs: --inventory PATH, --manifest PATH, --task ID, --dry-run, --skip-packages, --skip-repos, --output-format text|json, --list-tasks, --help
# outputs: stdout=[INFO|WARN|SUCCESS] workflow and child records; stderr=[ERROR] records
# exit_codes: 0=success, 1=error, 2=selected-task-skipped-or-not-applicable
# END-SCRIPT-METADATA
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/lib/common.bash
source "$PROJECT_ROOT/scripts/lib/common.bash"

MANIFEST="$PROJECT_ROOT/MANIFEST.yaml"
INVENTORY=''
SELECTED_TASK=''
DRY_RUN=false
SKIP_PACKAGES=false
SKIP_REPOS=false
LIST_TASKS=false
OUTPUT_FORMAT="${BOOTSTRAP_OUTPUT_FORMAT:-text}"

usage() {
    printf '%s\n' \
        'Usage: orchestrate.sh [options]' \
        '  --inventory PATH          Host inventory (default selected by operating system).' \
        '  --manifest PATH           Execution manifest (default: project MANIFEST.yaml).' \
        '  --task ID                 Run one declared bootstrap task instead of the workflow.' \
        '  --dry-run                 Forward dry-run mode to tasks that declare it.' \
        '  --skip-packages           Do not invoke the install-packages step.' \
        '  --skip-repos              Do not invoke the clone-repositories step.' \
        '  --output-format text|json Emit text records (default) or NDJSON records.' \
        '  --list-tasks              List task IDs and paths without executing them.' \
        '  --help, -h                Show this help.'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inventory|--manifest|--task|--output-format)
            if [[ $# -lt 2 ]]; then
                bootstrap_init 'unix-orchestrator' "$OUTPUT_FORMAT" || true
                bootstrap_write_record 'ERROR' 'unix-orchestrator' "Missing value for $1."
                exit 1
            fi
            case "$1" in
                --inventory) INVENTORY="$2" ;;
                --manifest) MANIFEST="$2" ;;
                --task) SELECTED_TASK="$2" ;;
                --output-format) OUTPUT_FORMAT="$2" ;;
            esac
            shift
            ;;
        --dry-run) DRY_RUN=true ;;
        --skip-packages) SKIP_PACKAGES=true ;;
        --skip-repos) SKIP_REPOS=true ;;
        --list-tasks) LIST_TASKS=true ;;
        --help|-h) usage; exit 0 ;;
        *)
            bootstrap_init 'unix-orchestrator' "$OUTPUT_FORMAT" || true
            bootstrap_write_record 'ERROR' 'unix-orchestrator' "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

bootstrap_init 'unix-orchestrator' "$OUTPUT_FORMAT" || exit 1
bootstrap_enable_error_trap

case "$(uname -s)" in
    Linux) DEFAULT_INVENTORY="$PROJECT_ROOT/inventory/ubuntu-main.yaml"; EXPECTED_INVENTORY_OS='ubuntu' ;;
    Darwin) DEFAULT_INVENTORY="$PROJECT_ROOT/inventory/macos-main.yaml"; EXPECTED_INVENTORY_OS='macos' ;;
    *)
        bootstrap_write_record 'ERROR' 'unix-orchestrator' "Unsupported operating system: $(uname -s)"
        exit 1
        ;;
esac
[[ -n "$INVENTORY" ]] || INVENTORY="$DEFAULT_INVENTORY"

bootstrap_require_file "$MANIFEST" 'Manifest' || exit 1

read_manifest_steps() {
    awk '
        function clean(value) {
            sub(/^[[:space:]]*/, "", value)
            sub(/[[:space:]]*$/, "", value)
            gsub(/^"|"$/, "", value)
            return value
        }
        function emit() {
            if (id != "") print order "|" id "|" unix_path "|" forwards "|" skip_option "|" failure_policy
        }
        /^bootstrap_steps:[[:space:]]*$/ { active=1; next }
        active && /^[^[:space:]]/ { emit(); active=0 }
        active && /^  - id:/ {
            emit()
            id=$0; sub(/^  - id:[[:space:]]*/, "", id); id=clean(id)
            order=""; unix_path=""; forwards=""; skip_option="none"; failure_policy="continue"
            next
        }
        active && /^    order:/ { order=$0; sub(/^    order:[[:space:]]*/, "", order); order=clean(order); next }
        active && /^    unix:/ { unix_path=$0; sub(/^    unix:[[:space:]]*/, "", unix_path); unix_path=clean(unix_path); next }
        active && /^    forwards:/ { forwards=$0; sub(/^    forwards:[[:space:]]*/, "", forwards); forwards=clean(forwards); next }
        active && /^    skip_option:/ { skip_option=$0; sub(/^    skip_option:[[:space:]]*/, "", skip_option); skip_option=clean(skip_option); next }
        active && /^    failure_policy:/ { failure_policy=$0; sub(/^    failure_policy:[[:space:]]*/, "", failure_policy); failure_policy=clean(failure_policy); next }
        END { if (active) emit() }
    ' "$MANIFEST" | sort -t '|' -k1,1n
}

if $LIST_TASKS; then
    task_count=0
    while IFS='|' read -r order id relative_path _; do
        [[ -n "$id" ]] || continue
        task_count=$((task_count + 1))
        bootstrap_write_record 'INFO' 'task-catalog' "$order $id $relative_path"
    done < <(read_manifest_steps)
    if [[ "$task_count" -eq 0 ]]; then
        bootstrap_write_record 'ERROR' 'unix-orchestrator' 'Manifest contains no bootstrap_steps.'
        exit 1
    fi
    bootstrap_write_record 'SUCCESS' 'unix-orchestrator' "$task_count task(s) declared."
    exit 0
fi

bootstrap_require_file "$INVENTORY" 'Inventory' || exit 1
INVENTORY_OS="$(bootstrap_read_yaml_scalar os "$INVENTORY")"
if [[ "$INVENTORY_OS" != "$EXPECTED_INVENTORY_OS" ]]; then
    bootstrap_write_record 'ERROR' 'unix-orchestrator' \
        "Inventory os '$INVENTORY_OS' does not match expected '$EXPECTED_INVENTORY_OS'."
    exit 1
fi
bootstrap_write_record 'INFO' 'unix-orchestrator' "Manifest: $MANIFEST"
bootstrap_write_record 'INFO' 'unix-orchestrator' "Inventory: $INVENTORY"
[[ -n "$SELECTED_TASK" ]] && bootstrap_write_record 'INFO' 'unix-orchestrator' "Selected task: $SELECTED_TASK"
$DRY_RUN && bootstrap_write_record 'INFO' 'unix-orchestrator' 'Dry-run mode enabled.'

# Preserve the original full-bootstrap preflight. Directly selected tasks stay
# independent and validate only their own declared prerequisites.
if [[ -z "$SELECTED_TASK" ]]; then
    bootstrap_write_record 'INFO' 'unix-orchestrator' "Operating system: $(uname -s)"
    bootstrap_write_record 'INFO' 'unix-orchestrator' "Hostname: $(hostname)"
    bootstrap_write_record 'INFO' 'unix-orchestrator' "Bash: $BASH_VERSION"
    if command -v git >/dev/null 2>&1; then
        bootstrap_write_record 'INFO' 'unix-orchestrator' "Git: $(git --version)"
    else
        bootstrap_write_record 'ERROR' 'unix-orchestrator' 'Git is required before bootstrap.'
        exit 1
    fi
fi

DECLARED_COUNT=0
MATCHED_COUNT=0
ERROR_COUNT=0
SELECTED_STATUS=0

while IFS='|' read -r order id relative_path forwards skip_option failure_policy; do
    [[ -n "$id" ]] || continue
    DECLARED_COUNT=$((DECLARED_COUNT + 1))
    if [[ -n "$SELECTED_TASK" && "$id" != "$SELECTED_TASK" ]]; then
        continue
    fi
    MATCHED_COUNT=$((MATCHED_COUNT + 1))

    if [[ "$skip_option" == 'skip-packages' && "$SKIP_PACKAGES" == true ]] || \
       [[ "$skip_option" == 'skip-repos' && "$SKIP_REPOS" == true ]]; then
        bootstrap_write_record 'WARN' "$id" "Skipped by --$skip_option."
        [[ -n "$SELECTED_TASK" ]] && SELECTED_STATUS=2
        continue
    fi

    if [[ -z "$order" || -z "$relative_path" || "$relative_path" == /* || \
          "$relative_path" == ../* || "$relative_path" == */../* || "$relative_path" == */.. ]]; then
        bootstrap_write_record 'ERROR' 'unix-orchestrator' "Invalid manifest entry for step: $id"
        exit 1
    fi
    step_path="$PROJECT_ROOT/$relative_path"
    bootstrap_require_file "$step_path" 'Declared step script' || exit 1

    step_args=()
    case ",$forwards," in *,inventory,*) step_args+=(--inventory "$INVENTORY") ;; esac
    if $DRY_RUN; then
        case ",$forwards," in *,dry-run,*) step_args+=(--dry-run) ;; esac
    fi
    case ",$forwards," in *,output-format,*) step_args+=(--output-format "$OUTPUT_FORMAT") ;; esac

    bootstrap_write_record 'INFO' "$id" "Starting step $order: $relative_path"
    if bash "$step_path" "${step_args[@]}"; then step_exit=0; else step_exit=$?; fi
    case "$step_exit" in
        0)
            bootstrap_write_record 'SUCCESS' "$id" 'Step completed.'
            ;;
        2)
            bootstrap_write_record 'WARN' "$id" 'Step reported skipped/not applicable.'
            [[ -n "$SELECTED_TASK" ]] && SELECTED_STATUS=2
            ;;
        *)
            if [[ "$step_exit" -ne 1 ]]; then
                bootstrap_write_record 'ERROR' "$id" "Unexpected exit code $step_exit; normalized to 1."
            else
                bootstrap_write_record 'ERROR' "$id" 'Step failed with exit code 1.'
            fi
            ERROR_COUNT=$((ERROR_COUNT + 1))
            if [[ "$failure_policy" == 'stop' ]]; then exit 1; fi
            ;;
    esac
done < <(read_manifest_steps)

if [[ "$DECLARED_COUNT" -eq 0 ]]; then
    bootstrap_write_record 'ERROR' 'unix-orchestrator' 'Manifest contains no bootstrap_steps.'
    exit 1
fi
if [[ "$MATCHED_COUNT" -eq 0 ]]; then
    bootstrap_write_record 'ERROR' 'unix-orchestrator' "Unknown task: $SELECTED_TASK"
    exit 1
fi
if [[ "$ERROR_COUNT" -gt 0 ]]; then
    bootstrap_write_record 'ERROR' 'unix-orchestrator' "Workflow completed with $ERROR_COUNT failed step(s)."
    exit 1
fi
if [[ -n "$SELECTED_TASK" && "$SELECTED_STATUS" -eq 2 ]]; then
    bootstrap_write_record 'WARN' 'unix-orchestrator' "Task $SELECTED_TASK did not apply."
    exit 2
fi

bootstrap_write_record 'SUCCESS' 'unix-orchestrator' "$MATCHED_COUNT task(s) processed successfully."
exit 0
