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
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
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
            DashboardUiPort      = Get-RequiredConfigPort -Config $config -Name 'DASHBOARD_UI_PORT' -ConfigFileName $configFileName
            OtlpGrpcPort         = Get-RequiredConfigPort -Config $config -Name 'OTLP_GRPC_PORT' -ConfigFileName $configFileName
            OtlpHttpPort         = Get-RequiredConfigPort -Config $config -Name 'OTLP_HTTP_PORT' -ConfigFileName $configFileName
            HostName             = Get-RequiredConfigString -Config $config -Name 'HOST_NAME' -ConfigFileName $configFileName
            AspireDashboardImage = Get-RequiredConfigString -Config $config -Name 'ASPIRE_DASHBOARD_IMAGE' -ConfigFileName $configFileName
            AllowAnonymous       = Get-RequiredConfigBool -Config $config -Name 'ALLOW_ANONYMOUS' -ConfigFileName $configFileName
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
