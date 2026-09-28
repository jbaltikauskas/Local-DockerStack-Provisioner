function Resolve-MSSqlInstallerPort () {
    <#
    .SYNOPSIS
        Validates the MSSQL port loaded from config-mssql.json.
    .DESCRIPTION
        Returns the configured port when available and throws when it is already in use.
    .NOTES
        1. Check the configured port.
        2. Throw when busy.
        3. Return the configured port.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$ConfiguredPort
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (-not (Test-TcpPortAvailable -Port $ConfiguredPort)) {
            throw "Configured PORT $ConfiguredPort is already in use. Change PORT in config-mssql.json."
        }

        return $ConfiguredPort
    }
}
