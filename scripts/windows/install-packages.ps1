<#
SCRIPT-METADATA
name: windows-install-packages
description: Validates winget and reports the retained Phase-1 package plan placeholder.
platform: windows
inputs: -Inventory PATH, -DryRun, -List, -OutputFormat text|json, -Help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: 0=success, 1=error, 2=phase-1-placeholder-not-applicable
END-SCRIPT-METADATA
#>
[CmdletBinding()]
param(
    [string]$Inventory,
    [switch]$DryRun,
    [switch]$List,
    [string]$OutputFormat = 'text',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
try {
    Import-Module (Join-Path $projectRoot 'scripts\lib\Bootstrap.Common.psm1') -Force
    Initialize-BootstrapRuntime -Component 'install-packages' -OutputFormat $OutputFormat
} catch {
    [Console]::Error.WriteLine("[ERROR] $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) [install-packages] Runtime initialization failed: $($_.Exception.Message)")
    exit 1
}

function Show-Usage {
    [Console]::Out.WriteLine(@'
Usage: install-packages.ps1 -Inventory PATH [options]
  -Inventory PATH          Inventory YAML file (required).
  -DryRun                  Report the package plan without changes.
  -List                    Report the package source files.
  -OutputFormat text|json  Emit text records (default) or NDJSON records.
  -Help                    Show this help.
'@)
}

if ($Help) { Show-Usage; exit 0 }

try {
    if (-not $Inventory) { throw '-Inventory is required.' }
    Assert-BootstrapFile -Path $Inventory -Label 'Inventory'
    Assert-BootstrapFile -Path (Join-Path $projectRoot 'manifests\common.yaml') -Label 'Common package manifest'
    Assert-BootstrapFile -Path (Join-Path $projectRoot 'manifests\windows.yaml') -Label 'Windows package manifest'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetVersion = & winget --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-BootstrapRecord -Level INFO -Message "Package manager: winget $wingetVersion"
        } else {
            Write-BootstrapRecord -Level WARN -Message 'winget exists but its version probe failed; the Phase-1 placeholder will still be reported.'
        }
    } else {
        Write-BootstrapRecord -Level WARN -Message 'winget is unavailable; the Phase-1 placeholder will still be reported.'
    }
    Write-BootstrapRecord -Level INFO -Message "Inventory: $Inventory"
    Write-BootstrapRecord -Level INFO -Message 'Package sources: manifests/common.yaml and manifests/windows.yaml.'
    if ($DryRun -or $List) {
        Write-BootstrapRecord -Level INFO -Message "Plan requested: dry_run=$($DryRun.IsPresent), list=$($List.IsPresent); no packages will be changed."
    }
    Write-BootstrapRecord -Level WARN -Message 'Package installation remains the original Phase-1 placeholder and is not applicable yet.'
    exit 2
} catch {
    Write-BootstrapRecord -Level ERROR -Message $_.Exception.Message
    exit 1
}
