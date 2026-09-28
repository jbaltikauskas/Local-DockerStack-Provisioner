function Get-AspireDashboardStartScriptTemplate () {
    <#
    .SYNOPSIS
        Returns the generated Start-AspireDashboard.ps1 script template.
    .DESCRIPTION
        The returned script starts the existing local compose containers and prints the dashboard endpoints.
    .NOTES
        1. Return the verbatim script template.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        return @'
<#
.SYNOPSIS
    Starts this Aspire Dashboard Docker stack.
.DESCRIPTION
    1. Resolve docker-compose.yml.
    2. Start the existing containers and print their status.
    3. Print the dashboard and OTLP endpoints.
.INPUTS
    None.
.OUTPUTS
    Docker Compose status and endpoint URLs.
.NOTES
    Requires PowerShell 7.2+ and Docker Desktop.
.EXAMPLE
    PS> .\Start-AspireDashboard.ps1
#>
#Requires -Version 7.2
[CmdletBinding()]
Param ()
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
try {

    $composePath = Join-Path $PSScriptRoot 'docker-compose.yml'
    if (-not (Test-Path -LiteralPath $composePath -PathType Leaf)) {
        throw "docker-compose.yml not found: '$composePath'."
    }

    & docker compose -f $composePath start
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose start failed with exit code $LASTEXITCODE."
    }

    $runningContainers = & docker compose -f $composePath ps --filter status=running --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose ps failed with exit code $LASTEXITCODE."
    }
    if ([string]::IsNullOrWhiteSpace(($runningContainers -join [Environment]::NewLine))) {
        throw "No containers are running after docker compose start. Run the installer again to recreate the stack."
    }

    & docker compose -f $composePath ps
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose ps failed with exit code $LASTEXITCODE."
    }

    Write-Host ""
    Write-Host "Aspire Dashboard is starting." -ForegroundColor Green
    Write-Host "Dashboard UI      : __DASHBOARD_URL__" -ForegroundColor Cyan
    Write-Host "OTLP gRPC endpoint: __OTLP_GRPC_ENDPOINT__"
    Write-Host "OTLP HTTP endpoint: __OTLP_HTTP_ENDPOINT__"
}
catch {
    Write-Error $_
    exit 1
}
'@
    }
}
