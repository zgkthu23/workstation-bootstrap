# Agent entry point

This repository is designed to be inspected and operated from one stable entry.
Read files in this order:

1. `MANIFEST.yaml` — machine-readable project map, contracts, workflow, and script catalog.
2. The selected file under `inventory/` — host identity, paths, enabled features, and project groups.
3. `manifests/common.yaml` plus the selected OS manifest — declared package data.
4. `projects/repos.yaml` — declared repository data.

Do not infer execution order from filenames. Use `bootstrap_steps` in
`MANIFEST.yaml`; `run.sh` and `run.ps1` read that section at runtime.

## Safe operating rules

- Start mutations with dry-run: `bash run.sh --dry-run` or `./run.ps1 -DryRun`.
- Prefer the root launcher. Use `--task ID` / `-Task ID` for one independently
  runnable task and `--list-tasks` / `-ListTasks` to discover task IDs.
- Use `--output-format json` / `-OutputFormat json` when consuming output as an
  Agent. Each stdout or stderr line is then one JSON object.
- Treat exit `0` as success, `1` as failure, and `2` as skipped/not applicable.
  In the full workflow, an expected child exit `2` is recorded and execution
  continues; a directly selected task propagates `2`.
- Do not add credentials or replace `PUT_YOUR_*` placeholders with secrets.
- Package installation and repository cloning are intentionally Phase-1
  placeholders. Refactoring must not silently turn them into mutating tasks.

## Change protocol

When adding or changing an executable script:

1. Keep its `SCRIPT-METADATA` header and `--help` / `-Help` interface current.
2. Emit records through `scripts/lib/common.bash` or
   `scripts/lib/Bootstrap.Common.psm1`.
3. Use only the `0/1/2` exit-code contract.
4. Add the executable to the `scripts` catalog in `MANIFEST.yaml`.
5. If it is part of bootstrap, add a platform pair to `bootstrap_steps`.
6. Run `uv run --quiet python tests/validate_manifests.py` and
   `uv run --quiet python tests/test_no_secrets.py`.

Human-facing background and recovery procedures live in `README.md` and
`docs/`. Script-specific conventions and direct examples live in
`scripts/README.md`.
