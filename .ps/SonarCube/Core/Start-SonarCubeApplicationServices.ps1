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
        [Parameter(Mandatory = $true, HelpMessage = "Path to the stack's docker-compose.yml file.")]
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
