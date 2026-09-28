function Get-SonarCubeScanScriptTemplate () {
    <#
    .SYNOPSIS
        Returns the generated Scan-SonarCube.ps1 script template.
    .DESCRIPTION
        The returned script runs SonarScanner for .NET begin/build/end using
        an embedded token so the file can be copied into application
        repositories. Project key is computed each run from the solution name
        plus optional git branch suffix. It prefers the first *.slnx in the
        current directory, then the first *.sln, then in the [src] folder,
        then prompts for a path.
    .NOTES
        1. Return the verbatim script template.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        return @'
<#
.SYNOPSIS
    Runs a SonarScanner for .NET analysis against a local project.
.DESCRIPTION
    Top-down flow when this script runs:

        1. Use the embedded host URL and analysis token.
        2. Resolve a solution path: -Path when supplied, else the first *.slnx
           in the current directory, else the first *.sln, else in the [src]
           folder, else prompt.
        3. Build the SonarQube project key from the solution name, appending
           `--<git-branch>` when a branch can be resolved.
        4. Run `dotnet sonarscanner begin` against this install's Web UI.
        5. Run `dotnet build` for the resolved solution.
        6. Run `dotnet sonarscanner end`.

    This script embeds SONAR_TOKEN so it can be copied into each application
    project. Treat the file as secret.

.PARAMETER Path
    Optional path to a .slnx or .sln file. When omitted, the script searches
    the current directory and [src] folder for the first *.slnx, then the first
    *.sln, then prompts for a path.

.INPUTS
    None. Token and host URL are embedded at install time. Project key is
    computed at runtime.

.OUTPUTS
    Host messages from SonarScanner and dotnet build. Exit code 0 on success.

.NOTES
    Requires PowerShell 7.2+, the .NET SDK, and the global dotnet-sonarscanner tool.

.EXAMPLE
    PS> .\Scan-SonarCube.ps1

.EXAMPLE
    PS> .\Scan-SonarCube.ps1 -Path C:\src\my-app\MyApp.sln
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = "Optional path to a .slnx or .sln solution file.")]
    [string]$Path
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
try {

    $token = '__SONAR_TOKEN__'
    $webUrl = '__WEB_URL__'
    $exclusions = '**/Scan-SonarCube.ps1,.ps1/**,.claude/**,.cursor/**,docs/**'
    $scriptRoot = $PSScriptRoot
    $workingDirectory = (Get-Location).Path
    $pathWasSupplied = -not [string]::IsNullOrWhiteSpace($Path)

    Write-Host ""
    Write-Host "--------------------------- BEGIN: Scan Settings ---------------------------"
    Write-Host ""
    Write-Host "Script root       : $scriptRoot"
    Write-Host "Working directory : $workingDirectory"
    Write-Host "Web URL           : $webUrl"
    Write-Host "Token             : embedded (not displayed)"
    Write-Host "Exclusions        : $exclusions"
    Write-Host "Path parameter    : $(if ($pathWasSupplied) { $Path } else { '(not supplied)' })"
    Write-Host "Project key       : (computed after solution is resolved)"
    Write-Host ""
    Write-Host "---------------------------- END: Scan Settings ----------------------------"
    Write-Host ""

    $resolvedPath = $null
    if ($pathWasSupplied) {
        Write-Host "Resolving solution from -Path parameter..." -ForegroundColor Yellow
        Write-Host "  Supplied Path   : $Path"
        $resolvedPath = [System.IO.Path]::GetFullPath($Path)
        Write-Host "  Resolved Path   : $resolvedPath"
        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            throw "Solution path not found: '$resolvedPath'."
        }
        Write-Host "  Path exists     : yes" -ForegroundColor Green
    }
    else {
        Write-Host "No -Path parameter supplied. Searching the working directory for a solution..." -ForegroundColor Yellow
        Write-Host "  Search directory: $workingDirectory"

        Write-Host "  Looking for first *.slnx..." -ForegroundColor Cyan
        $slnxFile = Get-ChildItem -LiteralPath $workingDirectory -Filter '*.slnx' -File -ErrorAction SilentlyContinue |
            Sort-Object -Property Name |
            Select-Object -First 1
        if ($null -ne $slnxFile) {
            $resolvedPath = $slnxFile.FullName
            Write-Host "  *.slnx found    : $resolvedPath" -ForegroundColor Green
        }
        else {
            Write-Host "  *.slnx found    : none" -ForegroundColor Yellow

            Write-Host "  Looking for first *.sln..." -ForegroundColor Cyan
            $slnFile = Get-ChildItem -LiteralPath $workingDirectory -Filter '*.sln' -File -ErrorAction SilentlyContinue |
                Sort-Object -Property Name |
                Select-Object -First 1
            if ($null -ne $slnFile) {
                $resolvedPath = $slnFile.FullName
                Write-Host "  *.sln found     : $resolvedPath" -ForegroundColor Green
            }
            else {
                Write-Host "  *.sln found     : none" -ForegroundColor Yellow

                $srcDirectory = Join-Path $workingDirectory 'src'
                if (Test-Path -LiteralPath $srcDirectory -PathType Container) {
                    Write-Host "  Checking [src] folder for solution file..." -ForegroundColor Cyan

                    Write-Host "  Looking for first *.slnx in [src]..." -ForegroundColor Cyan
                    $slnxFile = Get-ChildItem -LiteralPath $srcDirectory -Filter '*.slnx' -File -ErrorAction SilentlyContinue |
                        Sort-Object -Property Name |
                        Select-Object -First 1
                    if ($null -ne $slnxFile) {
                        $resolvedPath = $slnxFile.FullName
                        Write-Host "  *.slnx found in [src]: $resolvedPath" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  *.slnx found in [src]: none" -ForegroundColor Yellow

                        Write-Host "  Looking for first *.sln in [src]..." -ForegroundColor Cyan
                        $slnFile = Get-ChildItem -LiteralPath $srcDirectory -Filter '*.sln' -File -ErrorAction SilentlyContinue |
                            Sort-Object -Property Name |
                            Select-Object -First 1
                        if ($null -ne $slnFile) {
                            $resolvedPath = $slnFile.FullName
                            Write-Host "  *.sln found in [src] : $resolvedPath" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  *.sln found in [src] : none" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }

        while ([string]::IsNullOrWhiteSpace($resolvedPath)) {
            Write-Host "  Prompting for a .slnx or .sln solution path..." -ForegroundColor Yellow
            $enteredPath = (Read-Host 'No *.slnx or *.sln found in current directory or [src] folder. Enter path to a .slnx or .sln solution file').Trim()
            Write-Host "  Entered path    : $(if ([string]::IsNullOrWhiteSpace($enteredPath)) { '(empty)' } else { $enteredPath })"
            if ([string]::IsNullOrWhiteSpace($enteredPath)) {
                Write-Host 'Solution path cannot be empty.' -ForegroundColor Yellow
                continue
            }

            $candidatePath = [System.IO.Path]::GetFullPath($enteredPath)
            Write-Host "  Candidate path  : $candidatePath"
            if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
                Write-Host "Solution path not found: '$candidatePath'." -ForegroundColor Yellow
                continue
            }

            $extension = [System.IO.Path]::GetExtension($candidatePath)
            Write-Host "  Extension       : $extension"
            if ($extension -notin @('.slnx', '.sln')) {
                Write-Host 'Solution path must be a .slnx or .sln file.' -ForegroundColor Yellow
                continue
            }

            $resolvedPath = $candidatePath
            Write-Host "  Accepted path   : $resolvedPath" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Final solution path: $resolvedPath" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Computing SonarQube project key..." -ForegroundColor Yellow
    $solutionName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
    Write-Host "  Solution name   : $solutionName"
    $solutionSegment = ($solutionName -replace '[^A-Za-z0-9_.:\-]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($solutionSegment) -or $solutionSegment -notmatch '^[A-Za-z0-9]') {
        throw "Could not derive a valid SonarQube project key from solution name '$solutionName'."
    }
    Write-Host "  Solution segment: $solutionSegment"

    $branchName = $null
    $solutionDirectory = Split-Path -Parent $resolvedPath
    Write-Host "  Git directory   : $solutionDirectory"
    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    try {

        if (Get-Command git -ErrorAction SilentlyContinue) {
            $branchOutput = & git -C $solutionDirectory rev-parse --abbrev-ref HEAD 2>&1
            Write-Host "  git exit code   : $LASTEXITCODE"
            Write-Host "  git output      : $(($branchOutput | Out-String).Trim())"
            if ($LASTEXITCODE -eq 0) {
                $candidateBranch = (($branchOutput | Out-String).Trim())
                if (-not [string]::IsNullOrWhiteSpace($candidateBranch) -and $candidateBranch -ne 'HEAD') {
                    $branchName = $candidateBranch
                }
            }
        }
        else {
            Write-Host "  git             : not found on PATH" -ForegroundColor Yellow
        }
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
    }

    if ([string]::IsNullOrWhiteSpace($branchName)) {
        $projectKey = $solutionSegment
        Write-Host "  Branch suffix   : (none)" -ForegroundColor Yellow
    }
    else {
        $branchSegment = ($branchName -replace '[^A-Za-z0-9_.:\-]+', '-').Trim('-')
        Write-Host "  Branch name     : $branchName"
        Write-Host "  Branch segment  : $branchSegment"
        if ([string]::IsNullOrWhiteSpace($branchSegment)) {
            $projectKey = $solutionSegment
            Write-Host "  Branch suffix   : (ignored; sanitized empty)" -ForegroundColor Yellow
        }
        else {
            $projectKey = "$solutionSegment--$branchSegment"
            Write-Host "  Branch suffix   : --$branchSegment" -ForegroundColor Green
        }
    }

    Write-Host "  Project key     : $projectKey" -ForegroundColor Cyan
    Write-Host ""

    $scanStarted = $false
    $scanStopwatch = $null
    try {

        $scanStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Host "Scan stopwatch    : started" -ForegroundColor Cyan

        Write-Host "Step: dotnet sonarscanner begin" -ForegroundColor Green
        Write-Host "  /k                : $projectKey"
        Write-Host "  sonar.host.url    : $webUrl"
        Write-Host "  sonar.token       : embedded (not displayed)"
        Write-Host "  sonar.exclusions  : $exclusions"
        & dotnet sonarscanner begin `
            "/k:$projectKey" `
            "/d:sonar.host.url=$webUrl" `
            "/d:sonar.token=$token" `
            "/d:sonar.exclusions=$exclusions"
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet sonarscanner begin failed with exit code $LASTEXITCODE."
        }
        $scanStarted = $true
        Write-Host "  begin completed   : exit code 0" -ForegroundColor Green

        Write-Host ""
        Write-Host "Step: dotnet build" -ForegroundColor Green
        Write-Host "  Solution path     : $resolvedPath"
        & dotnet build $resolvedPath
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet build failed with exit code $LASTEXITCODE."
        }
        Write-Host "  build completed   : exit code 0" -ForegroundColor Green

        Write-Host ""
        Write-Host "Step: dotnet sonarscanner end" -ForegroundColor Green
        Write-Host "  sonar.token       : embedded (not displayed)"
        & dotnet sonarscanner end "/d:sonar.token=$token"
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet sonarscanner end failed with exit code $LASTEXITCODE."
        }
        $scanStarted = $false
        Write-Host "  end completed     : exit code 0" -ForegroundColor Green

        if ($null -ne $scanStopwatch -and $scanStopwatch.IsRunning) {
            $scanStopwatch.Stop()
        }
        if ($null -ne $scanStopwatch) {
            Write-Host "Scan duration     : $([math]::Round($scanStopwatch.Elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Cyan
        }

        Write-Host ""
        Write-Host "SonarQube analysis finished for project '$projectKey'." -ForegroundColor Green
        Write-Host "Review results at $webUrl" -ForegroundColor Green
    }
    finally {
        if ($scanStarted) {
            Write-Host "Attempting SonarScanner end after a failed build or mid-scan error..." -ForegroundColor Yellow
            Write-Host "  sonar.token       : embedded (not displayed)"
            $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
            try {

                & dotnet sonarscanner end "/d:sonar.token=$token" | Out-Null
                Write-Host "  recovery end exit : $LASTEXITCODE" -ForegroundColor Yellow
            }
            finally {
                $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
            }
        }

        if ($null -ne $scanStopwatch -and $scanStopwatch.IsRunning) {
            $scanStopwatch.Stop()
            Write-Host "Scan duration     : $([math]::Round($scanStopwatch.Elapsed.TotalSeconds, 1)) seconds (stopped after error/recovery)" -ForegroundColor Yellow
        }

        $token = $null
        $scanStopwatch = $null
    }
}
catch {
    Write-Error $_
    exit 1
}
'@
    }
}
