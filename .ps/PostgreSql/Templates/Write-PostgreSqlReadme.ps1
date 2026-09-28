function Write-PostgreSqlReadme () {
    <#
    .SYNOPSIS
        Writes the install-folder README.md.
    .DESCRIPTION
        Documents connection info, CSharp examples, folder layout, and daily management commands.
    .NOTES
        1. Render and overwrite README.md.
        2. Omit parameter tracing because rendered connection strings include secrets.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Root folder of the installed stack.")]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true, HelpMessage = "Host name used to reach the service.")]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter(Mandatory = $true, HelpMessage = "TCP port the service listens on (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true, HelpMessage = "Database user name.")]
        [ValidateNotNullOrEmpty()]
        [string]$User,

        [Parameter(Mandatory = $true, HelpMessage = "Database name.")]
        [ValidateNotNullOrEmpty()]
        [string]$Database,

        [Parameter(Mandatory = $true, HelpMessage = "Complete connection string including credentials.")]
        [ValidateNotNullOrEmpty()]
        [string]$FullConnectionString,

        [Parameter(Mandatory = $true, HelpMessage = "C# connection string for the README.")]
        [ValidateNotNullOrEmpty()]
        [string]$CSharpConnectionString,

        [Parameter(Mandatory = $true, HelpMessage = "Compose service name of the container.")]
        [ValidatePattern('^postgresql-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName
    )

    Process {

        $path = Join-Path $ServerRoot 'README.md'
        $content = @"
# PostgreSQL Docker Install

Connection string: ``Host=${HostName};Port=${Port};Username=${User};Database=${Database}``

Full connection string: ``$FullConnectionString``

Login: ``$User`` with the password from ``config\.env``.

## CSharp Connection Example

``````csharp
var connectionString = "$CSharpConnectionString";
``````

## Commands

``````batch
Start-PostgreSql.bat
Stop-PostgreSql.bat
docker compose -f .\docker-compose.yml logs -f $ServiceName
docker compose -f .\docker-compose.yml exec $ServiceName psql -U $User -d $Database
``````

## Data

- ``config\.env`` contains PostgreSQL settings (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB).
- The generated Docker named volume contains PostgreSQL persistent data.

Do not run ``docker compose -f .\docker-compose.yml down -v`` unless you intend to delete PostgreSQL data.
"@
        Write-Utf8NoBom -Path $path -Content $content
    }
}
