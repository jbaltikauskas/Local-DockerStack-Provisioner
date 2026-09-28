function Initialize-PostgreSqlInstallerFromConfig () {
    <#
    .SYNOPSIS
        Loads required installer runtime settings from config-postgresql.json.
    .DESCRIPTION
        Requires and validates all runtime settings. Values are written to
        script scope and cannot be overridden with installer parameters.
    .NOTES
        1. Require and parse config-postgresql.json.
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
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $configFileName = 'config-postgresql.json'
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
            InstallRootFolder = $installRootFolder
            Port             = $port
            HostName         = Get-RequiredConfigString -Config $config -Name 'HOST_NAME' -ConfigFileName $configFileName
            PostgreSqlImage  = Get-RequiredConfigString -Config $config -Name 'POSTGRES_IMAGE' -ConfigFileName $configFileName
            PostgreSqlUser   = Get-RequiredConfigString -Config $config -Name 'POSTGRES_USER' -ConfigFileName $configFileName
            PostgreSqlPassword = Get-RequiredConfigString -Config $config -Name 'POSTGRES_PASSWORD' -ConfigFileName $configFileName
            PostgreSqlDb     = Get-RequiredConfigString -Config $config -Name 'POSTGRES_DB' -ConfigFileName $configFileName
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
