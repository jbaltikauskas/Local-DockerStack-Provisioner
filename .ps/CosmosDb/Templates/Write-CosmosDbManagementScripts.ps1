function Write-CosmosDbManagementScripts () {
    <#
    .SYNOPSIS
        Writes generated Start and Stop scripts.
    .DESCRIPTION
        Replaces endpoint placeholders and always overwrites generated
        PowerShell scripts and batch launchers.
    .NOTES
        1. Render Start and Stop templates.
        2. Replace endpoint placeholders in the Start template.
        3. Render batch launchers for the PowerShell scripts.
        4. Write each generated file.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Root folder of the installed stack.")]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true, HelpMessage = "Service gateway endpoint URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,

        [Parameter(Mandatory = $true, HelpMessage = "URL of the Data Explorer web UI.")]
        [ValidateNotNullOrEmpty()]
        [string]$ExplorerUrl,

        [Parameter(Mandatory = $true, HelpMessage = "URL of the health probe endpoint.")]
        [ValidateNotNullOrEmpty()]
        [string]$HealthUrl
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $startScript = Get-CosmosDbStartScriptTemplate
        $startScript = $startScript.Replace('__ENDPOINT__', $Endpoint)
        $startScript = $startScript.Replace('__EXPLORER_URL__', $ExplorerUrl)
        $startScript = $startScript.Replace('__HEALTH_URL__', $HealthUrl)

        $scripts = @{
            (Join-Path $ServerRoot 'Start-CosmosDb.ps1') = $startScript
            (Join-Path $ServerRoot 'Stop-CosmosDb.ps1')  = Get-CosmosDbStopScriptTemplate
            (Join-Path $ServerRoot 'Start-CosmosDb.bat') = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-CosmosDb.ps1"
'@
            (Join-Path $ServerRoot 'Stop-CosmosDb.bat')  = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-CosmosDb.ps1"
'@
        }

        foreach ($item in $scripts.GetEnumerator()) {
            Write-Utf8NoBom -Path $item.Key -Content $item.Value
        }
    }
}
