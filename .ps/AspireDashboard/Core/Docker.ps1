function Assert-AspireDashboardInstallerPrerequisites () {
    <#
    .SYNOPSIS
        Verifies Docker Engine and Docker Compose v2.
    .DESCRIPTION
        Throws when Docker is missing, stopped, or Compose v2 is unavailable.
    .NOTES
        1. Resolve docker.
        2. Query Docker Engine.
        3. Query Docker Compose.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            throw "Docker was not found on PATH. Install and start Docker Desktop."
        }

        $engineVersion = & docker info --format '{{.ServerVersion}}'
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($engineVersion)) {
            throw "Docker Desktop is not responding. Start it and rerun the installer."
        }

        $composeVersion = & docker compose version --short
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($composeVersion)) {
            throw "Docker Compose v2 is required."
        }

        Write-Host "Docker Engine: $engineVersion" -ForegroundColor Green
        Write-Host "Docker Compose: $composeVersion" -ForegroundColor Green
    }
}

function Start-AspireDashboardStack () {
    <#
    .SYNOPSIS
        Pulls and starts the Aspire Dashboard compose stack.
    .DESCRIPTION
        Runs docker compose pull and up -d, then prints current service state.
    .NOTES
        1. Pull images.
        2. Start services.
        3. Print compose status.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        & docker compose -f $ComposePath pull
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose pull failed with exit code $LASTEXITCODE."
        }

        & docker compose -f $ComposePath up -d
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose up failed with exit code $LASTEXITCODE."
        }

        & docker compose -f $ComposePath ps
    }
}
