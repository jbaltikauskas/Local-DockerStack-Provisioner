function Assert-SonarCubeAdminPasswordPolicy () {
    <#
    .SYNOPSIS
        Validates the configured SonarQube admin password policy.
    .DESCRIPTION
        Throws when the password would fail SonarQube first-login password
        requirements. The password value is never logged.
    .NOTES
        1. Check length and required character classes.
        2. Throw a non-secret policy message when any check fails.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFileName
    )

    Process {

        if (
            $Password.Length -lt 12 -or
            $Password -cnotmatch '[A-Z]' -or
            $Password -cnotmatch '[a-z]' -or
            $Password -notmatch '\d' -or
            $Password -notmatch '[^a-zA-Z0-9]'
        ) {
            throw "$ConfigFileName SONAR_ADMIN_PASSWORD must be at least 12 characters and include at least 1 uppercase letter, 1 lowercase letter, 1 number, and 1 special character."
        }
    }
}

function Initialize-SonarCubeInstallerFromConfig () {
    <#
    .SYNOPSIS
        Loads required installer runtime settings from config-sonarcube.json.
    .DESCRIPTION
        Requires and validates all runtime settings. Values are written to
        script scope and cannot be overridden with installer parameters.
    .NOTES
        1. Require and parse config-sonarcube.json.
        2. Read and validate all required settings.
        3. Write validated values to script scope.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptRoot
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $configFileName = 'config-sonarcube.json'
        $configPath = Join-Path $ScriptRoot $configFileName
        if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
            throw "Required installer configuration file not found: '$configPath'."
        }

        try {

            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        }
        catch {
            throw "Could not parse required installer configuration '$configPath': $($_.Exception.Message)"
        }

        $portValue = Get-RequiredConfigString -Config $config -Name 'PORT' -ConfigFileName $configFileName
        $port = 0
        if (-not [int]::TryParse($portValue, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
            throw "$configFileName PORT must be an integer in range 1..65535."
        }

        $bindAddress = Get-RequiredConfigString -Config $config -Name 'BIND_ADDRESS' -ConfigFileName $configFileName
        if ($bindAddress -notin @('127.0.0.1', '0.0.0.0')) {
            throw "$configFileName BIND_ADDRESS must be 127.0.0.1 or 0.0.0.0."
        }

        $sonarAdminUsername = Get-RequiredConfigString -Config $config -Name 'SONAR_ADMIN_USERNAME' -ConfigFileName $configFileName
        $sonarAdminPassword = Get-RequiredConfigString -Config $config -Name 'SONAR_ADMIN_PASSWORD' -ConfigFileName $configFileName
        if ($sonarAdminPassword -eq 'admin') {
            throw "$configFileName SONAR_ADMIN_PASSWORD must not be admin."
        }
        Assert-SonarCubeAdminPasswordPolicy -Password $sonarAdminPassword -ConfigFileName $configFileName

        $installRootFolder = [string]$config.INSTALL_ROOT_FOLDER
        if ([string]::IsNullOrWhiteSpace($installRootFolder)) {
            $installRootFolder = $ScriptRoot
        }
        elseif (-not [System.IO.Path]::IsPathRooted($installRootFolder)) {
            $installRootFolder = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot $installRootFolder))
        }

        $settings = @{
            InstallRootFolder = $installRootFolder
            Port              = $port
            BindAddress       = $bindAddress
            WebHost           = Get-RequiredConfigString -Config $config -Name 'WEB_HOST' -ConfigFileName $configFileName
            SonarQubeImage    = Get-RequiredConfigString -Config $config -Name 'SONARQUBE_IMAGE' -ConfigFileName $configFileName
            PostgresImage     = Get-RequiredConfigString -Config $config -Name 'POSTGRES_IMAGE' -ConfigFileName $configFileName
            PostgresUser      = Get-RequiredConfigString -Config $config -Name 'POSTGRES_USER' -ConfigFileName $configFileName
            PostgresPassword  = Get-RequiredConfigString -Config $config -Name 'POSTGRES_PASSWORD' -ConfigFileName $configFileName
            PostgresDb        = Get-RequiredConfigString -Config $config -Name 'POSTGRES_DB' -ConfigFileName $configFileName
            SonarAdminUsername = $sonarAdminUsername
            SonarAdminPassword = $sonarAdminPassword
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
