#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs and starts a self-contained Azure Cosmos DB emulator Docker stack on Windows 11.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Load required runtime settings from config-cosmosdb.json next to this script.
        2. Verify PowerShell, Docker Engine, and Docker Compose v2.
        3. Resolve the configured install root, new dated install folder, and verify configured ports are free.
        4. Create the install root, config folder, and cosmos-data folder.
        5. Write config\.env, config\account.key, and docker-compose.yml.
        6. Write Start-CosmosDb.ps1, Stop-CosmosDb.ps1, batch launchers, README.md, and CosmosDb.url.
        7. Pull images, start the stack, and print the gateway, Data Explorer, and health endpoints.

.PARAMETER ServerNamePrefix
    Required install-folder prefix supplied directly to this script. The
    installer always appends -CosmosDb-yyyyMMdd.

.INPUTS
    None. ServerNamePrefix comes from parameters. Runtime settings come only
    from config-cosmosdb.json.

.OUTPUTS
    Host messages and files under the new install folder. Exit code 0 on success.

.NOTES
    Requires PowerShell 7.2+, Docker Desktop, and Docker Compose v2.

.EXAMPLE
    PS> .\Install-CosmosDb.ps1 -ServerNamePrefix dev

.EXAMPLE
    PS> .\Install-CosmosDb.ps1 -ServerNamePrefix team-a
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Install folder prefix. The installer appends -CosmosDb-yyyyMMdd.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerNamePrefix
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$modulePath = Join-Path $scriptRoot '.ps\CosmosDb'
if (-not (Test-Path -LiteralPath $modulePath -PathType Container)) {
    throw "Required helper folder not found: '$modulePath'."
}

