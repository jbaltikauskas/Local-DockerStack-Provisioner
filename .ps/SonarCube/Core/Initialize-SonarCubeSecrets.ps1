function Initialize-SonarCubeSecrets () {
    <#
    .SYNOPSIS
        Creates config\.env.secrets when it does not exist.
    .DESCRIPTION
        Stores the configured PostgreSQL credentials, SonarQube JDBC URL, and
        SonarQube admin credentials, then locks the file ACL.
    .NOTES
        1. Preserve an existing secrets file.
        2. Write the configured PostgreSQL credentials.
        3. Write a credential-bearing JDBC URL for SonarQube.
        4. Write SonarQube admin credentials for local reference.
        5. Lock permissions to the current Windows user.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretsPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^postgres-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$DatabaseServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseLogin,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseSecret,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminLogin,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminPassword
    )

    Process {

        if (Test-Path -LiteralPath $SecretsPath -PathType Leaf) {
            Write-Host "Preserving existing database credentials: $SecretsPath" -ForegroundColor Yellow
            return
        }

        $jdbcDatabase = [System.Uri]::EscapeDataString($DatabaseName)
        $jdbcUser = [System.Uri]::EscapeDataString($DatabaseLogin)
        $jdbcPassword = [System.Uri]::EscapeDataString($DatabaseSecret)
        $content = @"
SONAR_JDBC_URL=jdbc:postgresql://${DatabaseServiceName}:5432/${jdbcDatabase}?user=${jdbcUser}&password=${jdbcPassword}
POSTGRES_USER=$DatabaseLogin
POSTGRES_PASSWORD=$DatabaseSecret
SONAR_ADMIN_USERNAME=$AdminLogin
SONAR_ADMIN_PASSWORD=$AdminPassword
"@
        Write-Utf8NoBom -Path $SecretsPath -Content $content

        & icacls $SecretsPath /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not lock database secrets file ACL. icacls exit code: $LASTEXITCODE."
        }
    }
}
