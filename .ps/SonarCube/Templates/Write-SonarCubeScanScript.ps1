function Write-SonarCubeScanScript () {
    <#
    .SYNOPSIS
        Writes the generated Scan-SonarCube.ps1 helper.
    .DESCRIPTION
        Embeds the Web UI URL and analysis token into Scan-SonarCube.ps1 so the
        file can be copied into application projects. Project key is computed
        at scan time from the solution name and git branch.
    .NOTES
        1. Escape single quotes in the embedded token.
        2. Render the scan script template.
        3. Write Scan-SonarCube.ps1.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Root folder of the installed stack.")]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot,

        [Parameter(Mandatory = $true, HelpMessage = "Host name used in the service URL.")]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true, HelpMessage = "TCP port the service listens on (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true, HelpMessage = "SonarQube analysis token.")]
        [ValidateNotNullOrEmpty()]
        [string]$AnalysisToken
    )

    Process {

        $webUrl = "http://${WebHost}:${Port}"
        $escapedToken = $AnalysisToken.Replace("'", "''")
        $path = Join-Path $ServerRoot 'Scan-SonarCube.ps1'
        $content = (Get-SonarCubeScanScriptTemplate).
            Replace('__WEB_URL__', $webUrl).
            Replace('__SONAR_TOKEN__', $escapedToken)
        Write-Utf8NoBom -Path $path -Content $content
        Write-Host "Wrote scan script with embedded token: $path" -ForegroundColor Green
    }
}
