function ConvertTo-SnowflakeContainerPrefix () {
    <#
    .SYNOPSIS
        Converts an install folder name into a valid lowercase container prefix.
    .DESCRIPTION
        Converts <prefix>-Snowflake-yyyyMMdd into snowflake-<prefix>-yyyyMMdd.
        Other values are sanitized and prefixed with snowflake-.
    .NOTES
        1. Detect and split the dated Snowflake install-folder pattern.
        2. Sanitize the prefix.
        3. Return snowflake-<prefix>-<date>.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "The input value to process.")]
        [ValidateNotNullOrEmpty()]
        [string]$Value
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $lowerValue = $Value.ToLowerInvariant()
        if ($lowerValue -match '^(?<prefix>.+)-snowflake-(?<date>\d{8})$') {
            $safePrefix = ($Matches.prefix -replace '[^a-z0-9_.-]', '-') -replace '^[_.-]+|[_.-]+$', ''
            return "snowflake-$safePrefix-$($Matches.date)"
        }

        $safe = ($lowerValue -replace '[^a-z0-9_.-]', '-') -replace '^[_.-]+|[_.-]+$', ''
        return "snowflake-$safe"
    }
}
