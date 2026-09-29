function Register-ArgoCdRepository () {
    <#
    .SYNOPSIS
        Registers a Git repository with Argo CD.
    .DESCRIPTION
        Runs `argocd repo add` with --upsert so a public HTTPS repository is
        registered idempotently and reruns simply update the entry. Assumes the
        CLI is already logged in. Throws when the command fails. Returns nothing.
    .NOTES
        1. Upsert RepoUrl into Argo CD's repository list.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "HTTPS URL of the Git repository to register.")]
        [ValidateNotNullOrEmpty()]
        [string]$RepoUrl
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        Write-Host "Registering repository with Argo CD:" -ForegroundColor Green
        Write-Host "    $RepoUrl" -ForegroundColor Cyan
        & argocd repo add $RepoUrl --upsert
        if ($LASTEXITCODE -ne 0) {
            throw "argocd repo add failed for '$RepoUrl' with exit code $LASTEXITCODE."
        }
    }
}
