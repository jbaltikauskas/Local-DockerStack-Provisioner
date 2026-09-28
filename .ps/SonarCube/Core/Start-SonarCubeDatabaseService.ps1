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
