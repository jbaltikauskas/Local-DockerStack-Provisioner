function Get-AspireDashboardStopScriptTemplate () {
    <#
    .SYNOPSIS
        Returns the generated Stop-AspireDashboard.ps1 script template.
    .DESCRIPTION
        The returned script stops the existing local compose containers.
    .NOTES
        1. Return the verbatim script template.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        return @'
<#
.SYNOPSIS
    Stops this Aspire Dashboard Docker stack.
.DESCRIPTION
    1. Resolve docker-compose.yml.
    2. Run docker compose stop.
.INPUTS
    None.
.OUTPUTS
    Docker Compose output.
.NOTES
    This installer does not create persistent dashboard data.
.EXAMPLE
    PS> .\Stop-AspireDashboard.ps1
.EXAMPLE
    PS> pwsh -File .\Stop-AspireDashboard.ps1
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

    & docker compose -f $composePath stop
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose stop failed with exit code $LASTEXITCODE."
    }
}
catch {
    Write-Error $_
    exit 1
}
'@
    }
}
