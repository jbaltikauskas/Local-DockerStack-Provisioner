function Start-ComposeStack () {
    <#
    .SYNOPSIS
        Pulls and starts a Docker Compose stack.
    .DESCRIPTION
        Runs docker compose pull and up -d, then prints current service state.
    .NOTES
        1. Pull images.
        2. Start services.
        3. Print compose status.
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
