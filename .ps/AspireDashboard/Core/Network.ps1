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
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (-not (Test-TcpPortAvailable -Port $ConfiguredPort)) {
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
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
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
