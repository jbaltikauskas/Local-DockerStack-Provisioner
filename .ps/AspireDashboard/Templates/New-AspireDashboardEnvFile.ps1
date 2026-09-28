function New-AspireDashboardEnvFile () {
    <#
    .SYNOPSIS
        Writes non-secret Aspire Dashboard environment settings.
    .DESCRIPTION
        Always overwrites the installer-managed file.
    .NOTES
        1. Write DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvPath,

        [Parameter(Mandatory = $true)]
        [bool]$AllowAnonymous
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $allowAnonymousValue = $AllowAnonymous.ToString().ToLowerInvariant()
        $content = "DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=$allowAnonymousValue"
        Write-Utf8NoBom -Path $EnvPath -Content $content
    }
}
