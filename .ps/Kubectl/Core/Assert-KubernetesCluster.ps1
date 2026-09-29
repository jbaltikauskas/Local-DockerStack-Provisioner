function Assert-KubernetesCluster () {
    <#
    .SYNOPSIS
        Verifies kubectl has a current context that reaches a running cluster.
    .DESCRIPTION
        Fails fast, and cleanly, before the noisy API calls: first checks that a
        current kube-context is configured (without one, kubectl silently defaults
        to http://localhost:8080), then confirms the API server answers. Throws a
        distinct, actionable message for each case so the caller knows whether to
        enable a cluster or start an existing one.
    .NOTES
        1. Read the current context; throw with enable-a-cluster guidance when unset.
        2. Query cluster-info with a short timeout; throw with start-the-cluster
           guidance when the API server does not answer.
        3. Report the reachable context.
    #>
    [CmdletBinding()]
    Param ()

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        $currentContext = ''
        try {

            $currentContext = (& kubectl config current-context 2>$null | Out-String).Trim()
        }
        catch {
            $currentContext = ''
        }

        if ([string]::IsNullOrWhiteSpace($currentContext)) {
            throw "kubectl has no current context configured, so it defaults to http://localhost:8080 and cannot connect. Enable Kubernetes in Docker Desktop (Settings > Kubernetes > Enable Kubernetes, then Apply & Restart), or start a local cluster (kind / minikube / k3d). Confirm 'kubectl config current-context' prints a context before rerunning."
        }

        try {

            & kubectl cluster-info --request-timeout=10s 2>$null | Out-Null
        }
        catch {
            throw "Kubernetes context '$currentContext' is set but the API server did not respond. Make sure that cluster is running, then rerun. Underlying error: $($_.Exception.Message)"
        }

        Write-Host "Kubernetes cluster reachable (context: $currentContext)." -ForegroundColor Green
    }
}
