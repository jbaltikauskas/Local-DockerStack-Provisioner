function Resolve-SnowflakeInstallerPort () {
    <#
    .SYNOPSIS
        Validates the Snowflake port loaded from config-snowflake.json.
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
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (-not (Test-TcpPortAvailable -Port $ConfiguredPort)) {
            throw "Configured PORT $ConfiguredPort is already in use. Change PORT in config-snowflake.json."
        }

        return $ConfiguredPort
    }
}
