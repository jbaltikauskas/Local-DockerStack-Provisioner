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
        [Parameter(Mandatory = $true, HelpMessage = "Root folder of the installed stack.")]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true, HelpMessage = "URL of the dashboard web UI.")]
        [ValidateNotNullOrEmpty()]
        [string]$DashboardUrl,

        [Parameter(Mandatory = $true, HelpMessage = "OTLP gRPC endpoint URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$OtlpGrpcEndpoint,

        [Parameter(Mandatory = $true, HelpMessage = "OTLP HTTP endpoint URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$OtlpHttpEndpoint,

        [Parameter(Mandatory = $true, HelpMessage = "Compose service name of the container.")]
        [ValidatePattern('^aspire-dashboard-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName,

        [Parameter(Mandatory = $true, HelpMessage = "Whether the dashboard allows anonymous access.")]
        [bool]$AllowAnonymous
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
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
