function Write-MSSqlManagementScripts () {
    <#
    .SYNOPSIS
        Writes generated Start and Stop scripts.
    .DESCRIPTION
        Replaces the connection string placeholder and always overwrites generated
        PowerShell scripts and batch launchers.
    .NOTES
        1. Render Start and Stop templates.
        2. Replace __CONNECTION_STRING__ in the Start template.
        3. Render batch launchers for the PowerShell scripts.
        4. Write each generated file.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $connectionString = "Server=${HostName},${Port};User Id=sa;TrustServerCertificate=True"

        $scripts = @{
            (Join-Path $ServerRoot 'Start-MSSql.ps1') = (Get-MSSqlStartScriptTemplate).Replace('__CONNECTION_STRING__', $connectionString)
            (Join-Path $ServerRoot 'Stop-MSSql.ps1')  = Get-MSSqlStopScriptTemplate
            (Join-Path $ServerRoot 'Start-MSSql.bat') = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-MSSql.ps1"
'@
            (Join-Path $ServerRoot 'Stop-MSSql.bat')  = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-MSSql.ps1"
'@
        }

        foreach ($item in $scripts.GetEnumerator()) {
            Write-Utf8NoBom -Path $item.Key -Content $item.Value
        }
    }
}
