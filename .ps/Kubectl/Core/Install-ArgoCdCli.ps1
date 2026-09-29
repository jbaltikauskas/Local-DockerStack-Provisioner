function Install-ArgoCdCli () {
    <#
    .SYNOPSIS
        Ensures the Argo CD CLI is available on the current host.
    .DESCRIPTION
        When argocd already resolves on PATH it is left as is. Otherwise the
        latest release for this OS and architecture is downloaded from the
        argo-cd GitHub releases into DestinationDirectory and added to the
        session PATH. The CLI is required for logging in and for creating and
        syncing the application in later steps. Throws when the download fails.
        Returns nothing.
    .NOTES
        1. Resolve the OS / architecture moniker for this host.
        2. Build the latest-release URL and delegate to Install-PortableCli.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Folder argocd is written to and added to PATH when downloaded.")]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationDirectory
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (Get-Command argocd -ErrorAction SilentlyContinue) {
            Write-Host "argocd already available: $((Get-Command argocd).Source)" -ForegroundColor Green
            return
        }

        $platform = Get-HostPlatformMoniker

        $downloadUrl = "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-{0}-{1}{2}" -f `
            $platform.Os, $platform.Arch, $platform.ExeSuffix

        Install-PortableCli `
            -Command 'argocd' `
            -DownloadUrl $downloadUrl `
            -DestinationDirectory $DestinationDirectory `
            -ExeSuffix $platform.ExeSuffix
    }
}
