function Write-InternetShortcut () {
    <#
    .SYNOPSIS
        Writes a Windows Internet Shortcut (.url) file pointing at a URL.
    .DESCRIPTION
        Shared, installer-agnostic helper. Always refreshes <Name>.url under
        ServerRoot with the supplied Url and returns the full path so callers
        can report or reuse it.
    .NOTES
        1. Build the <Name>.url path under ServerRoot.
        2. Write the [InternetShortcut] file.
        3. Return the path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Url
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $path = Join-Path $ServerRoot ("{0}.url" -f $Name)
        Write-Utf8NoBom -Path $path -Content "[InternetShortcut]`nURL=$Url`n"
        return $path
    }
}
