function Sync-GitRepository () {
    <#
    .SYNOPSIS
        Clones a Git repository to disk, or fast-forwards it when already present.
    .DESCRIPTION
        Shared, installer-agnostic helper. Ensures git is on PATH, then clones
        RepoUrl into DestinationRootFolder under a folder named after the
        repository. When that folder already contains a clone, it runs `git pull`
        instead so reruns update in place. Throws when git is missing or a git
        command fails. Returns the absolute path to the local working copy.
    .NOTES
        1. Require git on PATH.
        2. Derive the local folder name from the repository URL.
        3. Clone when absent, otherwise pull.
        4. Return the local working-copy path.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "HTTPS URL of the Git repository to clone or update.")]
        [ValidateNotNullOrEmpty()]
        [string]$RepoUrl,

        [Parameter(Mandatory = $true, HelpMessage = "Root folder the repository is cloned under.")]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationRootFolder
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "git was not found on PATH. Install Git and rerun the installer."
        }

        $rootPath = [System.IO.Path]::GetFullPath($DestinationRootFolder)
        New-Item -ItemType Directory -Path $rootPath -Force | Out-Null

        $repoLeaf = [System.IO.Path]::GetFileNameWithoutExtension(($RepoUrl.TrimEnd('/')))
        $repoPath = Join-Path $rootPath $repoLeaf

        if (Test-Path -LiteralPath (Join-Path $repoPath '.git') -PathType Container) {
            Write-Host "Updating existing clone: $repoPath" -ForegroundColor Cyan
            & git -C $repoPath pull --ff-only
            if ($LASTEXITCODE -ne 0) {
                throw "git pull failed in '$repoPath' with exit code $LASTEXITCODE."
            }
        }
        else {
            Write-Host "Cloning $RepoUrl into: $repoPath" -ForegroundColor Cyan
            & git clone $RepoUrl $repoPath
            if ($LASTEXITCODE -ne 0) {
                throw "git clone of '$RepoUrl' failed with exit code $LASTEXITCODE."
            }
        }

        return $repoPath
    }
}
