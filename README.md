# workstation-bootstrap

Personal workstation infrastructure-as-code — declaratively define and rebuild
dev machine layout, packages, dotfiles, and Git project layout across Windows,
Ubuntu, and macOS.

## What this manages

- Directory structure (workspace, data, cloud, scratch roots)
- Development packages and toolchains
- Dotfiles and shell configuration
- Git project layout and clone targets
- Environment variable templates

## What this does NOT manage

- Personal files, documents, photos, media
- Cloud drive contents (OneDrive, Google Drive, iCloud)
- Large datasets and model weights (restic / separate backup)
- Application data, browser profiles, chat histories
- Secrets, tokens, SSH private keys, API keys
- Operating system installation or disk partitioning

## Supported hosts

| Host | OS | Role |
|------|----|------|
| windows-main | Windows 11 | Primary dev desktop |
| ubuntu-main | Ubuntu LTS | Linux dev / server |
| macos-main | macOS | Mobile / secondary dev |

## Quick start

```powershell
# Windows (PowerShell 7+)
.\scripts\windows\bootstrap.ps1 -DryRun
.\scripts\windows\bootstrap.ps1 -DryRun -WhatIf  # alias
```

```bash
# Ubuntu / macOS
./scripts/unix/bootstrap.sh --dry-run
```

## Dry-run examples

```powershell
# List what packages would be installed
.\scripts\windows\install-packages.ps1 -DryRun -List

# Show what directories would be created
.\scripts\windows\create-directories.ps1 -DryRun

# Show what repos would be cloned
.\scripts\windows\clone-repositories.ps1 -DryRun

# Run full verification
.\scripts\windows\verify.ps1
```

```bash
# Unix equivalents
./scripts/unix/install-packages.sh --dry-run --list
./scripts/unix/create-directories.sh --dry-run
./scripts/unix/clone-repositories.sh --dry-run
./scripts/unix/verify.sh
```

## Recovery: new machine from scratch

1. Install OS
2. Install Git
3. Configure GitHub SSH or HTTPS auth
4. `git clone git@github.com:zgkthu23/workstation-bootstrap.git`
5. Edit your machine's inventory file in `inventory/`
6. Run dry-run: `./scripts/unix/bootstrap.sh --dry-run`
7. Review output, confirm
8. Run: `./scripts/unix/bootstrap.sh`
9. Restore secrets from password manager
10. Restore cloud drive contents
11. Restore large data / restic snapshots
12. Run `./scripts/unix/verify.sh`

See `docs/recovery.md` for detailed steps.

## Adding a new machine

1. Copy an existing inventory file from `inventory/`
2. Edit paths, hostname, enabled feature groups
3. Add any machine-specific packages to the appropriate manifest
4. Run dry-run → verify → apply

See `docs/adding-a-machine.md`.

## Security

**This repo must remain private.** It contains host layout, installed software
inventory, and project URLs — information useful to an attacker.

Never commit:
- API keys, tokens, passwords
- SSH private keys
- `.env` files with real values
- Browser or shell history
- Cloud drive access tokens

See `docs/security.md` and `secrets/README.md`.

## Status

Phase 1: Framework, inventory, dry-run, verify — **done**
Phase 2: Actual package installation — planned
Phase 3: Dotfile deployment (chezmoi) — planned
Phase 4: Secrets management integration — planned