#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ensures kubectl, installs Argo CD into the current cluster, and deploys the
    kustom-webapp example application.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Load helper modules and required runtime settings from
           config-kubectl.json next to this script.
        2. Resolve the install-output folder and a per-user tools folder.
        3. Ensure the kubectl and Argo CD CLIs are on PATH, downloading the
           official single-binary releases for this OS/architecture when missing.
        4. Verify kubectl can reach a running Kubernetes cluster.
        5. Create the argocd namespace when it does not exist.
        6. Server-side apply the Argo CD installation manifest.
        7. Wait for the argocd-server deployment to be ready.
        8. Print the resources in the argocd namespace (kubectl get all).
        9. Start a background kubectl port-forward to the Argo CD server.
        10. Retrieve the initial admin password and write it to a protected file.
        11. Log the Argo CD CLI in as admin through the port-forward.
        12. Create the dev and qa workload namespaces and print each namespace.
        13. Register the argo-examples Git repository with Argo CD.
        14. Create the kustom-webapp application from the repository.
        15. Run the first sync and wait until it is Synced and Healthy.
        16. Write a cross-platform browser shortcut to the Argo CD UI.
        17. Print a summary.

    Every runtime value (namespace names, port, URLs, application details) comes
    from config-kubectl.json; this script takes no parameters. Kubernetes
    namespaces must be lowercase RFC 1123 labels, so the requested Dev/QA
    namespaces are created as dev/qa.

.INPUTS
    None. All runtime settings come from config-kubectl.json.

.OUTPUTS
    Host messages, an admin-password file and a UI shortcut under the install
    folder, and a running background port-forward job. Exit code 0 on success,
    1 on failure.

.NOTES
    Requires PowerShell 7.2+ and a reachable Kubernetes cluster (for example the
    Kubernetes feature in Docker Desktop, or kind / minikube / k3d). kubectl and
    the Argo CD CLI are installed automatically when missing. The background
    port-forward stays alive only while this PowerShell window is open.

.EXAMPLE
    PS> .\Install-Kubectl.ps1
    Runs the full Argo CD bootstrap against the current kubectl context.

.EXAMPLE
    PS> pwsh ./Install-Kubectl.ps1
    Same bootstrap invoked explicitly through pwsh on Linux or macOS.
#>

#Requires -Version 7.2

[CmdletBinding()]
Param ()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$modulePath = Join-Path $scriptRoot '.ps' 'Kubectl'
if (-not (Test-Path -LiteralPath $modulePath -PathType Container)) {
    throw "Required helper folder not found: '$modulePath'."
}

