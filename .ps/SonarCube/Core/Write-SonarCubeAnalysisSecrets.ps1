function Write-SonarCubeAnalysisSecrets () {
    <#
    .SYNOPSIS
        Persists the analysis token into config\.env.secrets.
    .DESCRIPTION
        Updates or appends SONAR_TOKEN without printing the secret value, then
        re-locks the file ACL. Removes any legacy SONAR_PROJECT_KEY line.
    .NOTES
        1. Read existing secrets content when present.
        2. Replace or append the SONAR_TOKEN line.
        3. Write UTF-8 without BOM and lock the ACL.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to the .env.secrets file holding generated credentials.")]
        [ValidateNotNullOrEmpty()]
        [string]$SecretsPath,

        [Parameter(Mandatory = $true, HelpMessage = "SonarQube analysis token.")]
        [ValidateNotNullOrEmpty()]
        [string]$AnalysisToken
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        $lines = @()
        if (Test-Path -LiteralPath $SecretsPath -PathType Leaf) {
            $lines = @(
                Get-Content -LiteralPath $SecretsPath |
                    Where-Object { $_ -notmatch '^(SONAR_TOKEN|SONAR_PROJECT_KEY)=' }
            )
        }

        $lines += "SONAR_TOKEN=$AnalysisToken"
        Write-Utf8NoBom -Path $SecretsPath -Content (($lines -join "`n") + "`n")

        & icacls $SecretsPath /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not lock analysis secrets file ACL. icacls exit code: $LASTEXITCODE."
        }

        Write-Host "Saved SONAR_TOKEN to $SecretsPath" -ForegroundColor Green
    }
}
