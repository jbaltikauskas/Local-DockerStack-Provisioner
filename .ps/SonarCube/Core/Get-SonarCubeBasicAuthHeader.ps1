function Get-SonarCubeBasicAuthHeader () {
    <#
    .SYNOPSIS
        Builds a Basic authentication header for SonarQube Web API calls.
    .DESCRIPTION
        Returns a hashtable with an Authorization header. Does not log credentials.
    .NOTES
        1. Encode login:password as Base64.
        2. Return the Authorization header hashtable.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Login,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Password
    )

    Process {

        $basicAuth = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${Login}:${Password}"))
        return @{
            Authorization = "Basic $basicAuth"
        }
    }
}
