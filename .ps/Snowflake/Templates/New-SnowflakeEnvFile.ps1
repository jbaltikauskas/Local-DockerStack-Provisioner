function New-SnowflakeEnvFile () {
    <#
    .SYNOPSIS
        Writes Snowflake emulator environment settings.
    .DESCRIPTION
        Always overwrites the installer-managed config\.env file. Snowflake uses
        one env file for both emulator runtime values and connection settings.
    .NOTES
        1. Write DB_PATH plus Snowflake account, user, password, warehouse, database, schema, and role.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingPlainTextForPassword',
        'CredentialValue',
        Justification = 'Snowflake emulator uses one local config env file from JSON by repository convention.'
    )]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Account,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialValue,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Warehouse,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Schema,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Role
    )

    Process {

        $content = @"
DB_PATH=/data/snowflake.db
SNOWFLAKE_ACCOUNT=$Account
SNOWFLAKE_USER=$User
SNOWFLAKE_PASSWORD=$CredentialValue
SNOWFLAKE_WAREHOUSE=$Warehouse
SNOWFLAKE_DATABASE=$Database
SNOWFLAKE_SCHEMA=$Schema
SNOWFLAKE_ROLE=$Role
"@
        Write-Utf8NoBom -Path $EnvPath -Content $content
    }
}
