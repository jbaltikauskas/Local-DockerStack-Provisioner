function Install-PortableCli () {
    <#
    .SYNOPSIS
        Ensures a single-binary CLI is available, downloading it when missing.
    .DESCRIPTION
        Shared, installer-agnostic helper for tools that ship as one static
        executable (kubectl, argocd). When Command already resolves on PATH it is
        left untouched. Otherwise the binary is downloaded from DownloadUrl into
        DestinationDirectory as "<Command><ExeSuffix>", marked executable on
        Linux and macOS, and its folder is prepended to the current session's
        PATH so later steps can invoke it. Throws when the download fails or the
        command still cannot be resolved afterwards. Returns nothing.
    .NOTES
        1. Return early when Command is already on PATH.
        2. Create DestinationDirectory and download the binary into it.
        3. Mark the binary executable on non-Windows hosts.
        4. Prepend DestinationDirectory to the session PATH.
        5. Throw when Command still does not resolve.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Command name to look for and install, for example 'kubectl'.")]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory = $true, HelpMessage = "URL of the single static executable to download.")]
        [ValidateNotNullOrEmpty()]
        [string]$DownloadUrl,

        [Parameter(Mandatory = $true, HelpMessage = "Folder the binary is written to and added to PATH.")]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationDirectory,

        [Parameter(Mandatory = $false, HelpMessage = "Executable suffix for the OS ('.exe' on Windows, otherwise empty).")]
        [AllowEmptyString()]
        [string]$ExeSuffix = ''
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $existing = Get-Command $Command -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "$Command already available: $($existing.Source)" -ForegroundColor Green
            return
        }

        Write-Host "$Command not found. Downloading from:" -ForegroundColor Yellow
        Write-Host "    $DownloadUrl" -ForegroundColor Cyan

        if (-not (Test-Path -LiteralPath $DestinationDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
        }

        $targetPath = Join-Path $DestinationDirectory ("{0}{1}" -f $Command, $ExeSuffix)
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $targetPath

        if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            throw "Download of '$Command' did not produce a file at '$targetPath'."
        }

        if (-not $IsWindows) {
            & chmod +x $targetPath
            if ($LASTEXITCODE -ne 0) {
                throw "Could not mark '$targetPath' executable (chmod exit code $LASTEXITCODE)."
            }
        }

        $env:PATH = "$DestinationDirectory$([System.IO.Path]::PathSeparator)$env:PATH"

        $resolved = Get-Command $Command -ErrorAction SilentlyContinue
        if (-not $resolved) {
            throw "Installed '$Command' to '$targetPath' but it still does not resolve on PATH."
        }

        Write-Host "Installed $Command to: $($resolved.Source)" -ForegroundColor Green
        Write-Host "Add '$DestinationDirectory' to your PATH permanently to keep $Command available." -ForegroundColor DarkGray
    }
}
