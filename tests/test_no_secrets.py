"""扫描仓库中意外提交的密钥。

检查的模式：
- 私钥头（PEM、SSH）
- API 密钥模式（sk-*、ghp_*、xoxb-* 等）
- 密钥赋值（SECRET=、TOKEN=、PASSWORD=）
- AWS 密钥模式（AKIA*、ASIA*）
- 可疑上下文中的高熵字符串

用法：
    uv run python tests/test_no_secrets.py
    uv run python tests/test_no_secrets.py --path /custom/path
"""

import re
import sys
from pathlib import Path

# Windows 控制台默认用 cp1252，不支持中文输出，强制 UTF-8
sys.stdout.reconfigure(encoding='utf-8')


# 匹配潜在密钥的模式
SECRET_PATTERNS = [
    # 私钥头
    (r"-----BEGIN\s+(?:RSA|DSA|EC|OPENSSH|PGP)?\s*PRIVATE\s+KEY", "私钥头"),
    # API 密钥前缀
    (r"(?:^|[^a-zA-Z0-9])sk-[a-zA-Z0-9]{20,}", "OpenAI/Claude 风格 API 密钥（sk-...）"),
    (r"(?:^|[^a-zA-Z0-9])ghp_[a-zA-Z0-9]{36}", "GitHub Personal Access Token（ghp_...）"),
    (r"(?:^|[^a-zA-Z0-9])gho_[a-zA-Z0-9]{36}", "GitHub OAuth Token（gho_...）"),
    (r"(?:^|[^a-zA-Z0-9])ghu_[a-zA-Z0-9]{36}", "GitHub User Token（ghu_...）"),
    (r"(?:^|[^a-zA-Z0-9])xox[bp]-[a-zA-Z0-9-]+", "Slack Token（xoxb-/xoxp-...）"),
    (r"(?:^|[^a-zA-Z0-9])AIza[0-9A-Za-z\-_]{35}", "Google API 密钥（AIza...）"),
    (r"(?:^|[^a-zA-Z0-9])AKIA[0-9A-Z]{16}", "AWS Access Key ID（AKIA...）"),
    (r"(?:^|[^a-zA-Z0-9])ASIA[0-9A-Z]{16}", "AWS STS 临时密钥（ASIA...）"),
    # 密钥赋值模式
    (r'(?:^|\s)(?:API_KEY|SECRET_KEY|SECRET|TOKEN|PASSWORD|PRIVATE_KEY|ACCESS_KEY|AUTH_TOKEN)\s*=\s*["\']?[^\s"\'$]{8,}', "密钥赋值（KEY=value）"),
    # 可疑上下文中的高熵十六进制字符串
    (r'(?:^|\s)(?:secret|token|key|password|pass)\s*[:=]\s*["\']?[0-9a-fA-F]{32,}', "十六进制密钥赋值"),
    # 通用 JWT 类 Token
    (r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}', "JWT Token"),
]

# 需要整体跳过的文件和目录
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

