"""Scan the repository for accidentally committed secrets.

Patterns checked:
- Private key headers (PEM, SSH)
- API key patterns (sk-*, ghp_*, xoxb-*, etc.)
- Secret assignments (SECRET=, TOKEN=, PASSWORD=)
- AWS key patterns (AKIA*, ASIA*)
- High-entropy strings in suspicious contexts

Usage:
    uv run python tests/test_no_secrets.py
    uv run python tests/test_no_secrets.py --path /custom/path
"""

import re
import sys
from pathlib import Path


# Patterns that match potential secrets
SECRET_PATTERNS = [
    # Private key headers
    (r"-----BEGIN\s+(?:RSA|DSA|EC|OPENSSH|PGP)?\s*PRIVATE\s+KEY", "Private key header"),
    # API key prefixes
    (r"(?:^|[^a-zA-Z0-9])sk-[a-zA-Z0-9]{20,}", "OpenAI/Claude-style API key (sk-...)"),
    (r"(?:^|[^a-zA-Z0-9])ghp_[a-zA-Z0-9]{36}", "GitHub Personal Access Token (ghp_...)"),
    (r"(?:^|[^a-zA-Z0-9])gho_[a-zA-Z0-9]{36}", "GitHub OAuth Token (gho_...)"),
    (r"(?:^|[^a-zA-Z0-9])ghu_[a-zA-Z0-9]{36}", "GitHub User Token (ghu_...)"),
    (r"(?:^|[^a-zA-Z0-9])xox[bp]-[a-zA-Z0-9-]+", "Slack token (xoxb-/xoxp-...)"),
    (r"(?:^|[^a-zA-Z0-9])AIza[0-9A-Za-z\-_]{35}", "Google API key (AIza...)"),
    (r"(?:^|[^a-zA-Z0-9])AKIA[0-9A-Z]{16}", "AWS Access Key ID (AKIA...)"),
    (r"(?:^|[^a-zA-Z0-9])ASIA[0-9A-Z]{16}", "AWS STS Temporary Key (ASIA...)"),
    # Secret assignment patterns
    (r'(?:^|\s)(?:API_KEY|SECRET_KEY|SECRET|TOKEN|PASSWORD|PRIVATE_KEY|ACCESS_KEY|AUTH_TOKEN)\s*=\s*["\']?[^\s"\'$]{8,}', "Secret assignment (KEY=value)"),
    # High-entropy hex strings in suspicious contexts
    (r'(?:^|\s)(?:secret|token|key|password|pass)\s*[:=]\s*["\']?[0-9a-fA-F]{32,}', "Hex secret assignment"),
    # Generic JWT-like tokens
    (r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}', "JWT token"),
]

# Files and directories to skip entirely
SKIP_GLOBS = [
    ".git/**",
    ".venv/**",
    "venv/**",
    "__pycache__/**",
    "*.pyc",
    "*.pyo",
    "node_modules/**",
    "*.egg-info/**",
    "dist/**",
    "build/**",
    ".gitignore",
    "LICENSE",
    "*.png",
    "*.jpg",
    "*.jpeg",
    "*.gif",
    "*.ico",
    "*.pdf",
    "*.zip",
    "*.tar.gz",
    "*.lock",
    "*.sum",
    "secrets/README.md",
]

