<#
SCRIPT-METADATA
name: windows-bootstrap-compatibility
description: Legacy Windows bootstrap path that delegates unchanged options to orchestrate.ps1.
platform: windows
inputs: same interface as scripts/windows/orchestrate.ps1
outputs: delegated stdout/stderr records
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

$arguments = @{ OutputFormat = $OutputFormat }
if ($Inventory) { $arguments.Inventory = $Inventory }
if ($Manifest) { $arguments.Manifest = $Manifest }
if ($Task) { $arguments.Task = $Task }
if ($DryRun -or $WhatIf) { $arguments.DryRun = $true }
if ($SkipPackages) { $arguments.SkipPackages = $true }
if ($SkipRepos) { $arguments.SkipRepos = $true }
if ($ListTasks) { $arguments.ListTasks = $true }
if ($Help) { $arguments.Help = $true }

& (Join-Path $PSScriptRoot 'orchestrate.ps1') @arguments
exit $LASTEXITCODE
