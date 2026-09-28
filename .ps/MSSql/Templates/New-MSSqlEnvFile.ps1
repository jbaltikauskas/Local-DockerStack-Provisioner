function New-MSSqlEnvFile () {
    <#
    .SYNOPSIS
        Writes non-secret MSSQL Server environment settings.
    .DESCRIPTION
        Always overwrites the installer-managed file. The SA password is kept
        separately in config\.env.secrets and is never written here.
    .NOTES
        1. Write ACCEPT_EULA and MSSQL_PID.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EnvPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Developer', 'Express', 'Standard', 'Enterprise', 'EnterpriseCore')]
        [string]$MSSqlPid
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $content = @"
ACCEPT_EULA=Y
MSSQL_PID=$MSSqlPid
"@
        Write-Utf8NoBom -Path $EnvPath -Content $content
    }
}
