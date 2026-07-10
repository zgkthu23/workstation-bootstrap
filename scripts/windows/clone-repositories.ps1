<#
SCRIPT-METADATA
name: windows-clone-repositories
description: Validates repository inputs and reports the retained Phase-1 clone placeholder.
platform: windows
inputs: -Inventory PATH, -DryRun, -OutputFormat text|json, -Help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: 0=success, 1=error, 2=phase-1-placeholder-not-applicable
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
    Initialize-BootstrapRuntime -Component 'clone-repositories' -OutputFormat $OutputFormat
} catch {
    [Console]::Error.WriteLine("[ERROR] $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) [clone-repositories] Runtime initialization failed: $($_.Exception.Message)")
    exit 1
}

function Show-Usage {
    [Console]::Out.WriteLine(@'
Usage: clone-repositories.ps1 -Inventory PATH [options]
  -Inventory PATH          Inventory YAML file (required).
  -DryRun                  Report the clone plan without changes.
  -OutputFormat text|json  Emit text records (default) or NDJSON records.
  -Help                    Show this help.
'@)
}

if ($Help) { Show-Usage; exit 0 }

try {
    if (-not $Inventory) { throw '-Inventory is required.' }
    Assert-BootstrapFile -Path $Inventory -Label 'Inventory'
    $reposYaml = Join-Path $projectRoot 'projects\repos.yaml'
    Assert-BootstrapFile -Path $reposYaml -Label 'Repository manifest'
    $workspaceRoot = Read-BootstrapYamlScalar -Path $Inventory -Key 'workspace_root'
    if (-not $workspaceRoot) { throw 'Inventory is missing workspace_root.' }

    Write-BootstrapRecord -Level INFO -Message "Repository manifest: $reposYaml"
    Write-BootstrapRecord -Level INFO -Message "Workspace root: $workspaceRoot"
    if ($DryRun) {
        Write-BootstrapRecord -Level INFO -Message 'Dry-run plan: targets would use WORKSPACE_ROOT\repos\<group>\<directory>.'
    }
    Write-BootstrapRecord -Level INFO -Message 'Safety policy: never overwrite an existing repository or force-update a dirty worktree.'
    Write-BootstrapRecord -Level WARN -Message 'Repository cloning remains the original Phase-1 placeholder and is not applicable yet.'
    exit 2
} catch {
    Write-BootstrapRecord -Level ERROR -Message $_.Exception.Message
    exit 1
}
