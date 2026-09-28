#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs and starts a self-contained MSSQL Server Developer Edition Docker stack on Windows 11.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Load required runtime settings from config-mssql.json next to this script.
        2. Verify PowerShell, Docker Engine, and Docker Compose v2.
        3. Resolve the configured install root, new dated install folder, and verify the configured port is free.
        4. Create the install root and config folder.
        5. Write the SA password to config\.env.secrets when it is missing.
        6. Write config\.env and docker-compose.yml.
        7. Write Start-MSSql.ps1, Stop-MSSql.ps1, batch launchers, and README.md.
        8. Pull images, start the stack, and print the connection string.

.PARAMETER ServerNamePrefix
    Required install-folder prefix supplied directly to this script. The
    installer always appends -MSSql-yyyyMMdd.

.INPUTS
    None. ServerNamePrefix comes from parameters. Runtime settings come only
    from config-mssql.json.

.OUTPUTS
    Host messages and files under the new install folder. Exit code 0 on success.

.NOTES
    Requires PowerShell 7.2+, Docker Desktop, and Docker Compose v2.

.EXAMPLE
    PS> .\Install-MSSql.ps1 -ServerNamePrefix dev

.EXAMPLE
    PS> .\Install-MSSql.ps1 -ServerNamePrefix team-a
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Install folder prefix. The installer appends -MSSql-yyyyMMdd.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerNamePrefix
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$modulePath = Join-Path $scriptRoot '.ps\MSSql'
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
        'Core\Initialize-MSSqlInstallerFromConfig.ps1'
        'Core\ConvertTo-MSSqlContainerPrefix.ps1'
        'Core\Resolve-MSSqlInstallFolder.ps1'
        'Core\New-MSSqlFolderLayout.ps1'
        'Core\Resolve-MSSqlInstallerPort.ps1'
        'Core\Initialize-MSSqlSecrets.ps1'
        'Templates\New-MSSqlComposeFile.ps1'
        'Templates\New-MSSqlEnvFile.ps1'
        'Templates\Get-MSSqlStartScriptTemplate.ps1'
        'Templates\Get-MSSqlStopScriptTemplate.ps1'
        'Templates\Write-MSSqlManagementScripts.ps1'
        'Templates\Write-MSSqlReadme.ps1'
    )

    foreach ($relativePath in $moduleFiles) {
        $moduleFile = Join-Path $modulePath $relativePath
        Write-Output "  $moduleFile"
        . $moduleFile
    }

    Write-Host "Done loading module files." -ForegroundColor Green


    Initialize-MSSqlInstallerFromConfig -ScriptRoot $scriptRoot
    Assert-DockerPrerequisites

    $serverRoot = Resolve-MSSqlInstallFolder -InstallRootFolder $InstallRootFolder -ServerNamePrefix $ServerNamePrefix
    $Port = Resolve-MSSqlInstallerPort -ConfiguredPort $Port
    $connectionString = "Server=${HostName},${Port};User Id=sa;TrustServerCertificate=True"

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install root    : $InstallRootFolder"
    Write-Output "Install folder  : $serverRoot"
    Write-Output "Connection      : $connectionString"
    Write-Output "Host name       : $HostName"
    Write-Output "MSSQL image     : $MSSqlImage"
    Write-Output "MSSQL edition   : $MSSqlPid"
    Write-Output ""
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    Write-Host "Creating folder layout:" -ForegroundColor Green
    $paths = New-MSSqlFolderLayout -ServerRoot $serverRoot
    $envPath = Join-Path $paths.Config '.env'
    $secretsPath = Join-Path $paths.Config '.env.secrets'
    $composePath = Join-Path $serverRoot 'docker-compose.yml'
    $serviceName = "mssql-$ServerNamePrefix"
    Write-Host "Done creating folder layout." -ForegroundColor Green

    Write-Output ""
    Write-Host "Initializing secrets:" -ForegroundColor Green
    Initialize-MSSqlSecrets `
        -SecretsPath $secretsPath `
        -SaPassword $MSSqlSaPassword
    Write-Host "Done initializing secrets." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating .env file:" -ForegroundColor Green
    New-MSSqlEnvFile -EnvPath $envPath -MSSqlPid $MSSqlPid

    $folderLeaf = Split-Path $serverRoot -Leaf
    $containerPrefix = ConvertTo-MSSqlContainerPrefix -Value $folderLeaf

    Write-Host "Creating compose file:" -ForegroundColor Green
    New-MSSqlComposeFile `
        -ComposePath $composePath `
        -ContainerPrefix $containerPrefix `
        -ServiceName $serviceName `
        -Port $Port `
        -MSSqlImage $MSSqlImage

    Write-Host "Done creating compose file." -ForegroundColor Green

    Write-Output ""
    Write-Host "Creating management scripts:" -ForegroundColor Green
    Write-MSSqlManagementScripts -ServerRoot $serverRoot -HostName $HostName -Port $Port
    $fullConnectionString = "Data Source=${HostName},${Port};Initial Catalog=master;Persist Security Info=True;User ID=sa;Password=${MSSqlSaPassword};Pooling=False;MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True;Command Timeout=0"
    $cSharpConnectionString = "Server=${HostName},${Port};Database=master;User Id=sa;Password=${MSSqlSaPassword};Encrypt=False;TrustServerCertificate=True;"
    Write-MSSqlReadme `
        -ServerRoot $serverRoot `
        -HostName $HostName `
        -Port $Port `
        -FullConnectionString $fullConnectionString `
        -CSharpConnectionString $cSharpConnectionString `
        -ServiceName $serviceName
    Write-Host "Done creating management scripts." -ForegroundColor Green

    Start-ComposeStack -ComposePath $composePath

    Write-Host ""
    Write-Host "MSSQL Server is starting. First start may take 30-60 seconds." -ForegroundColor Green
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
