<#
.SYNOPSIS
    创建 Windows 工作区目录结构。
.DESCRIPTION
    读取 inventory YAML 文件，创建逻辑根目录和工作区布局。
    支持幂等执行——可安全地多次运行。
.PARAMETER DryRun
    展示将要创建的目录。
.PARAMETER Force
    对目录创建无效（mkdir -Force 本身是安全的）。
.PARAMETER Inventory
    inventory YAML 文件路径。
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [Parameter(Mandatory=$true)]
    [string]$Inventory
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptDir\..\.."

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

# 简易 YAML 读取器（无外部依赖）
# ponytail: 极简 inventory YAML 解析器——仅处理我们使用的扁平结构
function Read-Inventory {
    param([string]$Path)
    $content = Get-Content $Path -Raw
    $result = @{}
    $lines = $content -split "`n"
    foreach ($line in $lines) {
        if ($line -match '^\s*(\w[\w_]*):\s*"?(.+?)"?\s*$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim('"', '''')
            $result[$key] = $value
        } elseif ($line -match '^\s*(\w[\w_]*):\s*(.+?)\s*$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value -ne '') { $result[$key] = $value }
        }
    }
    return $result
}

$inv = Read-Inventory $Inventory

$roots = @(
    $inv['workspace_root'],
    $inv['data_root'],
    $inv['scratch_root']
)
if ($inv.ContainsKey('cloud_root') -and $inv['cloud_root']) {
    $roots += $inv['cloud_root']
}

$workspace = $inv['workspace_root']
$workspaceDirs = @(
    "$workspace\repos\work",
    "$workspace\repos\personal",
    "$workspace\repos\research",
    "$workspace\repos\tools",
    "$workspace\repos\experiments",
    "$workspace\artifacts\releases",
    "$workspace\artifacts\reports",
    "$workspace\artifacts\exports",
    "$workspace\shared\templates",
    "$workspace\shared\scripts"
)

$allDirs = $roots + $workspaceDirs

Write-Log 'INFO' "Inventory: $Inventory"
Write-Log 'INFO' "根目录: $($roots -join ', ')"

$created = 0
$existed = 0

foreach ($dir in $allDirs) {
    if (Test-Path $dir) {
        Write-Log 'INFO' "已存在: $dir"
        $existed++
    } else {
        if ($DryRun) {
            Write-Host "  [试运行] 将创建: $dir" -ForegroundColor Yellow
        } else {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log 'INFO' "已创建: $dir"
        }
        $created++
    }
}

Write-Host ""
Write-Log 'INFO' "汇总: $existed 个已存在, $created 个待创建" + $(if ($DryRun) { ' (试运行)' } else { '' })