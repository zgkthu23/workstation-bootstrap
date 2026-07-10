"""SCRIPT-METADATA
name: scan-secrets
description: Scans repository text for likely accidentally committed credentials without external dependencies.
platform: windows, ubuntu, macos
inputs: --path PATH, --output-format text|json, --help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] finding records
exit_codes: 0=success, 1=finding-or-scan-error, 2=skipped-or-not-applicable
END-SCRIPT-METADATA

The scanner reports candidate locations for human review. It never modifies the
repository and intentionally uses placeholders in its own pattern definitions.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")


@dataclass
class Reporter:
    output_format: str
    component: str = "scan-secrets"

    def emit(self, level: str, message: str) -> None:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        if self.output_format == "json":
            line = json.dumps(
                {
                    "schema_version": 1,
                    "timestamp": timestamp,
                    "level": level,
                    "component": self.component,
                    "message": message,
                },
                ensure_ascii=False,
                separators=(",", ":"),
            )
        else:
            line = f"[{level}] {timestamp} [{self.component}] {message}"
        print(line, file=sys.stderr if level == "ERROR" else sys.stdout)


class ContractArgumentParser(argparse.ArgumentParser):
    """Normalize argparse usage errors to the repository's exit-code contract."""

    def error(self, message: str) -> None:
        output_format = "text"
        if "--output-format" in sys.argv:
            index = sys.argv.index("--output-format")
            if index + 1 < len(sys.argv) and sys.argv[index + 1] == "json":
                output_format = "json"
        Reporter(output_format).emit("ERROR", f"Argument error: {message}")
        self.exit(1)


SECRET_PATTERNS = [
    (r"-----BEGIN\s+(?:RSA|DSA|EC|OPENSSH|PGP)?\s*PRIVATE\s+KEY", "private-key-header"),
    (r"(?:^|[^a-zA-Z0-9])sk-[a-zA-Z0-9]{20,}", "api-key-sk"),
    (r"(?:^|[^a-zA-Z0-9])gh[opuxs]_[a-zA-Z0-9]{36,}", "github-token"),
    (r"(?:^|[^a-zA-Z0-9])xox[bp]-[a-zA-Z0-9-]+", "slack-token"),
    (r"(?:^|[^a-zA-Z0-9])AIza[0-9A-Za-z_-]{35}", "google-api-key"),
    (r"(?:^|[^a-zA-Z0-9])(?:AKIA|ASIA)[0-9A-Z]{16}", "aws-access-key"),
    (
        r'(?:^|\s)(?:API_KEY|SECRET_KEY|SECRET|TOKEN|PASSWORD|PRIVATE_KEY|ACCESS_KEY|AUTH_TOKEN)\s*=\s*["\']?[^\s"\'$]{8,}',
        "secret-assignment",
    ),
    (
        r'(?:^|\s)(?:secret|token|key|password|pass)\s*[:=]\s*["\']?[0-9a-fA-F]{32,}',
        "hex-secret-assignment",
    ),
    (r"eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}", "jwt-token"),
]

SKIP_PARTS = {
    ".git",
    ".venv",
    "venv",
    "__pycache__",
    "node_modules",
    "dist",
    "build",
}
SKIP_NAMES = {".gitignore", "LICENSE"}
SKIP_SUFFIXES = {
    ".pyc",
    ".pyo",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".ico",
    ".pdf",
    ".zip",
    ".7z",
    ".gz",
    ".lock",
    ".sum",
}

# Descriptions, templates, regex definitions, and redacted examples are expected.
WHITELIST_PATTERNS = [
    r"^\s*(?:#|//|/\*|\*)",
    r"example|template|placeholder|REPLACE_WITH_|PUT_YOUR_|YOUR_",
    r"SECRET_PATTERNS|WHITELIST_PATTERNS",
    r"r[\"\'].*(?:sk-|ghp_|xoxb-|AKIA|ASIA|AIza|PRIVATE\\s\+KEY)",
    r"(?:GITHUB_TOKEN|GH_TOKEN|OPENAI_API_KEY|ANTHROPIC_API_KEY|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|DATABASE_URL|SECRET|TOKEN|PASSWORD)=",
    r"password manager|1Password|Bitwarden|Token scopes|API Key",
    r"IdentityFile|ssh-keygen|id_(?:ed25519|rsa|ecdsa)|~/.ssh|git@github\.com",
    r"private key|PRIVATE KEY|credential",
]


def should_skip(relative: Path) -> bool:
    return (
        bool(SKIP_PARTS.intersection(relative.parts))
        or relative.name in SKIP_NAMES
        or relative.suffix.lower() in SKIP_SUFFIXES
        or relative.as_posix() == "secrets/README.md"
    )


def is_whitelisted(line: str) -> bool:
    return any(re.search(pattern, line, re.IGNORECASE) for pattern in WHITELIST_PATTERNS)


def scan_file(path: Path) -> tuple[list[tuple[int, str]], bool]:
    findings: list[tuple[int, str]] = []
    try:
        content = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return findings, False
    for line_number, line in enumerate(content.splitlines(), 1):
        if is_whitelisted(line):
            continue
        for pattern, name in SECRET_PATTERNS:
            if re.search(pattern, line):
                findings.append((line_number, name))
                break
    return findings, True


def parse_args() -> argparse.Namespace:
    parser = ContractArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument(
        "--path",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="directory to scan (default: project root)",
    )
    parser.add_argument(
        "--output-format",
        choices=("text", "json"),
        default="text",
        help="emit text records or newline-delimited JSON records",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.path.expanduser().resolve()
    reporter = Reporter(args.output_format)
    if not root.is_dir():
        reporter.emit("ERROR", f"Scan path is not a directory: {root}")
        return 1

    reporter.emit("INFO", f"Scanning for likely secrets: {root}")
    findings: dict[Path, list[tuple[int, str]]] = {}
    unreadable = 0
    scanned = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if should_skip(relative):
            continue
        file_findings, readable = scan_file(path)
        if not readable:
            unreadable += 1
            continue
        scanned += 1
        if file_findings:
            findings[relative] = file_findings

    if findings:
        total = sum(len(items) for items in findings.values())
        for relative, items in sorted(findings.items(), key=lambda item: item[0].as_posix()):
            for line_number, pattern_name in items:
                reporter.emit("ERROR", f"Potential secret: path={relative.as_posix()}, line={line_number}, pattern={pattern_name}.")
        reporter.emit("ERROR", f"Secret scan failed: findings={total}, files={len(findings)}, unreadable={unreadable}.")
        return 1

    if unreadable:
        reporter.emit("WARN", f"Secret scan skipped unreadable files: count={unreadable}.")
    reporter.emit("SUCCESS", f"Secret scan passed: files_scanned={scanned}, findings=0.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
