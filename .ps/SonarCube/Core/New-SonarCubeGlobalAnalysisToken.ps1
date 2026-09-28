function New-SonarCubeGlobalAnalysisToken () {
    <#
    .SYNOPSIS
        Creates a SonarQube Global Analysis Token with no expiration.
    .DESCRIPTION
        Authenticates as the configured admin, revokes any existing token with
        the same name, then posts api/user_tokens/generate. Returns the token
        value once; the value is never written to the host.
    .NOTES
        1. Build Web URL and Basic auth headers.
        2. Revoke an existing token with TokenName when present.
        3. POST api/user_tokens/generate with type GLOBAL_ANALYSIS_TOKEN and no expiration.
        4. Return the generated token string.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminLogin,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminPassword,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TokenName
    )

    Process {

        $webUrl = "http://${WebHost}:${Port}"
        $headers = Get-SonarCubeBasicAuthHeader -Login $AdminLogin -Password $AdminPassword

        try {

            $existing = Invoke-RestMethod `
                -Method Get `
                -Uri "$webUrl/api/user_tokens/search" `
                -Headers $headers `
                -TimeoutSec 10 `
                -ErrorAction Stop

            $matchingToken = @($existing.userTokens) | Where-Object { $_.name -eq $TokenName } | Select-Object -First 1
            if ($null -ne $matchingToken) {
                Invoke-RestMethod `
                    -Method Post `
                    -Uri "$webUrl/api/user_tokens/revoke" `
                    -Headers $headers `
                    -Body @{ name = $TokenName } `
                    -ContentType 'application/x-www-form-urlencoded' `
                    -TimeoutSec 10 `
                    -ErrorAction Stop | Out-Null
            }
        }
        catch {
            throw "Could not prepare SonarQube user token '$TokenName': $(Get-SonarCubeWebApiErrorMessage -ErrorRecord $_)"
        }

        try {

            $response = Invoke-RestMethod `
                -Method Post `
                -Uri "$webUrl/api/user_tokens/generate" `
                -Headers $headers `
                -Body @{
                    name = $TokenName
                    type = 'GLOBAL_ANALYSIS_TOKEN'
                } `
                -ContentType 'application/x-www-form-urlencoded' `
                -TimeoutSec 10 `
                -ErrorAction Stop

            if ([string]::IsNullOrWhiteSpace([string]$response.token)) {
                throw "SonarQube returned an empty token for '$TokenName'."
            }

            Write-Host "SonarQube Global Analysis Token '$TokenName' was created with no expiration." -ForegroundColor Green
            return [string]$response.token
        }
        catch {
            throw "Could not create SonarQube Global Analysis Token '$TokenName': $(Get-SonarCubeWebApiErrorMessage -ErrorRecord $_)"
        }
    }
}
