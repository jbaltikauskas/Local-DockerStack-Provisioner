function Install-ArgoCdManifest () {
    <#
    .SYNOPSIS
        Applies the Argo CD installation manifest into a namespace.
    .DESCRIPTION
        Runs a server-side apply of the Argo CD install manifest with
        --force-conflicts so reruns and upgrades reconcile cleanly. Assumes the
        target namespace already exists. Throws when kubectl fails. Returns nothing.
    .NOTES
        1. Server-side apply ManifestUrl into Namespace with --force-conflicts.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Namespace to install Argo CD into.")]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace,

        [Parameter(Mandatory = $true, HelpMessage = "URL of the Argo CD install manifest to apply.")]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestUrl
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        Write-Host "Applying Argo CD manifest into namespace '$Namespace':" -ForegroundColor Green
        Write-Host "    $ManifestUrl" -ForegroundColor Cyan
        & kubectl apply -n $Namespace --server-side --force-conflicts -f $ManifestUrl
        if ($LASTEXITCODE -ne 0) {
            throw "kubectl apply of the Argo CD manifest failed with exit code $LASTEXITCODE."
        }
    }
}
