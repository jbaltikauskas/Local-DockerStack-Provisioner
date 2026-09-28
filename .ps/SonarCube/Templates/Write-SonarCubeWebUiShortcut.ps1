function Write-SonarCubeWebUiShortcut () {
    <#
    .SYNOPSIS
        Writes a Windows Internet Shortcut for the SonarQube Web UI.
    .DESCRIPTION
        Always refreshes SonarCube.url with the configured host and port.
    .NOTES
        1. Build the Web UI URL.
        2. Write SonarCube.url.
        3. Return the path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $path = Join-Path $ServerRoot 'SonarCube.url'
        Write-Utf8NoBom -Path $path -Content "[InternetShortcut]`nURL=http://${WebHost}:${Port}`n"
        return $path
    }
}
