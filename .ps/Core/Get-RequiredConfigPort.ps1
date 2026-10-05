function Get-RequiredConfigPort () {
    <#
    .SYNOPSIS
        Reads and validates a required TCP port from an installer config file.
    .DESCRIPTION
        Returns the named property as an integer in the valid TCP port range.
        Depends on Get-RequiredConfigString, which every installer also loads.
    .NOTES
        1. Read Name from Config.
        2. Parse as integer.
        3. Validate range.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Parsed configuration object read from the config JSON.")]
        [object]$Config,

        [Parameter(Mandatory = $true, HelpMessage = "Name of the configuration setting to read.")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "Name of the config JSON file to read settings from.")]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFileName
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        $portValue = Get-RequiredConfigString -Config $Config -Name $Name -ConfigFileName $ConfigFileName
        $port = 0
        if (-not [int]::TryParse($portValue, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
            throw "$ConfigFileName $Name must be an integer in range 1..65535."
        }

        return $port
    }
}
