function Get-CosmosDbRequiredConfigString () {
    <#
    .SYNOPSIS
        Reads a required non-empty string from the Cosmos DB installer config file.
    .DESCRIPTION
        Returns the named property as a string and throws when it is absent or empty.
    .NOTES
        1. Read Name from Config.
        2. Throw when missing or empty.
        3. Return the string.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFileName
    )

    Process {

        $value = [string]$Config.$Name
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Required $ConfigFileName setting '$Name' is missing or empty."
        }

        return $value
    }
}

function Get-CosmosDbRequiredConfigPort () {
    <#
    .SYNOPSIS
        Reads and validates a required TCP port from config-cosmosdb.json.
    .DESCRIPTION
        Returns the named property as an integer in the valid TCP port range.
    .NOTES
        1. Read Name from Config.
        2. Parse as integer.
        3. Validate range.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFileName
    )

    Process {

        $portValue = Get-CosmosDbRequiredConfigString -Config $Config -Name $Name -ConfigFileName $ConfigFileName
        $port = 0
        if (-not [int]::TryParse($portValue, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
            throw "$ConfigFileName $Name must be an integer in range 1..65535."
        }

        return $port
    }
}

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

        $protocol = (Get-CosmosDbRequiredConfigString -Config $config -Name 'PROTOCOL' -ConfigFileName $configFileName).ToLowerInvariant()
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
            Port              = Get-CosmosDbRequiredConfigPort -Config $config -Name 'PORT' -ConfigFileName $configFileName
            HealthPort        = Get-CosmosDbRequiredConfigPort -Config $config -Name 'HEALTH_PORT' -ConfigFileName $configFileName
            ExplorerPort      = Get-CosmosDbRequiredConfigPort -Config $config -Name 'EXPLORER_PORT' -ConfigFileName $configFileName
            HostName          = Get-CosmosDbRequiredConfigString -Config $config -Name 'HOST_NAME' -ConfigFileName $configFileName
            CosmosDbImage     = Get-CosmosDbRequiredConfigString -Config $config -Name 'COSMOSDB_IMAGE' -ConfigFileName $configFileName
            Protocol          = $protocol
            AccountKey        = Get-CosmosDbRequiredConfigString -Config $config -Name 'ACCOUNT_KEY' -ConfigFileName $configFileName
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
