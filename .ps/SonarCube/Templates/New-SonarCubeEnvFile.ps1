function New-SonarCubeEnvFile () {
    <#
    .SYNOPSIS
        Writes non-secret SonarQube and PostgreSQL environment settings.
    .DESCRIPTION
        Always overwrites the installer-managed file.
    .NOTES
        1. Write the database name.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to the .env file to write.")]
        [ValidateNotNullOrEmpty()]
        [string]$EnvPath,

        [Parameter(Mandatory = $true, HelpMessage = "Database name.")]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $content = @"
POSTGRES_DB=$DatabaseName
"@
        Write-Utf8NoBom -Path $EnvPath -Content $content
    }
}
