function New-PostgreSqlComposeFile () {
    <#
    .SYNOPSIS
        Writes the PostgreSQL Docker Compose file.
    .DESCRIPTION
        Uses config/.env for environment values, maps the configured host port
        to container port 5432, and persists database files in a Docker named volume.
    .NOTES
        1. Render the single-service compose file.
        2. Write UTF-8 without BOM, replacing any existing file.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerPrefix,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^postgresql-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('127.0.0.1', '0.0.0.0')]
        [string]$BindAddress,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PostgreSqlImage
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $volumeName = "${ContainerPrefix}-data"
        $content = @"
services:
  ${ServiceName}:
    image: $PostgreSqlImage
    container_name: $ContainerPrefix
    env_file:
      - ./config/.env
    ports:
      - "${BindAddress}:${Port}:5432"
    volumes:
      - ${volumeName}:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  ${volumeName}:
"@

        Write-Utf8NoBom -Path $ComposePath -Content $content

        Write-Host "Compose file: $ComposePath"
        Write-Host $content
    }
}
