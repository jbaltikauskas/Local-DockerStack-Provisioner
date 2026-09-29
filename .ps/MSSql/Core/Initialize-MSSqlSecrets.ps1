function Initialize-MSSqlSecrets () {
    <#
    .SYNOPSIS
        Creates config\.env.secrets when it does not exist.
    .DESCRIPTION
        Stores the SA password and locks the file ACL to the current Windows user.
    .NOTES
        1. Preserve an existing secrets file.
        2. Write the SA password.
        3. Lock permissions to the current Windows user.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to the .env.secrets file holding generated credentials.")]
        [ValidateNotNullOrEmpty()]
        [string]$SecretsPath,

        [Parameter(Mandatory = $true, HelpMessage = "SQL Server sa account password.")]
        [ValidateNotNullOrEmpty()]
        [string]$SaPassword
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        if (Test-Path -LiteralPath $SecretsPath -PathType Leaf) {
            Write-Host "Preserving existing secrets file: $SecretsPath" -ForegroundColor Yellow
            return
        }

        $content = "MSSQL_SA_PASSWORD=$SaPassword"
        Write-Utf8NoBom -Path $SecretsPath -Content $content

        & icacls $SecretsPath /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not lock secrets file ACL. icacls exit code: $LASTEXITCODE."
        }
    }
}
