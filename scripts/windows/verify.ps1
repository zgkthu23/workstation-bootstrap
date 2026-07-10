<#
.SYNOPSIS
    Verify workstation state after bootstrap.
.DESCRIPTION
    Checks OS, hostname, inventory, directories, Git, package manager,
    and project structure. Returns non-zero exit code on issues.
.PARAMETER DryRun
    Show what would be verified.
.PARAMETER Inventory
    Path to inventory YAML file.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [Parameter(Mandatory=$true)]
    [string]$Inventory
)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptDir\..\.."

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN'  { 'Yellow' }
        'PASS'  { 'Green' }
        default { 'White' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

$errors = 0
$warnings = 0

Write-Host ""
Write-Host "=== Workstation Verification ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check OS
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Log 'INFO' "OS: $($osInfo.Caption)"
Write-Log 'INFO' "Hostname: $env:COMPUTERNAME"

# 2. Check inventory exists
if (-not (Test-Path $Inventory)) {
    Write-Log 'ERROR' "Inventory not found: $Inventory"
    $errors++
} else {
    Write-Log 'PASS' "Inventory found: $Inventory"
}

# 3. Check Git
try {
    $gitVersion = & git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'PASS' "Git: $gitVersion"
    } else {
        Write-Log 'ERROR' 'Git is not installed'
        $errors++
    }
} catch {
    Write-Log 'ERROR' 'Git is not installed'
    $errors++
}

# 4. Check winget
try {
    $wingetVersion = & winget --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'PASS' "winget: $wingetVersion"
    } else {
        Write-Log 'WARN' 'winget not available'
        $warnings++
    }
} catch {
    Write-Log 'WARN' 'winget not available'
    $warnings++
}

# 5. Check repos.yaml exists
$reposYaml = "$projectRoot\projects\repos.yaml"
if (Test-Path $reposYaml) {
    Write-Log 'PASS' "repos.yaml found"
} else {
    Write-Log 'ERROR' "repos.yaml not found: $reposYaml"
    $errors++
}

# 6. Check for secrets in repo
$secretsScan = "$projectRoot\tests\test_no_secrets.py"
if (Test-Path $secretsScan) {
    Write-Log 'INFO' "Running secret scan..."
    try {
        $result = & uv run python $secretsScan 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'PASS' 'Secret scan: clean'
        } else {
            Write-Log 'WARN' 'Secret scan found issues (see above)'
            $warnings++
        }
    } catch {
        Write-Log 'WARN' "Could not run secret scan: $_"
        $warnings++
    }
}

# 7. Summary
Write-Host ""
Write-Host "=== Verification Summary ===" -ForegroundColor Cyan
Write-Host "Errors  : $errors" -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'Green' })
Write-Host "Warnings: $warnings" -ForegroundColor $(if ($warnings -gt 0) { 'Yellow' } else { 'Green' })

if ($errors -gt 0) {
    Write-Host "VERIFICATION FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "VERIFICATION PASSED" -ForegroundColor Green
    exit 0
}