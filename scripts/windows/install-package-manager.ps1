# SCRIPT-METADATA
# name: windows-install-package-manager
# description: Ensures winget is available (preinstalled on Win11, installs App Installer on older versions).
# platform: windows
# inputs: -Inventory PATH, -DryRun, -OutputFormat text|json, -Help
# outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
# exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
# END-SCRIPT-METADATA
param(
    [string]$Inventory,
    [switch]$DryRun,
    [ValidateSet("text", "json")]
    [string]$OutputFormat = "text",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Host "Usage: install-package-manager.ps1 [-Inventory PATH] [-DryRun] [-OutputFormat text|json] [-Help]"
    Write-Host "Ensures winget is available."
    exit 0
}

# Source common module
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
. "$ProjectRoot\scripts\lib\Bootstrap.Common.psm1"

Initialize-Bootstrap "install-package-manager" -OutputFormat $OutputFormat

# winget is built into Windows 11. Check if available.
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-BootstrapLog "SUCCESS" "install-package-manager" "winget 已可用（Windows 11 自带）"
    exit 0
}

if ($DryRun) {
    Write-BootstrapLog "SUCCESS" "install-package-manager" "[DRY-RUN] 将安装 App Installer"
    exit 0
}

Write-BootstrapLog "INFO" "install-package-manager" "正在安装 App Installer（winget）..."
# App Installer is available from the Microsoft Store or via msixbundle
# On Windows 10, download from GitHub
$url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
$out = "$env:TEMP\AppInstaller.msixbundle"
Invoke-WebRequest -Uri $url -OutFile $out
Add-AppxPackage -Path $out

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-BootstrapLog "SUCCESS" "install-package-manager" "winget 安装成功"
} else {
    Write-BootstrapLog "ERROR" "install-package-manager" "winget 安装失败"
    exit 1
}