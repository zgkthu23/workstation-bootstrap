<#
SCRIPT-METADATA
name: windows-create-directories
description: Idempotently creates inventory-defined roots and the standard workspace layout.
platform: windows
inputs: -Inventory PATH, -DryRun, -OutputFormat text|json, -Help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
END-SCRIPT-METADATA
#>
[CmdletBinding()]
param(
    [string]$Inventory,
    [switch]$DryRun,
    [string]$OutputFormat = 'text',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
try {
    Import-Module (Join-Path $projectRoot 'scripts\lib\Bootstrap.Common.psm1') -Force
    Initialize-BootstrapRuntime -Component 'create-directories' -OutputFormat $OutputFormat
} catch {
    [Console]::Error.WriteLine("[ERROR] $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) [create-directories] Runtime initialization failed: $($_.Exception.Message)")
    exit 1
}

function Show-Usage {
    [Console]::Out.WriteLine(@'
Usage: create-directories.ps1 -Inventory PATH [options]
  -Inventory PATH          Inventory YAML file (required).
  -DryRun                  Report planned directories without creating them.
  -OutputFormat text|json  Emit text records (default) or NDJSON records.
  -Help                    Show this help.
'@)
}

if ($Help) { Show-Usage; exit 0 }

try {
    if (-not $Inventory) { throw '-Inventory is required.' }
    Assert-BootstrapFile -Path $Inventory -Label 'Inventory'

    $workspaceRoot = Read-BootstrapYamlScalar -Path $Inventory -Key 'workspace_root'
    $dataRoot = Read-BootstrapYamlScalar -Path $Inventory -Key 'data_root'
    $scratchRoot = Read-BootstrapYamlScalar -Path $Inventory -Key 'scratch_root'
    $cloudRoot = Read-BootstrapYamlScalar -Path $Inventory -Key 'cloud_root'
    if (-not $workspaceRoot -or -not $dataRoot -or -not $scratchRoot) {
        throw 'Inventory is missing required scalar(s): workspace_root, data_root, scratch_root.'
    }

    $roots = @($workspaceRoot, $dataRoot, $scratchRoot)
    if ($cloudRoot) { $roots += $cloudRoot }
    $workspaceDirectories = @(
        [IO.Path]::Combine($workspaceRoot, 'repos', 'work'),
        [IO.Path]::Combine($workspaceRoot, 'repos', 'personal'),
        [IO.Path]::Combine($workspaceRoot, 'repos', 'research'),
        [IO.Path]::Combine($workspaceRoot, 'repos', 'tools'),
        [IO.Path]::Combine($workspaceRoot, 'repos', 'experiments'),
        [IO.Path]::Combine($workspaceRoot, 'artifacts', 'releases'),
        [IO.Path]::Combine($workspaceRoot, 'artifacts', 'reports'),
        [IO.Path]::Combine($workspaceRoot, 'artifacts', 'exports'),
        [IO.Path]::Combine($workspaceRoot, 'shared', 'templates'),
        [IO.Path]::Combine($workspaceRoot, 'shared', 'scripts')
    )

    Write-BootstrapRecord -Level INFO -Message "Inventory: $Inventory"
    if ($DryRun) { Write-BootstrapRecord -Level INFO -Message 'Dry-run mode enabled.' }
    $created = 0
    $existed = 0
    foreach ($directory in @($roots + $workspaceDirectories)) {
        if (Test-Path -LiteralPath $directory -PathType Container) {
            Write-BootstrapRecord -Level INFO -Message "Already exists: $directory"
            $existed++
        } elseif ($DryRun) {
            Write-BootstrapRecord -Level INFO -Message "Would create: $directory"
            $created++
        } else {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Write-BootstrapRecord -Level INFO -Message "Created: $directory"
            $created++
        }
    }
    Write-BootstrapRecord -Level SUCCESS -Message "Directory task complete: existing=$existed, created_or_planned=$created, dry_run=$($DryRun.IsPresent)."
    exit 0
} catch {
    Write-BootstrapRecord -Level ERROR -Message $_.Exception.Message
    exit 1
}
