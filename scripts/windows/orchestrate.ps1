<#
SCRIPT-METADATA
name: windows-orchestrator
description: Reads MANIFEST.yaml and executes one task or the ordered Windows bootstrap workflow.
platform: windows
inputs: -Inventory PATH, -Manifest PATH, -Task ID, -DryRun, -WhatIf, -SkipPackages, -SkipRepos, -OutputFormat text|json, -ListTasks, -Help
outputs: stdout=[INFO|WARN|SUCCESS] workflow and child records; stderr=[ERROR] records
exit_codes: 0=success, 1=error, 2=selected-task-skipped-or-not-applicable
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
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
try {
    Import-Module (Join-Path $projectRoot 'scripts\lib\Bootstrap.Common.psm1') -Force
    Initialize-BootstrapRuntime -Component 'windows-orchestrator' -OutputFormat $OutputFormat
} catch {
    [Console]::Error.WriteLine("[ERROR] $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) [windows-orchestrator] Runtime initialization failed: $($_.Exception.Message)")
    exit 1
}

if (-not $Manifest) { $Manifest = Join-Path $projectRoot 'MANIFEST.yaml' }
if (-not $Inventory) { $Inventory = Join-Path $projectRoot 'inventory\windows-main.yaml' }
$isDryRun = $DryRun -or $WhatIf

function Show-Usage {
    [Console]::Out.WriteLine(@'
Usage: orchestrate.ps1 [options]
  -Inventory PATH          Host inventory (default: inventory/windows-main.yaml).
  -Manifest PATH           Execution manifest (default: project MANIFEST.yaml).
  -Task ID                 Run one declared bootstrap task instead of the workflow.
  -DryRun, -WhatIf         Forward dry-run mode to tasks that declare it.
  -SkipPackages            Do not invoke the install-packages step.
  -SkipRepos               Do not invoke the clone-repositories step.
  -OutputFormat text|json  Emit text records (default) or NDJSON records.
  -ListTasks               List task IDs and paths without executing them.
  -Help                    Show this help.
'@)
}

function Get-ManifestSteps {
    param([string]$Path)
    $steps = [Collections.Generic.List[object]]::new()
    $active = $false
    $current = $null
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^bootstrap_steps:\s*$') { $active = $true; continue }
        if ($active -and $line -match '^\S') { break }
        if (-not $active) { continue }
        if ($line -match '^  - id:\s*(.+?)\s*$') {
            if ($null -ne $current) { $steps.Add([pscustomobject]$current) }
            $current = [ordered]@{
                Id = $Matches[1].Trim('"')
                Order = $null
                Windows = ''
                Forwards = ''
                SkipOption = 'none'
                FailurePolicy = 'continue'
            }
            continue
        }
        if ($null -eq $current) { continue }
        if ($line -match '^    (order|windows|forwards|skip_option|failure_policy):\s*(.*?)\s*$') {
            $value = $Matches[2].Trim('"')
            switch ($Matches[1]) {
                order { $current.Order = [int]$value }
                windows { $current.Windows = $value }
                forwards { $current.Forwards = $value }
                skip_option { $current.SkipOption = $value }
                failure_policy { $current.FailurePolicy = $value }
            }
        }
    }
    if ($null -ne $current) { $steps.Add([pscustomobject]$current) }
    return $steps | Sort-Object Order
}

if ($Help) { Show-Usage; exit 0 }

