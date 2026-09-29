function Install-KubectlCli () {
    <#
    .SYNOPSIS
        Ensures the kubectl CLI is available on the current host.
    .DESCRIPTION
        Leaves kubectl alone when it already resolves on PATH. On Windows, kubectl
        is installed through winget (winget install -e --id Kubernetes.kubectl);
        when winget itself is missing, the winget install guide is opened in the
        default browser and the function throws so the user can install winget and
        rerun. On Linux and macOS, the official stable single-binary release for
        this OS/architecture is downloaded from dl.k8s.io into DestinationDirectory
        and added to the session PATH, matching the "install kubectl binary" steps
        in the Kubernetes docs. Throws when an install step fails or kubectl still
        cannot be resolved. Returns nothing.
    .NOTES
        1. Return early when kubectl is already on PATH.
        2. On Windows: require winget (open its install guide and throw when
           missing), winget install kubectl, then refresh the session PATH.
        3. On Linux/macOS: resolve the stable version and download the binary via
           Install-PortableCli.
        4. Throw when kubectl still does not resolve.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Folder kubectl is written to and added to PATH when downloaded (Linux/macOS).")]
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

        if ($IsWindows) {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                $wingetHelpUrl = 'https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/deployment/install-winget-windows-iot'
                Write-Host "winget is not installed. Opening the winget install guide in your browser:" -ForegroundColor Yellow
                Write-Host "    $wingetHelpUrl" -ForegroundColor Cyan
                Start-Process $wingetHelpUrl
                throw "winget is required to install kubectl on Windows but was not found. Install winget (App Installer) from the opened guide, then rerun."
            }

            Write-Host "Installing kubectl via winget (Kubernetes.kubectl):" -ForegroundColor Yellow
            & winget install -e --id Kubernetes.kubectl --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                throw "winget install of Kubernetes.kubectl failed with exit code $LASTEXITCODE."
            }

            # winget updates PATH for new shells; refresh this session from the registry.
            $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
            $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
            $env:PATH = "$machinePath$([System.IO.Path]::PathSeparator)$userPath"

            if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
                throw "kubectl was installed with winget but is not on PATH in this session yet. Open a new terminal and rerun."
            }

            Write-Host "Installed kubectl: $((Get-Command kubectl).Source)" -ForegroundColor Green
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
