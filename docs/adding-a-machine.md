# Adding a new machine

## Quick guide

### 1. Copy an inventory template
```bash
cp inventory/ubuntu-main.yaml inventory/ubuntu-server.yaml
```

### 2. Edit the inventory
```yaml
host: ubuntu-server
os: ubuntu
hostname: my-server
workspace_root: /home/deploy/workspace
data_root: /mnt/data
cloud_root: /home/deploy/cloud
scratch_root: /tmp/scratch
features:
  - common
  - python-development
  - docker
project_groups:
  - personal
  - tools
# ... rest of config
```

### 3. Update manifests (if needed)
If the new machine needs packages not in existing manifests, add them to
`manifests/ubuntu.yaml` or create a machine-specific manifest.

### 4. Add to repos.yaml (if needed)
If the new machine should clone repos not already listed, add them to
`projects/repos.yaml` with the new host in the `hosts` list.

### 5. Test
```bash
# From the new machine:
./scripts/unix/bootstrap.sh --dry-run
./scripts/unix/verify.sh
```

### 6. Apply
```bash
./scripts/unix/bootstrap.sh
```

## Inventory fields reference

| Field | Required | Description |
|-------|----------|-------------|
| `host` | Yes | Unique machine identifier |
| `os` | Yes | `windows`, `ubuntu`, or `macos` |
| `hostname` | Yes | Machine hostname |
| `workspace_root` | Yes | Absolute path for WORKSPACE_ROOT |
| `data_root` | Yes | Absolute path for DATA_ROOT |
| `cloud_root` | No | Absolute path for CLOUD_ROOT |
| `scratch_root` | Yes | Absolute path for SCRATCH_ROOT |
| `features` | Yes | List of feature groups to enable |
| `project_groups` | Yes | List of project groups to clone |
| `git_user_name` | No | Git user.name (template) |
| `git_user_email` | No | Git user.email (template) |
| `install_docker` | No | Whether to install Docker |
| `install_c_dev` | No | Whether to install C/C++ toolchain |
| `install_python_dev` | No | Whether to install Python toolchain |
| `install_node_dev` | No | Whether to install Node.js toolchain |
| `install_office` | No | Whether to install office tools |