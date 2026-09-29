#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ensures kubectl, installs Argo CD into the current cluster, and deploys the
    kustom-webapp example application.

.DESCRIPTION
    This follows the kubectl-only getting-started flow
    (https://argo-cd.readthedocs.io/en/stable/getting_started/): Argo CD is
    installed and the application is set up entirely with kubectl. The argocd CLI
    is never installed; admin login happens in the browser UI.

    Top-down flow when this script runs:

        1. Load helper modules and required runtime settings from
           config-kubectl.json next to this script.
        2. Resolve a new dated install folder (<prefix>-ArgoCD-yyyyMMdd) under the
           configured install root, plus a per-user tools folder.
        3. Ensure kubectl is on PATH (installed via winget on Windows, or the
           official single-binary release on Linux/macOS) when missing.
        4. Verify kubectl can reach a running Kubernetes cluster.
        5. Create the argocd namespace when it does not exist.
        6. Server-side apply the Argo CD installation manifest (ARGO_MANIFEST_URL).
        7. Wait for the argocd-server deployment to be ready.
        8. Print the resources in the argocd namespace (kubectl get all).
        9. Start a background kubectl port-forward to the Argo CD server.
        10. Retrieve the initial admin password and write it to a protected file
            in the install folder (for browser login).
        11. Create the dev and qa workload namespaces and print each namespace.
        12. Clone (or pull) the GIT_REPO_URL repository to disk under a repos
            folder inside the dated install folder.
        13. Apply an Argo CD Application manifest (kubectl) that tracks
            GIT_REPO_URL with an automated sync policy.
        14. Wait until the application is Synced and Healthy.
        15. Write a cross-platform browser shortcut to the Argo CD UI in the
            install folder.
        16. Print a summary.

    Runtime values (namespace names, port, URLs, application details, install
    root) come from config-kubectl.json; ServerNamePrefix is the only script
    parameter. The install folder, cloned repo, Application manifest,
    admin-password file, and UI shortcut all live under one dated
    <prefix>-ArgoCD-yyyyMMdd folder inside the install root. Kubernetes namespaces
    must be lowercase RFC 1123 labels, so the requested Dev/QA namespaces are
    created as dev/qa.

.PARAMETER ServerNamePrefix
    Required install-folder prefix. The installer always appends
    -ArgoCD-yyyyMMdd to form the dated install folder under the configured
    install root. It is never read from config-kubectl.json.

.INPUTS
    None. ServerNamePrefix comes from a parameter; all other settings come from
    config-kubectl.json.

.OUTPUTS
    Host messages and, under the dated install folder, an admin-password file, an
    Argo CD Application manifest, a UI shortcut, and the cloned repository (in a
    repos subfolder), plus a running background port-forward job. Exit code 0 on
    success, 1 on failure.

.NOTES
    Requires PowerShell 7.2+, git on PATH, and a reachable Kubernetes cluster
    (for example the Kubernetes feature in Docker Desktop, or kind / minikube /
    k3d). kubectl is installed automatically when missing (winget on Windows).
    The argocd CLI is not used. The background port-forward stays alive only while
    this PowerShell window is open.

.EXAMPLE
    PS> .\Install-Kubectl.ps1 -ServerNamePrefix dev
    Runs the full Argo CD bootstrap and creates a dev-ArgoCD-yyyyMMdd folder.

.EXAMPLE
    PS> pwsh ./Install-Kubectl.ps1 -ServerNamePrefix team-a
    Same bootstrap invoked explicitly through pwsh on Linux or macOS.
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Install folder prefix. The installer appends -ArgoCD-yyyyMMdd.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerNamePrefix
)

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
        , @('..', 'Core', 'Sync-GitRepository.ps1')
        , @('..', 'Core', 'Write-Utf8NoBom.ps1')
        , @('Core', 'Initialize-KubectlInstallerFromConfig.ps1')
        , @('Core', 'Resolve-KubectlInstallFolder.ps1')
        , @('Core', 'Install-KubectlCli.ps1')
        , @('Core', 'Assert-KubernetesCluster.ps1')
        , @('Core', 'New-KubernetesNamespace.ps1')
        , @('Core', 'Show-KubernetesResources.ps1')
        , @('Core', 'Install-ArgoCdManifest.ps1')
        , @('Core', 'Wait-ArgoCdServerReady.ps1')
        , @('Core', 'Get-ArgoCdInitialAdminPassword.ps1')
        , @('Core', 'Save-ArgoCdInitialAdminPassword.ps1')
        , @('Core', 'Start-ArgoCdPortForward.ps1')
        , @('Core', 'New-ArgoCdApplication.ps1')
        , @('Core', 'Wait-ArgoCdApplicationHealthy.ps1')
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

    # ---- 2. Resolve install and tools folders ------------------------------
    $serverRoot = Resolve-KubectlInstallFolder -InstallRootFolder $InstallRootFolder -ServerNamePrefix $ServerNamePrefix
    $reposFolder = Join-Path $serverRoot 'repos'
    $toolsDirectory = Join-Path $HOME '.local-dockerstack-provisioner-tools'
    $secretsPath = Join-Path $serverRoot 'argocd-admin-password.env'

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install folder     : $serverRoot"
    Write-Output "Repos folder       : $reposFolder"
    Write-Output "Tools folder       : $toolsDirectory"
    Write-Output "Argo CD namespace  : $ArgoNamespace"
    Write-Output "Port-forward       : https://${WebHost}:${PortForwardPort} -> service/argocd-server:443"
    Write-Output "Manifest           : $ArgoManifestUrl"
    Write-Output "Git repository     : $GitRepoUrl"
    Write-Output "Application        : $AppName ($AppPath -> namespace '$AppDestNamespace')"
    Write-Output "Workload namespaces: $($WorkloadNamespaces -join ', ')"
    Write-Output ""
    $PSBoundParameters | Out-String | Write-Output
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    # ---- 3. Ensure kubectl -------------------------------------------------
    Write-Host "Ensuring kubectl:" -ForegroundColor Green
    Install-KubectlCli -DestinationDirectory $toolsDirectory

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
    $adminPassword = $null
    Write-Host "Saved the initial admin password to: $savedSecretsPath" -ForegroundColor Cyan

    # ---- 11. Workload namespaces -------------------------------------------
    Write-Host ""
    Write-Host "Creating workload namespaces:" -ForegroundColor Green
    foreach ($workloadNamespace in $WorkloadNamespaces) {
        New-KubernetesNamespace -Name $workloadNamespace
    }

    foreach ($workloadNamespace in $WorkloadNamespaces) {
        Show-KubernetesResources -Namespace $workloadNamespace
    }

    # ---- 12. Pull the repository to disk -----------------------------------
    Write-Host ""
    Write-Host "Pulling the example repository:" -ForegroundColor Green
    $repoLocalPath = Sync-GitRepository -RepoUrl $GitRepoUrl -DestinationRootFolder $reposFolder

    # ---- 13. Create the application (declarative kubectl apply) ------------
    $applicationManifestPath = Join-Path $serverRoot 'argocd-application.yaml'
    New-ArgoCdApplication `
        -AppName $AppName `
        -RepoUrl $GitRepoUrl `
        -AppPath $AppPath `
        -Project $AppProject `
        -DestNamespace $AppDestNamespace `
        -ArgoNamespace $ArgoNamespace `
        -ManifestPath $applicationManifestPath

    # ---- 14. Wait until Synced and Healthy ---------------------------------
    Wait-ArgoCdApplicationHealthy -Namespace $ArgoNamespace -AppName $AppName

    # ---- 15. UI shortcut ---------------------------------------------------
    $shortcutPath = Write-ArgoCdWebUiShortcut `
        -ServerRoot $serverRoot `
        -Name 'ArgoCD' `
        -WebHost $WebHost `
        -Port $PortForwardPort

    # ---- 16. Summary -------------------------------------------------------
    Write-Host ""
    Write-Host "Argo CD is running." -ForegroundColor Green
    Write-Host "Web UI:        https://${WebHost}:${PortForwardPort}" -ForegroundColor Cyan
    Write-Host "Login:         admin / password saved in $savedSecretsPath (log in via the browser UI)" -ForegroundColor Cyan
    Write-Host "Application:   $AppName (namespace '$AppDestNamespace'); manifest $applicationManifestPath" -ForegroundColor Cyan
    Write-Host "Install:       $serverRoot" -ForegroundColor Cyan
    Write-Host "Repo clone:    $repoLocalPath" -ForegroundColor Cyan
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
