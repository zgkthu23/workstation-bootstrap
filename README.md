# Workstation Bootstrap

Simple declarative configuration for personal development workstations. An agent reads the files, shows a plan, waits for approval, and performs only missing work.

## Structure

```text
MANIFEST.yaml                 file locations and global rules
hosts/<machine>.yaml          everything selected for one machine
catalog/tools.yaml            platform installation mappings
catalog/repositories.yaml     repository URLs and target folders
repository-groups/*/README.md folder-purpose descriptions
templates/host.example.yaml   reference for adding a machine
```

There are no profiles, bundles, merge layers, bootstrap scripts, or version validators. A host lists its tools and repositories directly; catalogs use those IDs as YAML keys.

## Add a workstation

Copy the shape of `templates/host.example.yaml` into `hosts/<name>.yaml`, add its real hostname, and directly list the required tools and repositories. Add missing installation mappings or repository definitions to the catalogs.

Tools follow the package provider's stable release. Existing commands or applications satisfy the declaration and are not reinstalled.

## Secrets

Never commit a token, password, API key, or private key. This Mac stores secrets in macOS Keychain and may load them from Keychain in `.zshrc` for convenience.

Tavily uses Keychain service `tavily-api-key` and environment variable `TAVILY_API_KEY`. Claude Code and its Tavily MCP inherit the variable. CC Switch stores only non-secret MCP configuration.

GitHub CLI uses Keychain service `github-cli-gh-token` when process-level token access is needed. Prefer `gh auth login` for normal GitHub CLI authentication.

## Repository folders

- `personal`: configuration and personal projects
- `learning`: programming exercises and source repositories being studied
- `tools`: reusable utilities
- `work`: work projects
- `research`: research projects

Repositories are cloned to `~/workspace/repos/<group>/<directory>`. Existing directories are left untouched.
