function Enable-DockerDesktopKubernetes () {
    <#
    .SYNOPSIS
        Ensures a Kubernetes cluster is available, enabling Docker Desktop's
        Kubernetes on Windows when it is off.
    .DESCRIPTION
        First probes the cluster with Test-KubernetesNodeReady; when a node
        answers, it returns immediately and changes nothing. Otherwise, on Windows
        with Docker Desktop installed, it stops Docker Desktop and its service,
        sets the Kubernetes-enabled flag in Docker Desktop's settings file
        (settings-store.json on current versions, settings.json on older ones),
        relaunches Docker Desktop, and polls until a node is Ready or
        TimeoutSeconds elapses. On non-Windows hosts, or when Docker Desktop is not
        installed, it returns without changes and leaves the final cluster check to
        report the problem. Throws only when it enabled Kubernetes but the node
        never became Ready.
    .NOTES
        1. Return when a node is already Ready.
        2. Return (skip) when not Windows or Docker Desktop is not installed.
        3. Stop Docker Desktop and its service.
        4. Set the Kubernetes-enabled flag in the resolved settings file.
        5. Relaunch Docker Desktop and poll until a node is Ready or the timeout.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Seconds to wait for a node to be Ready after enabling Kubernetes.")]
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 600
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (Test-KubernetesNodeReady) {
            Write-Host "Kubernetes node already Ready; leaving Docker Desktop untouched." -ForegroundColor Green
            return
        }

        if (-not $IsWindows) {
            Write-Host "No Kubernetes node and not on Windows; skipping Docker Desktop automation." -ForegroundColor Yellow
            return
        }

        $dockerDesktopExe = Join-Path $env:ProgramFiles 'Docker' 'Docker' 'Docker Desktop.exe'
        $dockerAppData = Join-Path $env:APPDATA 'Docker'
        $settingsPath = @('settings-store.json', 'settings.json') |
            ForEach-Object { Join-Path $dockerAppData $_ } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($settingsPath) -or -not (Test-Path -LiteralPath $dockerDesktopExe -PathType Leaf)) {
            Write-Host "Docker Desktop or its settings file was not found; skipping automatic Kubernetes enable." -ForegroundColor Yellow
            return
        }

        Write-Host "No Kubernetes node yet. Enabling Kubernetes in Docker Desktop ($settingsPath):" -ForegroundColor Yellow

        # 1. Stop Docker Desktop and its background service.
        Stop-Process -Name 'Docker Desktop' -Force -ErrorAction SilentlyContinue
        Stop-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        # 2-4. Read the settings file, enable Kubernetes, save it back. The key is
        # KubernetesEnabled on current Docker Desktop and kubernetesEnabled on older ones.
        try {

            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        }
        catch {
            throw "Could not parse Docker Desktop settings '$settingsPath': $($_.Exception.Message)"
        }

        $enabledKey = if ($settings.PSObject.Properties.Name -contains 'kubernetesEnabled') {
            'kubernetesEnabled'
        }
        else {
            'KubernetesEnabled'
        }

        $settings.$enabledKey = $true
        $settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath -Encoding utf8NoBOM

        # 5. Relaunch Docker Desktop and wait for the node to come up.
        Start-Process $dockerDesktopExe
        Write-Host "Relaunched Docker Desktop. Waiting up to $TimeoutSeconds seconds for a Ready node ..." -ForegroundColor Yellow

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            if (Test-KubernetesNodeReady) {
                Write-Host "Kubernetes node is Ready." -ForegroundColor Green
                return
            }

            Start-Sleep -Seconds 10
        }

        throw "Kubernetes did not become Ready within $TimeoutSeconds seconds after enabling it in Docker Desktop. Open Docker Desktop, confirm Kubernetes is starting, then rerun."
    }
}
