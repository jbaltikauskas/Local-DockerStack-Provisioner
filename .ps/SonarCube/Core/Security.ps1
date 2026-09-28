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

function ConvertTo-SonarCubePostgreSqlIdentifier () {
    <#
    .SYNOPSIS
        Quotes a PostgreSQL identifier.
    .DESCRIPTION
        Returns a double-quoted PostgreSQL identifier with embedded double
        quotes escaped.
    .NOTES
        1. Double embedded quote characters.
        2. Wrap the value in double quotes.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        return '"' + ($Value -replace '"', '""') + '"'
    }
}

function ConvertTo-SonarCubePostgreSqlLiteral () {
    <#
    .SYNOPSIS
        Quotes a PostgreSQL string literal.
    .DESCRIPTION
        Returns a single-quoted PostgreSQL string literal with embedded single
        quotes escaped.
    .NOTES
        1. Double embedded apostrophe characters.
        2. Wrap the value in apostrophes.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    Process {

        return "'" + ($Value -replace "'", "''") + "'"
    }
}

function Invoke-SonarCubePostgreSqlCommand () {
    <#
    .SYNOPSIS
        Runs a PostgreSQL command inside the compose database container.
    .DESCRIPTION
        Executes psql through docker compose exec and returns exit code and
        output without exposing SQL in thrown errors.
    .NOTES
        1. Temporarily disable native command exceptions.
        2. Execute docker compose exec psql.
        3. Return command result metadata.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath,

        [Parameter(Mandatory = $true)]
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
        [string]$Sql
    )

    Process {

        $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
        try {

            $output = & docker compose -f $ComposePath exec -T $DatabaseServiceName psql -U $DatabaseLogin -d $DatabaseName -v ON_ERROR_STOP=1 -tAc $Sql 2>&1
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($output | Out-String).Trim()
            }
        }
        finally {
            $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
        }
    }
}

function Repair-SonarCubePostgreSqlPassword () {
    <#
    .SYNOPSIS
        Synchronizes the PostgreSQL role password with config.
    .DESCRIPTION
        Waits for PostgreSQL local psql access inside the container, verifies
        that the configured role exists, then updates its password. This repairs
        existing Docker volumes whose role password differs from current config.
    .NOTES
        1. Wait until psql can connect inside the database container.
        2. Fail clearly when the configured PostgreSQL role is missing.
        3. Alter the configured role password.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath,

        [Parameter(Mandatory = $true)]
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

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 600)]
        [int]$TimeoutSeconds = 120,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]$RetryIntervalSeconds = 5
    )

    Process {

        $deadlineUtc = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
        $lastError = 'No response yet.'

        while ([datetime]::UtcNow -lt $deadlineUtc) {
            $probe = Invoke-SonarCubePostgreSqlCommand `
                -ComposePath $ComposePath `
                -DatabaseServiceName $DatabaseServiceName `
                -DatabaseName $DatabaseName `
                -DatabaseLogin $DatabaseLogin `
                -Sql 'select 1;'

            if ($probe.ExitCode -eq 0) {
                break
            }

            $lastError = $probe.Output
            if ($lastError -match 'role ".+" does not exist') {
                throw "Configured POSTGRES_USER '$DatabaseLogin' does not exist in the existing PostgreSQL volume. The volume was initialized with a different user. Migrate the role manually or recreate the PostgreSQL volume."
            }

            Start-Sleep -Seconds $RetryIntervalSeconds
        }

        if ([datetime]::UtcNow -ge $deadlineUtc) {
            throw "PostgreSQL did not accept local psql commands for user '$DatabaseLogin' before the timeout. Last error: $lastError"
        }

        $quotedRole = ConvertTo-SonarCubePostgreSqlIdentifier -Value $DatabaseLogin
        $quotedPassword = ConvertTo-SonarCubePostgreSqlLiteral -Value $DatabaseSecret
        $repair = Invoke-SonarCubePostgreSqlCommand `
            -ComposePath $ComposePath `
            -DatabaseServiceName $DatabaseServiceName `
            -DatabaseName $DatabaseName `
            -DatabaseLogin $DatabaseLogin `
            -Sql "alter user $quotedRole with password $quotedPassword;"

        if ($repair.ExitCode -ne 0) {
            throw "Could not repair PostgreSQL password for configured POSTGRES_USER '$DatabaseLogin'. Last error: $($repair.Output)"
        }

        Write-Host "PostgreSQL password is synchronized for configured POSTGRES_USER '$DatabaseLogin'." -ForegroundColor Green
    }
}

