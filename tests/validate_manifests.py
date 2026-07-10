"""验证 YAML manifest 文件的必填字段和结构。

用法：
    uv run python tests/validate_manifests.py
"""

import sys
from pathlib import Path

# Windows 控制台默认用 cp1252，不支持中文输出，强制 UTF-8
sys.stdout.reconfigure(encoding='utf-8')


# 不需要 PyYAML — 使用最小化检查。
# ponytail: inline YAML structural validation, no PyYAML dep needed for Phase 1

def check_required_fields(filepath: Path, required_keys: list[str]) -> list[str]:
    """检查 YAML 文件中是否存在必填字段（基于简单 grep）。"""
    content = filepath.read_text(encoding="utf-8", errors="ignore")
    missing = []
    for key in required_keys:
        if key not in content:
            missing.append(key)
    return missing


def main() -> int:
    project_root = Path(__file__).resolve().parent.parent
    errors = 0

    # 检查 inventory 文件
    print("=== Inventory 文件 ===")
    inventory_dir = project_root / "inventory"
    required_inventory = ["host:", "os:", "hostname:", "workspace_root:", "features:", "project_groups:"]
    for inv_file in sorted(inventory_dir.glob("*.yaml")):
        missing = check_required_fields(inv_file, required_inventory)
        if missing:
            print(f"  失败 {inv_file.name}: 缺少 {missing}")
            errors += 1
        else:
            print(f"  通过 {inv_file.name}")

    # 检查 manifest 文件
    print("\n=== Manifest 文件 ===")
    manifests_dir = project_root / "manifests"
    for mf in sorted(manifests_dir.glob("*.yaml")):
        content = mf.read_text(encoding="utf-8", errors="ignore")
        if "features:" in content or "common:" in content or "packages:" in content:
            print(f"  通过 {mf.name}")
        else:
            print(f"  警告 {mf.name}: 未找到 features/common/packages 节")
            # 不是错误 — common.yaml 可能使用不同的结构

    # 检查 repos.yaml
    print("\n=== 项目文件 ===")
    repos_yaml = project_root / "projects" / "repos.yaml"
    if repos_yaml.exists():
        content = repos_yaml.read_text(encoding="utf-8", errors="ignore")
        required = ["name:", "url:", "group:", "directory:", "hosts:"]
        missing = check_required_fields(repos_yaml, required)
        if missing:
            print(f"  失败 repos.yaml: 缺少 {missing}")
            errors += 1
        else:
            print(f"  通过 repos.yaml")
    else:
        print(f"  失败 repos.yaml: 未找到")
        errors += 1

    # 检查脚本是否存在
    print("\n=== 脚本文件 ===")
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
            print(f"  警告 {sdir.relative_to(project_root)}: 目录未找到")
            continue
        ext = ".ps1" if sdir.name == "windows" else ".sh"
        for name in expected_scripts:
            script = sdir / f"{name}{ext}"
            if script.exists():
                print(f"  通过 {script.relative_to(project_root)}")
            else:
                print(f"  失败 {script.relative_to(project_root)}: 未找到")
                errors += 1

    print(f"\n{'通过' if errors == 0 else '失败'}: {errors} 个错误")
    return 1 if errors > 0 else 0


if __name__ == "__main__":
    sys.exit(main())