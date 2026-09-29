function Sync-ArgoCdApplication () {
    <#
    .SYNOPSIS
        Runs the first sync of an Argo CD application and waits for health.
    .DESCRIPTION
        Triggers `argocd app sync` to apply the tracked manifests, then blocks on
        `argocd app wait --health --sync` until the application reports Synced and
        Healthy or TimeoutSeconds elapses. Throws when either command fails.
        Returns nothing.
    .NOTES
        1. Sync the application.
        2. Wait for Synced and Healthy status within TimeoutSeconds.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Argo CD application name to sync.")]
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

        Write-Host "Syncing Argo CD application '$AppName':" -ForegroundColor Green
        & argocd app sync $AppName
        if ($LASTEXITCODE -ne 0) {
            throw "argocd app sync failed for '$AppName' with exit code $LASTEXITCODE."
        }

        Write-Host "Waiting up to $TimeoutSeconds seconds for '$AppName' to be Synced and Healthy ..." -ForegroundColor Yellow
        & argocd app wait $AppName --health --sync --timeout $TimeoutSeconds
        if ($LASTEXITCODE -ne 0) {
            throw "Argo CD application '$AppName' did not become Synced and Healthy within $TimeoutSeconds seconds."
        }

        Write-Host "Argo CD application '$AppName' is Synced and Healthy." -ForegroundColor Green
    }
}
