# Workstation Bootstrap

Ansible project to configure personal development workstations across macOS, Windows, and Linux over a Tailscale mesh.

## Control node

The Mac (`guangkuos-macbook-air`) runs Ansible and pushes to the other hosts over Tailscale. Ansible [core] 2.18+ is required for SSH-to-Windows support (installed: 2.21.2).

## Setup

```bash
ansible-galaxy collection install -r requirements.yml
```

## Hosts

| Inventory name | Platform | Connection |
|---|---|---|
| guangkuos-macbook-air | macOS | local |
| desktop-317 | Windows | ssh (pwsh) |
| ubuntu-vps | Linux | ssh |

## Run

```bash
# Connectivity check (builtin.ping needs Python on the remote, so Windows
# uses win_ping, which runs over PowerShell):
ansible macos,linux -m ansible.builtin.ping
ansible windows -m ansible.windows.win_ping

ansible-playbook site.yml    # apply configuration
```

## Current scope

Phase 1 creates a consistent home-directory layout on every host:

- `~/workspace/personal`
- `~/workspace/learning`
- `~/workspace/work`
- `~/workspace/research`
- `~/data`

Later phases add tool installation, repository cloning, dotfiles, and secrets.
