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

function Resolve-AspireDashboardInstallFolder () {
    <#
    .SYNOPSIS
        Resolves a new dated install folder.
    .DESCRIPTION
        Uses the install root folder and the required ServerNamePrefix script
        parameter, then always appends -AspireDashboard-yyyyMMdd. The prefix is
        never read from config-aspire-dashboard.json.
    .NOTES
        1. Validate ServerNamePrefix.
        2. Create the install root folder when it does not exist.
        3. Append -AspireDashboard-yyyyMMdd.
        4. Reject an existing folder.
        5. Return the absolute path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InstallRootFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerNamePrefix
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $dateSuffix = Get-Date -Format 'yyyyMMdd'
        if ($ServerNamePrefix -match '[\\/:*?"<>|]') {
            throw "ServerNamePrefix contains invalid path characters: '$ServerNamePrefix'."
        }

        if ($ServerNamePrefix -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            throw "ServerNamePrefix must contain only letters, numbers, periods, underscores, or hyphens."
        }

        if ($ServerNamePrefix -match '-AspireDashboard-\d{8}$') {
            throw "ServerNamePrefix must not include the generated -AspireDashboard-yyyyMMdd suffix."
        }

        $installRootPath = [System.IO.Path]::GetFullPath($InstallRootFolder)
        New-Item -ItemType Directory -Path $installRootPath -Force | Out-Null

        $leaf = "$ServerNamePrefix-AspireDashboard-$dateSuffix"
        $path = [System.IO.Path]::GetFullPath((Join-Path $installRootPath $leaf))
        if (Test-Path -LiteralPath $path) {
            throw "Install folder already exists: '$path'. Pick another ServerNamePrefix."
        }

        return $path
    }
}

function New-AspireDashboardFolderLayout () {
    <#
    .SYNOPSIS
        Creates the install root and config folder.
    .DESCRIPTION
        Aspire Dashboard has no installer-managed persistent data folder.
        Returns a hashtable containing local install paths.
    .NOTES
        1. Build required paths.
        2. Create each directory.
        3. Return paths.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerRoot
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $paths = @{
            ServerRoot = $ServerRoot
            Config     = Join-Path $ServerRoot 'config'
        }

        foreach ($path in $paths.Values) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        return $paths
    }
}
