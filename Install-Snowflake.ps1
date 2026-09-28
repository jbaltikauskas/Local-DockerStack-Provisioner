#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs and starts a self-contained Snowflake Docker stack on Windows 11.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Load required runtime settings from config-snowflake.json next to this script.
        2. Verify PowerShell, Docker Engine, and Docker Compose v2.
        3. Resolve the configured install root, new dated install folder, and verify the configured port is free.
        4. Create the install root, config folder, and snowflake-dat data folder.
        5. Write config\.env with Snowflake connection values and DB_PATH.
        6. Write docker-compose.yml.
        7. Write Start-Snowflake.ps1, Stop-Snowflake.ps1, batch launchers, and README.md.
        8. Pull images, start the stack, and print the endpoint.

.PARAMETER ServerNamePrefix
    Required install-folder prefix supplied directly to this script. The
    installer always appends -Snowflake-yyyyMMdd.

.INPUTS
    None. ServerNamePrefix comes from parameters. Runtime settings come only
    from config-snowflake.json.

.OUTPUTS
    Host messages and files under the new install folder. Exit code 0 on success.

.NOTES
    Requires PowerShell 7.2+, Docker Desktop, and Docker Compose v2.

.EXAMPLE
    PS> .\Install-Snowflake.ps1 -ServerNamePrefix dev

.EXAMPLE
    PS> .\Install-Snowflake.ps1 -ServerNamePrefix team-a
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Install folder prefix. The installer appends -Snowflake-yyyyMMdd.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerNamePrefix
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$modulePath = Join-Path $scriptRoot '.ps\Snowflake'
if (-not (Test-Path -LiteralPath $modulePath -PathType Container)) {
    throw "Required helper folder not found: '$modulePath'."
}

try {

    Write-Output "Loading module files:"

    $moduleFiles = @(
        '..\Core\Write-Utf8NoBom.ps1'
        '..\Core\Get-RequiredConfigString.ps1'
        '..\Core\Get-RequiredConfigBool.ps1'
        '..\Core\Assert-DockerPrerequisites.ps1'
        '..\Core\Start-ComposeStack.ps1'
        '..\Core\Test-TcpPortAvailable.ps1'
        '..\Core\Resolve-BindAddressFromHostName.ps1'
        'Core\Initialize-SnowflakeInstallerFromConfig.ps1'
        'Core\ConvertTo-SnowflakeContainerPrefix.ps1'
        'Core\Resolve-SnowflakeInstallFolder.ps1'
        'Core\New-SnowflakeFolderLayout.ps1'
        'Core\Resolve-SnowflakeInstallerPort.ps1'
        'Templates\New-SnowflakeComposeFile.ps1'
        'Templates\New-SnowflakeEnvFile.ps1'
        'Templates\Get-SnowflakeStartScriptTemplate.ps1'
        'Templates\Get-SnowflakeStopScriptTemplate.ps1'
        'Templates\Write-SnowflakeManagementScripts.ps1'
        'Templates\Write-SnowflakeReadme.ps1'
    )

    foreach ($relativePath in $moduleFiles) {
        $moduleFile = Join-Path $modulePath $relativePath
        Write-Output "  $moduleFile"
        . $moduleFile
    }

    Write-Host "Done loading module files." -ForegroundColor Green

    Initialize-SnowflakeInstallerFromConfig -ScriptRoot $scriptRoot
    Assert-DockerPrerequisites

    $serverRoot = Resolve-SnowflakeInstallFolder -InstallRootFolder $InstallRootFolder -ServerNamePrefix $ServerNamePrefix
    $Port = Resolve-SnowflakeInstallerPort -ConfiguredPort $Port
    $endpoint = "http://${HostName}:${Port}"

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install root      : $InstallRootFolder"
    Write-Output "Install folder    : $serverRoot"
    Write-Output "Endpoint          : $endpoint"
    Write-Output "Host name         : $HostName"
    Write-Output "Snowflake image   : $SnowflakeImage"
    Write-Output "Account           : $SnowflakeAccount"
    Write-Output "User              : $SnowflakeUser"
    Write-Output "Warehouse         : $SnowflakeWarehouse"
    Write-Output "Database          : $SnowflakeDatabase"
    Write-Output "Schema            : $SnowflakeSchema"
    Write-Output "Role              : $SnowflakeRole"
    Write-Output ""
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    Write-Host "Creating folder layout:" -ForegroundColor Green
    $paths = New-SnowflakeFolderLayout -ServerRoot $serverRoot
    $envPath = Join-Path $paths.Config '.env'
    $composePath = Join-Path $serverRoot 'docker-compose.yml'
    $serviceName = 'snowflake-emulator'
    Write-Host "Done creating folder layout." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating .env file:" -ForegroundColor Green
    New-SnowflakeEnvFile `
        -EnvPath $envPath `
        -Account $SnowflakeAccount `
        -User $SnowflakeUser `
        -CredentialValue $SnowflakePassword `
        -Warehouse $SnowflakeWarehouse `
        -Database $SnowflakeDatabase `
        -Schema $SnowflakeSchema `
        -Role $SnowflakeRole

    Write-Host "Creating compose file:" -ForegroundColor Green
    New-SnowflakeComposeFile `
        -ComposePath $composePath `
        -Port $Port `
        -SnowflakeImage $SnowflakeImage

    Write-Host "Done creating compose file." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating management scripts:" -ForegroundColor Green
    Write-SnowflakeManagementScripts `
        -ServerRoot $serverRoot `
        -HostName $HostName `
        -Port $Port
    $cSharpConnectionString = "account=$SnowflakeAccount;user=$SnowflakeUser;password=<see config\.env>;warehouse=$SnowflakeWarehouse;database=$SnowflakeDatabase;schema=$SnowflakeSchema;protocol=http;"
    Write-SnowflakeReadme `
        -ServerRoot $serverRoot `
        -HostName $HostName `
        -Port $Port `
        -CSharpConnectionString $cSharpConnectionString `
        -Account $SnowflakeAccount `
        -User $SnowflakeUser `
        -Database $SnowflakeDatabase `
        -Schema $SnowflakeSchema `
        -Warehouse $SnowflakeWarehouse `
        -Role $SnowflakeRole `
        -SnowflakeImage $SnowflakeImage `
        -ServiceName $serviceName
    Write-Host "Done creating management scripts." -ForegroundColor Green

    Start-ComposeStack -ComposePath $composePath

    Write-Host ""
    Write-Host "Snowflake is starting. First start may take about a minute." -ForegroundColor Green
    Write-Host "Endpoint: $endpoint" -ForegroundColor Cyan
    Write-Host "Install:  $serverRoot"
    Write-Host "Logs:     docker compose -f `"$composePath`" logs -f $serviceName"
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
