function Get-SonarCubeWebApiErrorMessage () {
    <#
    .SYNOPSIS
        Returns a non-secret Web API error summary.
    .DESCRIPTION
        Extracts the HTTP status code and exception message without reading or
        logging request bodies.
    .NOTES
        1. Read status code when present.
        2. Return a compact diagnostic string.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Error record to inspect for a message.")]
        [object]$ErrorRecord
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $statusCode = $ErrorRecord.Exception.Response.StatusCode
        if ($null -ne $statusCode) {
            return "HTTP $([int]$statusCode): $($ErrorRecord.Exception.Message)"
        }

        return $ErrorRecord.Exception.Message
    }
}
