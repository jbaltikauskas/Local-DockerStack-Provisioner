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
        [Parameter(Mandatory = $true, HelpMessage = "Host name used in the service URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true, HelpMessage = "TCP port the service listens on (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true, HelpMessage = "Administrator login name.")]
        [ValidateNotNullOrEmpty()]
        [string]$AdminLogin,

        [Parameter(Mandatory = $true, HelpMessage = "Administrator password.")]
        [ValidateNotNullOrEmpty()]
        [string]$AdminPassword
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

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
