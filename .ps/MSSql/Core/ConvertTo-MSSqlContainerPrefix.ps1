function ConvertTo-MSSqlContainerPrefix () {
    <#
    .SYNOPSIS
        Converts an install folder name into a valid lowercase container prefix.
    .DESCRIPTION
        Converts <prefix>-MSSql-yyyyMMdd into mssql-<prefix>-yyyyMMdd.
        Other values are sanitized and prefixed with mssql-.
    .NOTES
        1. Detect and split the dated MSSql install-folder pattern.
        2. Sanitize the prefix.
        3. Return mssql-<prefix>-<date>.
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

        $lowerValue = $Value.ToLowerInvariant()
        if ($lowerValue -match '^(?<prefix>.+)-mssql-(?<date>\d{8})$') {
            $safePrefix = ($Matches.prefix -replace '[^a-z0-9_.-]', '-') -replace '^[_.-]+|[_.-]+$', ''
            return "mssql-$safePrefix-$($Matches.date)"
        }

        $safe = ($lowerValue -replace '[^a-z0-9_.-]', '-') -replace '^[_.-]+|[_.-]+$', ''
        return "mssql-$safe"
    }
}
