function New-CosmosDbEnvFile () {
    <#
    .SYNOPSIS
        Writes Cosmos DB emulator environment settings and the account key file.
    .DESCRIPTION
        Always overwrites the installer-managed config\.env and config\account.key
        files. Cosmos DB uses one env file plus a mounted key file.
    .NOTES
        1. Write emulator runtime settings to .env.
        2. Write ACCOUNT_KEY to account.key for KEY_FILE.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingPlainTextForPassword',
        'AccountKey',
        Justification = 'Cosmos DB emulator uses one local config env file and key file from JSON by repository convention.'
    )]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyFilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('http', 'https', 'https-insecure')]
        [string]$Protocol,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AccountKey
    )

    Process {

        $content = @"
PORT=8081
PROTOCOL=$Protocol
ENABLE_EXPLORER=true
EXPLORER_PORT=1234
EXPLORER_PROTOCOL=$Protocol
GATEWAY_PUBLIC_ENDPOINT=$HostName
DATA_PATH=/data
KEY_FILE=/account.key
ENABLE_TELEMETRY=false
"@
        Write-Utf8NoBom -Path $EnvPath -Content $content
        Write-Utf8NoBom -Path $KeyFilePath -Content $AccountKey
    }
}
