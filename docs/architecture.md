# Architecture

## Control plane vs data plane

```
┌─────────────────────────────────────────────────┐
│                CONTROL PLANE                     │
│        (this repo: workstation-bootstrap)        │
│                                                  │
│  inventory/   manifests/   scripts/   dotfiles/  │
│  ─────────   ──────────   ────────   ─────────  │
│  host defs    feature       bootstrap  config    │
│               groups        automation templates │
└─────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────────────────┐
│    DATA PLANE   │  │       DATA PLANE             │
│   (workspace)   │  │   (cloud / data / scratch)   │
│                 │  │                              │
│  repos/         │  │  OneDrive, Google Drive,     │
│  artifacts/     │  │  iCloud documents            │
│  shared/        │  │                              │
│                 │  │  Large datasets, models      │
│  Under Git for  │  │  Backups (restic)            │
│  each project   │  │                              │
└─────────────────┘  └─────────────────────────────┘
```

This repo is the **control plane**. It describes what should exist.
The **data plane** is the actual files on disk — repos, documents, datasets.
The control plane never contains data plane contents.

## Logical directory model

All hosts share the same logical model, mapped to host-specific absolute paths
via inventory files.

| Logical root | Purpose | Windows default | Unix default |
|-------------|---------|-----------------|--------------|
| `WORKSPACE_ROOT` | Git repos, dev projects | `D:\workspace` | `$HOME/workspace` |
| `DATA_ROOT` | Large data, models, datasets | `D:\data` | `$HOME/data` |
| `CLOUD_ROOT` | Cloud drive documents | Inventory-defined | `$HOME/cloud` |
| `SCRATCH_ROOT` | Temporary, disposable | `D:\scratch` | `$HOME/scratch` |

## Workspace layout

```
WORKSPACE_ROOT/
├── repos/           # Git clones organized by category
│   ├── work/        # Work projects
│   ├── personal/    # Personal projects
│   ├── research/    # Research / academic
│   ├── tools/       # Third-party tools, utilities
│   └── experiments/ # Throwaway prototypes
├── artifacts/       # Built outputs, not under version control
│   ├── releases/    # Binary releases
│   ├── reports/     # Generated reports
│   └── exports/     # Data exports
└── shared/          # Shared resources across projects
    ├── templates/   # Project templates
    └── scripts/     # Shared utility scripts
```

## Host inventory

Each host has a YAML file in `inventory/` defining:
- Identity (hostname, OS)
- Physical path mappings
- Enabled feature groups
- Git user info templates

No secrets in inventory files.

## Manifests

`manifests/` defines *what* gets installed per feature group:
- `common.yaml` — tools every machine needs
- `windows.yaml` / `ubuntu.yaml` / `macos.yaml` — OS-specific additions

## Feature groups

| Group | What it includes |
|-------|-----------------|
| `common` | Git, shell, editor, basic CLI tools |
| `c-development` | GCC/Clang, CMake, make, debugger |
| `python-development` | Python, uv, common libraries |
| `node-development` | Node.js, npm, pnpm |
| `docker` | Docker Engine, docker-compose |
| `office` | Document tools, PDF readers |
| `research` | LaTeX, Jupyter, scientific computing |
| `optional` | Nice-to-have utilities |

## Dotfiles strategy

See dedicated section below.

## Dotfiles: strategy comparison

### Options evaluated

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **chezmoi** | Templating, diff, dry-run, cross-platform, secret management | One extra binary dependency | ✅ Recommended |
| **GNU Stow** | Simple, symlink-based, no extra deps | No templating, manual per-machine | OK for Unix-only |
| **Symlinks** | Zero deps, transparent | No templating, fragile on Windows, manual | Minimalist |
| **Direct copy** | Dead simple | No version tracking, drift risk | ❌ Not recommended |

### Recommendation: chezmoi

- Single binary, no runtime deps
- Go templates for per-machine customization
- Built-in diff and dry-run
- `chezmoi apply` is idempotent
- Password manager integration (1Password, Bitwarden, etc.)
- Works on Windows, Linux, macOS

Phase 1: Integration interface defined, example dotfiles created.
Phase 3: Full chezmoi configuration.

## Script design

Scripts follow a layered architecture:

```
bootstrap.{ps1,sh}          # Orchestrator
    ├── create-directories  # Directory structure
    ├── install-packages    # Package managers
    ├── clone-repositories  # Git clones
    └── verify              # Post-bootstrap checks
```

All scripts:
- Strict error handling (`set -euo pipefail` / `$ErrorActionPreference = 'Stop'`)
- `--dry-run` / `-DryRun` flag
- Idempotent (safe to re-run)
- Structured logging with timestamps
- Human-readable action summaries
- Non-zero exit on failure