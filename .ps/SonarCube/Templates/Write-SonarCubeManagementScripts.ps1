function Write-SonarCubeManagementScripts () {
    <#
    .SYNOPSIS
        Writes generated Start and Stop scripts.
    .DESCRIPTION
        Replaces the Web UI URL placeholder and always overwrites generated scripts.
    .NOTES
        1. Render Start and Stop templates.
        2. Write each generated file.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $composePath = Join-Path $ServerRoot 'docker-compose.yml'
        $composeText = Get-Content -LiteralPath $composePath -Raw
        if ($composeText -notmatch '"[^"]*:(\d+):9000"') {
            throw "Could not read the host port from '$composePath'."
        }

        $webUrl = "http://${WebHost}:$($Matches[1])"
        $scripts = @{
            (Join-Path $ServerRoot 'Start-SonarCube.ps1') = (Get-SonarCubeStartScriptTemplate).Replace('__WEB_URL__', $webUrl)
            (Join-Path $ServerRoot 'Stop-SonarCube.ps1')  = Get-SonarCubeStopScriptTemplate
        }

        foreach ($item in $scripts.GetEnumerator()) {
            Write-Utf8NoBom -Path $item.Key -Content $item.Value
        }
    }
}
