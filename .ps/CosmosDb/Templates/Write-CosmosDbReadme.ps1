function Write-CosmosDbReadme () {
    <#
    .SYNOPSIS
        Writes the install-folder README.md.
    .DESCRIPTION
        Documents gateway, explorer, and health endpoints, connection examples,
        folder layout, and daily management commands.
    .NOTES
        1. Render and overwrite README.md.
        2. Omit parameter tracing because rendered connection strings include secrets.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExplorerUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HealthUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CSharpConnectionExample,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^cosmosdb-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName
    )

    Process {

        $path = Join-Path $ServerRoot 'README.md'
        $content = @"
# Azure Cosmos DB Docker Install

Gateway endpoint: ``$Endpoint``

Data Explorer: ``$ExplorerUrl``

Health probe: ``$HealthUrl``

Connection string: ``$ConnectionString``

The account key is in ``config\account.key``. This stack uses the Azure Cosmos DB
vNext emulator (NoSQL API, gateway mode).

## CSharp Connection Example

``````csharp
$CSharpConnectionExample
``````

## Commands

``````powershell
.\Start-CosmosDb.ps1
.\Stop-CosmosDb.ps1
.\Start-CosmosDb.bat
.\Stop-CosmosDb.bat
docker compose -f .\docker-compose.yml logs -f $ServiceName
docker compose -f .\docker-compose.yml exec $ServiceName cosmoshell.sh
``````

## Files

- ``docker-compose.yml`` runs the Cosmos DB emulator container.
- ``config\.env`` contains emulator runtime settings.
- ``config\account.key`` contains the emulator account key.
- ``cosmos-data`` contains persistent emulator data.
- ``CosmosDb.url`` opens the Data Explorer in a browser.

Do not delete ``cosmos-data`` unless you intend to delete Cosmos DB emulator data.
"@
        Write-Utf8NoBom -Path $path -Content $content
    }
}
