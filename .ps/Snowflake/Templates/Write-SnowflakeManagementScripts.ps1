function Write-SnowflakeManagementScripts () {
    <#
    .SYNOPSIS
        Writes generated Start and Stop scripts.
    .DESCRIPTION
        Replaces the endpoint placeholder and always overwrites generated
        PowerShell scripts and batch launchers.
    .NOTES
        1. Render Start and Stop templates.
        2. Replace __ENDPOINT__ in the Start template.
        3. Render batch launchers for the PowerShell scripts.
        4. Write each generated file.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Root folder of the installed stack.")]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true, HelpMessage = "Host name used to reach the service.")]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter(Mandatory = $true, HelpMessage = "TCP port the service listens on (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $endpoint = "http://${HostName}:${Port}"

        $scripts = @{
            (Join-Path $ServerRoot 'Start-Snowflake.ps1') = (Get-SnowflakeStartScriptTemplate).Replace('__ENDPOINT__', $endpoint)
            (Join-Path $ServerRoot 'Stop-Snowflake.ps1')  = Get-SnowflakeStopScriptTemplate
            (Join-Path $ServerRoot 'Start-Snowflake.bat') = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Snowflake.ps1"
'@
            (Join-Path $ServerRoot 'Stop-Snowflake.bat')  = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-Snowflake.ps1"
'@
        }

        foreach ($item in $scripts.GetEnumerator()) {
            Write-Utf8NoBom -Path $item.Key -Content $item.Value
        }
    }
}
