<#
.SYNOPSIS
    Create workspace directory structure for Windows.
.DESCRIPTION
    Reads inventory YAML and creates logical root directories plus
    workspace layout. Idempotent — safe to run multiple times.
.PARAMETER DryRun
    Show what directories would be created.
.PARAMETER Force
    Not used for directories (mkdir -Force is safe).
.PARAMETER Inventory
    Path to inventory YAML file.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [Parameter(Mandatory=$true)]
    [string]$Inventory
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptDir\..\.."

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

# Simple YAML reader (no external dependency)
# ponytail: minimal YAML parser for inventory — only handles the flat structure we use
function Read-Inventory {
    param([string]$Path)
    $content = Get-Content $Path -Raw
    $result = @{}
    $lines = $content -split "`n"
    foreach ($line in $lines) {
        if ($line -match '^\s*(\w[\w_]*):\s*"?(.+?)"?\s*$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim('"', '''')
            $result[$key] = $value
        } elseif ($line -match '^\s*(\w[\w_]*):\s*(.+?)\s*$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value -ne '') { $result[$key] = $value }
        }
    }
    return $result
}

$inv = Read-Inventory $Inventory

$roots = @(
    $inv['workspace_root'],
    $inv['data_root'],
    $inv['scratch_root']
)
if ($inv.ContainsKey('cloud_root') -and $inv['cloud_root']) {
    $roots += $inv['cloud_root']
}

$workspace = $inv['workspace_root']
$workspaceDirs = @(
    "$workspace\repos\work",
    "$workspace\repos\personal",
    "$workspace\repos\research",
    "$workspace\repos\tools",
    "$workspace\repos\experiments",
    "$workspace\artifacts\releases",
    "$workspace\artifacts\reports",
    "$workspace\artifacts\exports",
    "$workspace\shared\templates",
    "$workspace\shared\scripts"
)

$allDirs = $roots + $workspaceDirs

Write-Log 'INFO' "Inventory: $Inventory"
Write-Log 'INFO' "Roots: $($roots -join ', ')"

$created = 0
$existed = 0

foreach ($dir in $allDirs) {
    if (Test-Path $dir) {
        Write-Log 'INFO' "Exists: $dir"
        $existed++
    } else {
        if ($DryRun) {
            Write-Host "  [DRY-RUN] Would create: $dir" -ForegroundColor Yellow
        } else {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log 'INFO' "Created: $dir"
        }
        $created++
    }
}

Write-Host ""
Write-Log 'INFO' "Summary: $existed already existed, $created to create" + $(if ($DryRun) { ' (dry-run)' } else { '' })