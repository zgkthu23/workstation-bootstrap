#!/usr/bin/env bash
# SCRIPT-METADATA
# name: unix-bootstrap-compatibility
# description: Legacy Unix bootstrap path that delegates unchanged arguments to orchestrate.sh.
# platform: ubuntu, macos
# inputs: same interface as scripts/unix/orchestrate.sh, including --help
# outputs: delegated stdout/stderr records
# exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
# END-SCRIPT-METADATA
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/orchestrate.sh" "$@"
