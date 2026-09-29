function Save-ArgoCdInitialAdminPassword () {
    <#
    .SYNOPSIS
        Writes the Argo CD initial admin credentials to a protected file.
    .DESCRIPTION
        Writes the admin user name and Password, UTF-8 without a BOM, to
        SecretsPath, then locks the file down to the current user on Windows via
        icacls (skipped on Linux and macOS, where the file inherits the parent
        folder's permissions). Returns the file path. The password is never
        logged. Parameters are not traced because this function handles a secret.
    .NOTES
        1. Write the credentials to SecretsPath.
        2. Restrict the file to the current user on Windows.
        3. Return the path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "File path the credentials are written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$SecretsPath,

        [Parameter(Mandatory = $true, HelpMessage = "Initial admin password; never logged.")]
        [ValidateNotNullOrEmpty()]
        [string]$Password
    )

    Process {

        Write-Utf8NoBom -Path $SecretsPath -Content ("ARGOCD_ADMIN_USERNAME=admin`nARGOCD_ADMIN_PASSWORD={0}`n" -f $Password)

        if ($IsWindows) {
            & icacls $SecretsPath /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
        }

        return $SecretsPath
    }
}
