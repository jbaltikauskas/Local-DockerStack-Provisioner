#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs and starts a self-contained .NET Aspire Dashboard Docker stack on Windows 11.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Load required runtime settings from config-aspire-dashboard.json next to this script.
        2. Verify PowerShell, Docker Engine, and Docker Compose v2.
        3. Resolve the configured install root, new dated install folder, and verify configured ports are free.
        4. Create the install root and config folder.
        5. Write config\.env and docker-compose.yml.
        6. Write Start-AspireDashboard.ps1, Stop-AspireDashboard.ps1, batch launchers, README.md, and AspireDashboard.url.
        7. Pull images, start the stack, and print the dashboard and OTLP endpoints.

.PARAMETER ServerNamePrefix
    Required install-folder prefix supplied directly to this script. The
    installer always appends -AspireDashboard-yyyyMMdd.

.INPUTS
    None. ServerNamePrefix comes from parameters. Runtime settings come only
    from config-aspire-dashboard.json.

.OUTPUTS
    Host messages and files under the new install folder. Exit code 0 on success.

.NOTES
    Requires PowerShell 7.2+, Docker Desktop, and Docker Compose v2.

.EXAMPLE
    PS> .\Install-AspireDashboard.ps1 -ServerNamePrefix dev

.EXAMPLE
    PS> .\Install-AspireDashboard.ps1 -ServerNamePrefix team-a
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Install folder prefix. The installer appends -AspireDashboard-yyyyMMdd.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerNamePrefix
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$modulePath = Join-Path $scriptRoot '.ps\AspireDashboard'
if (-not (Test-Path -LiteralPath $modulePath -PathType Container)) {
    throw "Required helper folder not found: '$modulePath'."
}

