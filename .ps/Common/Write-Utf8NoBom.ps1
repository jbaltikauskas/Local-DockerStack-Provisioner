function Write-Utf8NoBom () {
    <#
    .SYNOPSIS
        Writes text as UTF-8 without a BOM.
    .DESCRIPTION
        Writes exact content without adding a trailing newline. Bound parameters
        are not logged because Content may contain secrets.
    .NOTES
        1. Write Content to Path as UTF-8 without BOM or an added newline.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    Process {

        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM -NoNewline
    }
}
