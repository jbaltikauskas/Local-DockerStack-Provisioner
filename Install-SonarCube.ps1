#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs and starts a self-contained SonarQube Docker stack on Windows 11.

.DESCRIPTION
    Top-down flow when this script runs:

        1. Load required runtime settings from config-sonarcube.json next to this script.
        2. Verify PowerShell, Docker Engine, and Docker Compose v2.
        3. Resolve the configured install root, new dated install folder, and an available Web UI port.
        4. Create the install root and config folder.
        5. Write configured admin-derived database credentials when config\.env.secrets is missing.
        6. Write config\.env and docker-compose.yml.
        7. Write Start-SonarCube.ps1, Stop-SonarCube.ps1, README.md, and SonarCube.url.
        8. Set vm.max_map_count inside Docker Desktop's Linux VM.
        9. Create unique named volumes, pull images, and start PostgreSQL.
        10. Repair the configured PostgreSQL user password for existing volumes.
        11. Start SonarQube.
        12. Pause briefly, wait for the SonarQube Web API, and set the admin password.
        13. Append required global sonar.exclusions through the Web API.
        14. Install or update the global SonarScanner for .NET tool
            (dotnet-sonarscanner) and verify with `dotnet sonarscanner --version`.
        15. Create a no-expiration Global Analysis Token and save SONAR_TOKEN in
            config\.env.secrets.
        16. Write Scan-SonarCube.ps1 with embedded host URL and token; project
            key is computed at scan time from solution name and git branch.
        17. Print the Web UI URL.

.PARAMETER ServerNamePrefix
    Required install-folder prefix supplied directly to this script. The
    installer always appends -SonarCube-yyyyMMdd.

.INPUTS
    None. ServerNamePrefix comes from parameters. Runtime settings come only
    from config-sonarcube.json.

.OUTPUTS
    Host messages and files under the new install folder. Exit code 0 on success.

.NOTES
    Requires PowerShell 7.2+, Docker Desktop, Docker Compose v2, and the .NET SDK
    (for the global SonarScanner for .NET tool).

.EXAMPLE
    PS> .\Install-SonarCube.ps1 -ServerNamePrefix dev

.EXAMPLE
    PS> .\Install-SonarCube.ps1 -ServerNamePrefix team-a
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Install folder prefix. The installer appends -SonarCube-yyyyMMdd.")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerNamePrefix
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$modulePath = Join-Path $scriptRoot '.ps\SonarCube'
if (-not (Test-Path -LiteralPath $modulePath -PathType Container)) {
    throw "Required helper folder not found: '$modulePath'."
}