function Get-SonarCubeWebApiErrorMessage () {
    <#
    .SYNOPSIS
        Returns a non-secret Web API error summary.
    .DESCRIPTION
        Extracts the HTTP status code and exception message without reading or
        logging request bodies.
    .NOTES
        1. Read status code when present.
        2. Return a compact diagnostic string.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [object]$ErrorRecord
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $statusCode = $ErrorRecord.Exception.Response.StatusCode
        if ($null -ne $statusCode) {
            return "HTTP $([int]$statusCode): $($ErrorRecord.Exception.Message)"
        }

        return $ErrorRecord.Exception.Message
    }
}

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

function Get-SonarCubeBasicAuthHeader () {
    <#
    .SYNOPSIS
        Builds a Basic authentication header for SonarQube Web API calls.
    .DESCRIPTION
        Returns a hashtable with an Authorization header. Does not log credentials.
    .NOTES
        1. Encode login:password as Base64.
        2. Return the Authorization header hashtable.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Login,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Password
    )

    Process {

        $basicAuth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${Login}:${Password}"))
        return @{
            Authorization = "Basic $basicAuth"
        }
    }
}

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
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretsPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AnalysisToken
    )

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

function Set-SonarCubeAnalysisExclusions () {
    <#
    .SYNOPSIS
        Appends required global sonar.exclusions via the SonarQube Web API.
    .DESCRIPTION
        Reads existing instance-level sonar.exclusions, appends any missing
        required patterns, and posts api/settings/set once. Does not log
        credentials.
    .NOTES
        1. Build Web URL and Basic auth headers.
        2. GET existing sonar.exclusions values.
        3. Merge required patterns without duplicates.
        4. POST api/settings/set with one values field per pattern.
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
        [string]$AdminPassword
    )

    Process {

        $requiredPatterns = @(
            '**/Scan-SonarCube.ps1'
            '.ps1/**'
            '.claude/**'
            '.cursor/**'
            'docs/**'
        )
        $requiredList = $requiredPatterns -join ','
        $webUrl = "http://${WebHost}:${Port}"
        $headers = Get-SonarCubeBasicAuthHeader -Login $AdminLogin -Password $AdminPassword
        $valuesUrl = "$webUrl/api/settings/values?keys=sonar.exclusions"
        $setUrl = "$webUrl/api/settings/set"

        Write-Host "Configuring global sonar.exclusions..." -ForegroundColor Green
        Write-Host "  Required list   : $requiredList"

        $existingPatterns = [System.Collections.Generic.List[string]]::new()
        try {

            $response = Invoke-RestMethod `
                -Method Get `
                -Uri $valuesUrl `
                -Headers $headers `
                -TimeoutSec 10 `
                -ErrorAction Stop

            $setting = @($response.settings) | Where-Object { $_.key -eq 'sonar.exclusions' } | Select-Object -First 1
            if ($null -ne $setting) {
                if ($null -ne $setting.values) {
                    foreach ($value in @($setting.values)) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                            $existingPatterns.Add([string]$value)
                        }
                    }
                }
                elseif (-not [string]::IsNullOrWhiteSpace([string]$setting.value)) {
                    foreach ($value in ([string]$setting.value -split ',')) {
                        $trimmed = $value.Trim()
                        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                            $existingPatterns.Add($trimmed)
                        }
                    }
                }
            }
        }
        catch {
            throw "Could not read SonarQube sonar.exclusions at '$valuesUrl': $(Get-SonarCubeWebApiErrorMessage -ErrorRecord $_)"
        }

        Write-Host "  Existing values : $(if ($existingPatterns.Count -eq 0) { '(none)' } else { ($existingPatterns -join ',') })"

        $mergedPatterns = [System.Collections.Generic.List[string]]::new()
        foreach ($pattern in $existingPatterns) {
            if (-not $mergedPatterns.Contains($pattern)) {
                $mergedPatterns.Add($pattern)
            }
        }
        foreach ($pattern in $requiredPatterns) {
            if (-not $mergedPatterns.Contains($pattern)) {
                $mergedPatterns.Add($pattern)
            }
        }

        $mergedList = $mergedPatterns -join ','
        Write-Host "  Merged list     : $mergedList"

        $bodyParts = [System.Collections.Generic.List[string]]::new()
        $bodyParts.Add('key=sonar.exclusions')
        foreach ($pattern in $mergedPatterns) {
            $bodyParts.Add('values=' + [System.Uri]::EscapeDataString($pattern))
        }
        $body = $bodyParts -join '&'

        try {

            Invoke-RestMethod `
                -Method Post `
                -Uri $setUrl `
                -Headers $headers `
                -Body $body `
                -ContentType 'application/x-www-form-urlencoded' `
                -TimeoutSec 10 `
                -ErrorAction Stop | Out-Null

            Write-Host "Global sonar.exclusions updated through the Web API." -ForegroundColor Green
        }
        catch {
            throw "Could not set SonarQube sonar.exclusions at '$setUrl': $(Get-SonarCubeWebApiErrorMessage -ErrorRecord $_)"
        }
    }
}
