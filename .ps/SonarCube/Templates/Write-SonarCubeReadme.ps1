function Write-SonarCubeReadme () {
    <#
    .SYNOPSIS
        Writes the install-folder README.md.
    .DESCRIPTION
        Documents login, folder layout, and daily management commands.
    .NOTES
        1. Render and overwrite README.md.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^sonarqube-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$SonarQubeServiceName
    )

    Begin {
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $path = Join-Path $ServerRoot 'README.md'
        $content = @"
# SonarQube Docker Install

Web UI: http://${WebHost}:${Port}

Login with the configured ``SONAR_ADMIN_USERNAME`` and ``SONAR_ADMIN_PASSWORD`` from the root ``config-sonarcube.json``.

The installer installs or updates the global SonarScanner for .NET tool
(``dotnet tool install --global dotnet-sonarscanner`` or
``dotnet tool update --global dotnet-sonarscanner``; verify with
``dotnet sonarscanner --version``), sets global ``sonar.exclusions`` to
``**/Scan-SonarCube.ps1,.ps1/**,.claude/**,.cursor/**,docs/**``, then generates
a no-expiration Global Analysis Token named ``local-global-analysis``. Copy
``Scan-SonarCube.ps1`` into each application project; it embeds the host URL
and token.

## Commands

``````powershell
.\Start-SonarCube.ps1
.\Stop-SonarCube.ps1
.\Scan-SonarCube.ps1
docker compose -f .\docker-compose.yml logs -f $SonarQubeServiceName
dotnet tool update --global dotnet-sonarscanner
dotnet sonarscanner --version
``````

``Scan-SonarCube.ps1`` embeds the host URL and analysis token so you can copy
it into each application project. Treat that file as secret. It looks for the
first ``*.slnx`` in the current directory, then the first ``*.sln``, then checks
the ``src`` folder, and prompts only when none is found. The SonarQube project key is
``<solution-name>`` or ``<solution-name>--<git-branch>`` when a branch is
available. It also passes the same ``sonar.exclusions`` list on
``dotnet sonarscanner begin``. It runs ``dotnet sonarscanner begin``,
``dotnet build``, and ``dotnet sonarscanner end``.

## Data

- ``config\.env`` contains non-secret PostgreSQL settings.
- ``config\.env.secrets`` contains PostgreSQL connection secrets plus
  ``SONAR_TOKEN``.
- Docker named volumes contain SonarQube and PostgreSQL persistent data.
- Volume names start with ``$(ConvertTo-SonarCubeContainerPrefix -Value (Split-Path $ServerRoot -Leaf))``.
- Both services use the ``sonarnet-<ServerNamePrefix>`` Docker network.

Do not run ``docker compose down -v`` or ``docker volume prune`` unless you
intend to delete this installation's data.
"@
        Write-Utf8NoBom -Path $path -Content $content
    }
}
