function Get-RequiredConfigString () {
    <#
    .SYNOPSIS
        Reads a required non-empty string from an installer config file.
    .DESCRIPTION
        Returns the named property as a string and throws when it is absent or empty.
    .NOTES
        1. Read Name from Config.
        2. Throw when missing or empty.
        3. Return the string.
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

        $value = [string]$Config.$Name
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Required $ConfigFileName setting '$Name' is missing or empty."
        }

        return $value
    }
}

function Get-RequiredConfigPort () {
    <#
    .SYNOPSIS
        Reads and validates a required TCP port from an installer config file.
    .DESCRIPTION
        Returns the named property as an integer in the valid TCP port range.
    .NOTES
        1. Read Name from Config.
        2. Parse as integer.
        3. Validate range.
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

        $portValue = Get-RequiredConfigString -Config $Config -Name $Name -ConfigFileName $ConfigFileName
        $port = 0
        if (-not [int]::TryParse($portValue, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
            throw "$ConfigFileName $Name must be an integer in range 1..65535."
        }

        return $port
    }
}

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
