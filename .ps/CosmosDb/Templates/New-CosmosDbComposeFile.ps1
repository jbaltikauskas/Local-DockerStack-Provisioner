function New-CosmosDbComposeFile () {
    <#
    .SYNOPSIS
        Writes the Cosmos DB Docker Compose file.
    .DESCRIPTION
        Maps the gateway, health, and Data Explorer host ports to the vNext
        emulator container ports. Persists emulator files in cosmos-data and
        mounts the generated account key file.
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
        [ValidatePattern('^cosmosdb-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('127.0.0.1', '0.0.0.0')]
        [string]$BindAddress,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$HealthPort,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$ExplorerPort,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CosmosDbImage
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $content = @"
services:
  ${ServiceName}:
    image: $CosmosDbImage
    container_name: $ContainerPrefix
    env_file:
      - ./config/.env
    ports:
      - "${BindAddress}:${Port}:8081"
      - "${BindAddress}:${HealthPort}:8080"
      - "${BindAddress}:${ExplorerPort}:1234"
    volumes:
      - ./cosmos-data:/data
      - ./config/account.key:/account.key:ro
    restart: unless-stopped
"@

        Write-Utf8NoBom -Path $ComposePath -Content $content

        Write-Host "Compose file: $ComposePath"
        Write-Host $content
    }
}
