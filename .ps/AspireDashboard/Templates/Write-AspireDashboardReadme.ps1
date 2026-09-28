function Write-AspireDashboardReadme () {
    <#
    .SYNOPSIS
        Writes the install-folder README.md.
    .DESCRIPTION
        Documents dashboard endpoints, folder layout, and daily management commands.
    .NOTES
        1. Render and overwrite README.md.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DashboardUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OtlpGrpcEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OtlpHttpEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^aspire-dashboard-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [bool]$AllowAnonymous
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $path = Join-Path $ServerRoot 'README.md'
        $content = @"
# Aspire Dashboard Docker Install

Dashboard UI: ``$DashboardUrl``

OTLP gRPC endpoint: ``$OtlpGrpcEndpoint``

OTLP HTTP endpoint: ``$OtlpHttpEndpoint``

Anonymous access enabled: ``$AllowAnonymous``

## Commands

``````powershell
.\Start-AspireDashboard.ps1
.\Stop-AspireDashboard.ps1
.\Start-AspireDashboard.bat
.\Stop-AspireDashboard.bat
docker compose -f .\docker-compose.yml logs -f $ServiceName
``````

## Telemetry

Configure local apps to send telemetry to these endpoints:

- OTLP gRPC: ``$OtlpGrpcEndpoint``
- OTLP HTTP: ``$OtlpHttpEndpoint``

## Files

- ``docker-compose.yml`` runs the Aspire Dashboard container.
- ``config\.env`` contains non-secret dashboard environment settings.
- ``AspireDashboard.url`` opens the dashboard UI in a browser.

This installer does not create a persistent data folder.
"@
        Write-Utf8NoBom -Path $path -Content $content
    }
}
