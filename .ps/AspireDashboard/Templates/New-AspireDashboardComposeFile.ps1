function New-AspireDashboardComposeFile () {
    <#
    .SYNOPSIS
        Writes the Aspire Dashboard Docker Compose file.
    .DESCRIPTION
        Maps the dashboard UI, OTLP gRPC, and OTLP HTTP host ports to the
        Aspire Dashboard container ports. Environment settings come from config/.env.
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
        [ValidatePattern('^aspire-dashboard-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('127.0.0.1', '0.0.0.0')]
        [string]$BindAddress,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$DashboardUiPort,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$OtlpGrpcPort,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$OtlpHttpPort,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AspireDashboardImage
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $content = @"
services:
  ${ServiceName}:
    image: $AspireDashboardImage
    container_name: $ContainerPrefix
    env_file:
      - ./config/.env
    ports:
      - "${BindAddress}:${DashboardUiPort}:18888"
      - "${BindAddress}:${OtlpGrpcPort}:18889"
      - "${BindAddress}:${OtlpHttpPort}:18890"
    restart: unless-stopped
"@

        Write-Utf8NoBom -Path $ComposePath -Content $content

        Write-Host "Compose file: $ComposePath"
        Write-Host $content
    }
}
