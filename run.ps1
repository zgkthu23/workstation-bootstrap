<#
SCRIPT-METADATA
name: run-powershell
description: Canonical PowerShell entry point; selects and delegates to the native manifest-driven orchestrator.
platform: windows, ubuntu, macos
inputs: -Inventory PATH, -Manifest PATH, -Task ID, -DryRun, -WhatIf, -SkipPackages, -SkipRepos, -OutputFormat text|json, -ListTasks, -Help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
END-SCRIPT-METADATA
#>
[CmdletBinding()]
param(
    [string]$Inventory,
    [string]$Manifest,
    [string]$Task,
    [switch]$DryRun,
    [switch]$WhatIf,
    [switch]$SkipPackages,
    [switch]$SkipRepos,
    [string]$OutputFormat = 'text',
    [switch]$ListTasks,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    Import-Module (Join-Path $projectRoot 'scripts\lib\Bootstrap.Common.psm1') -Force
    Initialize-BootstrapRuntime -Component 'run-powershell' -OutputFormat $OutputFormat
} catch {
    [Console]::Error.WriteLine("[ERROR] $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) [run-powershell] Runtime initialization failed: $($_.Exception.Message)")
    exit 1
}

try {
    $isWindowsHost = $PSVersionTable.PSEdition -eq 'Desktop' -or
        ((Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) -and $IsWindows)

    if ($isWindowsHost) {
        $arguments = @{ OutputFormat = $OutputFormat }
        if ($Inventory) { $arguments.Inventory = $Inventory }
        if ($Manifest) { $arguments.Manifest = $Manifest }
        if ($Task) { $arguments.Task = $Task }
        if ($DryRun -or $WhatIf) { $arguments.DryRun = $true }
        if ($SkipPackages) { $arguments.SkipPackages = $true }
        if ($SkipRepos) { $arguments.SkipRepos = $true }
        if ($ListTasks) { $arguments.ListTasks = $true }
        if ($Help) { $arguments.Help = $true }
        & (Join-Path $projectRoot 'scripts\windows\orchestrate.ps1') @arguments
        exit $LASTEXITCODE
    }

    $bashArguments = @('--output-format', $OutputFormat)
    if ($Inventory) { $bashArguments += @('--inventory', $Inventory) }
    if ($Manifest) { $bashArguments += @('--manifest', $Manifest) }
    if ($Task) { $bashArguments += @('--task', $Task) }
    if ($DryRun -or $WhatIf) { $bashArguments += '--dry-run' }
    if ($SkipPackages) { $bashArguments += '--skip-packages' }
    if ($SkipRepos) { $bashArguments += '--skip-repos' }
    if ($ListTasks) { $bashArguments += '--list-tasks' }
    if ($Help) { $bashArguments += '--help' }
    & bash (Join-Path $projectRoot 'run.sh') @bashArguments
    exit $LASTEXITCODE
} catch {
    Write-BootstrapRecord -Level ERROR -Message $_.Exception.Message
    exit 1
}
