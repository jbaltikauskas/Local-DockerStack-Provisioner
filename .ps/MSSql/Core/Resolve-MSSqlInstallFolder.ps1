function Resolve-MSSqlInstallFolder () {
    <#
    .SYNOPSIS
        Resolves a new dated install folder.
    .DESCRIPTION
        Uses the install root folder and the required ServerNamePrefix script
        parameter, then always appends -MSSql-yyyyMMdd. The prefix is never read
        from config-mssql.json.
    .NOTES
        1. Validate ServerNamePrefix.
        2. Create the install root folder when it does not exist.
        3. Append -MSSql-yyyyMMdd.
        4. Reject an existing folder.
        5. Return the absolute path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Root folder under which the dated install folder is created.")]
        [ValidateNotNullOrEmpty()]
        [string]$InstallRootFolder,

        [Parameter(Mandatory = $true, HelpMessage = "Install-folder prefix; the installer appends the stack name and date.")]
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

        if ($ServerNamePrefix -match '-MSSql-\d{8}$') {
            throw "ServerNamePrefix must not include the generated -MSSql-yyyyMMdd suffix."
        }

        $installRootPath = [System.IO.Path]::GetFullPath($InstallRootFolder)
        New-Item -ItemType Directory -Path $installRootPath -Force | Out-Null

        $leaf = "$ServerNamePrefix-MSSql-$dateSuffix"
        $path = [System.IO.Path]::GetFullPath((Join-Path $installRootPath $leaf))
        if (Test-Path -LiteralPath $path) {
            throw "Install folder already exists: '$path'. Pick another ServerNamePrefix."
        }

        return $path
    }
}