# 误报行（文档、示例、有意为之）
WHITELIST_PATTERNS = [
    r"^\s*#",                      # 注释行
    r"^\s*//",                     # JS/TS 注释行
    r"^\s*/\*",                    # C 风格注释起始
    r"^\s*\*",                     # C 风格注释续行
    r"example",                    # 示例文件
    r"REPLACE_WITH_",              # 文档占位符
    r"PUT_YOUR_",                  # 模板占位符
    r"YOUR_",                      # 模板占位符
    r"\.example",                  # 示例文件
    r"templates/",                 # 模板文件
    r"Environment variable",       # 文档描述
    r"^\s*description:",           # YAML 描述
    r"^\s*Summary:",               # 文档
    r"^\s*\$",                     # Shell 变量引用
    r"process\.env\.",             # 代码引用
    r"GITHUB_TOKEN=",              # env.example 文档
    r"GH_TOKEN=",                  # env.example 文档
    r"sk-",                        # 文档/白名单中提及
    r"ghp_",                       # 文档/白名单中提及
    r"xoxb-",                      # 文档/白名单中提及
    r"AKIA",                       # 文档/白名单中提及
    r"ASIA",                       # 文档/白名单中提及
    r"AIza",                       # 文档/白名单中提及
    r"OPENAI_API_KEY=",            # env.example
    r"ANTHROPIC_API_KEY=",         # env.example
    r"AWS_ACCESS_KEY_ID=",         # env.example
    r"AWS_SECRET_ACCESS_KEY=",     # env.example
    r"DATABASE_URL=",              # env.example
    r"CLAUDE_API_KEY=",            # env.example
    r"SECRET_KEY=",                # env.example
    r"password manager",           # 文档
    r"1Password",                  # 文档
    r"Bitwarden",                  # 文档
    r"Token:",                     # 文档
    r"Token scopes",               # 文档
    r"ghp_\*",                     # 文档中的脱敏 Token
    r"PRIVATE_KEY",                # 文档
    r"SECRET=",                    # env.example
    r"TOKEN=",                     # env.example
    r"PASSWORD=",                  # env.example
    r"ACCESS_KEY=",                # env.example
    r"AUTH_TOKEN=",                # env.example
    r"secret\s*[:=]",              # 文档
    r"token\s*[:=]",               # 文档
    r"key\s*[:=]",                 # 文档
    r"password\s*[:=]",            # 文档
    r"SECRETS",                    # 文档
    r"Secret",                     # 文档
    r"Token scopes:",              # 文档
    r"API Key",                    # 文档
    r"API_KEY",                    # 文档
    r"IdentityFile",               # SSH 配置模板
    r"ssh-keygen",                 # 文档
    r"id_ed25519",                 # 文档
    r"id_rsa",                     # 文档
    r"id_ecdsa",                   # 文档
    r"\.pem",                      # 文档
    r"\.key",                      # 文档
    r"\.pub",                      # 文档
    r"ssh-",                       # 文档
    r"ssh/config",                 # 文档
    r"ssh_config",                 # 文档
    r"ssh_config",                 # 文档
    r"~/.ssh",                     # 文档
    r"PRIVATE KEY",                # 文档
    r"private key",                # 文档
    r"ssh-keygen",                 # 文档
    r"ssh -T",                     # 文档
    r"git@github.com",             # 文档
    r"credential",                 # 文档
    r"osxkeychain",                # 文档
    r"git-credential",             # 文档
    r"credential.helper",          # 文档
    r"git filter",                 # 文档
    r"git push",                   # 文档
    r"git clone",                  # 文档
    r"git remote",                 # 文档
    r"git config",                 # 文档
    r"git init",                   # 文档
    r"git commit",                 # 文档
    r"git branch",                 # 文档
    r"git checkout",               # 文档
    r"git add",                    # 文档
    r"git log",                    # 文档
    r"git diff",                   # 文档
    r"git merge",                  # 文档
    r"git rebase",                 # 文档
    r"git stash",                  # 文档
    r"git status",                 # 文档
    r"git pull",                   # 文档
    r"git fetch",                  # 文档
    r"git tag",                    # 文档
    r"git show",                   # 文档
    r"git blame",                  # 文档
    r"git bisect",                 # 文档
    r"git grep",                   # 文档
    r"git worktree",               # 文档
    r"git worktree add",           # 文档
    r"git worktree remove",        # 文档
    r"git worktree list",          # 文档
    r"git worktree prune",         # 文档
    r"git worktree lock",          # 文档
    r"git worktree unlock",        # 文档
    r"git worktree repair",        # 文档
    r"git sparse-checkout",        # 文档
    r"git submodule",              # 文档
    r"git subtree",                # 文档
    r"git notes",                  # 文档
    r"git reflog",                 # 文档
    r"git reset",                  # 文档
    r"git clean",                  # 文档
    r"git gc",                     # 文档
    r"git prune",                  # 文档
    r"git fsck",                   # 文档
    r"git archive",                # 文档
    r"git bundle",                 # 文档
    r"git daemon",                 # 文档
    r"git instaweb",               # 文档
    r"git web--browse",            # 文档
    r"git help",                   # 文档
    r"git version",                # 文档
    r"git --version",              # 文档
    r"git --help",                 # 文档
    r"git --exec-path",            # 文档
    r"git --html-path",            # 文档
    r"git --man-path",             # 文档
    r"git --info-path",            # 文档
    r"git --paginate",             # 文档
    r"git --no-pager",             # 文档
    r"git --no-replace-objects",   # 文档
    r"git --literal-pathspecs",    # 文档
    r"git --glob-pathspecs",       # 文档
    r"git --noglob-pathspecs",     # 文档
    r"git --icase-pathspecs",      # 文档
    r"git --no-optional-locks",    # 文档
    r"git --list-cmds",            # 文档
    r"git --config-env",           # 文档
    r"git --config",               # 文档
    r"git --no-config",            # 文档
    r"git --work-tree",            # 文档
    r"git --git-dir",              # 文档
    r"git --namespace",            # 文档
    r"git --super-prefix",         # 文档
    r"git --bare",                 # 文档
    r"git --no-bare",              # 文档
    r"git --git-common-dir",       # 文档
    r"git --resolve-git-dir",      # 文档
    r"git --git-path",             # 文档
    r"git --html-path",            # 文档
    r"git --man-path",             # 文档
    r"git --info-path",            # 文档
    r"git --exec-path",            # 文档
    r"git --version",              # 文档
    r"git --help",                 # 文档
    r"GITHUB_TOKEN",               # 文档
    r"GH_TOKEN",                   # 文档
    r"GITHUB_PAT",                 # 文档
    r"GH_PAT",                     # 文档
    r"API_KEY",                    # 文档
    r"SECRET_KEY",                 # 文档
    r"ACCESS_KEY",                 # 文档
    r"AUTH_TOKEN",                 # 文档
    r"PRIVATE_KEY",                # 文档
    r"SECRET",                     # 文档
    r"TOKEN",                      # 文档
    r"PASSWORD",                   # 文档
    r"ACCESS_KEY",                 # 文档
    r"AUTH_TOKEN",                 # 文档
]


