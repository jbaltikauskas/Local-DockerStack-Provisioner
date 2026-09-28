function Initialize-SnowflakeInstallerFromConfig () {
    <#
    .SYNOPSIS
        Loads required installer runtime settings from config-snowflake.json.
    .DESCRIPTION
        Requires and validates all runtime settings. Values are written to
        script scope and cannot be overridden with installer parameters.
    .NOTES
        1. Require and parse config-snowflake.json.
        2. Read and validate all required settings.
        3. Write validated values to script scope.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Absolute path to the installer script's own folder.")]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptRoot
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $configFileName = 'config-snowflake.json'
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

        $installRootFolder = [string]$config.INSTALL_ROOT_FOLDER
        if ([string]::IsNullOrWhiteSpace($installRootFolder)) {
            $installRootFolder = $ScriptRoot
        }
        elseif (-not [System.IO.Path]::IsPathRooted($installRootFolder)) {
            $installRootFolder = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot $installRootFolder))
        }

        $settings = @{
            InstallRootFolder   = $installRootFolder
            Port               = $port
            HostName           = Get-RequiredConfigString -Config $config -Name 'HOST_NAME' -ConfigFileName $configFileName
            SnowflakeImage     = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_IMAGE' -ConfigFileName $configFileName
            SnowflakeAccount   = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_ACCOUNT' -ConfigFileName $configFileName
            SnowflakeUser      = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_USER' -ConfigFileName $configFileName
            SnowflakePassword  = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_PASSWORD' -ConfigFileName $configFileName
            SnowflakeWarehouse = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_WAREHOUSE' -ConfigFileName $configFileName
            SnowflakeDatabase  = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_DATABASE' -ConfigFileName $configFileName
            SnowflakeSchema    = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_SCHEMA' -ConfigFileName $configFileName
            SnowflakeRole      = Get-RequiredConfigString -Config $config -Name 'SNOWFLAKE_ROLE' -ConfigFileName $configFileName
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
