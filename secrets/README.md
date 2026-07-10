# Secrets

This directory is intentionally empty except for this README.

## What belongs here

Nothing. This directory is a placeholder to remind you that secrets
are managed OUTSIDE this repository.

## How secrets are managed

All secrets (API keys, tokens, passwords, SSH private keys) are stored in
a password manager (1Password, Bitwarden, etc.) and referenced by entry name
in templates and scripts.

## Recovery

When setting up a new machine:
1. Install your password manager
2. Sign in and sync your vault
3. Use the templates in `../templates/` to create real config files
4. Never commit those real files to this repo

## What this repo references

- `templates/env.example` — lists environment variable names
- `templates/gitconfig.example` — git config without real email
- `templates/ssh-config.example` — SSH config without real hostnames

## Pre-commit protection

The `tests/test_no_secrets.py` scan runs on every commit to catch
accidentally committed secrets. See `docs/security.md` for what to do
if you accidentally commit a secret.