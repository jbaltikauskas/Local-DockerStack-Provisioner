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

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

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