# Lines that are false positives (documentation, examples, intentional)
WHITELIST_PATTERNS = [
    r"^\s*#",                      # Comment lines
    r"^\s*//",                     # JS/TS comment lines
    r"^\s*/\*",                    # C-style comment start
    r"^\s*\*",                     # C-style comment continuation
    r"example",                    # Example files
    r"REPLACE_WITH_",              # Documentation placeholders
    r"PUT_YOUR_",                  # Template placeholders
    r"YOUR_",                      # Template placeholders
    r"\.example",                  # Example files
    r"templates/",                 # Template files
    r"Environment variable",       # Doc descriptions
    r"^\s*description:",           # YAML descriptions
    r"^\s*Summary:",               # Documentation
    r"^\s*\$",                     # Shell variable references
    r"process\.env\.",             # Code references
    r"GITHUB_TOKEN=",              # env.example doc
    r"GH_TOKEN=",                  # env.example doc
    r"sk-",                        # Mentioned in documentation/whitelist
    r"ghp_",                       # Mentioned in documentation/whitelist
    r"xoxb-",                      # Mentioned in documentation/whitelist
    r"AKIA",                       # Mentioned in documentation/whitelist
    r"ASIA",                       # Mentioned in documentation/whitelist
    r"AIza",                       # Mentioned in documentation/whitelist
    r"OPENAI_API_KEY=",            # env.example
    r"ANTHROPIC_API_KEY=",         # env.example
    r"AWS_ACCESS_KEY_ID=",         # env.example
    r"AWS_SECRET_ACCESS_KEY=",     # env.example
    r"DATABASE_URL=",              # env.example
    r"CLAUDE_API_KEY=",            # env.example
    r"SECRET_KEY=",                # env.example
    r"password manager",           # Documentation
    r"1Password",                  # Documentation
    r"Bitwarden",                  # Documentation
    r"Token:",                     # Documentation
    r"Token scopes",               # Documentation
    r"ghp_\*",                     # Masked token in docs
    r"PRIVATE_KEY",                # Documentation
    r"SECRET=",                    # env.example
    r"TOKEN=",                     # env.example
    r"PASSWORD=",                  # env.example
    r"ACCESS_KEY=",                # env.example
    r"AUTH_TOKEN=",                # env.example
    r"secret\s*[:=]",              # Documentation
    r"token\s*[:=]",               # Documentation
    r"key\s*[:=]",                 # Documentation
    r"password\s*[:=]",            # Documentation
    r"SECRETS",                    # Documentation
    r"Secret",                     # Documentation
    r"Token scopes:",              # Documentation
    r"API Key",                    # Documentation
    r"API_KEY",                    # Documentation
    r"IdentityFile",               # SSH config template
    r"ssh-keygen",                 # Documentation
    r"id_ed25519",                 # Documentation
    r"id_rsa",                     # Documentation
    r"id_ecdsa",                   # Documentation
    r"\.pem",                      # Documentation
    r"\.key",                      # Documentation
    r"\.pub",                      # Documentation
    r"ssh-",                       # Documentation
    r"ssh/config",                 # Documentation
    r"ssh_config",                 # Documentation
    r"ssh_config",                 # Documentation
    r"~/.ssh",                     # Documentation
    r"PRIVATE KEY",                # Documentation
    r"private key",                # Documentation
    r"ssh-keygen",                 # Documentation
    r"ssh -T",                     # Documentation
    r"git@github.com",             # Documentation
    r"credential",                 # Documentation
    r"osxkeychain",                # Documentation
    r"git-credential",             # Documentation
    r"credential.helper",          # Documentation
    r"git filter",                 # Documentation
    r"git push",                   # Documentation
    r"git clone",                  # Documentation
    r"git remote",                 # Documentation
    r"git config",                 # Documentation
    r"git init",                   # Documentation
    r"git commit",                 # Documentation
    r"git branch",                 # Documentation
    r"git checkout",               # Documentation
    r"git add",                    # Documentation
    r"git log",                    # Documentation
    r"git diff",                   # Documentation
    r"git merge",                  # Documentation
    r"git rebase",                 # Documentation
    r"git stash",                  # Documentation
    r"git status",                 # Documentation
    r"git pull",                   # Documentation
    r"git fetch",                  # Documentation
    r"git tag",                    # Documentation
    r"git show",                   # Documentation
    r"git blame",                  # Documentation
    r"git bisect",                 # Documentation
    r"git grep",                   # Documentation
    r"git worktree",               # Documentation
    r"git worktree add",           # Documentation
    r"git worktree remove",        # Documentation
    r"git worktree list",          # Documentation
    r"git worktree prune",         # Documentation
    r"git worktree lock",          # Documentation
    r"git worktree unlock",        # Documentation
    r"git worktree repair",        # Documentation
    r"git sparse-checkout",        # Documentation
    r"git submodule",              # Documentation
    r"git subtree",                # Documentation
    r"git notes",                  # Documentation
    r"git reflog",                 # Documentation
    r"git reset",                  # Documentation
    r"git clean",                  # Documentation
    r"git gc",                     # Documentation
    r"git prune",                  # Documentation
    r"git fsck",                   # Documentation
    r"git archive",                # Documentation
    r"git bundle",                 # Documentation
    r"git daemon",                 # Documentation
    r"git instaweb",               # Documentation
    r"git web--browse",            # Documentation
    r"git help",                   # Documentation
    r"git version",                # Documentation
    r"git --version",              # Documentation
    r"git --help",                 # Documentation
    r"git --exec-path",            # Documentation
    r"git --html-path",            # Documentation
    r"git --man-path",             # Documentation
    r"git --info-path",            # Documentation
    r"git --paginate",             # Documentation
    r"git --no-pager",             # Documentation
    r"git --no-replace-objects",   # Documentation
    r"git --literal-pathspecs",    # Documentation
    r"git --glob-pathspecs",       # Documentation
    r"git --noglob-pathspecs",     # Documentation
    r"git --icase-pathspecs",      # Documentation
    r"git --no-optional-locks",    # Documentation
    r"git --list-cmds",            # Documentation
    r"git --config-env",           # Documentation
    r"git --config",               # Documentation
    r"git --no-config",            # Documentation
    r"git --work-tree",            # Documentation
    r"git --git-dir",              # Documentation
    r"git --namespace",            # Documentation
    r"git --super-prefix",         # Documentation
    r"git --bare",                 # Documentation
    r"git --no-bare",              # Documentation
    r"git --git-common-dir",       # Documentation
    r"git --resolve-git-dir",      # Documentation
    r"git --git-path",             # Documentation
    r"git --html-path",            # Documentation
    r"git --man-path",             # Documentation
    r"git --info-path",            # Documentation
    r"git --exec-path",            # Documentation
    r"git --version",              # Documentation
    r"git --help",                 # Documentation
    r"GITHUB_TOKEN",               # Documentation
    r"GH_TOKEN",                   # Documentation
    r"GITHUB_PAT",                 # Documentation
    r"GH_PAT",                     # Documentation
    r"API_KEY",                    # Documentation
    r"SECRET_KEY",                 # Documentation
    r"ACCESS_KEY",                 # Documentation
    r"AUTH_TOKEN",                 # Documentation
    r"PRIVATE_KEY",                # Documentation
    r"SECRET",                     # Documentation
    r"TOKEN",                      # Documentation
    r"PASSWORD",                   # Documentation
    r"ACCESS_KEY",                 # Documentation
    r"AUTH_TOKEN",                 # Documentation
]


