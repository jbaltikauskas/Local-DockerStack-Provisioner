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
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFileName
    )

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
