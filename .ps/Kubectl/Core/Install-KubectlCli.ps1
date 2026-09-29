function Install-KubectlCli () {
    <#
    .SYNOPSIS
        Ensures the kubectl CLI is available on the current host.
    .DESCRIPTION
        When kubectl already resolves on PATH it is left as is. Otherwise the
        official stable release for this OS and architecture is downloaded from
        dl.k8s.io into DestinationDirectory and added to the session PATH, matching
        the manual "install kubectl binary" steps in the Kubernetes docs for
        Windows and macOS (and Linux). Throws when the version probe or download
        fails. Returns nothing.
    .NOTES
        1. Resolve the OS / architecture moniker for this host.
        2. Read the stable version tag from dl.k8s.io/release/stable.txt.
        3. Build the release URL and delegate to Install-PortableCli.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Folder kubectl is written to and added to PATH when downloaded.")]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationDirectory
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (Get-Command kubectl -ErrorAction SilentlyContinue) {
            Write-Host "kubectl already available: $((Get-Command kubectl).Source)" -ForegroundColor Green
            return
        }

        $platform = Get-HostPlatformMoniker

        $stableVersion = (Invoke-WebRequest -Uri 'https://dl.k8s.io/release/stable.txt').Content
        if ($stableVersion) {
            $stableVersion = $stableVersion.Trim()
        }

        if ([string]::IsNullOrWhiteSpace($stableVersion)) {
            throw "Could not resolve the stable kubectl version from dl.k8s.io/release/stable.txt."
        }

        $downloadUrl = "https://dl.k8s.io/release/{0}/bin/{1}/{2}/kubectl{3}" -f `
            $stableVersion, $platform.Os, $platform.Arch, $platform.ExeSuffix

        Install-PortableCli `
            -Command 'kubectl' `
            -DownloadUrl $downloadUrl `
            -DestinationDirectory $DestinationDirectory `
            -ExeSuffix $platform.ExeSuffix
    }
}
