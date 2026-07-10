#!/usr/bin/env bash
# SCRIPT-METADATA
# name: run-unix
# description: Canonical shell entry point; selects and delegates to the native manifest-driven orchestrator.
# platform: windows, ubuntu, macos
# inputs: --inventory PATH, --manifest PATH, --task ID, --dry-run, --skip-packages, --skip-repos, --output-format text|json, --list-tasks, --help
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
# END-SCRIPT-METADATA
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.bash
source "$SCRIPT_DIR/scripts/lib/common.bash"
bootstrap_init 'run-unix' "${BOOTSTRAP_OUTPUT_FORMAT:-text}" || exit 1

case "$(uname -s)" in
    Linux|Darwin)
        exec bash "$SCRIPT_DIR/scripts/unix/orchestrate.sh" "$@"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        if ! command -v pwsh >/dev/null 2>&1; then
            bootstrap_write_record 'ERROR' 'run-unix' \
                'PowerShell 7 (pwsh) is required when run.sh is used on Windows.'
            exit 1
        fi
        ps_args=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --dry-run) ps_args+=('-DryRun') ;;
                --skip-packages) ps_args+=('-SkipPackages') ;;
                --skip-repos) ps_args+=('-SkipRepos') ;;
                --list-tasks) ps_args+=('-ListTasks') ;;
                --inventory|--manifest|--task|--output-format)
                    if [[ $# -lt 2 ]]; then
                        bootstrap_write_record 'ERROR' 'run-unix' "Missing value for $1."
                        exit 1
                    fi
                    case "$1" in
                        --inventory) ps_args+=('-Inventory' "$2") ;;
                        --manifest) ps_args+=('-Manifest' "$2") ;;
                        --task) ps_args+=('-Task' "$2") ;;
                        --output-format)
                            BOOTSTRAP_OUTPUT_FORMAT="$2"
                            bootstrap_init 'run-unix' "$2" || exit 1
                            ps_args+=('-OutputFormat' "$2")
                            ;;
                    esac
                    shift
                    ;;
                --help|-h) ps_args+=('-Help') ;;
                *)
                    bootstrap_write_record 'ERROR' 'run-unix' "Unknown option: $1"
                    exit 1
                    ;;
            esac
            shift
        done
        exec pwsh -NoLogo -NoProfile -File "$SCRIPT_DIR/run.ps1" "${ps_args[@]}"
        ;;
    *)
        bootstrap_write_record 'ERROR' 'run-unix' "Unsupported operating system: $(uname -s)"
        exit 1
        ;;
esac
