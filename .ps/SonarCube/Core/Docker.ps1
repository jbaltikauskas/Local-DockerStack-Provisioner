function Set-SonarCubeDockerVirtualMemory () {
    <#
    .SYNOPSIS
        Sets vm.max_map_count for SonarQube inside Docker Desktop.
    .DESCRIPTION
        Runs sysctl in the docker-desktop WSL distribution when WSL is available.
    .NOTES
        1. Resolve wsl.exe.
        2. Set vm.max_map_count.
        3. Throw when the command fails.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            throw "wsl.exe was not found. Docker Desktop on Windows requires WSL 2 for this installer."
        }

        & wsl.exe -d docker-desktop -u root -- sysctl -w vm.max_map_count=262144 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not set vm.max_map_count in Docker Desktop. Exit code: $LASTEXITCODE."
        }
    }
}

function Start-SonarCubeDatabaseService () {
    <#
    .SYNOPSIS
        Pulls and starts only the PostgreSQL compose service.
    .DESCRIPTION
        Starts the database before the full SonarQube stack so existing
        PostgreSQL volumes can be repaired before SonarQube connects.
    .NOTES
        1. Pull images.
        2. Start the PostgreSQL service.
        3. Print compose status.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^postgres-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$DatabaseServiceName
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        & docker compose -f $ComposePath pull
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose pull failed with exit code $LASTEXITCODE."
        }

        & docker compose -f $ComposePath up -d $DatabaseServiceName
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose up for PostgreSQL failed with exit code $LASTEXITCODE."
        }

        & docker compose -f $ComposePath ps
    }
}

function Start-SonarCubeApplicationServices () {
    <#
    .SYNOPSIS
        Starts the full SonarQube compose stack.
    .DESCRIPTION
        Runs docker compose up -d after the PostgreSQL password repair step,
        then prints current service state.
    .NOTES
        1. Start all services.
        2. Print compose status.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        & docker compose -f $ComposePath up -d
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose up failed with exit code $LASTEXITCODE."
        }

        & docker compose -f $ComposePath ps
    }
}
