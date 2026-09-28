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
