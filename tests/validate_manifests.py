"""Validate YAML manifest files for required fields and structure.

Usage:
    uv run python tests/validate_manifests.py
"""

import sys
from pathlib import Path


# We don't require PyYAML — use a minimal check.
# ponytail: inline YAML structural validation, no PyYAML dep needed for Phase 1

def check_required_fields(filepath: Path, required_keys: list[str]) -> list[str]:
    """Check that required keys exist in a YAML file (simple grep-based)."""
    content = filepath.read_text(encoding="utf-8", errors="ignore")
    missing = []
    for key in required_keys:
        if key not in content:
            missing.append(key)
    return missing


def main() -> int:
    project_root = Path(__file__).resolve().parent.parent
    errors = 0

    # Check inventory files
    print("=== Inventory files ===")
    inventory_dir = project_root / "inventory"
    required_inventory = ["host:", "os:", "hostname:", "workspace_root:", "features:", "project_groups:"]
    for inv_file in sorted(inventory_dir.glob("*.yaml")):
        missing = check_required_fields(inv_file, required_inventory)
        if missing:
            print(f"  FAIL {inv_file.name}: missing {missing}")
            errors += 1
        else:
            print(f"  PASS {inv_file.name}")

    # Check manifest files
    print("\n=== Manifest files ===")
    manifests_dir = project_root / "manifests"
    for mf in sorted(manifests_dir.glob("*.yaml")):
        content = mf.read_text(encoding="utf-8", errors="ignore")
        if "features:" in content or "common:" in content or "packages:" in content:
            print(f"  PASS {mf.name}")
        else:
            print(f"  WARN {mf.name}: no features/common/packages section found")
            # Not an error — common.yaml might use different structure

    # Check repos.yaml
    print("\n=== Project files ===")
    repos_yaml = project_root / "projects" / "repos.yaml"
    if repos_yaml.exists():
        content = repos_yaml.read_text(encoding="utf-8", errors="ignore")
        required = ["name:", "url:", "group:", "directory:", "hosts:"]
        missing = check_required_fields(repos_yaml, required)
        if missing:
            print(f"  FAIL repos.yaml: missing {missing}")
            errors += 1
        else:
            print(f"  PASS repos.yaml")
    else:
        print(f"  FAIL repos.yaml: not found")
        errors += 1

    # Check scripts exist
    print("\n=== Script files ===")
    script_dirs = [
        project_root / "scripts" / "windows",
        project_root / "scripts" / "unix",
    ]
    expected_scripts = [
        "bootstrap",
        "create-directories",
        "install-packages",
        "clone-repositories",
        "verify",
    ]
    for sdir in script_dirs:
        if not sdir.exists():
            print(f"  WARN {sdir.relative_to(project_root)}: directory not found")
            continue
        ext = ".ps1" if sdir.name == "windows" else ".sh"
        for name in expected_scripts:
            script = sdir / f"{name}{ext}"
            if script.exists():
                print(f"  PASS {script.relative_to(project_root)}")
            else:
                print(f"  FAIL {script.relative_to(project_root)}: not found")
                errors += 1

    print(f"\n{'PASS' if errors == 0 else 'FAIL'}: {errors} error(s)")
    return 1 if errors > 0 else 0


if __name__ == "__main__":
    sys.exit(main())