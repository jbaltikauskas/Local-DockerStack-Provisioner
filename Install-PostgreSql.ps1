#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs and starts a self-contained PostgreSQL Docker stack on Windows 11.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Load required runtime settings from config-postgresql.json next to this script.
        2. Verify PowerShell, Docker Engine, and Docker Compose v2.
        3. Resolve the configured install root, new dated install folder, and verify the configured port is free.
        4. Create the install root and config folder.
        5. Write config\.env and docker-compose.yml.
        6. Write Start-PostgreSql.bat, Stop-PostgreSql.bat, and README.md.
        7. Pull images, start the stack, and print the connection string.

.PARAMETER ServerNamePrefix
    Required install-folder prefix supplied directly to this script. The
    installer always appends -PostgreSql-yyyyMMdd.

.INPUTS
    None. ServerNamePrefix comes from parameters. Runtime settings come only
    from config-postgresql.json.

.OUTPUTS
    Host messages and files under the new install folder. Exit code 0 on success.

.NOTES
    Requires PowerShell 7.2+, Docker Desktop, and Docker Compose v2.

.EXAMPLE
    PS> .\Install-PostgreSql.ps1 -ServerNamePrefix dev

.EXAMPLE
    PS> .\Install-PostgreSql.ps1 -ServerNamePrefix team-a
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Install folder prefix. The installer appends -PostgreSql-yyyyMMdd.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerNamePrefix
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$modulePath = Join-Path $scriptRoot '.ps\PostgreSql'
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
        'Core\Initialize-PostgreSqlInstallerFromConfig.ps1'
        'Core\ConvertTo-PostgreSqlContainerPrefix.ps1'
        'Core\Resolve-PostgreSqlInstallFolder.ps1'
        'Core\New-PostgreSqlFolderLayout.ps1'
        'Core\Resolve-PostgreSqlInstallerPort.ps1'
        'Templates\New-PostgreSqlComposeFile.ps1'
        'Templates\New-PostgreSqlEnvFile.ps1'
        'Templates\Get-PostgreSqlStartScriptTemplate.ps1'
        'Templates\Get-PostgreSqlStopScriptTemplate.ps1'
        'Templates\Write-PostgreSqlManagementScripts.ps1'
        'Templates\Write-PostgreSqlReadme.ps1'
    )

    foreach ($relativePath in $moduleFiles) {
        $moduleFile = Join-Path $modulePath $relativePath
        Write-Output "  $moduleFile"
        . $moduleFile
    }

    Write-Host "Done loading module files." -ForegroundColor Green

    Initialize-PostgreSqlInstallerFromConfig -ScriptRoot $scriptRoot
    Assert-DockerPrerequisites

    $serverRoot = Resolve-PostgreSqlInstallFolder -InstallRootFolder $InstallRootFolder -ServerNamePrefix $ServerNamePrefix
    $bindAddress = Resolve-BindAddressFromHostName -HostName $HostName -ConfigFileName 'config-postgresql.json'
    $Port = Resolve-PostgreSqlInstallerPort -ConfiguredPort $Port
    $connectionString = "Host=${HostName};Port=${Port};Username=${PostgreSqlUser};Database=${PostgreSqlDb}"

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install root     : $InstallRootFolder"
    Write-Output "Install folder   : $serverRoot"
    Write-Output "Connection       : $connectionString"
    Write-Output "Host name        : $HostName"
    Write-Output "Bind address     : $bindAddress"
    Write-Output "PostgreSQL image : $PostgreSqlImage"
    Write-Output "Database         : $PostgreSqlDb"
    Write-Output "User             : $PostgreSqlUser"
    Write-Output ""
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    Write-Host "Creating folder layout:" -ForegroundColor Green
    $paths = New-PostgreSqlFolderLayout -ServerRoot $serverRoot
    $envPath = Join-Path $paths.Config '.env'
    $composePath = Join-Path $serverRoot 'docker-compose.yml'
    $serviceName = "postgresql-$ServerNamePrefix"
    Write-Host "Done creating folder layout." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating .env file:" -ForegroundColor Green
    New-PostgreSqlEnvFile `
        -EnvPath $envPath `
        -User $PostgreSqlUser `
        -Password $PostgreSqlPassword `
        -Database $PostgreSqlDb

    $folderLeaf = Split-Path $serverRoot -Leaf
    $containerPrefix = ConvertTo-PostgreSqlContainerPrefix -Value $folderLeaf

    Write-Host "Creating compose file:" -ForegroundColor Green
    New-PostgreSqlComposeFile `
        -ComposePath $composePath `
        -ContainerPrefix $containerPrefix `
        -ServiceName $serviceName `
        -BindAddress $bindAddress `
        -Port $Port `
        -PostgreSqlImage $PostgreSqlImage

    Write-Host "Done creating compose file." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating management scripts:" -ForegroundColor Green
    Write-PostgreSqlManagementScripts `
        -ServerRoot $serverRoot `
        -HostName $HostName `
        -Port $Port `
        -User $PostgreSqlUser `
        -Database $PostgreSqlDb
    $fullConnectionString = "Host=${HostName};Port=${Port};Database=${PostgreSqlDb};Username=${PostgreSqlUser};Password=${PostgreSqlPassword};"
    $cSharpConnectionString = $fullConnectionString
    Write-PostgreSqlReadme `
        -ServerRoot $serverRoot `
        -HostName $HostName `
        -Port $Port `
        -User $PostgreSqlUser `
        -Database $PostgreSqlDb `
        -FullConnectionString $fullConnectionString `
        -CSharpConnectionString $cSharpConnectionString `
        -ServiceName $serviceName
    Write-Host "Done creating management scripts." -ForegroundColor Green

    Start-ComposeStack -ComposePath $composePath

    Write-Host ""
    Write-Host "PostgreSQL is starting. First start may take a few seconds." -ForegroundColor Green
    Write-Host "Connection: $connectionString" -ForegroundColor Cyan
    Write-Host "Install:    $serverRoot"
    Write-Host "Logs:       docker compose -f `"$composePath`" logs -f $serviceName"
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