try {

    Write-Host "Loading module files:" -ForegroundColor Green

    # Relative module paths are stored as segment arrays and combined portably,
    # so the loader never hardcodes a path separator (Windows / Linux / macOS).
    $moduleFiles = @(
        , @('..', 'Core', 'Get-RequiredConfigString.ps1')
        , @('..', 'Core', 'Get-HostPlatformMoniker.ps1')
        , @('..', 'Core', 'Install-PortableCli.ps1')
        , @('..', 'Core', 'Write-Utf8NoBom.ps1')
        , @('Core', 'Initialize-KubectlInstallerFromConfig.ps1')
        , @('Core', 'Install-KubectlCli.ps1')
        , @('Core', 'Install-ArgoCdCli.ps1')
        , @('Core', 'Assert-KubernetesCluster.ps1')
        , @('Core', 'New-KubernetesNamespace.ps1')
        , @('Core', 'Show-KubernetesResources.ps1')
        , @('Core', 'Install-ArgoCdManifest.ps1')
        , @('Core', 'Wait-ArgoCdServerReady.ps1')
        , @('Core', 'Get-ArgoCdInitialAdminPassword.ps1')
        , @('Core', 'Save-ArgoCdInitialAdminPassword.ps1')
        , @('Core', 'Start-ArgoCdPortForward.ps1')
        , @('Core', 'Connect-ArgoCdCli.ps1')
        , @('Core', 'Register-ArgoCdRepository.ps1')
        , @('Core', 'New-ArgoCdApplication.ps1')
        , @('Core', 'Sync-ArgoCdApplication.ps1')
        , @('Core', 'Write-ArgoCdWebUiShortcut.ps1')
    )

    foreach ($segments in $moduleFiles) {
        $moduleFile = $modulePath
        foreach ($segment in $segments) {
            $moduleFile = Join-Path $moduleFile $segment
        }

        Write-Host "$moduleFile"
        . $moduleFile
    }

    Write-Host "Done loading module files." -ForegroundColor Green

    # ---- 1. Load settings --------------------------------------------------
    Initialize-KubectlInstallerFromConfig -ScriptRoot $scriptRoot

    # ---- 2. Resolve output and tools folders -------------------------------
    if (-not (Test-Path -LiteralPath $InstallRootFolder -PathType Container)) {
        New-Item -ItemType Directory -Path $InstallRootFolder -Force | Out-Null
    }

    $toolsDirectory = Join-Path $HOME '.local-dockerstack-provisioner-tools'
    $secretsPath = Join-Path $InstallRootFolder 'argocd-admin-password.env'

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install folder    : $InstallRootFolder"
    Write-Output "Tools folder      : $toolsDirectory"
    Write-Output "Argo CD namespace : $ArgoNamespace"
    Write-Output "Port-forward      : https://${WebHost}:${PortForwardPort} -> service/argocd-server:443"
    Write-Output "Manifest          : $ArgoManifestUrl"
    Write-Output "Git repository    : $GitRepoUrl"
    Write-Output "Application        : $AppName ($AppPath -> namespace '$AppDestNamespace')"
    Write-Output "Workload namespaces: $($WorkloadNamespaces -join ', ')"
    Write-Output ""
    $PSBoundParameters | Out-String | Write-Output
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    # ---- 3. Ensure the CLIs ------------------------------------------------
    Write-Host "Ensuring kubectl and Argo CD CLIs:" -ForegroundColor Green
    Install-KubectlCli -DestinationDirectory $toolsDirectory
    Install-ArgoCdCli -DestinationDirectory $toolsDirectory

    # ---- 4. Verify the cluster ---------------------------------------------
    Assert-KubernetesCluster

    # ---- 5. argocd namespace -----------------------------------------------
    New-KubernetesNamespace -Name $ArgoNamespace

    # ---- 6. Apply the Argo CD manifest -------------------------------------
    Install-ArgoCdManifest -Namespace $ArgoNamespace -ManifestUrl $ArgoManifestUrl

    # ---- 7. Wait for the server --------------------------------------------
    Wait-ArgoCdServerReady -Namespace $ArgoNamespace

    # ---- 8. Show argocd resources ------------------------------------------
    Show-KubernetesResources -Namespace $ArgoNamespace

    # ---- 9. Port-forward ---------------------------------------------------
    $kubectlPath = (Get-Command kubectl).Source
    $portForwardJob = Start-ArgoCdPortForward `
        -Namespace $ArgoNamespace `
        -Port $PortForwardPort `
        -KubectlPath $kubectlPath

    # ---- 10. Initial admin password ----------------------------------------
    $adminPassword = Get-ArgoCdInitialAdminPassword -Namespace $ArgoNamespace
    $savedSecretsPath = Save-ArgoCdInitialAdminPassword -SecretsPath $secretsPath -Password $adminPassword
    Write-Host "Saved the initial admin password to: $savedSecretsPath" -ForegroundColor Cyan

    # ---- 11. Log in --------------------------------------------------------
    Connect-ArgoCdCli -WebHost $WebHost -Port $PortForwardPort -AdminLogin 'admin' -AdminPassword $adminPassword
    $adminPassword = $null

    # ---- 12. Workload namespaces -------------------------------------------
    Write-Host ""
    Write-Host "Creating workload namespaces:" -ForegroundColor Green
    foreach ($workloadNamespace in $WorkloadNamespaces) {
        New-KubernetesNamespace -Name $workloadNamespace
    }

    foreach ($workloadNamespace in $WorkloadNamespaces) {
        Show-KubernetesResources -Namespace $workloadNamespace
    }

    # ---- 13. Register the repository ----------------------------------------
    Register-ArgoCdRepository -RepoUrl $GitRepoUrl

    # ---- 14. Create the application ----------------------------------------
    New-ArgoCdApplication `
        -AppName $AppName `
        -RepoUrl $GitRepoUrl `
        -AppPath $AppPath `
        -Project $AppProject `
        -DestNamespace $AppDestNamespace

    # ---- 15. First sync ----------------------------------------------------
    Sync-ArgoCdApplication -AppName $AppName

    # ---- 16. UI shortcut ---------------------------------------------------
    $shortcutPath = Write-ArgoCdWebUiShortcut `
        -ServerRoot $InstallRootFolder `
        -Name 'ArgoCD' `
        -WebHost $WebHost `
        -Port $PortForwardPort

    # ---- 17. Summary -------------------------------------------------------
    Write-Host ""
    Write-Host "Argo CD is running." -ForegroundColor Green
    Write-Host "Web UI:        https://${WebHost}:${PortForwardPort}" -ForegroundColor Cyan
    Write-Host "Login:         admin / password saved in $savedSecretsPath" -ForegroundColor Cyan
    Write-Host "Application:   $AppName (namespace '$AppDestNamespace')" -ForegroundColor Cyan
    Write-Host "Shortcut:      $shortcutPath" -ForegroundColor Cyan
    Write-Host "Port-forward:  background job '$($portForwardJob.Name)' (id $($portForwardJob.Id)); it stays up while this window is open." -ForegroundColor DarkGray
    Write-Host "Restart it:    kubectl port-forward service/argocd-server -n $ArgoNamespace ${PortForwardPort}:443" -ForegroundColor DarkGray
}
catch {

    Write-Host ""
    Write-Error "Caught an exception:" -ErrorAction Continue
    Write-Error "Exception Type: $($_.Exception.GetType().FullName)" -ErrorAction Continue
    Write-Error "Exception Message: $($_.Exception.Message)" -ErrorAction Continue
    Write-Host ""
    Write-Host "Script failed to execute." -ForegroundColor Red
    Read-Host "Press Enter to close the window ..."
    EXIT 1
}

Write-Host ""
Write-Host "Script executed successfully." -ForegroundColor Green
Read-Host "Press Enter to close the window ..."
