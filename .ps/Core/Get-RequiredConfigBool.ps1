function Get-RequiredConfigBool () {
    <#
    .SYNOPSIS
        Reads a required Boolean from an installer config file.
    .DESCRIPTION
        Returns the named property as a Boolean and throws when it is absent or not Boolean-like.
    .NOTES
        1. Read Name from Config.
        2. Parse as Boolean.
        3. Return the Boolean.
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

        $property = $Config.PSObject.Properties[$Name]
        if ($null -eq $property) {
            throw "Required $ConfigFileName setting '$Name' is missing."
        }

        $value = $property.Value
        if ($value -is [bool]) {
            return $value
        }

        $boolValue = $false
        if ([bool]::TryParse([string]$value, [ref]$boolValue)) {
            return $boolValue
        }

        throw "$ConfigFileName $Name must be true or false."
    }
}
