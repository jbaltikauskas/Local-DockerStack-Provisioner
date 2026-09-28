function Write-PostgreSqlManagementScripts () {
    <#
    .SYNOPSIS
        Writes generated Start and Stop scripts.
    .DESCRIPTION
        Replaces the connection string placeholder and always overwrites generated batch scripts.
    .NOTES
        1. Render Start and Stop templates.
        2. Replace __CONNECTION_STRING__ in the Start template.
        3. Write each generated file.
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
        [int]$Port,

        [Parameter(Mandatory = $true, HelpMessage = "Database user name.")]
        [ValidateNotNullOrEmpty()]
        [string]$User,

        [Parameter(Mandatory = $true, HelpMessage = "Database name.")]
        [ValidateNotNullOrEmpty()]
        [string]$Database
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $connectionString = "Host=${HostName};Port=${Port};Username=${User};Database=${Database}"

        $scripts = @{
            (Join-Path $ServerRoot 'Start-PostgreSql.bat') = (Get-PostgreSqlStartScriptTemplate).Replace('__CONNECTION_STRING__', $connectionString)
            (Join-Path $ServerRoot 'Stop-PostgreSql.bat')  = Get-PostgreSqlStopScriptTemplate
        }

        foreach ($item in $scripts.GetEnumerator()) {
            Write-Utf8NoBom -Path $item.Key -Content $item.Value
        }
    }
}
