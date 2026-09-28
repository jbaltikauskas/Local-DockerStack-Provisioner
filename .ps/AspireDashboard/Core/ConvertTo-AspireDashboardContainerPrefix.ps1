function ConvertTo-AspireDashboardContainerPrefix () {
    <#
    .SYNOPSIS
        Converts an install folder name into a valid lowercase container prefix.
    .DESCRIPTION
        Converts <prefix>-AspireDashboard-yyyyMMdd into
        aspire-dashboard-<prefix>-yyyyMMdd. Other values are sanitized and
        prefixed with aspire-dashboard-.
    .NOTES
        1. Detect and split the dated Aspire Dashboard install-folder pattern.
        2. Sanitize the prefix.
        3. Return aspire-dashboard-<prefix>-<date>.
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
        if ($lowerValue -match '^(?<prefix>.+)-aspiredashboard-(?<date>\d{8})$') {
            $safePrefix = ($Matches.prefix -replace '[^a-z0-9_.-]', '-') -replace '^[_.-]+|[_.-]+$', ''
            return "aspire-dashboard-$safePrefix-$($Matches.date)"
        }

        $safe = ($lowerValue -replace '[^a-z0-9_.-]', '-') -replace '^[_.-]+|[_.-]+$', ''
        return "aspire-dashboard-$safe"
    }
}
