# Agent instructions

This repository describes workstation setup. It contains configuration only; do not add bootstrap scripts, parsers, or validators.

## Rules

- Never put tokens, passwords, API keys, or private keys in this repository.
- Read `MANIFEST.yaml`, match exactly one file in `hosts/` by hostname, then read `catalog/tools.yaml` and `catalog/repositories.yaml`.
- Before changing a machine, show the resolved paths, settings, tools, skipped items, repositories, and target directories, then wait for confirmation.
- Check before acting. Do not reinstall an existing tool, recreate an existing directory, or clone over an existing repository.
- Use the host's platform mapping from the tool catalog. If no mapping exists, report and skip it.
- Use stable provider releases unless the catalog explicitly says otherwise.
- Keep secrets in the declared credential store. A personal host may load them into its shell environment without storing their values in files.
- `templates/` is reference material only.

## Execution order

1. Show the plan and wait for confirmation.
2. Configure declared settings.
3. Create missing directories.
4. Install missing tools.
5. Clone missing repositories.
6. Report what changed and what was skipped.
