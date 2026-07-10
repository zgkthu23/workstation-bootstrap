# Bootstrap process

## Overview

Bootstrap is the orchestrator that runs all setup scripts in order.

## Order of operations

1. **Pre-flight checks** — OS detected, Git installed, inventory found
2. **Create directories** — Logical root directories and workspace layout
3. **Install packages** — OS packages and development toolchains
4. **Clone repositories** — Git projects from `projects/repos.yaml`
5. **Verify** — Post-bootstrap validation

## Dry-run mode

All scripts support dry-run. In dry-run mode:
- No filesystem changes
- No package installation
- No git clone operations
- Output is a human-readable plan of what *would* happen

## Idempotency

Scripts are designed to be safe to run multiple times:
- Directory creation: `mkdir -p` (no-op if exists)
- Package install: skip if already installed
- Git clone: skip if directory exists and is a git repo
- Dotfiles: skip if target exists (unless `--force`)

## Error handling

- Single package failure does not stop the entire run
- Single repo clone failure does not stop other clones
- Errors are collected and reported at the end
- Exit code reflects overall success/failure

## Post-bootstrap

After bootstrap completes:
1. Run `verify` script
2. Restore secrets from password manager
3. Restore cloud drive contents
4. Restore large data from backup
5. Review and install any manual-only software