function New-ArgoCdApplication () {
    <#
    .SYNOPSIS
        Creates the Argo CD application declaratively with kubectl.
    .DESCRIPTION
        Writes an argoproj.io/v1alpha1 Application manifest to ManifestPath and
        applies it into the Argo CD namespace with kubectl (no argocd CLI). The
        application tracks AppPath in RepoUrl at HEAD and deploys into
        DestNamespace on the in-cluster API server. An automated sync policy
        (prune + selfHeal, CreateNamespace) lets Argo CD perform the first sync
        itself. Rerunning re-applies the same manifest. Throws when kubectl apply
        fails. Returns the manifest path.
    .NOTES
        1. Render the Application manifest from the parameters.
        2. Write it to ManifestPath (UTF-8, no BOM).
        3. kubectl apply it into ArgoNamespace.
        4. Return the manifest path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Argo CD application name.")]
        [ValidateNotNullOrEmpty()]
        [string]$AppName,

        [Parameter(Mandatory = $true, HelpMessage = "HTTPS URL of the source Git repository.")]
        [ValidateNotNullOrEmpty()]
        [string]$RepoUrl,

        [Parameter(Mandatory = $true, HelpMessage = "Path within the repository to deploy.")]
        [ValidateNotNullOrEmpty()]
        [string]$AppPath,

        [Parameter(Mandatory = $true, HelpMessage = "Argo CD project the application belongs to.")]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory = $true, HelpMessage = "Destination namespace the application deploys into.")]
        [ValidateNotNullOrEmpty()]
        [string]$DestNamespace,

        [Parameter(Mandatory = $true, HelpMessage = "Namespace Argo CD (and the Application resource) lives in.")]
        [ValidateNotNullOrEmpty()]
        [string]$ArgoNamespace,

        [Parameter(Mandatory = $true, HelpMessage = "File path the Application manifest is written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $manifest = @"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $AppName
  namespace: $ArgoNamespace
spec:
  project: $Project
  source:
    repoURL: $RepoUrl
    targetRevision: HEAD
    path: $AppPath
  destination:
    server: https://kubernetes.default.svc
    namespace: $DestNamespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

"@

        Write-Utf8NoBom -Path $ManifestPath -Content $manifest

        Write-Host "Applying Argo CD Application '$AppName' ($AppPath -> namespace '$DestNamespace'):" -ForegroundColor Green
        Write-Host "    $ManifestPath" -ForegroundColor Cyan
        & kubectl apply -n $ArgoNamespace -f $ManifestPath
        if ($LASTEXITCODE -ne 0) {
            throw "kubectl apply of the Argo CD Application '$AppName' failed with exit code $LASTEXITCODE."
        }

        return $ManifestPath
    }
}
