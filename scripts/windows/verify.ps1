<#
.SYNOPSIS
    初始化后验证工作站状态。
.DESCRIPTION
    检查操作系统、主机名、inventory、目录、Git、包管理器
    和项目结构。发现问题时返回非零退出码。
.PARAMETER Inventory
    inventory YAML 文件路径。
#>

[CmdletBinding()]
param(
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
Write-Host "=== 工作站验证 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 检查操作系统
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Log 'INFO' "操作系统: $($osInfo.Caption)"
Write-Log 'INFO' "主机名: $env:COMPUTERNAME"

# 2. 检查 inventory 是否存在
if (-not (Test-Path $Inventory)) {
    Write-Log 'ERROR' "未找到 inventory: $Inventory"
    $errors++
} else {
    Write-Log 'PASS' "已找到 inventory: $Inventory"
}

# 3. 检查 Git
try {
    $gitVersion = & git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'PASS' "Git: $gitVersion"
    } else {
        Write-Log 'ERROR' 'Git 未安装'
        $errors++
    }
} catch {
    Write-Log 'ERROR' 'Git 未安装'
    $errors++
}

# 4. 检查 winget
try {
    $wingetVersion = & winget --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Log 'PASS' "winget: $wingetVersion"
    } else {
        Write-Log 'WARN' 'winget 不可用'
        $warnings++
    }
} catch {
    Write-Log 'WARN' 'winget 不可用'
    $warnings++
}

# 5. 检查 repos.yaml 是否存在
$reposYaml = "$projectRoot\projects\repos.yaml"
if (Test-Path $reposYaml) {
    Write-Log 'PASS' "已找到 repos.yaml"
} else {
    Write-Log 'ERROR' "未找到 repos.yaml: $reposYaml"
    $errors++
}

# 6. 扫描仓库中的密钥
$secretsScan = "$projectRoot\tests\test_no_secrets.py"
if (Test-Path $secretsScan) {
    Write-Log 'INFO' "正在运行密钥扫描..."
    try {
        & uv run python $secretsScan 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'PASS' '密钥扫描: 无问题'
        } else {
            Write-Log 'WARN' '密钥扫描发现问题（见上方输出）'
            $warnings++
        }
    } catch {
        Write-Log 'WARN' "无法运行密钥扫描: $_"
        $warnings++
    }
}

# 7. 汇总
Write-Host ""
Write-Host "=== 验证汇总 ===" -ForegroundColor Cyan
Write-Host "错误: $errors" -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'Green' })
Write-Host "警告: $warnings" -ForegroundColor $(if ($warnings -gt 0) { 'Yellow' } else { 'Green' })

if ($errors -gt 0) {
    Write-Host "验证未通过" -ForegroundColor Red
    exit 1
} else {
    Write-Host "验证通过" -ForegroundColor Green
    exit 0
}