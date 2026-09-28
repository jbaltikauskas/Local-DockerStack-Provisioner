function Write-InternetShortcut () {
    <#
    .SYNOPSIS
        Writes a Windows Internet Shortcut (.url) file for a host and port.
    .DESCRIPTION
        Shared, installer-agnostic helper. Builds a scheme://WebHost:Port URL
        (http by default, https when -UseHttps is set), always refreshes
        <Name>.url under ServerRoot with it, and returns the full path so
        callers can report or reuse it.
    .NOTES
        1. Resolve the URL scheme from the -UseHttps flag.
        2. Build the <Name>.url path under ServerRoot.
        3. Write the [InternetShortcut] file and return the path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Root folder of the installed stack.")]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true, HelpMessage = "Base file name for the shortcut; .url is appended.")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "Host name used in the service URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true, HelpMessage = "TCP port the service listens on (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $false, HelpMessage = "Write an https:// URL instead of http://.")]
        [switch]$UseHttps
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $scheme = if ($UseHttps) { 'https' } else { 'http' }
        $path = Join-Path $ServerRoot ("{0}.url" -f $Name)
        Write-Utf8NoBom -Path $path -Content "[InternetShortcut]`nURL=${scheme}://${WebHost}:${Port}`n"
        return $path
    }
}
