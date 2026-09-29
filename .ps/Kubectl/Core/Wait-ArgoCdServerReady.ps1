function Wait-ArgoCdServerReady () {
    <#
    .SYNOPSIS
        Waits for the Argo CD API server deployment to become available.
    .DESCRIPTION
        Blocks on `kubectl rollout status` for the argocd-server deployment so
        later port-forward and login steps run against a ready API. Throws when
        the deployment does not become available within TimeoutSeconds. Returns
        nothing.
    .NOTES
        1. Wait on the argocd-server deployment rollout in Namespace.
        2. Throw when it is not ready within TimeoutSeconds.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Namespace Argo CD is installed in.")]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace,

        [Parameter(Mandatory = $false, HelpMessage = "Seconds to wait for the argocd-server rollout.")]
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 300
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        Write-Host "Waiting up to $TimeoutSeconds seconds for argocd-server to be ready ..." -ForegroundColor Yellow
        & kubectl rollout status deployment/argocd-server -n $Namespace --timeout ("{0}s" -f $TimeoutSeconds)
        if ($LASTEXITCODE -ne 0) {
            throw "argocd-server did not become ready within $TimeoutSeconds seconds."
        }

        Write-Host "argocd-server is ready." -ForegroundColor Green
    }
}
