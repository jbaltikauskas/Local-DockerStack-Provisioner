function Write-MSSqlReadme () {
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
        [string]$FullConnectionString,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CSharpConnectionString,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^mssql-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName
    )

    Process {

        $path = Join-Path $ServerRoot 'README.md'
        $content = @"
# MSSQL Server Docker Install

Connection string: ``Server=${HostName},${Port};User Id=sa;TrustServerCertificate=True``

Full connection string: ``$FullConnectionString``

Login: ``sa`` with the password from ``config\.env.secrets``.

## CSharp Connection Example

``````csharp
var connectionString = "$CSharpConnectionString";
``````

## Commands

``````powershell
.\Start-MSSql.ps1
.\Stop-MSSql.ps1
.\Start-MSSql.bat
.\Stop-MSSql.bat
docker compose -f .\docker-compose.yml logs -f $ServiceName
``````

## Data

- ``config\.env`` contains non-secret settings (ACCEPT_EULA, MSSQL_PID).
- ``config\.env.secrets`` contains the SA password.
- ``mssql_dev_data`` contains MSSQL persistent data beside ``docker-compose.yml``.

Do not delete the ``mssql_dev_data`` folder unless you intend to delete MSSQL data.
"@
        Write-Utf8NoBom -Path $path -Content $content
    }
}
