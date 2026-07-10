<#
.SYNOPSIS
    Workstation bootstrap orchestrator for Windows.
.DESCRIPTION
    Coordinates create-directories, install-packages, clone-repositories,
    and verify scripts in order. Supports dry-run and idempotent execution.
.PARAMETER DryRun
    Show what would be done without making changes.
.PARAMETER WhatIf
    Alias for DryRun.
.PARAMETER Force
    Overwrite existing files and configurations.
.PARAMETER SkipPackages
    Skip package installation step.
.PARAMETER SkipRepos
    Skip repository clone step.
.PARAMETER Inventory
    Path to inventory YAML file (default: auto-detect from hostname).
.EXAMPLE
    .\bootstrap.ps1 -DryRun
    .\bootstrap.ps1 -SkipPackages
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$WhatIf,
    [switch]$Force,
    [switch]$SkipPackages,
    [switch]$SkipRepos,
    [string]$Inventory
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptDir\..\.."

# Resolve dry-run
$isDryRun = $DryRun -or $WhatIf

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

# ==============================================================================
# Main
# ==============================================================================

Write-Host @"
╔══════════════════════════════════════════════════╗
║     workstation-bootstrap — Windows             ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Green

if ($isDryRun) {
    Write-Log 'INFO' 'DRY-RUN MODE — no changes will be made'
}

Write-Log 'INFO' "Project root: $projectRoot"

# Pre-flight checks
Write-Step 'Pre-flight checks'

$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Log 'INFO' "OS: $($osInfo.Caption)"
Write-Log 'INFO' "Hostname: $env:COMPUTERNAME"

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 7) {
    Write-Log 'WARN' "PowerShell $psVersion — recommend PowerShell 7+"
} else {
    Write-Log 'INFO' "PowerShell $psVersion"
}

# Check git
try {
    $gitVersion = & git --version 2>$null
    Write-Log 'INFO' "Git: $gitVersion"
} catch {
    Write-Log 'ERROR' 'Git is not installed. Install Git first.'
    exit 1
}

# Resolve inventory
if (-not $Inventory) {
    $hostname = $env:COMPUTERNAME.ToLower()
    $inventoryPath = "$projectRoot\inventory\windows-main.yaml"
    if (-not (Test-Path $inventoryPath)) {
        Write-Log 'ERROR' "No inventory found at $inventoryPath"
        Write-Log 'INFO' 'Create one from the template or specify with -Inventory'
        exit 1
    }
    $Inventory = $inventoryPath
}
Write-Log 'INFO' "Inventory: $Inventory"

# Step 1: Create directories
Write-Step 'Step 1: Create directory structure'
$createDirsArgs = @{ Inventory = $Inventory }
if ($isDryRun) { $createDirsArgs['DryRun'] = $true }
if ($Force) { $createDirsArgs['Force'] = $true }
& "$scriptDir\create-directories.ps1" @createDirsArgs
if ($LASTEXITCODE -ne 0) {
    Write-Log 'ERROR' 'Directory creation failed'
    exit $LASTEXITCODE
}

# Step 2: Install packages
if (-not $SkipPackages) {
    Write-Step 'Step 2: Install packages'
    $installPkgsArgs = @{ Inventory = $Inventory }
    if ($isDryRun) { $installPkgsArgs['DryRun'] = $true }
    & "$scriptDir\install-packages.ps1" @installPkgsArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'WARN' 'Package installation had errors (check output above)'
    }
} else {
    Write-Log 'INFO' 'Skipping package installation (--skip-packages)'
}

# Step 3: Clone repositories
if (-not $SkipRepos) {
    Write-Step 'Step 3: Clone repositories'
    $cloneReposArgs = @{ Inventory = $Inventory }
    if ($isDryRun) { $cloneReposArgs['DryRun'] = $true }
    & "$scriptDir\clone-repositories.ps1" @cloneReposArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'WARN' 'Repository cloning had errors (check output above)'
    }
} else {
    Write-Log 'INFO' 'Skipping repository cloning (--skip-repos)'
}

# Step 4: Verify
Write-Step 'Step 4: Verify'
$verifyArgs = @{ Inventory = $Inventory }
if ($isDryRun) { $verifyArgs['DryRun'] = $true }
& "$scriptDir\verify.ps1" @verifyArgs
$verifyExit = $LASTEXITCODE

Write-Step 'Bootstrap complete'
if ($isDryRun) {
    Write-Log 'INFO' 'Dry-run finished. Review output above, then run without -DryRun to apply.'
} else {
    Write-Log 'INFO' "Bootstrap finished. Verify exit code: $verifyExit"
}

exit $verifyExit