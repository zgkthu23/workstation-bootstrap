<#
.SYNOPSIS
    工作站初始化编排脚本（Windows）。
.DESCRIPTION
    按顺序协调 create-directories、install-packages、clone-repositories、
    和 verify 脚本。支持试运行和幂等执行。
.PARAMETER DryRun
    仅展示将要执行的操作，不做实际修改。
.PARAMETER WhatIf
    DryRun 的别名。
.PARAMETER SkipPackages
    跳过软件包安装步骤。
.PARAMETER SkipRepos
    跳过仓库克隆步骤。
.PARAMETER Inventory
    inventory YAML 文件路径（默认：根据主机名自动检测）。
.EXAMPLE
    .\bootstrap.ps1 -DryRun
    .\bootstrap.ps1 -SkipPackages
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$WhatIf,
    [switch]$SkipPackages,
    [switch]$SkipRepos,
    [string]$Inventory
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptDir\..\.."

# 解析试运行标志
$isDryRun = $DryRun -or $WhatIf

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

# ==============================================================================
# 主流程
# ==============================================================================

Write-Host @"
╔══════════════════════════════════════════════════╗
║     workstation-bootstrap — Windows             ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Green

if ($isDryRun) {
    Write-Log 'INFO' '试运行模式 — 不会进行任何修改'
}

Write-Log 'INFO' "项目根目录: $projectRoot"

# 飞行前检查
Write-Step '飞行前检查'

$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Log 'INFO' "操作系统: $($osInfo.Caption)"
Write-Log 'INFO' "主机名: $env:COMPUTERNAME"

# 检查 PowerShell 版本
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 7) {
    Write-Log 'WARN' "PowerShell $psVersion — 建议升级到 PowerShell 7+"
} else {
    Write-Log 'INFO' "PowerShell $psVersion"
}

# 检查 Git
try {
    $gitVersion = & git --version 2>$null
    Write-Log 'INFO' "Git: $gitVersion"
} catch {
    Write-Log 'ERROR' 'Git 未安装。请先安装 Git。'
    exit 1
}

# 解析 inventory 文件
if (-not $Inventory) {
    $inventoryPath = "$projectRoot\inventory\windows-main.yaml"
    if (-not (Test-Path $inventoryPath)) {
        Write-Log 'ERROR' "未找到 inventory 文件: $inventoryPath"
        Write-Log 'INFO' '请从模板创建一份，或使用 -Inventory 参数指定路径'
        exit 1
    }
    $Inventory = $inventoryPath
}
Write-Log 'INFO' "Inventory: $Inventory"

# 步骤 1：创建目录
Write-Step '步骤 1: 创建目录结构'
$createDirsArgs = @{ Inventory = $Inventory }
if ($isDryRun) { $createDirsArgs['DryRun'] = $true }
& "$scriptDir\create-directories.ps1" @createDirsArgs
if ($LASTEXITCODE -ne 0) {
    Write-Log 'ERROR' '目录创建失败'
    exit $LASTEXITCODE
}

# 步骤 2：安装软件包
if (-not $SkipPackages) {
    Write-Step '步骤 2: 安装软件包'
    $installPkgsArgs = @{ Inventory = $Inventory }
    if ($isDryRun) { $installPkgsArgs['DryRun'] = $true }
    & "$scriptDir\install-packages.ps1" @installPkgsArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'WARN' '软件包安装出现错误（请查看上方输出）'
    }
} else {
    Write-Log 'INFO' '跳过软件包安装（--skip-packages）'
}

# 步骤 3：克隆仓库
if (-not $SkipRepos) {
    Write-Step '步骤 3: 克隆仓库'
    $cloneReposArgs = @{ Inventory = $Inventory }
    if ($isDryRun) { $cloneReposArgs['DryRun'] = $true }
    & "$scriptDir\clone-repositories.ps1" @cloneReposArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'WARN' '仓库克隆出现错误（请查看上方输出）'
    }
} else {
    Write-Log 'INFO' '跳过仓库克隆（--skip-repos）'
}

# 步骤 4：验证
Write-Step '步骤 4: 验证'
$verifyArgs = @{ Inventory = $Inventory }
& "$scriptDir\verify.ps1" @verifyArgs
$verifyExit = $LASTEXITCODE

Write-Step '初始化完成'
if ($isDryRun) {
    Write-Log 'INFO' '试运行结束。请查看上方输出，确认无误后去掉 -DryRun 重新运行。'
} else {
    Write-Log 'INFO' "初始化完成。验证退出码: $verifyExit"
}

exit $verifyExit