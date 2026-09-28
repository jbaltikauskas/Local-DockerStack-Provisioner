function Write-SnowflakeReadme () {
    <#
    .SYNOPSIS
        Writes the install-folder README.md.
    .DESCRIPTION
        Documents endpoint info, connection examples, compose shape, folder layout,
        and daily management commands.
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
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CSharpConnectionString,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Account,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$User,

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
        [string]$Role,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SnowflakeImage,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^snowflake-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName
    )

    Process {

        $path = Join-Path $ServerRoot 'README.md'
        $gosnowflakeDsn = "${User}:<password>@${HostName}:${Port}/${Database}/${Schema}?account=${Account}&protocol=http"
        $content = @"
# Snowflake Docker Install

Endpoint: ``http://${HostName}:${Port}``

Login: ``$User`` with the password from ``config\.env``.

Default context:

- Warehouse: ``$Warehouse``
- Database: ``$Database``
- Schema: ``$Schema``
- Role: ``$Role``

## How To Connect

You can connect to this emulator using the standard gosnowflake driver or REST API.

DSN:

``````
$gosnowflakeDsn
``````

## CSharp Connection Example

``````csharp
var connectionString = "$CSharpConnectionString";
``````

## Commands

``````powershell
.\Start-Snowflake.ps1
.\Stop-Snowflake.ps1
.\Start-Snowflake.bat
.\Stop-Snowflake.bat
docker compose -f .\docker-compose.yml logs -f $ServiceName
``````

## Generated Docker Compose

``````yaml
version: '3.8'

services:
  snowflake-emulator:
    image: $SnowflakeImage
    container_name: local-snowflake
    ports:
      - "${Port}:8080"
    env_file:
      - ./config/.env
    volumes:
      - ./snowflake-dat:/data
    restart: unless-stopped
``````

## Data

- ``config\.env`` contains Snowflake connection settings, password, and ``DB_PATH``.
- ``snowflake-dat`` contains the emulator database file.

Do not delete ``snowflake-dat`` unless you intend to delete Snowflake emulator data.
"@
        Write-Utf8NoBom -Path $path -Content $content
    }
}
