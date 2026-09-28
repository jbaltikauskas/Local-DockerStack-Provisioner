function New-AspireDashboardFolderLayout () {
    <#
    .SYNOPSIS
        Creates the install root and config folder.
    .DESCRIPTION
        Aspire Dashboard has no installer-managed persistent data folder.
        Returns a hashtable containing local install paths.
    .NOTES
        1. Build required paths.
        2. Create each directory.
        3. Return paths.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Root folder of the installed stack.")]
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
