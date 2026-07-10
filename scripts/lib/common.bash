#!/usr/bin/env bash
# MODULE-METADATA
# name: unix-runtime
# description: Shared dependency-free logging, validation, and YAML-scalar helpers for Unix scripts.
# platform: ubuntu, macos
# interface: source this file, call bootstrap_init COMPONENT FORMAT, then use bootstrap_write_record.
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: library functions return 0=success or 1=error; callers own process exit codes.
# END-MODULE-METADATA

# This file is a sourced module, not a command. It deliberately changes no shell
# options so every executable remains in control of its own failure policy.

BOOTSTRAP_COMPONENT='bootstrap'
BOOTSTRAP_OUTPUT_FORMAT='text'

bootstrap_utc_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

bootstrap_json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

bootstrap_write_record() {
    local level="$1" component="$2" message="$3" timestamp line
    timestamp="$(bootstrap_utc_timestamp)"

    if [[ "$BOOTSTRAP_OUTPUT_FORMAT" == 'json' ]]; then
        line=$(printf '{"schema_version":1,"timestamp":"%s","level":"%s","component":"%s","message":"%s"}' \
            "$(bootstrap_json_escape "$timestamp")" \
            "$(bootstrap_json_escape "$level")" \
            "$(bootstrap_json_escape "$component")" \
            "$(bootstrap_json_escape "$message")")
    else
        line="[$level] $timestamp [$component] $message"
    fi

    if [[ "$level" == 'ERROR' ]]; then
        printf '%s\n' "$line" >&2
    else
        printf '%s\n' "$line"
    fi
}

bootstrap_init() {
    BOOTSTRAP_COMPONENT="$1"
    BOOTSTRAP_OUTPUT_FORMAT="${2:-text}"
    if [[ "$BOOTSTRAP_OUTPUT_FORMAT" != 'text' && "$BOOTSTRAP_OUTPUT_FORMAT" != 'json' ]]; then
        BOOTSTRAP_OUTPUT_FORMAT='text'
        bootstrap_write_record 'ERROR' "$BOOTSTRAP_COMPONENT" 'Output format must be text or json.'
        return 1
    fi
}

bootstrap_handle_unexpected_error() {
    local exit_code="$1" line_number="$2"
    trap - ERR
    bootstrap_write_record 'ERROR' "$BOOTSTRAP_COMPONENT" \
        "Unhandled command failure at line $line_number (original exit code $exit_code)."
    exit 1
}

bootstrap_enable_error_trap() {
    trap 'bootstrap_handle_unexpected_error "$?" "$LINENO"' ERR
}

bootstrap_require_file() {
    local path="$1" label="$2"
    if [[ ! -f "$path" ]]; then
        bootstrap_write_record 'ERROR' "$BOOTSTRAP_COMPONENT" "$label not found: $path"
        return 1
    fi
}

# Read the first top-level scalar from the intentionally simple inventory YAML.
# This is not a general YAML parser; MANIFEST.yaml documents that constraint.
bootstrap_read_yaml_scalar() {
    local key="$1" path="$2"
    awk -v wanted="$key" '
        /^[[:space:]]*#/ { next }
        {
            line=$0
            if (line ~ "^[[:space:]]*" wanted ":[[:space:]]*") {
                sub("^[[:space:]]*" wanted ":[[:space:]]*", "", line)
                sub(/[[:space:]]+#.*$/, "", line)
                sub(/^[[:space:]]*/, "", line)
                sub(/[[:space:]]*$/, "", line)
                if ((substr(line, 1, 1) == "\"" && substr(line, length(line), 1) == "\"") ||
                    (substr(line, 1, 1) == "\047" && substr(line, length(line), 1) == "\047")) {
                    line=substr(line, 2, length(line)-2)
                }
                print line
                exit
            }
        }
    ' "$path"
}
