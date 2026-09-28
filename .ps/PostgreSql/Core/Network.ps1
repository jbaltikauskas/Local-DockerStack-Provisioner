function Test-PostgreSqlTcpPortAvailable () {
    <#
    .SYNOPSIS
        Returns true when a TCP port has no local listener.
    .DESCRIPTION
        Checks active TCP listeners on the Windows host.
    .NOTES
        1. Query active listeners.
        2. Return whether Port is absent.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $listeners = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
        return -not ($listeners | Where-Object { $_.Port -eq $Port })
    }
}

function Resolve-PostgreSqlBindAddressFromHostName () {
    <#
    .SYNOPSIS
        Maps HOST_NAME from config-postgresql.json to a Docker port-bind address.
    .DESCRIPTION
        localhost resolves to 127.0.0.1. Literal 127.0.0.1 and 0.0.0.0 pass through.
    .NOTES
        1. Map localhost to 127.0.0.1.
        2. Accept 127.0.0.1 and 0.0.0.0.
        3. Throw for other values.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFileName
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        switch ($HostName) {
            'localhost' { return '127.0.0.1' }
            '127.0.0.1' { return '127.0.0.1' }
            '0.0.0.0'   { return '0.0.0.0' }
            default {
                throw "$ConfigFileName HOST_NAME must be localhost, 127.0.0.1, or 0.0.0.0."
            }
        }
    }
}

function Resolve-PostgreSqlInstallerPort () {
    <#
    .SYNOPSIS
        Validates the PostgreSQL port loaded from config-postgresql.json.
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

        if (-not (Test-PostgreSqlTcpPortAvailable -Port $ConfiguredPort)) {
            throw "Configured PORT $ConfiguredPort is already in use. Change PORT in config-postgresql.json."
        }

        return $ConfiguredPort
    }
}
