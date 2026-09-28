function Write-AspireDashboardManagementScripts () {
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

        [Parameter(Mandatory = $true, HelpMessage = "URL of the dashboard web UI.")]
        [ValidateNotNullOrEmpty()]
        [string]$DashboardUrl,

        [Parameter(Mandatory = $true, HelpMessage = "OTLP gRPC endpoint URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$OtlpGrpcEndpoint,

        [Parameter(Mandatory = $true, HelpMessage = "OTLP HTTP endpoint URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$OtlpHttpEndpoint
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $startScript = Get-AspireDashboardStartScriptTemplate
        $startScript = $startScript.Replace('__DASHBOARD_URL__', $DashboardUrl)
        $startScript = $startScript.Replace('__OTLP_GRPC_ENDPOINT__', $OtlpGrpcEndpoint)
        $startScript = $startScript.Replace('__OTLP_HTTP_ENDPOINT__', $OtlpHttpEndpoint)

        $scripts = @{
            (Join-Path $ServerRoot 'Start-AspireDashboard.ps1') = $startScript
            (Join-Path $ServerRoot 'Stop-AspireDashboard.ps1')  = Get-AspireDashboardStopScriptTemplate
            (Join-Path $ServerRoot 'Start-AspireDashboard.bat') = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AspireDashboard.ps1"
'@
            (Join-Path $ServerRoot 'Stop-AspireDashboard.bat')  = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-AspireDashboard.ps1"
'@
        }

        foreach ($item in $scripts.GetEnumerator()) {
            Write-Utf8NoBom -Path $item.Key -Content $item.Value
        }
    }
}
