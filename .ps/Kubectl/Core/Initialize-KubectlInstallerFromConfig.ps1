function Initialize-KubectlInstallerFromConfig () {
    <#
    .SYNOPSIS
        Loads required installer runtime settings from config-kubectl.json.
    .DESCRIPTION
        Requires and validates every runtime setting the ArgoCD bootstrap needs,
        then writes the validated values to script scope so the orchestrator can
        read them as plain variables. Throws when the file is missing, cannot be
        parsed, or any required setting is absent or invalid.
    .NOTES
        1. Require and parse config-kubectl.json next to the installer.
        2. Read and validate the namespace, port, URLs, and application settings.
        3. Resolve INSTALL_ROOT_FOLDER to an absolute path.
        4. Write validated values to script scope.
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

        $configFileName = 'config-kubectl.json'
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

        $portForwardPort = Get-RequiredConfigPort -Config $config -Name 'PORT_FORWARD_PORT' -ConfigFileName $configFileName

        $workloadNamespaces = @($config.WORKLOAD_NAMESPACES)
        if ($workloadNamespaces.Count -eq 0) {
            throw "$configFileName WORKLOAD_NAMESPACES must list at least one namespace."
        }

        $installRootFolder = [string]$config.INSTALL_ROOT_FOLDER
        if ([string]::IsNullOrWhiteSpace($installRootFolder)) {
            $installRootFolder = $ScriptRoot
        }
        elseif (-not [System.IO.Path]::IsPathRooted($installRootFolder)) {
            $installRootFolder = [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot $installRootFolder))
        }

        $settings = @{
            InstallRootFolder  = $installRootFolder
            ArgoNamespace      = Get-RequiredConfigString -Config $config -Name 'ARGO_NAMESPACE' -ConfigFileName $configFileName
            PortForwardPort    = $portForwardPort
            WebHost            = Get-RequiredConfigString -Config $config -Name 'WEB_HOST' -ConfigFileName $configFileName
            ArgoManifestUrl    = Get-RequiredConfigString -Config $config -Name 'ARGO_MANIFEST_URL' -ConfigFileName $configFileName
            GitRepoUrl         = Get-RequiredConfigString -Config $config -Name 'GIT_REPO_URL' -ConfigFileName $configFileName
            AppName            = Get-RequiredConfigString -Config $config -Name 'APP_NAME' -ConfigFileName $configFileName
            AppPath            = Get-RequiredConfigString -Config $config -Name 'APP_PATH' -ConfigFileName $configFileName
            AppProject         = Get-RequiredConfigString -Config $config -Name 'APP_PROJECT' -ConfigFileName $configFileName
            AppDestNamespace   = Get-RequiredConfigString -Config $config -Name 'APP_DEST_NAMESPACE' -ConfigFileName $configFileName
            WorkloadNamespaces = [string[]]$workloadNamespaces
        }

        foreach ($setting in $settings.GetEnumerator()) {
            Set-Variable -Name $setting.Key -Value $setting.Value -Scope Script
        }

        Write-Host "Loaded required installer settings from $configPath" -ForegroundColor Green
    }
}
