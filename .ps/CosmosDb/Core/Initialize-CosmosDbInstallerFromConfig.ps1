function Initialize-CosmosDbInstallerFromConfig () {
    <#
    .SYNOPSIS
        Loads required installer runtime settings from config-cosmosdb.json.
    .DESCRIPTION
        Requires and validates all runtime settings. Values are written to
        script scope and cannot be overridden with installer parameters.
    .NOTES
        1. Require and parse config-cosmosdb.json.
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

        $configFileName = 'config-cosmosdb.json'
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

        $protocol = (Get-RequiredConfigString -Config $config -Name 'PROTOCOL' -ConfigFileName $configFileName).ToLowerInvariant()
        $allowedProtocols = @('http', 'https', 'https-insecure')
        if ($allowedProtocols -notcontains $protocol) {
            throw "$configFileName PROTOCOL must be http, https, or https-insecure."
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
            Port              = Get-RequiredConfigPort -Config $config -Name 'PORT' -ConfigFileName $configFileName
            HealthPort        = Get-RequiredConfigPort -Config $config -Name 'HEALTH_PORT' -ConfigFileName $configFileName
            ExplorerPort      = Get-RequiredConfigPort -Config $config -Name 'EXPLORER_PORT' -ConfigFileName $configFileName
            HostName          = Get-RequiredConfigString -Config $config -Name 'HOST_NAME' -ConfigFileName $configFileName
            CosmosDbImage     = Get-RequiredConfigString -Config $config -Name 'COSMOSDB_IMAGE' -ConfigFileName $configFileName
            Protocol          = $protocol
            AccountKey        = Get-RequiredConfigString -Config $config -Name 'ACCOUNT_KEY' -ConfigFileName $configFileName
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
