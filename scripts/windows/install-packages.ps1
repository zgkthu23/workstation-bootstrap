<#
.SYNOPSIS
    Install Windows packages via winget.
.DESCRIPTION
    Reads inventory and manifests, installs packages for enabled features.
    Supports dry-run, list, and verify modes.
.PARAMETER DryRun
    Show what packages would be installed.
.PARAMETER List
    List all packages for enabled features without installing.
.PARAMETER Inventory
    Path to inventory YAML file.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$List,
    [Parameter(Mandatory=$true)]
    [string]$Inventory
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

# Simple YAML reader (same as create-directories)
function Read-YamlFlat {
    param([string]$Path)
    $result = @{}
    foreach ($line in (Get-Content $Path)) {
        if ($line -match '^\s*(\w[\w_-]*):\s*"?(.+?)"?\s*$') {
            $result[$Matches[1]] = $Matches[2].Trim('"', '''')
        }
    }
    return $result
}

$inv = Read-YamlFlat $Inventory

Write-Log 'INFO' 'Checking winget availability...'
try {
    $wingetVersion = & winget --version 2>$null
    Write-Log 'INFO' "winget: $wingetVersion"
} catch {
    Write-Log 'ERROR' 'winget is not available. Install App Installer from Microsoft Store.'
    exit 1
}

Write-Log 'INFO' 'Package installation is not yet implemented in Phase 1.'
Write-Log 'INFO' 'This is a placeholder that will parse manifests and install via winget.'
Write-Log 'INFO' 'Feature groups from inventory will be read from manifests/ directory.'
Write-Log 'INFO' "DryRun: $DryRun, List: $List"

if ($DryRun -or $List) {
    Write-Host ""
    Write-Host '[DRY-RUN] Would parse manifests and install packages for enabled features.' -ForegroundColor Yellow
    Write-Host '[DRY-RUN] Packages would come from: manifests\common.yaml, manifests\windows.yaml' -ForegroundColor Yellow
}