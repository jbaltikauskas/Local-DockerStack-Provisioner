function Get-AspireDashboardRequiredConfigString () {
    <#
    .SYNOPSIS
        Reads a required non-empty string from the Aspire Dashboard installer config file.
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

function Get-AspireDashboardRequiredConfigBool () {
    <#
    .SYNOPSIS
        Reads a required Boolean from the Aspire Dashboard installer config file.
    .DESCRIPTION
        Returns the named property as a Boolean and throws when it is absent or not Boolean-like.
    .NOTES
        1. Read Name from Config.
        2. Parse as Boolean.
        3. Return the Boolean.
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

        $property = $Config.PSObject.Properties[$Name]
        if ($null -eq $property) {
            throw "Required $ConfigFileName setting '$Name' is missing."
        }

        $value = $property.Value
        if ($value -is [bool]) {
            return $value
        }

        $boolValue = $false
        if ([bool]::TryParse([string]$value, [ref]$boolValue)) {
            return $boolValue
        }

        throw "$ConfigFileName $Name must be true or false."
    }
}

function Get-AspireDashboardRequiredConfigPort () {
    <#
    .SYNOPSIS
        Reads and validates a required TCP port from config-aspire-dashboard.json.
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

        $portValue = Get-AspireDashboardRequiredConfigString -Config $Config -Name $Name -ConfigFileName $ConfigFileName
        $port = 0
        if (-not [int]::TryParse($portValue, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
            throw "$ConfigFileName $Name must be an integer in range 1..65535."
        }

        return $port
    }
}

function Initialize-AspireDashboardInstallerFromConfig () {
    <#
    .SYNOPSIS
        Loads required installer runtime settings from config-aspire-dashboard.json.
    .DESCRIPTION
        Requires and validates all runtime settings. Values are written to
        script scope and cannot be overridden with installer parameters.
    .NOTES
        1. Require and parse config-aspire-dashboard.json.
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

        $configFileName = 'config-aspire-dashboard.json'
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

        $installRootFolder = [string]$config.INSTALL_ROOT_FOLDER
        if ([string]::IsNullOrWhiteSpace($installRootFolder)) {
            $installRootFolder = $ScriptRoot
        }
        elseif (-not [System.IO.Path]::IsPathRooted($installRootFolder)) {
            $installRootFolder = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot $installRootFolder))
        }

        $settings = @{
            InstallRootFolder    = $installRootFolder
            DashboardUiPort      = Get-AspireDashboardRequiredConfigPort -Config $config -Name 'DASHBOARD_UI_PORT' -ConfigFileName $configFileName
            OtlpGrpcPort         = Get-AspireDashboardRequiredConfigPort -Config $config -Name 'OTLP_GRPC_PORT' -ConfigFileName $configFileName
            OtlpHttpPort         = Get-AspireDashboardRequiredConfigPort -Config $config -Name 'OTLP_HTTP_PORT' -ConfigFileName $configFileName
            HostName             = Get-AspireDashboardRequiredConfigString -Config $config -Name 'HOST_NAME' -ConfigFileName $configFileName
            AspireDashboardImage = Get-AspireDashboardRequiredConfigString -Config $config -Name 'ASPIRE_DASHBOARD_IMAGE' -ConfigFileName $configFileName
            AllowAnonymous       = Get-AspireDashboardRequiredConfigBool -Config $config -Name 'ALLOW_ANONYMOUS' -ConfigFileName $configFileName
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
