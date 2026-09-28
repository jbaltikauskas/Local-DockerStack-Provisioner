function Initialize-MSSqlInstallerFromConfig () {
    <#
    .SYNOPSIS
        Loads required installer runtime settings from config-mssql.json.
    .DESCRIPTION
        Requires and validates all runtime settings. Values are written to
        script scope and cannot be overridden with installer parameters.
    .NOTES
        1. Require and parse config-mssql.json.
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

        $configFileName = 'config-mssql.json'
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

        $mssqlPid = Get-RequiredConfigString -Config $config -Name 'MSSQL_PID' -ConfigFileName $configFileName
        if ($mssqlPid -notin @('Developer', 'Express', 'Standard', 'Enterprise', 'EnterpriseCore')) {
            throw "$configFileName MSSQL_PID must be one of: Developer, Express, Standard, Enterprise, EnterpriseCore."
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
            Port           = $port
            HostName       = Get-RequiredConfigString -Config $config -Name 'HOST_NAME' -ConfigFileName $configFileName
            MSSqlImage     = Get-RequiredConfigString -Config $config -Name 'MSSQL_IMAGE' -ConfigFileName $configFileName
            MSSqlSaPassword = Get-RequiredConfigString -Config $config -Name 'MSSQL_SA_PASSWORD' -ConfigFileName $configFileName
            MSSqlPid       = $mssqlPid
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
