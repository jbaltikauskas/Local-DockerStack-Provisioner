function Write-ArgoCdWebUiShortcut () {
    <#
    .SYNOPSIS
        Writes a browser shortcut to the Argo CD UI for the current OS.
    .DESCRIPTION
        Builds an https://WebHost:Port URL (the port-forwarded Argo CD server) and
        writes the shortcut in the format the host OS understands: a Windows
        Internet Shortcut (.url), a macOS web location (.webloc), or a Linux
        desktop entry (.desktop, marked executable). Overwrites any existing
        shortcut and returns the full path so the caller can report it.
    .NOTES
        1. Build the https URL from WebHost and Port.
        2. Branch on $IsWindows / $IsMacOS / $IsLinux to pick the format and file.
        3. Write the shortcut (UTF-8, no BOM), make it executable on Linux, return the path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Folder the shortcut file is written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true, HelpMessage = "Base file name for the shortcut; the OS-specific extension is appended.")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "Host the Argo CD UI is reachable on, for example localhost.")]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true, HelpMessage = "Local port the Argo CD UI is forwarded to (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $url = "https://{0}:{1}" -f $WebHost, $Port

        if ($IsWindows) {
            $path = Join-Path $ServerRoot ("{0}.url" -f $Name)
            $content = "[InternetShortcut]`nURL=$url`n"
        }
        elseif ($IsMacOS) {
            $path = Join-Path $ServerRoot ("{0}.webloc" -f $Name)
            $content = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>$url</string>
</dict>
</plist>
"@
        }
        else {
            $path = Join-Path $ServerRoot ("{0}.desktop" -f $Name)
            $content = @"
[Desktop Entry]
Type=Link
Name=$Name
URL=$url
Icon=text-html
"@
        }

        Write-Utf8NoBom -Path $path -Content $content

        if ($IsLinux) {
            & chmod +x $path
            if ($LASTEXITCODE -ne 0) {
                throw "Could not mark the desktop shortcut '$path' executable (chmod exit code $LASTEXITCODE)."
            }
        }

        return $path
    }
}
