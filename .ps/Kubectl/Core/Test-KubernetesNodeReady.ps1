function Test-KubernetesNodeReady () {
    <#
    .SYNOPSIS
        Returns whether kubectl can list at least one cluster node.
    .DESCRIPTION
        Runs `kubectl get nodes` with a short timeout and returns $true only when
        the command succeeds and reports one or more nodes. Never throws: a
        missing context or an unreachable API server returns $false, so callers
        can branch on cluster availability.
    .NOTES
        1. Run kubectl get nodes with a short request timeout, tolerating failure.
        2. Return $true when it succeeded and listed a node; otherwise $false.
    #>
    [CmdletBinding()]
    Param ()

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        $output = ''
        try {

            $output = (& kubectl get nodes --no-headers --request-timeout=10s 2>$null | Out-String).Trim()
        }
        catch {
            return $false
        }

        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        return -not [string]::IsNullOrWhiteSpace($output)
    }
}
