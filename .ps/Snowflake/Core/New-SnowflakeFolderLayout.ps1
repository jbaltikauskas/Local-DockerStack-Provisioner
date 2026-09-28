function New-SnowflakeFolderLayout () {
    <#
    .SYNOPSIS
        Creates the install root and config folder.
    .DESCRIPTION
        Creates installer-managed files plus a snowflake-dat data folder used
        by the emulator bind mount. Returns a hashtable containing local paths.
    .NOTES
        1. Build required paths.
        2. Create each directory.
        3. Return paths.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $paths = @{
            ServerRoot = $ServerRoot
            Config     = Join-Path $ServerRoot 'config'
            Data       = Join-Path $ServerRoot 'snowflake-dat'
        }

        foreach ($path in $paths.Values) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        return $paths
    }
}
