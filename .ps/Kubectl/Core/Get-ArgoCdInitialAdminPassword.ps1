function Get-ArgoCdInitialAdminPassword () {
    <#
    .SYNOPSIS
        Reads the Argo CD initial admin password from its Kubernetes secret.
    .DESCRIPTION
        Retries briefly for the argocd-initial-admin-secret, base64-decodes its
        password field, and returns the plaintext. The caller must keep the value
        out of logs and null it after use. Throws when the secret does not appear
        within the retry window. Parameters are not traced because this function
        handles secret material.
    .NOTES
        1. Poll for the argocd-initial-admin-secret password field.
        2. Base64-decode it and return the plaintext.
        3. Throw when it does not appear within TimeoutSeconds.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Namespace Argo CD is installed in.")]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace,

        [Parameter(Mandatory = $false, HelpMessage = "Seconds to wait for the initial admin secret to appear.")]
        [ValidateRange(1, 600)]
        [int]$TimeoutSeconds = 120
    )

    Process {

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $encoded = $null

        while ((Get-Date) -lt $deadline) {
            $encoded = & kubectl -n $Namespace get secret argocd-initial-admin-secret --ignore-not-found --output "jsonpath={.data.password}"
            if (-not [string]::IsNullOrWhiteSpace($encoded)) {
                break
            }

            Start-Sleep -Seconds 3
        }

        if ([string]::IsNullOrWhiteSpace($encoded)) {
            throw "The argocd-initial-admin-secret was not available within $TimeoutSeconds seconds."
        }

        return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))
    }
}
