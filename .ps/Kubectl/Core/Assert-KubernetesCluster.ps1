function Assert-KubernetesCluster () {
    <#
    .SYNOPSIS
        Verifies kubectl can reach a running Kubernetes cluster.
    .DESCRIPTION
        Runs `kubectl cluster-info` against the current context and throws a clear,
        actionable message when no cluster answers, so later apply and rollout
        steps fail early with guidance instead of a raw kubectl error.
    .NOTES
        1. Query cluster-info for the current context.
        2. Throw an actionable message when the cluster is unreachable.
    #>
    [CmdletBinding()]
    Param ()

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        try {

            & kubectl cluster-info | Out-Null
        }
        catch {
            throw "No reachable Kubernetes cluster for the current kubectl context. Enable Kubernetes in Docker Desktop, or start a local cluster (kind / minikube / k3d), then rerun. Underlying error: $($_.Exception.Message)"
        }

        $currentContext = & kubectl config current-context
        Write-Host "Kubernetes cluster reachable (context: $currentContext)." -ForegroundColor Green
    }
}
