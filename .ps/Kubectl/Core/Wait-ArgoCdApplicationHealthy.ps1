function Wait-ArgoCdApplicationHealthy () {
    <#
    .SYNOPSIS
        Waits until an Argo CD application is Synced and Healthy.
    .DESCRIPTION
        Polls the Application resource with kubectl until its sync status is
        Synced and its health status is Healthy, or TimeoutSeconds elapses. With
        an automated sync policy Argo CD performs the sync itself, so this only
        waits (no argocd CLI). Transient read failures while the controller starts
        are treated as "not ready yet". Throws on timeout. Returns nothing.
    .NOTES
        1. Poll the Application sync and health status via kubectl jsonpath.
        2. Return when both are Synced and Healthy.
        3. Throw with the last observed status when the timeout elapses.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Namespace the Application resource lives in (the Argo CD namespace).")]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace,

        [Parameter(Mandatory = $true, HelpMessage = "Argo CD application name to wait on.")]
        [ValidateNotNullOrEmpty()]
        [string]$AppName,

        [Parameter(Mandatory = $false, HelpMessage = "Seconds to wait for the application to become Synced and Healthy.")]
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 300
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        Write-Host "Waiting up to $TimeoutSeconds seconds for '$AppName' to be Synced and Healthy ..." -ForegroundColor Yellow
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $syncStatus = ''
        $healthStatus = ''

        while ((Get-Date) -lt $deadline) {
            try {

                $syncStatus = (& kubectl -n $Namespace get application $AppName --output "jsonpath={.status.sync.status}" 2>$null | Out-String).Trim()
                $healthStatus = (& kubectl -n $Namespace get application $AppName --output "jsonpath={.status.health.status}" 2>$null | Out-String).Trim()
            }
            catch {
                $syncStatus = ''
                $healthStatus = ''
            }

            if ($syncStatus -eq 'Synced' -and $healthStatus -eq 'Healthy') {
                Write-Host "Argo CD application '$AppName' is Synced and Healthy." -ForegroundColor Green
                return
            }

            Write-Host "  status: sync=$syncStatus health=$healthStatus" -ForegroundColor DarkGray
            Start-Sleep -Seconds 5
        }

        throw "Argo CD application '$AppName' did not become Synced and Healthy within $TimeoutSeconds seconds (last status: sync=$syncStatus health=$healthStatus)."
    }
}
