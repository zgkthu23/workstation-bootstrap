#!/usr/bin/env bash
# ==============================================================================
# workstation-bootstrap — Unix orchestrator
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY_RUN=false
FORCE=false
SKIP_PACKAGES=false
SKIP_REPOS=false
INVENTORY=""

log() {
    local level="$1" message="$2"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message"
}

step() {
    printf '\n=== %s ===\n' "$1"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run          Show what would be done without making changes
  --force            Overwrite existing files and configurations
  --skip-packages    Skip package installation step
  --skip-repos       Skip repository clone step
  --inventory PATH   Path to inventory YAML file (default: auto-detect)
  --help             Show this help message
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --force)     FORCE=true ;;
        --skip-packages) SKIP_PACKAGES=true ;;
        --skip-repos)    SKIP_REPOS=true ;;
        --inventory) INVENTORY="$2"; shift ;;
        --help)      usage ;;
        -h)          usage ;;
        *)           echo "Unknown option: $1"; usage ;;
    esac
    shift
done

# Banner
echo ''
echo '╔══════════════════════════════════════════════════╗'
echo '║     workstation-bootstrap — Unix                ║'
echo '╚══════════════════════════════════════════════════╝'
echo ''

if $DRY_RUN; then
    log 'INFO' 'DRY-RUN MODE — no changes will be made'
fi

log 'INFO' "Project root: $PROJECT_ROOT"

# ── Pre-flight checks ──────────────────────────────────────────────────
step 'Pre-flight checks'

log 'INFO' "OS: $(uname -s)"
log 'INFO' "Hostname: $(hostname)"

# Check bash version
log 'INFO' "Bash: ${BASH_VERSION}"

# Check git
if command -v git &>/dev/null; then
    log 'INFO' "Git: $(git --version)"
else
    log 'ERROR' 'Git is not installed. Install Git first.'
    exit 1
fi

# Resolve inventory
if [[ -z "$INVENTORY" ]]; then
    case "$(uname -s)" in
        Linux)  INVENTORY="$PROJECT_ROOT/inventory/ubuntu-main.yaml" ;;
        Darwin) INVENTORY="$PROJECT_ROOT/inventory/macos-main.yaml" ;;
        *)      log 'ERROR' "Unknown OS: $(uname -s)"; exit 1 ;;
    esac
fi

if [[ ! -f "$INVENTORY" ]]; then
    log 'ERROR' "No inventory found at $INVENTORY"
    log 'INFO' 'Create one from the template or specify with --inventory'
    exit 1
fi
log 'INFO' "Inventory: $INVENTORY"

# ── Step 1: Create directories ─────────────────────────────────────────
step 'Step 1: Create directory structure'
CREATE_ARGS="--inventory $INVENTORY"
$DRY_RUN && CREATE_ARGS="$CREATE_ARGS --dry-run"
$FORCE && CREATE_ARGS="$CREATE_ARGS --force"
"$SCRIPT_DIR/create-directories.sh" $CREATE_ARGS || {
    log 'ERROR' 'Directory creation failed'
    exit 1
}

# ── Step 2: Install packages ───────────────────────────────────────────
if ! $SKIP_PACKAGES; then
    step 'Step 2: Install packages'
    INSTALL_ARGS="--inventory $INVENTORY"
    $DRY_RUN && INSTALL_ARGS="$INSTALL_ARGS --dry-run"
    "$SCRIPT_DIR/install-packages.sh" $INSTALL_ARGS || {
        log 'WARN' 'Package installation had errors (check output above)'
    }
else
    log 'INFO' 'Skipping package installation (--skip-packages)'
fi

# ── Step 3: Clone repositories ─────────────────────────────────────────
if ! $SKIP_REPOS; then
    step 'Step 3: Clone repositories'
    CLONE_ARGS="--inventory $INVENTORY"
    $DRY_RUN && CLONE_ARGS="$CLONE_ARGS --dry-run"
    "$SCRIPT_DIR/clone-repositories.sh" $CLONE_ARGS || {
        log 'WARN' 'Repository cloning had errors (check output above)'
    }
else
    log 'INFO' 'Skipping repository cloning (--skip-repos)'
fi

# ── Step 4: Verify ─────────────────────────────────────────────────────
step 'Step 4: Verify'
VERIFY_ARGS="--inventory $INVENTORY"
$DRY_RUN && VERIFY_ARGS="$VERIFY_ARGS --dry-run"
"$SCRIPT_DIR/verify.sh" $VERIFY_ARGS
VERIFY_EXIT=$?

step 'Bootstrap complete'
if $DRY_RUN; then
    log 'INFO' 'Dry-run finished. Review output above, then run without --dry-run to apply.'
else
    log 'INFO' "Bootstrap finished. Verify exit code: $VERIFY_EXIT"
fi

exit $VERIFY_EXIT