try {

    Write-Output "Loading module files:"

    $moduleFiles = @(
        '..\Common\Write-Utf8NoBom.ps1'
        'Core\Configuration.ps1'
        'Core\Docker.ps1'
        'Core\FileSystem.ps1'
        'Core\Network.ps1'
        'Templates\New-CosmosDbComposeFile.ps1'
        'Templates\New-CosmosDbEnvFile.ps1'
        'Templates\Get-CosmosDbStartScriptTemplate.ps1'
        'Templates\Get-CosmosDbStopScriptTemplate.ps1'
        'Templates\Write-CosmosDbManagementScripts.ps1'
        'Templates\Write-CosmosDbReadme.ps1'
        'Templates\Write-CosmosDbWebUiShortcut.ps1'
    )

    foreach ($relativePath in $moduleFiles) {
        $moduleFile = Join-Path $modulePath $relativePath
        Write-Output "  $moduleFile"
        . $moduleFile
    }

    Write-Host "Done loading module files." -ForegroundColor Green

    Initialize-CosmosDbInstallerFromConfig -ScriptRoot $scriptRoot
    Assert-CosmosDbInstallerPrerequisites

    $serverRoot = Resolve-CosmosDbInstallFolder -InstallRootFolder $InstallRootFolder -ServerNamePrefix $ServerNamePrefix
    $bindAddress = Resolve-CosmosDbBindAddressFromHostName -HostName $HostName -ConfigFileName 'config-cosmosdb.json'
    $Port = Resolve-CosmosDbInstallerPort -ConfiguredPort $Port -SettingName 'PORT'
    $HealthPort = Resolve-CosmosDbInstallerPort -ConfiguredPort $HealthPort -SettingName 'HEALTH_PORT'
    $ExplorerPort = Resolve-CosmosDbInstallerPort -ConfiguredPort $ExplorerPort -SettingName 'EXPLORER_PORT'
    Assert-CosmosDbDistinctPorts -Ports @($Port, $HealthPort, $ExplorerPort)

    $urlScheme = 'https'
    if ($Protocol -eq 'http') {
        $urlScheme = 'http'
    }

    $endpoint = "${urlScheme}://${HostName}:${Port}"
    $explorerUrl = "${urlScheme}://${HostName}:${ExplorerPort}"
    $healthUrl = "http://${HostName}:${HealthPort}/ready"
    $connectionString = "AccountEndpoint=${endpoint}/;AccountKey=${AccountKey}"

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install root     : $InstallRootFolder"
    Write-Output "Install folder   : $serverRoot"
    Write-Output "Gateway          : $endpoint"
    Write-Output "Data Explorer    : $explorerUrl"
    Write-Output "Health probe     : $healthUrl"
    Write-Output "Host name        : $HostName"
    Write-Output "Bind address     : $bindAddress"
    Write-Output "Cosmos DB image  : $CosmosDbImage"
    Write-Output "Protocol         : $Protocol"
    Write-Output ""
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    Write-Host "Creating folder layout:" -ForegroundColor Green
    $paths = New-CosmosDbFolderLayout -ServerRoot $serverRoot
    $envPath = Join-Path $paths.Config '.env'
    $keyFilePath = Join-Path $paths.Config 'account.key'
    $composePath = Join-Path $serverRoot 'docker-compose.yml'
    $serviceName = "cosmosdb-$ServerNamePrefix"
    Write-Host "Done creating folder layout." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating .env file:" -ForegroundColor Green
    New-CosmosDbEnvFile `
        -EnvPath $envPath `
        -KeyFilePath $keyFilePath `
        -HostName $HostName `
        -Protocol $Protocol `
        -AccountKey $AccountKey

    $folderLeaf = Split-Path $serverRoot -Leaf
    $containerPrefix = ConvertTo-CosmosDbContainerPrefix -Value $folderLeaf

    Write-Host "Creating compose file:" -ForegroundColor Green
    New-CosmosDbComposeFile `
        -ComposePath $composePath `
        -ContainerPrefix $containerPrefix `
        -ServiceName $serviceName `
        -BindAddress $bindAddress `
        -Port $Port `
        -HealthPort $HealthPort `
        -ExplorerPort $ExplorerPort `
        -CosmosDbImage $CosmosDbImage

    Write-Host "Done creating compose file." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating management scripts:" -ForegroundColor Green
    Write-CosmosDbManagementScripts `
        -ServerRoot $serverRoot `
        -Endpoint $endpoint `
        -ExplorerUrl $explorerUrl `
        -HealthUrl $healthUrl

    if ($Protocol -eq 'http') {
        $cSharpConnectionExample = @"
var accountEndpoint = "$endpoint/";
var accountKey = "$AccountKey";
var cosmosClientOptions = new CosmosClientOptions
{
    ConnectionMode = ConnectionMode.Gateway
};
using var cosmosClient = new CosmosClient(accountEndpoint, accountKey, cosmosClientOptions);
"@
    }
    else {
        $cSharpConnectionExample = @"
var accountEndpoint = "$endpoint/";
var accountKey = "$AccountKey";
var cosmosClientOptions = new CosmosClientOptions
{
    ConnectionMode = ConnectionMode.Gateway,
    HttpClientFactory = () => new HttpClient(new HttpClientHandler
    {
        ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
    })
};
using var cosmosClient = new CosmosClient(accountEndpoint, accountKey, cosmosClientOptions);
"@
    }

    Write-CosmosDbReadme `
        -ServerRoot $serverRoot `
        -Endpoint $endpoint `
        -ExplorerUrl $explorerUrl `
        -HealthUrl $healthUrl `
        -ConnectionString $connectionString `
        -CSharpConnectionExample $cSharpConnectionExample `
        -ServiceName $serviceName
    Write-CosmosDbWebUiShortcut -ServerRoot $serverRoot -ExplorerUrl $explorerUrl | Out-Null
    Write-Host "Done creating management scripts." -ForegroundColor Green

    Start-CosmosDbStack -ComposePath $composePath

    Write-Host ""
    Write-Host "Cosmos DB is starting. First start may take a few seconds." -ForegroundColor Green
    Write-Host "Gateway:        $endpoint" -ForegroundColor Cyan
    Write-Host "Data Explorer:  $explorerUrl" -ForegroundColor Cyan
    Write-Host "Health probe:   $healthUrl"
    Write-Host "Install:        $serverRoot"
    Write-Host "Logs:           docker compose -f `"$composePath`" logs -f $serviceName"
}
catch {

    Write-Host ""
    Write-Error "Caught an exception:" -ErrorAction Continue
    Write-Error "Exception Type: $($_.Exception.GetType().FullName)" -ErrorAction Continue
    Write-Error "Exception Message: $($_.Exception.Message)" -ErrorAction Continue
    Write-Host ""
    Write-Host "Script failed to execute." -ForegroundColor Red
    Read-Host "Press Enter to close the window ..."
    EXIT 1
}

Write-Host ""
Write-Host "Script executed successfully." -ForegroundColor Green
Read-Host "Press Enter to close the window ..."
