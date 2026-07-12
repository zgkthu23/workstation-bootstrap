<# SCRIPT-METADATA
name: windows-install-package-manager
description: Ensures winget is available (preinstalled on Win11, installs App Installer on older versions).
platform: windows
inputs: -Inventory PATH, -DryRun, -OutputFormat text|json, -Help
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: 0=success, 1=error, 2=skipped-or-not-applicable
END-SCRIPT-METADATA #>
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

try {
    # Source common module
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectRoot = Resolve-Path "$ScriptDir\..\.."
    Import-Module "$ProjectRoot\scripts\lib\Bootstrap.Common.psm1" -Force

    Initialize-BootstrapRuntime "install-package-manager" -OutputFormat $OutputFormat

    # On Windows 10, winget may be an app-execution-alias stub that Get-Command resolves
    # but doesn't actually run. Verify by executing it.
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            $null = winget --version 2>&1
            Write-BootstrapRecord -Level SUCCESS -Message "winget 已可用"
            exit 0
        } catch {
            Write-BootstrapRecord -Level WARN -Message "winget 检测到但无法运行，将尝试安装"
        }
    }

    if ($DryRun) {
        Write-BootstrapRecord -Level SUCCESS -Message "[DRY-RUN] 将安装 App Installer"
        exit 0
    }

    Write-BootstrapRecord -Level INFO -Message "正在安装 App Installer（winget）..."
    # App Installer is available from the Microsoft Store or via msixbundle
    # On Windows 10, download from GitHub
    $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $out = "$env:TEMP\AppInstaller.msixbundle"
    Invoke-WebRequest -Uri $url -OutFile $out
    Add-AppxPackage -Path $out

    Write-BootstrapRecord -Level WARN -Message "winget 安装后需重启终端才能使用"
    exit 0
} catch {
    Write-BootstrapRecord -Level ERROR -Message "安装失败: $_"
    exit 1
}