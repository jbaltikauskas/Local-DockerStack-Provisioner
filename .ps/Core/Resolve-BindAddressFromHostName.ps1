function Resolve-BindAddressFromHostName () {
    <#
    .SYNOPSIS
        Maps a configured HOST_NAME value to a Docker port-bind address.
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
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
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