try {

    Write-Output "Loading module files:" -ForegroundColor Green

    $moduleFiles = @(
        '..\Core\Configuration.ps1'
        '..\Core\Docker.ps1'
        '..\Core\Network.ps1'
        'Core\Configuration.ps1'
        'Core\Docker.ps1'
        'Core\DotNet.ps1'
        'Core\FileSystem.ps1'
        'Core\Network.ps1'
        'Core\Security.ps1'
        '..\Common\Write-Utf8NoBom.ps1'
        'Templates\New-SonarCubeComposeFile.ps1'
        'Templates\New-SonarCubeEnvFile.ps1'
        'Templates\Get-SonarCubeStartScriptTemplate.ps1'
        'Templates\Get-SonarCubeStopScriptTemplate.ps1'
        'Templates\Get-SonarCubeScanScriptTemplate.ps1'
        'Templates\Write-SonarCubeManagementScripts.ps1'
        'Templates\Write-SonarCubeScanScript.ps1'
        'Templates\Write-SonarCubeReadme.ps1'
        'Templates\Write-SonarCubeWebUiShortcut.ps1'
    )

    foreach ($relativePath in $moduleFiles) {
        $moduleFile = Join-Path $modulePath $relativePath
        Write-Output "$moduleFile"
        . $moduleFile
    }

    Write-Output "Done loading module files." -ForegroundColor Green


    Initialize-SonarCubeInstallerFromConfig -ScriptRoot $scriptRoot
    Assert-DockerPrerequisites

    $serverRoot = Resolve-SonarCubeInstallFolder -InstallRootFolder $InstallRootFolder -ServerNamePrefix $ServerNamePrefix
    $Port = Resolve-SonarCubeInstallerPort -ConfiguredPort $Port -BindAddress $BindAddress

    Write-Output ""
    Write-Output "--------------------------- BEGIN: Settings ---------------------------"
    Write-Output ""
    Write-Output "Install root    : $InstallRootFolder"
    Write-Output "Install folder  : $serverRoot"
    Write-Output "Web UI          : http://${WebHost}:${Port}"
    Write-Output "Bind address    : $BindAddress"
    Write-Output "SonarQube image : $SonarQubeImage"
    Write-Output "Postgres image  : $PostgresImage"
    Write-Output "Postgres user   : $PostgresUser"
    Write-Output "Postgres DB     : $PostgresDb"
    Write-Output "Admin user      : $SonarAdminUsername"
    Write-Output "Admin password  : configured in config-sonarcube.json"
    Write-Output ""
    $PSBoundParameters | Out-String | Write-Output
    Write-Output "---------------------------- END: Settings ----------------------------"
    Write-Output ""

    Write-Output "Creating folder layout:" -ForegroundColor Green
    $paths = New-SonarCubeFolderLayout -ServerRoot $serverRoot
    $envPath = Join-Path $paths.Config '.env'
    $secretsPath = Join-Path $paths.Config '.env.secrets'
    Write-Output "Config path: $paths.Config" -ForegroundColor Yellow
    $composePath = Join-Path $serverRoot 'docker-compose.yml'
    Write-Output "Done creating folder layout." -ForegroundColor Yellow
    $sonarQubeServiceName = "sonarqube-$ServerNamePrefix"
    $databaseServiceName = "postgres-$ServerNamePrefix"
    Write-Output "Done creating folder layout." -ForegroundColor Green

    Write-Output ""
    Write-Output "Initializing secrets:" -ForegroundColor Green
    Initialize-SonarCubeSecrets `
        -SecretsPath $secretsPath `
        -DatabaseServiceName $databaseServiceName `
        -DatabaseName $PostgresDb `
        -DatabaseLogin $PostgresUser `
        -DatabaseSecret $PostgresPassword `
        -AdminLogin $SonarAdminUsername `
        -AdminPassword $SonarAdminPassword
    Write-Output "Done initializing secrets." -ForegroundColor Green

    Write-Output ""

    Write-Output "Creating .env file:" -ForegroundColor Green
    New-SonarCubeEnvFile -EnvPath $envPath -DatabaseName $PostgresDb

    $folderLeaf = Split-Path $serverRoot -Leaf
    $containerPrefix = ConvertTo-SonarCubeContainerPrefix -Value $folderLeaf

    Write-Output "Creating compose file:" -ForegroundColor Green
    New-SonarCubeComposeFile `
        -ComposePath $composePath `
        -ContainerPrefix $containerPrefix `
        -SonarQubeServiceName $sonarQubeServiceName `
        -DatabaseServiceName $databaseServiceName `
        -NetworkName "sonarnet-$ServerNamePrefix" `
        -BindAddress $BindAddress `
        -Port $Port `
        -SonarQubeImage $SonarQubeImage `
        -PostgresImage $PostgresImage

    Write-Output "Done creating compose file." -ForegroundColor Green

    Write-Output ""

    Write-Output "Creating management scripts:" -ForegroundColor Green
    Write-SonarCubeManagementScripts -ServerRoot $serverRoot -WebHost $WebHost
    Write-SonarCubeReadme -ServerRoot $serverRoot -WebHost $WebHost -Port $Port -SonarQubeServiceName $sonarQubeServiceName
    $shortcutPath = Write-SonarCubeWebUiShortcut -ServerRoot $serverRoot -WebHost $WebHost -Port $Port

    Set-SonarCubeDockerVirtualMemory
    Start-SonarCubeDatabaseService -ComposePath $composePath -DatabaseServiceName $databaseServiceName
    Repair-SonarCubePostgreSqlPassword `
        -ComposePath $composePath `
        -DatabaseServiceName $databaseServiceName `
        -DatabaseName $PostgresDb `
        -DatabaseLogin $PostgresUser `
        -DatabaseSecret $PostgresPassword
    Start-SonarCubeApplicationServices -ComposePath $composePath
    Write-Host "Waiting 30 seconds before configuring the SonarQube admin password." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Set-SonarCubeAdminPassword -WebHost $WebHost -Port $Port -AdminLogin $SonarAdminUsername -AdminPassword $SonarAdminPassword

    Write-Host ""
    Write-Host "Configuring analysis exclusions:" -ForegroundColor Green
    Set-SonarCubeAnalysisExclusions `
        -WebHost $WebHost `
        -Port $Port `
        -AdminLogin $SonarAdminUsername `
        -AdminPassword $SonarAdminPassword
    Write-Host "Done configuring analysis exclusions." -ForegroundColor Green

    Write-Host ""
    Write-Host "Installing SonarScanner for .NET:" -ForegroundColor Green
    Install-SonarCubeDotNetScanner
    Write-Host "Done installing SonarScanner for .NET." -ForegroundColor Green

    Write-Host ""
    Write-Host "Configuring scanner credentials:" -ForegroundColor Green
    $analysisToken = New-SonarCubeGlobalAnalysisToken `
        -WebHost $WebHost `
        -Port $Port `
        -AdminLogin $SonarAdminUsername `
        -AdminPassword $SonarAdminPassword `
        -TokenName 'local-global-analysis'
    Write-SonarCubeAnalysisSecrets `
        -SecretsPath $secretsPath `
        -AnalysisToken $analysisToken
    Write-Host "Done configuring scanner credentials." -ForegroundColor Green

    Write-Host ""
    Write-Host "Creating scan script:" -ForegroundColor Green
    Write-SonarCubeScanScript `
        -ServerRoot $serverRoot `
        -WebHost $WebHost `
        -Port $Port `
        -AnalysisToken $analysisToken
    $analysisToken = $null
    Write-Host "Done creating scan script." -ForegroundColor Green

    Write-Host ""
    Write-Host "SonarQube is running." -ForegroundColor Green
    Write-Host "Web UI:      http://${WebHost}:${Port}" -ForegroundColor Cyan
    Write-Host "Login:       configured SONAR_ADMIN_USERNAME / configured SONAR_ADMIN_PASSWORD" -ForegroundColor Cyan
    Write-Host "Project key: computed at scan time (solution name[--git-branch])" -ForegroundColor Cyan
    Write-Host "Token:       embedded in Scan-SonarCube.ps1 (also saved in config\.env.secrets)" -ForegroundColor Cyan
    Write-Host "Scanner:     global tool dotnet-sonarscanner (dotnet sonarscanner --version)" -ForegroundColor Cyan
    Write-Host "Scan script: $(Join-Path $serverRoot 'Scan-SonarCube.ps1')" -ForegroundColor Cyan
    Write-Host "Install:     $serverRoot"
    Write-Host "Shortcut:    $shortcutPath"
    Write-Host "Logs:        docker compose -f `"$composePath`" logs -f $sonarQubeServiceName"
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