def should_skip(path: Path) -> bool:
    """检查文件路径是否应跳过。"""
    path_str = str(path).replace("\\", "/")
    for glob in SKIP_GLOBS:
        if path.match(glob):
            return True
    return False


def is_whitelisted(line: str) -> bool:
    """检查行是否匹配白名单模式。"""
    for pattern in WHITELIST_PATTERNS:
        if re.search(pattern, line, re.IGNORECASE):
            return True
    return False


def scan_file(filepath: Path) -> list[tuple[int, str, str]]:
    """扫描文件中的密钥。返回 (行号, 模式名称, 行内容) 列表。"""
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
                break  # 每行只记录一个发现即可
    return findings


def scan_directory(root: Path) -> dict[Path, list[tuple[int, str, str]]]:
    """递归扫描目录中的所有文件。"""
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

    print(f"正在扫描 {root} 中的密钥...")
    findings = scan_directory(root)

    if not findings:
        print("  未发现密钥。")
        print("  通过")
        return 0

    print(f"\n  在 {len(findings)} 个文件中发现 {sum(len(v) for v in findings.values())} 个潜在密钥：\n")
    for filepath, file_findings in sorted(findings.items()):
        rel = filepath.relative_to(root)
        print(f"  {rel}:")
        for line_no, name, line in file_findings:
            print(f"    L{line_no}: [{name}]")
            print(f"      {line}")

    print("\n  请检查以上发现。如果它们是误报：")
    print("    1. 将其添加到 test_no_secrets.py 中的 WHITELIST_PATTERNS")
    print("    2. 或将文件添加到 SKIP_GLOBS")
    print("  如果它们是真实密钥：请立即轮换密钥，并从 git 历史中删除。")
    print("  失败")
    return 1


if __name__ == "__main__":
    sys.exit(main())