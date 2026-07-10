<#
.SYNOPSIS
    从 projects/repos.yaml 克隆 Git 仓库。
.DESCRIPTION
    读取 repos.yaml 并为当前主机克隆每个项目。
    安全策略：不覆盖已有仓库，有未提交更改时不强制拉取。
    支持试运行。
.PARAMETER DryRun
    展示将要克隆的仓库。
.PARAMETER Inventory
    inventory YAML 文件路径。
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
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

function Read-YamlFlat {
    param([string]$Path)
    $result = @{}
    foreach ($line in (Get-Content $Path)) {
        if ($line -match '^\s*(\w[\w_-]*):\s*"?(.+?)"?\s*$') {
            $result[$Matches[1]] = $Matches[2].Trim('"', '''')
        }
    }
    return $result
}

$inv = Read-YamlFlat $Inventory
$reposYaml = "$projectRoot\projects\repos.yaml"

if (-not (Test-Path $reposYaml)) {
    Write-Log 'ERROR' "未找到 repos.yaml: $reposYaml"
    exit 1
}

Write-Log 'INFO' "仓库配置: $reposYaml"
Write-Log 'INFO' "工作区根目录: $($inv['workspace_root'])"
Write-Log 'INFO' '仓库克隆功能是 Phase 1 占位实现。'
Write-Log 'INFO' '完整实现将解析 repos.yaml 并克隆每个项目。'
Write-Log 'INFO' '安全规则：不覆盖已有仓库，有未提交更改时不强制拉取，支持试运行。'

if ($DryRun) {
    Write-Host ""
    Write-Host '[试运行] 将解析 repos.yaml 并为本机克隆仓库。' -ForegroundColor Yellow
    Write-Host '[试运行] 目标: WORKSPACE_ROOT\repos\<group>\<directory>' -ForegroundColor Yellow
}