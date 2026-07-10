# Security

## Repository classification

This repository should be **private**. It contains:
- Host layout and installed software inventory
- Project URLs and organization
- Development environment configuration

An attacker with access to this repo could:
- Map your development infrastructure
- Identify installed software versions for targeted exploits
- Discover internal project URLs and repository names

## What is allowed in this repo

| Category | Allowed | Examples |
|----------|---------|----------|
| Configuration templates | ✅ | `.env.example`, `config.yaml.example` |
| Environment variable names | ✅ | `DATABASE_URL`, `API_KEY` (names only) |
| Password manager entry names | ✅ | `"GitHub PAT"`, `"AWS Access Key"` |
| Public keys | ✅ | `id_ed25519.pub`, `*.pub` |
| Example files | ✅ | Files with `.example` extension |
| Package lists | ✅ | `apt-packages.txt`, `Brewfile` |
| Directory structure | ✅ | Paths, layout definitions |

## What is NEVER allowed

| Category | Examples |
|----------|----------|
| API keys | `sk-...`, `ghp_...`, `xoxb-...` |
| Private keys | `id_rsa`, `*.pem`, `*.key` |
| Passwords | Database passwords, service passwords |
| Tokens | GitHub PAT, OpenAI keys, Claude keys |
| Cookies | Browser cookies, session tokens |
| Real `.env` files | `.env`, `.env.local`, `.env.production` |
| Company credentials | Work passwords, VPN configs with secrets |
| Browser data | Chrome/Firefox profiles, history |
| Shell history | `.bash_history`, `.zsh_history` |
| SSH config with hosts | Real hostnames and IPs in `~/.ssh/config` |

## Pre-commit protection

The `tests/test_no_secrets.py` scan runs on every commit (via GitHub Actions)
and can be run locally:

```bash
uv run python tests/test_no_secrets.py
```

It scans for:
- Private key headers (`-----BEGIN.*PRIVATE KEY-----`)
- API key patterns (`sk-*`, `ghp_*`, `xoxb-*`, etc.)
- Secret assignments (`SECRET=`, `TOKEN=`, `PASSWORD=`)
- AWS key patterns (`AKIA*`, `ASIA*`)
- High-entropy base64 strings in suspicious contexts

## If you accidentally commit a secret

1. **Rotate the secret immediately** — revoke and regenerate
2. Run `git filter-branch` or `git filter-repo` to purge from history
3. Force push
4. Verify with `test_no_secrets.py`

## Password manager integration

All secrets should live in a password manager (1Password, Bitwarden, etc.).
This repo references them by entry name only.

Example: `templates/env.example` contains:
```
# Copy to .env and fill from password manager
DATABASE_URL=    # Bitwarden: "project-db-url"
API_KEY=         # 1Password: "project-api-key"
```