try {

    Write-Output "Loading module files:"

    $moduleFiles = @(
        '..\Common\Write-Utf8NoBom.ps1'
        '..\Core\Get-RequiredConfigString.ps1'
        '..\Core\Get-RequiredConfigBool.ps1'
        '..\Core\Assert-DockerPrerequisites.ps1'
        '..\Core\Start-ComposeStack.ps1'
        '..\Core\Test-TcpPortAvailable.ps1'
        '..\Core\Resolve-BindAddressFromHostName.ps1'
        '..\Core\Write-InternetShortcut.ps1'
        'Core\Initialize-AspireDashboardInstallerFromConfig.ps1'
        'Core\ConvertTo-AspireDashboardContainerPrefix.ps1'
        'Core\Resolve-AspireDashboardInstallFolder.ps1'
        'Core\New-AspireDashboardFolderLayout.ps1'
        'Core\Resolve-AspireDashboardInstallerPort.ps1'
        'Core\Assert-AspireDashboardDistinctPorts.ps1'
        'Templates\New-AspireDashboardComposeFile.ps1'
        'Templates\New-AspireDashboardEnvFile.ps1'
        'Templates\Get-AspireDashboardStartScriptTemplate.ps1'
        'Templates\Get-AspireDashboardStopScriptTemplate.ps1'
        'Templates\Write-AspireDashboardManagementScripts.ps1'
        'Templates\Write-AspireDashboardReadme.ps1'
    )

    foreach ($relativePath in $moduleFiles) {
        $moduleFile = Join-Path $modulePath $relativePath
        Write-Output "  $moduleFile"
        . $moduleFile
    }

    Write-Host "Done loading module files." -ForegroundColor Green


    Initialize-AspireDashboardInstallerFromConfig -ScriptRoot $scriptRoot
    Assert-DockerPrerequisites

    $serverRoot = Resolve-AspireDashboardInstallFolder -InstallRootFolder $InstallRootFolder -ServerNamePrefix $ServerNamePrefix
    $bindAddress = Resolve-BindAddressFromHostName -HostName $HostName -ConfigFileName 'config-aspire-dashboard.json'
    $DashboardUiPort = Resolve-AspireDashboardInstallerPort -ConfiguredPort $DashboardUiPort -SettingName 'DASHBOARD_UI_PORT'
    $OtlpGrpcPort = Resolve-AspireDashboardInstallerPort -ConfiguredPort $OtlpGrpcPort -SettingName 'OTLP_GRPC_PORT'
    $OtlpHttpPort = Resolve-AspireDashboardInstallerPort -ConfiguredPort $OtlpHttpPort -SettingName 'OTLP_HTTP_PORT'
    Assert-AspireDashboardDistinctPorts -Ports @($DashboardUiPort, $OtlpGrpcPort, $OtlpHttpPort)

    $dashboardUrl = "http://${HostName}:${DashboardUiPort}"
    $otlpGrpcEndpoint = "http://${HostName}:${OtlpGrpcPort}"
    $otlpHttpEndpoint = "http://${HostName}:${OtlpHttpPort}"

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install root       : $InstallRootFolder"
    Write-Output "Install folder     : $serverRoot"
    Write-Output "Dashboard UI       : $dashboardUrl"
    Write-Output "OTLP gRPC endpoint : $otlpGrpcEndpoint"
    Write-Output "OTLP HTTP endpoint : $otlpHttpEndpoint"
    Write-Output "Host name          : $HostName"
    Write-Output "Bind address       : $bindAddress"
    Write-Output "Dashboard image    : $AspireDashboardImage"
    Write-Output "Allow anonymous    : $AllowAnonymous"
    Write-Output ""
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    Write-Host "Creating folder layout:" -ForegroundColor Green
    $paths = New-AspireDashboardFolderLayout -ServerRoot $serverRoot
    $envPath = Join-Path $paths.Config '.env'
    $composePath = Join-Path $serverRoot 'docker-compose.yml'
    $serviceName = "aspire-dashboard-$ServerNamePrefix"
    Write-Host "Done creating folder layout." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating .env file:" -ForegroundColor Green
    New-AspireDashboardEnvFile -EnvPath $envPath -AllowAnonymous $AllowAnonymous

    $folderLeaf = Split-Path $serverRoot -Leaf
    $containerPrefix = ConvertTo-AspireDashboardContainerPrefix -Value $folderLeaf

    Write-Host "Creating compose file:" -ForegroundColor Green
    New-AspireDashboardComposeFile `
        -ComposePath $composePath `
        -ContainerPrefix $containerPrefix `
        -ServiceName $serviceName `
        -BindAddress $bindAddress `
        -DashboardUiPort $DashboardUiPort `
        -OtlpGrpcPort $OtlpGrpcPort `
        -OtlpHttpPort $OtlpHttpPort `
        -AspireDashboardImage $AspireDashboardImage

    Write-Host "Done creating compose file." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating management scripts:" -ForegroundColor Green
    Write-AspireDashboardManagementScripts `
        -ServerRoot $serverRoot `
        -DashboardUrl $dashboardUrl `
        -OtlpGrpcEndpoint $otlpGrpcEndpoint `
        -OtlpHttpEndpoint $otlpHttpEndpoint
    Write-AspireDashboardReadme `
        -ServerRoot $serverRoot `
        -DashboardUrl $dashboardUrl `
        -OtlpGrpcEndpoint $otlpGrpcEndpoint `
        -OtlpHttpEndpoint $otlpHttpEndpoint `
        -ServiceName $serviceName `
        -AllowAnonymous $AllowAnonymous
    Write-InternetShortcut -ServerRoot $serverRoot -Name 'AspireDashboard' -Url $dashboardUrl | Out-Null
    Write-Host "Done creating management scripts." -ForegroundColor Green

    Start-ComposeStack -ComposePath $composePath

    Write-Host ""
    Write-Host "Aspire Dashboard is starting." -ForegroundColor Green
    Write-Host "Dashboard UI      : $dashboardUrl" -ForegroundColor Cyan
    Write-Host "OTLP gRPC endpoint: $otlpGrpcEndpoint"
    Write-Host "OTLP HTTP endpoint: $otlpHttpEndpoint"
    Write-Host "Install:           $serverRoot"
    Write-Host "Logs:              docker compose -f `"$composePath`" logs -f $serviceName"
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
