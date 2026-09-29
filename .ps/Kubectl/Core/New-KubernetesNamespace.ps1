function New-KubernetesNamespace () {
    <#
    .SYNOPSIS
        Creates a Kubernetes namespace when it does not already exist.
    .DESCRIPTION
        Validates that Name is a legal RFC 1123 namespace label (lowercase
        letters, digits, and dashes), then creates it only when missing so the
        step is idempotent and safe to rerun. Throws on an invalid name or when
        kubectl fails. Returns nothing.
    .NOTES
        1. Validate Name against the RFC 1123 label rules.
        2. Query for the namespace with --ignore-not-found.
        3. Create it when absent; otherwise report that it exists.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Namespace name (lowercase RFC 1123 label).")]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if ($Name -cnotmatch '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' -or $Name.Length -gt 63) {
            throw "Invalid namespace name '$Name'. Kubernetes namespaces must be a lowercase RFC 1123 label (letters, digits, and dashes; max 63 characters)."
        }

        $existing = & kubectl get namespace $Name --ignore-not-found --output name
        if ([string]::IsNullOrWhiteSpace($existing)) {
            & kubectl create namespace $Name | Out-Null
            Write-Host "Created namespace '$Name'." -ForegroundColor Green
        }
        else {
            Write-Host "Namespace '$Name' already exists." -ForegroundColor Yellow
        }
    }
}
