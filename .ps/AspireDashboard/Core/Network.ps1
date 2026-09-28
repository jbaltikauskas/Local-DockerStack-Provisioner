function Test-AspireDashboardTcpPortAvailable () {
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

function Resolve-AspireDashboardBindAddressFromHostName () {
    <#
    .SYNOPSIS
        Maps HOST_NAME from config-aspire-dashboard.json to a Docker port-bind address.
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

function Resolve-AspireDashboardInstallerPort () {
    <#
    .SYNOPSIS
        Validates an Aspire Dashboard port loaded from config-aspire-dashboard.json.
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
        [int]$ConfiguredPort,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SettingName
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (-not (Test-AspireDashboardTcpPortAvailable -Port $ConfiguredPort)) {
            throw "Configured $SettingName $ConfiguredPort is already in use. Change $SettingName in config-aspire-dashboard.json."
        }

        return $ConfiguredPort
    }
}

function Assert-AspireDashboardDistinctPorts () {
    <#
    .SYNOPSIS
        Verifies the configured Aspire Dashboard host ports are distinct.
    .DESCRIPTION
        Docker cannot bind multiple container ports to the same host port.
    .NOTES
        1. Group configured ports.
        2. Throw when any host port is repeated.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int[]]$Ports
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $duplicates = $Ports | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($duplicates) {
            $duplicatePorts = ($duplicates | ForEach-Object { $_.Name }) -join ', '
            throw "Aspire Dashboard host ports must be distinct. Duplicate port(s): $duplicatePorts."
        }
    }
}
