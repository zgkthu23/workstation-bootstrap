<#
SCRIPT-METADATA
name: windows-verify
description: Verifies host prerequisites plus the project contract and repository secret scan.
platform: windows
inputs: -Inventory PATH, -OutputFormat text|json, -Help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: 0=success, 1=verification-error, 2=skipped-or-not-applicable
END-SCRIPT-METADATA
#>
[CmdletBinding()]
param(
    [string]$Inventory,
    [string]$OutputFormat = 'text',
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
try {
    Import-Module (Join-Path $projectRoot 'scripts\lib\Bootstrap.Common.psm1') -Force
    Initialize-BootstrapRuntime -Component 'verify' -OutputFormat $OutputFormat
} catch {
    [Console]::Error.WriteLine("[ERROR] $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) [verify] Runtime initialization failed: $($_.Exception.Message)")
    exit 1
}

function Show-Usage {
    [Console]::Out.WriteLine(@'
Usage: verify.ps1 -Inventory PATH [options]
  -Inventory PATH          Inventory YAML file (required).
  -OutputFormat text|json  Emit text records (default) or NDJSON records.
  -Help                    Show this help.
'@)
}

if ($Help) { Show-Usage; exit 0 }
if (-not $Inventory) {
    Write-BootstrapRecord -Level ERROR -Message '-Inventory is required.'
    exit 1
}

$errors = 0
$warnings = 0
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-BootstrapRecord -Level INFO -Message "Operating system: $($osInfo.Caption)"
} catch {
    Write-BootstrapRecord -Level WARN -Message "Could not query operating system details: $($_.Exception.Message)"
    $warnings++
}
Write-BootstrapRecord -Level INFO -Message "Hostname: $env:COMPUTERNAME"

if (Test-Path -LiteralPath $Inventory -PathType Leaf) {
    Write-BootstrapRecord -Level SUCCESS -Message "Inventory found: $Inventory"
} else {
    Write-BootstrapRecord -Level ERROR -Message "Inventory not found: $Inventory"
    $errors++
}

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($gitCommand) {
    $gitVersion = & git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-BootstrapRecord -Level SUCCESS -Message "Git available: $gitVersion"
    } else {
        Write-BootstrapRecord -Level ERROR -Message 'Git version check failed.'
        $errors++
    }
} else {
    Write-BootstrapRecord -Level ERROR -Message 'Git is not installed.'
    $errors++
}

$wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetCommand) {
    $wingetVersion = & winget --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-BootstrapRecord -Level SUCCESS -Message "winget available: $wingetVersion"
    } else {
        Write-BootstrapRecord -Level WARN -Message 'winget version check failed.'
        $warnings++
    }
} else {
    Write-BootstrapRecord -Level WARN -Message 'winget is unavailable.'
    $warnings++
}

$reposYaml = Join-Path $projectRoot 'projects\repos.yaml'
if (Test-Path -LiteralPath $reposYaml -PathType Leaf) {
    Write-BootstrapRecord -Level SUCCESS -Message "Repository manifest found: $reposYaml"
} else {
    Write-BootstrapRecord -Level ERROR -Message "Repository manifest not found: $reposYaml"
    $errors++
}

$pythonCommand = $null
if (Get-Command uv -ErrorAction SilentlyContinue) {
    & uv run --quiet python --version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $pythonCommand = 'uv' }
}
foreach ($candidate in 'python', 'python3', 'py') {
    if ($pythonCommand) { break }
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        if ($candidate -eq 'py') { & py -3 --version 2>$null | Out-Null }
        else { & $candidate --version 2>$null | Out-Null }
        if ($LASTEXITCODE -eq 0) { $pythonCommand = $candidate; break }
    }
}

if ($pythonCommand) {
    $validations = @(
        @{ Id = 'project-contract'; Path = (Join-Path $projectRoot 'tests\validate_manifests.py'); Arguments = @('--root', $projectRoot, '--output-format', $OutputFormat) },
        @{ Id = 'secret-scan'; Path = (Join-Path $projectRoot 'tests\test_no_secrets.py'); Arguments = @('--path', $projectRoot, '--output-format', $OutputFormat) }
    )
    foreach ($validation in $validations) {
        if (-not (Test-Path -LiteralPath $validation.Path -PathType Leaf)) {
            Write-BootstrapRecord -Level WARN -Message "Validation script not found: $($validation.Path)"
            $warnings++
            continue
        }
        Write-BootstrapRecord -Level INFO -Message "Running $($validation.Id) validation."
        if ($pythonCommand -eq 'uv') { & uv run --quiet python $validation.Path @($validation.Arguments) }
        elseif ($pythonCommand -eq 'py') { & py -3 $validation.Path @($validation.Arguments) }
        else { & $pythonCommand $validation.Path @($validation.Arguments) }
        $validationExit = $LASTEXITCODE
        if ($validationExit -eq 0) {
            Write-BootstrapRecord -Level SUCCESS -Message "$($validation.Id) validation passed."
        } else {
            Write-BootstrapRecord -Level WARN -Message "$($validation.Id) validation returned exit code $validationExit."
            $warnings++
        }
    }
} else {
    Write-BootstrapRecord -Level WARN -Message 'Python is unavailable; Python repository validations were not run.'
    $warnings++
}

if ($errors -gt 0) {
    Write-BootstrapRecord -Level ERROR -Message "Verification failed: errors=$errors, warnings=$warnings."
    exit 1
}
Write-BootstrapRecord -Level SUCCESS -Message "Verification passed: errors=0, warnings=$warnings."
exit 0