try {
    Assert-BootstrapFile -Path $Manifest -Label 'Manifest'
    $steps = @(Get-ManifestSteps -Path $Manifest)
    if ($steps.Count -eq 0) { throw 'Manifest contains no bootstrap_steps.' }

    if ($ListTasks) {
        foreach ($step in $steps) {
            Write-BootstrapRecord -Level INFO -Component 'task-catalog' -Message "$($step.Order) $($step.Id) $($step.Windows)"
        }
        Write-BootstrapRecord -Level SUCCESS -Component 'windows-orchestrator' -Message "$($steps.Count) task(s) declared."
        exit 0
    }

    Assert-BootstrapFile -Path $Inventory -Label 'Inventory'
    $inventoryOs = Read-BootstrapYamlScalar -Path $Inventory -Key 'os'
    if ($inventoryOs -ne 'windows') {
        throw "Inventory os '$inventoryOs' does not match expected 'windows'."
    }
    Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message "Manifest: $Manifest"
    Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message "Inventory: $Inventory"
    if ($Task) { Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message "Selected task: $Task" }
    if ($isDryRun) { Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message 'Dry-run mode enabled.' }

    # Preserve the original full-bootstrap preflight. Directly selected tasks
    # stay independent and validate only their own declared prerequisites.
    if (-not $Task) {
        Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message "Operating system: $([Environment]::OSVersion.VersionString)"
        Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message "Hostname: $env:COMPUTERNAME"
        Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message "PowerShell: $($PSVersionTable.PSVersion)"
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw 'Git is required before bootstrap.'
        }
        $gitVersion = & git --version 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'Git version check failed during preflight.' }
        Write-BootstrapRecord -Level INFO -Component 'windows-orchestrator' -Message "Git: $gitVersion"
    }

    $matchedCount = 0
    $errorCount = 0
    $selectedStatus = 0
    foreach ($step in $steps) {
        if ($Task -and $step.Id -ne $Task) { continue }
        $matchedCount++

        $skip = ($step.SkipOption -eq 'skip-packages' -and $SkipPackages) -or
            ($step.SkipOption -eq 'skip-repos' -and $SkipRepos)
        if ($skip) {
            Write-BootstrapRecord -Level WARN -Component $step.Id -Message "Skipped by -$($step.SkipOption)."
            if ($Task) { $selectedStatus = 2 }
            continue
        }

        if (-not $step.Order -or -not $step.Windows -or
            $step.Windows.Contains('..') -or [IO.Path]::IsPathRooted($step.Windows)) {
            throw "Invalid manifest entry for step: $($step.Id)"
        }
        $stepPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $step.Windows))
        $rootPrefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if (-not $stepPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Step path escapes project root: $($step.Windows)"
        }
        Assert-BootstrapFile -Path $stepPath -Label 'Declared step script'

        $stepArguments = @{}
        $forwarded = @($step.Forwards -split ',')
        if ($forwarded -contains 'inventory') { $stepArguments.Inventory = $Inventory }
        if ($isDryRun -and $forwarded -contains 'dry-run') { $stepArguments.DryRun = $true }
        if ($forwarded -contains 'output-format') { $stepArguments.OutputFormat = $OutputFormat }

        Write-BootstrapRecord -Level INFO -Component $step.Id -Message "Starting step $($step.Order): $($step.Windows)"
        & $stepPath @stepArguments
        $stepExit = $LASTEXITCODE
        # Child scripts share this PowerShell process and initialize the imported
        # runtime module for their own component. Restore the parent context.
        Initialize-BootstrapRuntime -Component 'windows-orchestrator' -OutputFormat $OutputFormat
        switch ($stepExit) {
            0 { Write-BootstrapRecord -Level SUCCESS -Component $step.Id -Message 'Step completed.' }
            2 {
                Write-BootstrapRecord -Level WARN -Component $step.Id -Message 'Step reported skipped/not applicable.'
                if ($Task) { $selectedStatus = 2 }
            }
            default {
                if ($stepExit -ne 1) {
                    Write-BootstrapRecord -Level ERROR -Component $step.Id -Message "Unexpected exit code $stepExit; normalized to 1."
                } else {
                    Write-BootstrapRecord -Level ERROR -Component $step.Id -Message 'Step failed with exit code 1.'
                }
                $errorCount++
                if ($step.FailurePolicy -eq 'stop') { exit 1 }
            }
        }
    }

    if ($matchedCount -eq 0) { throw "Unknown task: $Task" }
    if ($errorCount -gt 0) {
        Write-BootstrapRecord -Level ERROR -Component 'windows-orchestrator' -Message "Workflow completed with $errorCount failed step(s)."
        exit 1
    }
    if ($Task -and $selectedStatus -eq 2) {
        Write-BootstrapRecord -Level WARN -Component 'windows-orchestrator' -Message "Task $Task did not apply."
        exit 2
    }
    Write-BootstrapRecord -Level SUCCESS -Component 'windows-orchestrator' -Message "$matchedCount task(s) processed successfully."
    exit 0
} catch {
    Write-BootstrapRecord -Level ERROR -Component 'windows-orchestrator' -Message $_.Exception.Message
    exit 1
}
