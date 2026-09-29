function Show-KubernetesResources () {
    <#
    .SYNOPSIS
        Prints the resources in a namespace with `kubectl get all`.
    .DESCRIPTION
        Host-only reporting helper. Writes a cyan header naming the command, then
        runs `kubectl get all -n <Namespace>` so the log shows the namespace's
        current state. An empty namespace (kubectl exit code 0) is reported as
        such; a real kubectl failure throws.
    .NOTES
        1. Print the command header.
        2. Run `kubectl get all` for the namespace and let its output through.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Namespace whose resources are listed.")]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        Write-Host ""
        Write-Host "kubectl get all -n $Namespace" -ForegroundColor Cyan
        & kubectl get all -n $Namespace
    }
}
