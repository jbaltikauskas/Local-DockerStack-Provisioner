function Get-SonarCubeStartScriptTemplate () {
    <#
    .SYNOPSIS
        Returns the generated Start-SonarCube.ps1 script template.
    .DESCRIPTION
        The returned script starts the existing local compose containers and optionally opens the Web UI.
    .NOTES
        1. Return the verbatim script template.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        return @'
<#
.SYNOPSIS
    Starts this SonarQube Docker stack.
.DESCRIPTION
    1. Resolve docker-compose.yml.
    2. Set Docker Desktop vm.max_map_count.
    3. Start the existing containers and print their status.
    4. Optionally open the Web UI.
.PARAMETER Open
    Opens the Web UI after the stack starts. Default: true.
.INPUTS
    None.
.OUTPUTS
    Docker Compose status and the Web UI URL.
.NOTES
    Requires PowerShell 7.2+ and Docker Desktop.
.EXAMPLE
    PS> .\Start-SonarCube.ps1
.EXAMPLE
    PS> .\Start-SonarCube.ps1 -Open:$false
#>
#Requires -Version 7.2
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false, HelpMessage = "Open the Web UI after start.")]
    [bool]$Open = $true
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
try {

    $composePath = Join-Path $PSScriptRoot 'docker-compose.yml'
    if (-not (Test-Path -LiteralPath $composePath -PathType Leaf)) {
        throw "docker-compose.yml not found: '$composePath'."
    }

    & wsl.exe -d docker-desktop -u root -- sysctl -w vm.max_map_count=262144 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not set vm.max_map_count. Exit code: $LASTEXITCODE."
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

    Write-Host "Web UI: __WEB_URL__" -ForegroundColor Cyan
    if ($Open) {
        Start-Process '__WEB_URL__'
    }
}
catch {
    Write-Error $_
    exit 1
}
'@
    }
}
