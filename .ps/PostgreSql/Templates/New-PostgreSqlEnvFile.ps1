function New-PostgreSqlEnvFile () {
    <#
    .SYNOPSIS
        Writes PostgreSQL environment settings.
    .DESCRIPTION
        Always overwrites the installer-managed file with all environment
        variables required by the PostgreSQL container.
    .NOTES
        1. Write POSTGRES_USER, POSTGRES_PASSWORD, and POSTGRES_DB.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database
    )

    Process {

        $content = @"
POSTGRES_USER=$User
POSTGRES_PASSWORD=$Password
POSTGRES_DB=$Database
"@
        Write-Utf8NoBom -Path $EnvPath -Content $content
    }
}
