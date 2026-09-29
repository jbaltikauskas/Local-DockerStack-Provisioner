function Install-SonarCubeDotNetScanner () {
    <#
    .SYNOPSIS
        Installs the global SonarScanner for .NET tool.
    .DESCRIPTION
        Requires the .NET SDK on PATH, installs or updates
        dotnet-sonarscanner as a global tool, then verifies by running
        `dotnet sonarscanner --version`. That command may exit non-zero
        after printing the version banner because the scanner still expects
        begin/end; verification succeeds when the version banner is present.
    .NOTES
        1. Resolve the dotnet CLI.
        2. Ensure %USERPROFILE%\.dotnet\tools is on PATH for this session.
        3. Install or update the global dotnet-sonarscanner tool.
        4. Run `dotnet sonarscanner --version` and accept the version banner
           even when the exit code is non-zero.
    #>
    [CmdletBinding()]
    Param ()

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
            throw "dotnet was not found on PATH. Install the .NET SDK, then rerun the installer."
        }

        $dotnetToolsPath = Join-Path $env:USERPROFILE '.dotnet\tools'
        if (($env:PATH -split ';') -notcontains $dotnetToolsPath) {
            $env:PATH = "$dotnetToolsPath;$env:PATH"
        }

        $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
        try {

            $toolListOutput = & dotnet tool list --global 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Could not list global .NET tools. Exit code: $LASTEXITCODE. Output: $(($toolListOutput | Out-String).Trim())"
            }

            $toolListText = ($toolListOutput | Out-String)
            if ($toolListText -match 'dotnet-sonarscanner') {
                Write-Host "Updating global .NET tool: dotnet-sonarscanner" -ForegroundColor Yellow
                $toolOutput = & dotnet tool update --global dotnet-sonarscanner 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Could not update dotnet-sonarscanner. Exit code: $LASTEXITCODE. Output: $(($toolOutput | Out-String).Trim())"
                }
            }
            else {
                Write-Host "Installing global .NET tool: dotnet-sonarscanner" -ForegroundColor Yellow
                $toolOutput = & dotnet tool install --global dotnet-sonarscanner 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Could not install dotnet-sonarscanner. Exit code: $LASTEXITCODE. Output: $(($toolOutput | Out-String).Trim())"
                }
            }

            $versionOutput = & dotnet sonarscanner --version 2>&1
            $versionText = ($versionOutput | Out-String)
            $versionLine = $versionOutput |
                ForEach-Object { "$_" } |
                Where-Object { $_ -match 'SonarScanner for \.NET\s+\d+' } |
                Select-Object -First 1

            if ([string]::IsNullOrWhiteSpace($versionLine)) {
                throw "SonarScanner for .NET verification failed. Expected a version banner in the output. Exit code: $LASTEXITCODE. Output: $($versionText.Trim())"
            }

            Write-Host "SonarScanner for .NET: $($versionLine.Trim())" -ForegroundColor Green
        }
        finally {
            $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
        }
    }
}
