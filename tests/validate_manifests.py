"""SCRIPT-METADATA
name: validate-project
description: Validates repository data, workflow paths, script catalog completeness, metadata headers, and Agent entry files.
platform: windows, ubuntu, macos
inputs: --root PATH, --output-format text|json, --help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: 0=success, 1=validation-error, 2=skipped-or-not-applicable
END-SCRIPT-METADATA

Dependency-free project contract validator. It intentionally validates only the
YAML subset used by this repository and does not claim to be a general parser.
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
    component: str = "validate-project"

    def emit(self, level: str, message: str, component: str | None = None) -> None:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        target = component or self.component
        if self.output_format == "json":
            line = json.dumps(
                {
                    "schema_version": 1,
                    "timestamp": timestamp,
                    "level": level,
                    "component": target,
                    "message": message,
                },
                ensure_ascii=False,
                separators=(",", ":"),
            )
        else:
            line = f"[{level}] {timestamp} [{target}] {message}"
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


def scalar_keys(path: Path) -> set[str]:
    """Return YAML-looking keys without importing a third-party parser."""
    keys: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        match = re.match(r"^\s*(?:-\s+)?([A-Za-z_][\w-]*):", line)
        if match:
            keys.add(match.group(1))
    return keys


def parse_bootstrap_steps(content: str) -> list[dict[str, str]]:
    steps: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    active = False
    for line in content.splitlines():
        if line == "bootstrap_steps:":
            active = True
            continue
        if active and line and not line[0].isspace():
            break
        if not active:
            continue
        match = re.match(r"^  - id:\s*(.+?)\s*$", line)
        if match:
            if current:
                steps.append(current)
            current = {"id": match.group(1).strip('"')}
            continue
        match = re.match(
            r"^    (order|windows|unix|forwards|skip_option|failure_policy):\s*(.*?)\s*$",
            line,
        )
        if current is not None and match:
            current[match.group(1)] = match.group(2).strip('"')
    if current:
        steps.append(current)
    return steps


def parse_catalog_paths(content: str, section: str = "scripts") -> set[str]:
    paths: set[str] = set()
    active = False
    for line in content.splitlines():
        if line == f"{section}:":
            active = True
            continue
        if active and line and not line[0].isspace():
            break
        if active:
            match = re.match(r"^    path:\s*(.+?)\s*$", line)
            if match:
                paths.add(match.group(1).strip('"').replace("\\", "/"))
    return paths


def parse_script_entries(content: str) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    active = False
    for line in content.splitlines():
        if line == "scripts:":
            active = True
            continue
        if active and line and not line[0].isspace():
            break
        if not active:
            continue
        match = re.match(r"^  - id:\s*(.+?)\s*$", line)
        if match:
            if current:
                entries.append(current)
            current = {"id": match.group(1).strip('"')}
            continue
        match = re.match(r"^    ([A-Za-z_][\w-]*):\s*(.*?)\s*$", line)
        if match and current is not None:
            current[match.group(1)] = match.group(2).strip('"')
    if current:
        entries.append(current)
    return entries


def executable_scripts(root: Path) -> set[str]:
    candidates = list(root.glob("*.sh")) + list(root.glob("*.ps1"))
    candidates += list((root / "scripts").rglob("*.sh"))
    candidates += list((root / "scripts").rglob("*.ps1"))
    candidates += list((root / "tests").glob("*.py"))
    return {path.relative_to(root).as_posix() for path in candidates}


def runtime_modules(root: Path) -> set[str]:
    candidates = list((root / "scripts" / "lib").glob("*.bash"))
    candidates += list((root / "scripts" / "lib").glob("*.psm1"))
    return {path.relative_to(root).as_posix() for path in candidates}


def validate(root: Path, reporter: Reporter) -> int:
    errors = 0

    def passed(message: str, component: str = "validate-project") -> None:
        reporter.emit("SUCCESS", message, component)

    def failed(message: str, component: str = "validate-project") -> None:
        nonlocal errors
        errors += 1
        reporter.emit("ERROR", message, component)

    for entry in ("AGENTS.md", "MANIFEST.yaml", "README.md", "run.sh", "run.ps1"):
        if (root / entry).is_file():
            passed(f"Required entry file exists: {entry}", "entry-files")
        else:
            failed(f"Required entry file is missing: {entry}", "entry-files")

    manifest_path = root / "MANIFEST.yaml"
    if not manifest_path.is_file():
        reporter.emit("ERROR", "Cannot continue without MANIFEST.yaml.")
        return 1
    manifest_content = manifest_path.read_text(encoding="utf-8", errors="ignore")
    for section in (
        "schema_version:",
        "project:",
        "agent:",
        "contracts:",
        "structure:",
        "data_interfaces:",
        "bootstrap_steps:",
        "scripts:",
        "modules:",
    ):
        if re.search(rf"^{re.escape(section)}", manifest_content, re.MULTILINE):
            passed(f"Manifest section exists: {section[:-1]}", "manifest")
        else:
            failed(f"Manifest section is missing: {section[:-1]}", "manifest")

    steps = parse_bootstrap_steps(manifest_content)
    seen_ids: set[str] = set()
    seen_orders: set[str] = set()
    required_step_fields = {
        "id",
        "order",
        "windows",
        "unix",
        "forwards",
        "skip_option",
        "failure_policy",
    }
    for step in steps:
        step_id = step.get("id", "<missing-id>")
        missing = sorted(required_step_fields - step.keys())
        if missing:
            failed(f"Step {step_id} is missing fields: {', '.join(missing)}", "workflow")
            continue
        if step_id in seen_ids:
            failed(f"Duplicate bootstrap step id: {step_id}", "workflow")
        seen_ids.add(step_id)
        if step["order"] in seen_orders:
            failed(f"Duplicate bootstrap order: {step['order']}", "workflow")
        seen_orders.add(step["order"])
        if not step["order"].isdigit():
            failed(f"Step {step_id} has a non-numeric order: {step['order']}", "workflow")
        if step["failure_policy"] not in {"stop", "continue"}:
            failed(f"Step {step_id} has invalid failure_policy.", "workflow")
        for platform in ("windows", "unix"):
            relative = Path(step[platform])
            if relative.is_absolute() or ".." in relative.parts:
                failed(f"Step {step_id} has unsafe {platform} path: {relative}", "workflow")
            elif not (root / relative).is_file():
                failed(f"Step {step_id} path does not exist: {relative}", "workflow")
        passed(f"Workflow step is valid: {step_id}", "workflow")
    if not steps:
        failed("Manifest contains no bootstrap steps.", "workflow")

    inventory_required = {
        "host",
        "os",
        "hostname",
        "workspace_root",
        "data_root",
        "scratch_root",
        "features",
        "project_groups",
    }
    inventory_files = sorted((root / "inventory").glob("*.yaml"))
    if not inventory_files:
        failed("No inventory YAML files were found.", "data")
    for path in inventory_files:
        missing = sorted(inventory_required - scalar_keys(path))
        if missing:
            failed(f"{path.relative_to(root)} is missing keys: {', '.join(missing)}", "data")
        else:
            passed(f"Inventory contract passed: {path.relative_to(root)}", "data")

    for path in sorted((root / "manifests").glob("*.yaml")):
        keys = scalar_keys(path)
        if {"features", "common", "packages"} & keys:
            passed(f"Package manifest contract passed: {path.relative_to(root)}", "data")
        else:
            failed(f"Package manifest has no recognized root: {path.relative_to(root)}", "data")

    repos_path = root / "projects" / "repos.yaml"
    repos_required = {"projects", "name", "url", "group", "directory", "hosts", "optional", "description"}
    if not repos_path.is_file():
        failed("Repository manifest is missing: projects/repos.yaml", "data")
    else:
        missing = sorted(repos_required - scalar_keys(repos_path))
        if missing:
            failed(f"projects/repos.yaml is missing keys: {', '.join(missing)}", "data")
        else:
            passed("Repository manifest contract passed: projects/repos.yaml", "data")

    declared = parse_catalog_paths(manifest_content)
    actual = executable_scripts(root)
    script_entries = parse_script_entries(manifest_content)
    required_catalog_fields = {
        "id", "path", "role", "platform", "description", "inputs", "outputs", "exit_codes"
    }
    catalog_ids: set[str] = set()
    for entry in script_entries:
        entry_id = entry.get("id", "<missing-id>")
        missing = sorted(required_catalog_fields - entry.keys())
        if missing:
            failed(f"Script catalog entry {entry_id} is missing: {', '.join(missing)}", "script-catalog")
        if entry_id in catalog_ids:
            failed(f"Duplicate script catalog id: {entry_id}", "script-catalog")
        catalog_ids.add(entry_id)
        exit_contract = entry.get("exit_codes", "")
        if exit_contract and not all(f"{code}:" in exit_contract for code in (0, 1, 2)):
            failed(f"Script catalog entry {entry_id} does not declare exit codes 0, 1, and 2.", "script-catalog")
    for missing_path in sorted(actual - declared):
        failed(f"Executable script is absent from MANIFEST.yaml: {missing_path}", "script-catalog")
    for stale_path in sorted(declared - actual):
        failed(f"Catalog path is missing or not executable: {stale_path}", "script-catalog")

    required_metadata = ("name:", "description:", "platform:", "inputs:", "outputs:", "exit_codes:")
    for relative in sorted(actual):
        path = root / relative
        content = path.read_text(encoding="utf-8", errors="ignore")
        header = "\n".join(content.splitlines()[:35])
        if "SCRIPT-METADATA" not in header or "END-SCRIPT-METADATA" not in header:
            failed(f"Script metadata block is missing: {relative}", "script-catalog")
            continue
        absent = [field[:-1] for field in required_metadata if field not in header]
        if absent:
            failed(f"Script metadata fields missing in {relative}: {', '.join(absent)}", "script-catalog")
        elif "help" not in content.lower():
            failed(f"Script has no discoverable help interface: {relative}", "script-catalog")
        else:
            passed(f"Script is self-documenting: {relative}", "script-catalog")

    if declared == actual:
        passed(f"Script catalog is complete: {len(actual)} executable(s).", "script-catalog")

    declared_modules = parse_catalog_paths(manifest_content, "modules")
    actual_modules = runtime_modules(root)
    for missing_path in sorted(actual_modules - declared_modules):
        failed(f"Runtime module is absent from MANIFEST.yaml: {missing_path}", "module-catalog")
    for stale_path in sorted(declared_modules - actual_modules):
        failed(f"Cataloged runtime module is missing: {stale_path}", "module-catalog")

    required_module_metadata = (
        "name:",
        "description:",
        "platform:",
        "interface:",
        "outputs:",
        "exit_codes:",
    )
    for relative in sorted(actual_modules):
        content = (root / relative).read_text(encoding="utf-8", errors="ignore")
        header = "\n".join(content.splitlines()[:35])
        if "MODULE-METADATA" not in header or "END-MODULE-METADATA" not in header:
            failed(f"Module metadata block is missing: {relative}", "module-catalog")
            continue
        absent = [field[:-1] for field in required_module_metadata if field not in header]
        if absent:
            failed(
                f"Module metadata fields missing in {relative}: {', '.join(absent)}",
                "module-catalog",
            )
        else:
            passed(f"Runtime module is self-documenting: {relative}", "module-catalog")
    if declared_modules == actual_modules:
        passed(f"Module catalog is complete: {len(actual_modules)} module(s).", "module-catalog")

    if errors:
        reporter.emit("ERROR", f"Project validation failed: errors={errors}.")
        return 1
    reporter.emit("SUCCESS", "Project validation passed: errors=0.")
    return 0


def parse_args() -> argparse.Namespace:
    parser = ContractArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="project root (default: parent of tests/)",
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
    root = args.root.expanduser().resolve()
    reporter = Reporter(args.output_format)
    if not root.is_dir():
        reporter.emit("ERROR", f"Project root is not a directory: {root}")
        return 1
    reporter.emit("INFO", f"Validating project root: {root}")
    return validate(root, reporter)


if __name__ == "__main__":
    raise SystemExit(main())