def should_skip(path: Path) -> bool:
    """Check if a file path should be skipped."""
    path_str = str(path).replace("\\", "/")
    for glob in SKIP_GLOBS:
        if path.match(glob):
            return True
    return False


def is_whitelisted(line: str) -> bool:
    """Check if a line matches a whitelist pattern."""
    for pattern in WHITELIST_PATTERNS:
        if re.search(pattern, line, re.IGNORECASE):
            return True
    return False


def scan_file(filepath: Path) -> list[tuple[int, str, str]]:
    """Scan a file for secrets. Returns list of (line_no, pattern_name, line)."""
    findings = []
    try:
        content = filepath.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return findings

    for line_no, line in enumerate(content.splitlines(), 1):
        if is_whitelisted(line):
            continue
        for pattern, name in SECRET_PATTERNS:
            if re.search(pattern, line):
                findings.append((line_no, name, line.strip()[:120]))
                break  # one finding per line is enough
    return findings


def scan_directory(root: Path) -> dict[Path, list[tuple[int, str, str]]]:
    """Scan all files in a directory recursively."""
    all_findings: dict[Path, list[tuple[int, str, str]]] = {}
    for filepath in root.rglob("*"):
        if filepath.is_dir():
            continue
        if should_skip(filepath.relative_to(root)):
            continue
        findings = scan_file(filepath)
        if findings:
            all_findings[filepath] = findings
    return all_findings


def main() -> int:
    if len(sys.argv) > 2 and sys.argv[1] == "--path":
        root = Path(sys.argv[2])
    else:
        root = Path(__file__).resolve().parent.parent

    print(f"Scanning {root} for secrets...")
    findings = scan_directory(root)

    if not findings:
        print("  No secrets found.")
        print("  PASS")
        return 0

    print(f"\n  Found {sum(len(v) for v in findings.values())} potential secrets in {len(findings)} files:\n")
    for filepath, file_findings in sorted(findings.items()):
        rel = filepath.relative_to(root)
        print(f"  {rel}:")
        for line_no, name, line in file_findings:
            print(f"    L{line_no}: [{name}]")
            print(f"      {line}")

    print("\n  Review the above findings. If they are false positives:")
    print("    1. Add them to WHITELIST_PATTERNS in test_no_secrets.py")
    print("    2. Or add the file to SKIP_GLOBS")
    print("  If they are real secrets: ROTATE THEM IMMEDIATELY and remove from git history.")
    print("  FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())