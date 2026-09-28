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
        [Parameter(Mandatory = $true, HelpMessage = "Path to the .env file to write.")]
        [ValidateNotNullOrEmpty()]
        [string]$EnvPath,

        [Parameter(Mandatory = $true, HelpMessage = "Snowflake account identifier.")]
        [ValidateNotNullOrEmpty()]
        [string]$Account,

        [Parameter(Mandatory = $true, HelpMessage = "Database user name.")]
        [ValidateNotNullOrEmpty()]
        [string]$User,

        [Parameter(Mandatory = $true, HelpMessage = "Credential value to store.")]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialValue,

        [Parameter(Mandatory = $true, HelpMessage = "Snowflake warehouse name.")]
        [ValidateNotNullOrEmpty()]
        [string]$Warehouse,

        [Parameter(Mandatory = $true, HelpMessage = "Database name.")]
        [ValidateNotNullOrEmpty()]
        [string]$Database,

        [Parameter(Mandatory = $true, HelpMessage = "Snowflake schema name.")]
        [ValidateNotNullOrEmpty()]
        [string]$Schema,

        [Parameter(Mandatory = $true, HelpMessage = "Snowflake role name.")]
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
