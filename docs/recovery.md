# Recovery: new machine from scratch

## Prerequisites

- [ ] OS installed and updated
- [ ] Internet connection
- [ ] GitHub account access
- [ ] Password manager access

## Step-by-step

### 1. Install OS
Install the operating system with default settings. Create your user account.

### 2. Install Git
```bash
# Ubuntu
sudo apt install git

# macOS
xcode-select --install  # includes git
# or: brew install git

# Windows
winget install Git.Git
```

### 3. Configure GitHub access
```bash
# SSH (recommended)
ssh-keygen -t ed25519 -C "your-email@example.com"
# Add ~/.ssh/id_ed25519.pub to GitHub → Settings → SSH Keys
ssh -T git@github.com  # verify

# OR HTTPS with PAT
git config --global credential.helper store
# Set GH_TOKEN or GITHUB_TOKEN environment variable
```

### 4. Clone this repository
```bash
git clone git@github.com:zgkthu23/workstation-bootstrap.git
cd workstation-bootstrap
```

### 5. Edit your inventory
Edit `inventory/<your-machine>.yaml`:
- Set correct hostname
- Set correct paths
- Enable desired feature groups
- Set git user info

### 6. Dry-run
```bash
# Unix
./scripts/unix/bootstrap.sh --dry-run

# Windows
.\scripts\windows\bootstrap.ps1 -DryRun
```

### 7. Review and confirm
Read the dry-run output carefully. Confirm:
- Correct directories will be created
- Correct packages will be installed
- Correct repos will be cloned
- No unexpected modifications

### 8. Run bootstrap
```bash
# Unix
./scripts/unix/bootstrap.sh

# Windows
.\scripts\windows\bootstrap.ps1
```

### 9. Restore secrets
From your password manager:
- SSH keys (if not using new ones)
- API tokens (GitHub, OpenAI, Claude, etc.)
- Database credentials
- `.env` files for projects

### 10. Restore cloud drive
- Sign into OneDrive / Google Drive / iCloud
- Let files sync down

### 11. Restore large data
- Restore from restic / external drive
- Re-download datasets and models

### 12. Verify
```bash
# Unix
./scripts/unix/verify.sh

# Windows
.\scripts\windows\verify.ps1
```

## Estimated time

| Step | Time |
|------|------|
| OS install | 30-60 min |
| Git + GitHub setup | 10 min |
| Bootstrap (automated) | 15-30 min |
| Cloud sync | 1-24 hours (depends on volume) |
| Data restore | 1-8 hours (depends on volume) |
| **Total hands-on** | **~1 hour** |
| **Total wall clock** | **2-24 hours** |