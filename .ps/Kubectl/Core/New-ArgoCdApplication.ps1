function New-ArgoCdApplication () {
    <#
    .SYNOPSIS
        Creates or updates an Argo CD application from a Git path.
    .DESCRIPTION
        Runs `argocd app create` with --upsert so the application is created on
        the first run and reconciled on later runs. The application tracks AppPath
        in RepoUrl and deploys into DestNamespace on the in-cluster API server.
        Sync policy is left manual so the first sync is an explicit step. Throws
        when the command fails. Returns nothing.
    .NOTES
        1. Upsert the application definition (repo, path, project, destination).
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
        [string]$DestNamespace
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        Write-Host "Creating Argo CD application '$AppName' ($AppPath -> namespace '$DestNamespace'):" -ForegroundColor Green
        & argocd app create $AppName `
            --repo $RepoUrl `
            --path $AppPath `
            --project $Project `
            --dest-server 'https://kubernetes.default.svc' `
            --dest-namespace $DestNamespace `
            --sync-policy none `
            --upsert
        if ($LASTEXITCODE -ne 0) {
            throw "argocd app create failed for '$AppName' with exit code $LASTEXITCODE."
        }
    }
}
