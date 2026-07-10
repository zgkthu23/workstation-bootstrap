<#
MODULE-METADATA
name: windows-runtime
description: Shared dependency-free logging, validation, and YAML-scalar helpers for PowerShell scripts.
platform: windows
interface: Import-Module this file; call Initialize-BootstrapRuntime before writing records.
outputs: stdout=[INFO|WARN|SUCCESS] records; stderr=[ERROR] records
exit_codes: functions throw or return values; callers own process exit codes.
END-MODULE-METADATA
#>

$script:BootstrapComponent = 'bootstrap'
$script:BootstrapOutputFormat = 'text'

function Initialize-BootstrapRuntime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Component,
        [string]$OutputFormat = 'text'
    )

    $script:BootstrapComponent = $Component
    $script:BootstrapOutputFormat = $OutputFormat.ToLowerInvariant()
    if ($script:BootstrapOutputFormat -notin @('text', 'json')) {
        $script:BootstrapOutputFormat = 'text'
        Write-BootstrapRecord -Level ERROR -Message 'Output format must be text or json.'
        throw 'Invalid output format.'
    }
}

function Write-BootstrapRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Component = $script:BootstrapComponent
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    if ($script:BootstrapOutputFormat -eq 'json') {
        $line = [ordered]@{
            schema_version = 1
            timestamp = $timestamp
            level = $Level
            component = $Component
            message = $Message
        } | ConvertTo-Json -Compress
    } else {
        $line = "[$Level] $timestamp [$Component] $Message"
    }

    if ($Level -eq 'ERROR') {
        [Console]::Error.WriteLine($line)
    } else {
        [Console]::Out.WriteLine($line)
    }
}

function Assert-BootstrapFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label not found: $Path"
    }
}

function Read-BootstrapYamlScalar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Key
    )

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match "^\s*$([Regex]::Escape($Key)):\s*(.*?)\s*$") {
            $value = ($Matches[1] -replace '\s+#.*$', '').Trim()
            return $value.Trim('"', "'")
        }
    }
    return ''
}

Export-ModuleMember -Function @(
    'Initialize-BootstrapRuntime',
    'Write-BootstrapRecord',
    'Assert-BootstrapFile',
    'Read-BootstrapYamlScalar'
)
