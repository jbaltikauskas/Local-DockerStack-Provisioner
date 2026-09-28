function Get-MSSqlStopScriptTemplate () {
    <#
    .SYNOPSIS
        Returns the generated Stop-MSSql.ps1 script template.
    .DESCRIPTION
        The returned script stops the existing local compose containers without deleting the data folder.
    .NOTES
        1. Return the verbatim script template.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        return @'
<#
.SYNOPSIS
    Stops this MSSQL Server Docker stack.
.DESCRIPTION
    1. Resolve docker-compose.yml.
    2. Run docker compose stop.
.INPUTS
    None.
.OUTPUTS
    Docker Compose output.
.NOTES
    Persistent data in the local mssql_dev_data folder is preserved.
    Do not delete mssql_dev_data unless you intend to delete the data.
.EXAMPLE
    PS> .\Stop-MSSql.ps1
.EXAMPLE
    PS> pwsh -File .\Stop-MSSql.ps1
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
