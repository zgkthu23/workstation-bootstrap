# Refactor audit

## Scope reviewed

The refactor audited all repository files and all executable sources present at the start of the work: five Bash task/orchestration scripts, five PowerShell equivalents, and two Python validation scripts. The package manifests, host inventories, repository declarations, templates, and architecture/recovery documentation were also reviewed as their data interfaces feed those scripts.

## Findings before the refactor

- The two platform `bootstrap` scripts hard-coded step paths and order; no machine-readable execution graph existed.
- Script headers varied by language and did not consistently declare platforms, complete inputs/outputs, or exit codes.
- Logs mixed timestamped records, banners, colors, unprefixed dry-run text, and Chinese pass/fail labels. PowerShell used `Write-Host`, making stdout/stderr intent unclear.
- Failure behavior was inconsistent. Package and repository placeholders implicitly returned success, while orchestration sometimes warned about child failures without preserving an overall failure.
- Windows and Unix exposed similar but independently evolved interfaces, and the documented quick start bypassed a repository-level entry point.
- Existing Python tests validated only part of the data layout and did not enforce manifest/script completeness or self-description headers.
- Package installation and repository cloning were explicitly incomplete Phase‑1 implementations in the original source.

## Implemented architecture

- `AGENTS.md` is now the stable Agent entry point; `MANIFEST.yaml` is the complete machine-readable execution/catalog contract.
- `run.sh` and `run.ps1` are canonical cross-platform launchers using native shell option conventions.
- `scripts/<platform>/orchestrate.*` parses `bootstrap_steps` from the manifest, validates paths remain inside the repository, forwards only declared inputs, and normalizes child results.
- `scripts/lib/` contains separately cataloged sourced/imported runtime modules; they are explicitly not executable task commands.
- Legacy `scripts/<platform>/bootstrap.*` paths are thin compatibility launchers.
- Every `.sh`, `.ps1`, and `.py` file has the same `SCRIPT-METADATA` fields.
- Operational stdout uses `INFO`, `WARN`, or `SUCCESS`; stderr uses `ERROR`.
  Text and NDJSON renderings expose the same stable record fields.
- All scripts use `0=success`, `1=error`, and `2=skipped/not applicable`.
- The two original Phase‑1 placeholders now validate their inputs, report that no state changed, and return `2` instead of silently implying completed work.
- `tests/validate_manifests.py` now checks data interfaces, workflow paths, exact executable-script catalog coverage, explicit catalog contracts, and self-description header completeness; sourced/imported modules are documented separately in `scripts/README.md`.

## Behavioral boundaries preserved

This was an architecture refactor, not an expansion of the original bootstrap scope. Directory creation and verification remain functional and idempotent. Package installation and repository cloning remain incomplete because their original implementations were incomplete; their status is now explicit and Agent-readable rather than hidden behind a zero exit status.
