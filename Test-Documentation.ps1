#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies that the repository documentation stays in sync with the code.

.DESCRIPTION
    A dependency-free check that guards the facts most prone to drift between the
    installers and the prose that describes them:

        1. Every root Install-*.ps1 orchestrator is listed in both Readme.md and
           AGENTS.md.
        2. Every root config-*.json file is listed in both Readme.md and
           AGENTS.md.
        3. The global sonar.exclusions string baked into
           Set-SonarCubeAnalysisExclusions.ps1 appears verbatim in both AGENTS.md
           and docs/Install-SonarCube.md.

    Unlike the Install-*.ps1 scripts this is a non-interactive utility: it writes
    a PASS/FAIL summary and exits 0 when everything is in sync, 1 otherwise, so it
    can run in a pre-commit hook or CI without blocking on a prompt.

.PARAMETER RepoRoot
    Repository root to check. Defaults to the folder this script lives in.

.OUTPUTS
    Host messages describing each check. Exit code 0 when all checks pass, 1 when
    any check fails.

.EXAMPLE
    PS> .\Test-Documentation.ps1
    Runs every documentation-sync check against the current repository.
#>

#Requires -Version 7.2

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false, HelpMessage = "Repository root to check. Defaults to this script's folder.")]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

function Test-MentionedEverywhere ([string]$Needle, [hashtable]$Documents) {
    # Returns the names of documents that do NOT contain $Needle.
    $missing = foreach ($entry in $Documents.GetEnumerator()) {
        if (-not $entry.Value.Contains($Needle)) { $entry.Key }
    }

    return @($missing)
}

try {

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Get-Location).Path
    }

    $readmePath = Join-Path $RepoRoot 'Readme.md'
    $agentsPath = Join-Path $RepoRoot 'AGENTS.md'
    $sonarDocPath = Join-Path $RepoRoot 'docs' 'Install-SonarCube.md'
    $exclusionsPath = Join-Path $RepoRoot '.ps' 'SonarCube' 'Core' 'Set-SonarCubeAnalysisExclusions.ps1'

    foreach ($required in @($readmePath, $agentsPath, $sonarDocPath, $exclusionsPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Required file not found: '$required'."
        }
    }

    $readme = Get-Content -LiteralPath $readmePath -Raw
    $agents = Get-Content -LiteralPath $agentsPath -Raw
    $sonarDoc = Get-Content -LiteralPath $sonarDocPath -Raw

    $failures = [System.Collections.Generic.List[string]]::new()

    # ---- 1 & 2. Installer and config inventory ----------------------------
    $inventory = @(
        Get-ChildItem -LiteralPath $RepoRoot -Filter 'Install-*.ps1' -File
        Get-ChildItem -LiteralPath $RepoRoot -Filter 'config-*.json' -File
    ) | Select-Object -ExpandProperty Name | Sort-Object

    Write-Host "Checking installer and config inventory ($($inventory.Count) files):" -ForegroundColor Green
    foreach ($name in $inventory) {
        $missing = Test-MentionedEverywhere -Needle $name -Documents @{ 'Readme.md' = $readme; 'AGENTS.md' = $agents }
        if ($missing.Count -gt 0) {
            $failures.Add("$name is not listed in: $($missing -join ', ')")
            Write-Host "  [FAIL] $name (missing from $($missing -join ', '))" -ForegroundColor Red
        }
        else {
            Write-Host "  [ok]   $name" -ForegroundColor DarkGray
        }
    }

    # ---- 3. SonarCube exclusions string -----------------------------------
    Write-Host "Checking SonarCube sonar.exclusions string:" -ForegroundColor Green
    $exclusionsSource = Get-Content -LiteralPath $exclusionsPath -Raw
    if ($exclusionsSource -notmatch '(?s)\$requiredPatterns\s*=\s*@\((.*?)\)') {
        throw "Could not find the \$requiredPatterns array in '$exclusionsPath'."
    }

    $patternBlock = $Matches[1]
    $patterns = [regex]::Matches($patternBlock, "'([^']*)'") | ForEach-Object { $_.Groups[1].Value }
    if ($patterns.Count -eq 0) {
        throw "Found an empty \$requiredPatterns array in '$exclusionsPath'."
    }

    $joined = $patterns -join ','
    $missing = Test-MentionedEverywhere -Needle $joined -Documents @{ 'AGENTS.md' = $agents; 'docs/Install-SonarCube.md' = $sonarDoc }
    if ($missing.Count -gt 0) {
        $failures.Add("sonar.exclusions string '$joined' is not in: $($missing -join ', ')")
        Write-Host "  [FAIL] '$joined' (missing from $($missing -join ', '))" -ForegroundColor Red
    }
    else {
        Write-Host "  [ok]   '$joined'" -ForegroundColor DarkGray
    }

    # ---- Summary ----------------------------------------------------------
    Write-Host ""
    if ($failures.Count -gt 0) {
        Write-Host "Documentation checks FAILED ($($failures.Count)):" -ForegroundColor Red
        foreach ($failure in $failures) {
            Write-Host "  - $failure" -ForegroundColor Red
        }

        exit 1
    }

    Write-Host "All documentation checks passed." -ForegroundColor Green
    exit 0
}
catch {

    Write-Host ""
    Write-Error "Documentation check could not run: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
