<#
.SYNOPSIS
    通过 winget 安装 Windows 软件包。
.DESCRIPTION
    读取 inventory 和清单文件，为已启用的功能安装软件包。
    支持试运行、列表和验证模式。
.PARAMETER DryRun
    展示将要安装的软件包。
.PARAMETER List
    列出已启用功能的所有软件包，不执行安装。
.PARAMETER Inventory
    inventory YAML 文件路径。
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$List,
    [Parameter(Mandatory=$true)]
    [string]$Inventory
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

# 简易 YAML 读取器（与 create-directories 相同）
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

Write-Log 'INFO' '正在检查 winget 可用性...'
try {
    $wingetVersion = & winget --version 2>$null
    Write-Log 'INFO' "winget: $wingetVersion"
} catch {
    Write-Log 'ERROR' 'winget 不可用。请从 Microsoft Store 安装应用安装程序。'
    exit 1
}

Write-Log 'INFO' '软件包安装功能在 Phase 1 中尚未实现。'
Write-Log 'INFO' '这是一个占位脚本，后续将解析清单文件并通过 winget 安装。'
Write-Log 'INFO' 'inventory 中的功能分组将从 manifests/ 目录读取。'
Write-Log 'INFO' "DryRun: $DryRun, List: $List"

if ($DryRun -or $List) {
    Write-Host ""
    Write-Host '[试运行] 将解析清单文件并为已启用功能安装软件包。' -ForegroundColor Yellow
    Write-Host '[试运行] 软件包来源: manifests\common.yaml, manifests\windows.yaml' -ForegroundColor Yellow
}