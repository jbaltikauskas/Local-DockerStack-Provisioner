function Assert-DockerPrerequisites () {
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

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

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
