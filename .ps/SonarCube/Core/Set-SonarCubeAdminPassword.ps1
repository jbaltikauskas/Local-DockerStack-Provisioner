function Wait-SonarCubeWebApiReady () {
    <#
    .SYNOPSIS
        Waits until the SonarQube Web API reports UP.
    .DESCRIPTION
        Polls api/system/status until SonarQube is ready or the shared installer
        deadline is reached.
    .NOTES
        1. Build the status URL.
        2. Poll until status is UP.
        3. Throw with the last non-secret error on timeout.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebUrl,

        [Parameter(Mandatory = $true)]
        [datetime]$DeadlineUtc,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 300)]
        [int]$RetryIntervalSeconds
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $statusUrl = "$WebUrl/api/system/status"
        $lastError = 'No response yet.'

        while ([datetime]::UtcNow -lt $DeadlineUtc) {
            try {

                $response = Invoke-RestMethod -Method Get -Uri $statusUrl -TimeoutSec 10 -ErrorAction Stop
                if ($response.status -eq 'UP') {
                    Write-Host "SonarQube Web API is ready: $statusUrl" -ForegroundColor Green
                    return
                }

                $lastError = "Status endpoint returned '$($response.status)'."
            }
            catch {
                $lastError = Get-SonarCubeWebApiErrorMessage -ErrorRecord $_
            }

            Start-Sleep -Seconds $RetryIntervalSeconds
        }

        throw "SonarQube Web API did not become ready at '$statusUrl' before the timeout. Last error: $lastError"
    }
}

function Test-SonarCubeAdminCredential () {
    <#
    .SYNOPSIS
        Tests whether the configured SonarQube admin credential works.
    .DESCRIPTION
        Calls api/authentication/validate with Basic authentication and returns
        true only when SonarQube reports the credential is valid.
    .NOTES
        1. Build Basic authentication from the configured credential.
        2. Call the validation endpoint.
        3. Return the endpoint's Boolean result.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminLogin,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminPassword
    )

    Process {

        $basicAuth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${AdminLogin}:${AdminPassword}"))
        $headers = @{
            Authorization = "Basic $basicAuth"
        }

        try {

            $response = Invoke-RestMethod -Method Get -Uri "$WebUrl/api/authentication/validate" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
            return $response.valid -eq $true
        }
        catch {
            return $false
        }
    }
}

function Set-SonarCubeAdminPassword () {
    <#
    .SYNOPSIS
        Sets the built-in SonarQube admin password through the Web API.
    .DESCRIPTION
        Waits for the Web API, then changes the configured admin account from
        the default password to the configured password. The configured
        password is never printed. If the configured credential already works,
        the function returns success.
    .NOTES
        1. Wait for api/system/status to return UP.
        2. POST api/users/change_password with the default admin password.
        3. Treat an already-configured admin credential as success.
        4. Retry transient failures until the timeout.
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

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 180,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$RetryIntervalSeconds = 10
    )

    Process {

        $webUrl = "http://${WebHost}:${Port}"
        $deadlineUtc = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
        Wait-SonarCubeWebApiReady -WebUrl $webUrl -DeadlineUtc $deadlineUtc -RetryIntervalSeconds $RetryIntervalSeconds

        $changePasswordUrl = "$webUrl/api/users/change_password"
        $basicAuth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${AdminLogin}:admin"))
        $headers = @{
            Authorization = "Basic $basicAuth"
        }
        $body = @{
            login            = $AdminLogin
            previousPassword = 'admin'
            password         = $AdminPassword
        }
        $lastError = 'No response yet.'

        while ([datetime]::UtcNow -lt $deadlineUtc) {
            try {

                Invoke-RestMethod `
                    -Method Post `
                    -Uri $changePasswordUrl `
                    -Headers $headers `
                    -Body $body `
                    -ContentType 'application/x-www-form-urlencoded' `
                    -TimeoutSec 10 `
                    -ErrorAction Stop | Out-Null

                Write-Host "SonarQube admin password was updated through the Web API." -ForegroundColor Green
                return
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized) {
                    if (Test-SonarCubeAdminCredential -WebUrl $webUrl -AdminLogin $AdminLogin -AdminPassword $AdminPassword) {
                        Write-Host "SonarQube admin password is already configured." -ForegroundColor Green
                        return
                    }
                }

                $lastError = Get-SonarCubeWebApiErrorMessage -ErrorRecord $_
            }

            Start-Sleep -Seconds $RetryIntervalSeconds
        }

        throw "Could not update the SonarQube admin password at '$changePasswordUrl' before the timeout. Last error: $lastError"
    }
}
