function New-SonarCubeComposeFile () {
    <#
    .SYNOPSIS
        Writes the SonarQube and PostgreSQL Docker Compose file.
    .DESCRIPTION
        Uses unique Docker named volumes for each install. SonarSource requires
        named volumes instead of bind mounts for SonarQube persistence.
    .NOTES
        1. Render the two-service compose file.
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
        [ValidatePattern('^sonarqube-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$SonarQubeServiceName,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^postgres-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$DatabaseServiceName,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^sonarnet-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$NetworkName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('127.0.0.1', '0.0.0.0')]
        [string]$BindAddress,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SonarQubeImage,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PostgresImage
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $content = @"
services:
  ${SonarQubeServiceName}:
    image: $SonarQubeImage
    container_name: $ContainerPrefix
    depends_on:
      ${DatabaseServiceName}:
        condition: service_healthy
    env_file:
      - ./config/.env
      - ./config/.env.secrets
    ports:
      - "${BindAddress}:${Port}:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    networks:
      - sonarnet
    stop_grace_period: 1h
    restart: unless-stopped

  ${DatabaseServiceName}:
    image: $PostgresImage
    container_name: ${ContainerPrefix}-db
    env_file:
      - ./config/.env
      - ./config/.env.secrets
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U `$`${POSTGRES_USER} -d `$`${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    networks:
      - sonarnet
    restart: unless-stopped

volumes:
  sonarqube_data:
    name: ${ContainerPrefix}-data
  sonarqube_extensions:
    name: ${ContainerPrefix}-extensions
  sonarqube_logs:
    name: ${ContainerPrefix}-logs
  postgresql_data:
    name: ${ContainerPrefix}-postgresql

networks:
  sonarnet:
    name: $NetworkName
"@

        Write-Utf8NoBom -Path $ComposePath -Content $content

        Write-Host "Compose file: $ComposePath"
        Write-Host $content
    }
}
