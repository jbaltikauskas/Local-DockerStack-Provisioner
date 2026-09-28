function New-SonarCubeFolderLayout () {
    <#
    .SYNOPSIS
        Creates the install root and config folder.
    .DESCRIPTION
        SonarQube and PostgreSQL data use unique Docker named volumes created
        by Docker Compose. Returns a hashtable containing local config paths.
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
        }

        foreach ($path in $paths.Values) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        return $paths
    }
}
