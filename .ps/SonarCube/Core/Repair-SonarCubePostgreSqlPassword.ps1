function ConvertTo-SonarCubePostgreSqlIdentifier () {
    <#
    .SYNOPSIS
        Quotes a PostgreSQL identifier.
    .DESCRIPTION
        Returns a double-quoted PostgreSQL identifier with embedded double
        quotes escaped.
    .NOTES
        1. Double embedded quote characters.
        2. Wrap the value in double quotes.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        return '"' + ($Value -replace '"', '""') + '"'
    }
}

function ConvertTo-SonarCubePostgreSqlLiteral () {
    <#
    .SYNOPSIS
        Quotes a PostgreSQL string literal.
    .DESCRIPTION
        Returns a single-quoted PostgreSQL string literal with embedded single
        quotes escaped.
    .NOTES
        1. Double embedded apostrophe characters.
        2. Wrap the value in apostrophes.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    Process {

        return "'" + ($Value -replace "'", "''") + "'"
    }
}

function Invoke-SonarCubePostgreSqlCommand () {
    <#
    .SYNOPSIS
        Runs a PostgreSQL command inside the compose database container.
    .DESCRIPTION
        Executes psql through docker compose exec and returns exit code and
        output without exposing SQL in thrown errors.
    .NOTES
        1. Temporarily disable native command exceptions.
        2. Execute docker compose exec psql.
        3. Return command result metadata.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^postgres-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$DatabaseServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseLogin,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Sql
    )

    Process {

        $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
        try {

            $output = & docker compose -f $ComposePath exec -T $DatabaseServiceName psql -U $DatabaseLogin -d $DatabaseName -v ON_ERROR_STOP=1 -tAc $Sql 2>&1
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($output | Out-String).Trim()
            }
        }
        finally {
            $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
        }
    }
}

function Repair-SonarCubePostgreSqlPassword () {
    <#
    .SYNOPSIS
        Synchronizes the PostgreSQL role password with config.
    .DESCRIPTION
        Waits for PostgreSQL local psql access inside the container, verifies
        that the configured role exists, then updates its password. This repairs
        existing Docker volumes whose role password differs from current config.
    .NOTES
        1. Wait until psql can connect inside the database container.
        2. Fail clearly when the configured PostgreSQL role is missing.
        3. Alter the configured role password.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^postgres-[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string]$DatabaseServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseLogin,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseSecret,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 600)]
        [int]$TimeoutSeconds = 120,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]$RetryIntervalSeconds = 5
    )

    Process {

        $deadlineUtc = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
        $lastError = 'No response yet.'

        while ([datetime]::UtcNow -lt $deadlineUtc) {
            $probe = Invoke-SonarCubePostgreSqlCommand `
                -ComposePath $ComposePath `
                -DatabaseServiceName $DatabaseServiceName `
                -DatabaseName $DatabaseName `
                -DatabaseLogin $DatabaseLogin `
                -Sql 'select 1;'

            if ($probe.ExitCode -eq 0) {
                break
            }

            $lastError = $probe.Output
            if ($lastError -match 'role ".+" does not exist') {
                throw "Configured POSTGRES_USER '$DatabaseLogin' does not exist in the existing PostgreSQL volume. The volume was initialized with a different user. Migrate the role manually or recreate the PostgreSQL volume."
            }

            Start-Sleep -Seconds $RetryIntervalSeconds
        }

        if ([datetime]::UtcNow -ge $deadlineUtc) {
            throw "PostgreSQL did not accept local psql commands for user '$DatabaseLogin' before the timeout. Last error: $lastError"
        }

        $quotedRole = ConvertTo-SonarCubePostgreSqlIdentifier -Value $DatabaseLogin
        $quotedPassword = ConvertTo-SonarCubePostgreSqlLiteral -Value $DatabaseSecret
        $repair = Invoke-SonarCubePostgreSqlCommand `
            -ComposePath $ComposePath `
            -DatabaseServiceName $DatabaseServiceName `
            -DatabaseName $DatabaseName `
            -DatabaseLogin $DatabaseLogin `
            -Sql "alter user $quotedRole with password $quotedPassword;"

        if ($repair.ExitCode -ne 0) {
            throw "Could not repair PostgreSQL password for configured POSTGRES_USER '$DatabaseLogin'. Last error: $($repair.Output)"
        }

        Write-Host "PostgreSQL password is synchronized for configured POSTGRES_USER '$DatabaseLogin'." -ForegroundColor Green
    }
}
