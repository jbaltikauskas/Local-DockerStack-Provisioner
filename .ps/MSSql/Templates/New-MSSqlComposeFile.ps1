function New-MSSqlComposeFile () {
    <#
    .SYNOPSIS
        Writes the MSSQL Server Docker Compose file.
    .DESCRIPTION
        Maps MSSQL data to the local mssql_dev_data folder beside the compose
        file. Non-secret settings come from config/.env; the SA password comes
        from config/.env.secrets.
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
        [ValidatePattern('^mssql-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSSqlImage
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $content = @"
services:
  ${ServiceName}:
    image: $MSSqlImage
    container_name: $ContainerPrefix
    env_file:
      - ./config/.env
      - ./config/.env.secrets
    ports:
      - "${Port}:1433"
    volumes:
      - ./mssql_dev_data:/var/opt/mssql/data
    restart: unless-stopped
"@

        Write-Utf8NoBom -Path $ComposePath -Content $content

        Write-Host "Compose file: $ComposePath"
        Write-Host $content
    }
}
