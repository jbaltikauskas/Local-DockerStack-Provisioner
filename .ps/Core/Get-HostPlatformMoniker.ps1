function Get-HostPlatformMoniker () {
    <#
    .SYNOPSIS
        Resolves the current OS and CPU architecture as release-asset monikers.
    .DESCRIPTION
        Shared, installer-agnostic helper. Maps the PowerShell $IsWindows /
        $IsLinux / $IsMacOS automatic variables and the process architecture to
        the operating-system moniker ("windows" / "linux" / "darwin"), the
        architecture moniker ("amd64" / "arm64"), and the executable suffix
        (".exe" on Windows, otherwise empty) that kubectl and Argo CD use in
        their download URLs. Throws on an unsupported OS or architecture.
    .NOTES
        1. Resolve the OS moniker and executable suffix from the OS variables.
        2. Map the process architecture to amd64 / arm64; throw when unsupported.
        3. Return an object with Os, Arch, and ExeSuffix.
    #>
    [CmdletBinding()]
    Param ()

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
    }

    Process {

        if ($IsWindows) {
            $os = 'windows'
            $exeSuffix = '.exe'
        }
        elseif ($IsMacOS) {
            $os = 'darwin'
            $exeSuffix = ''
        }
        elseif ($IsLinux) {
            $os = 'linux'
            $exeSuffix = ''
        }
        else {
            throw "Unsupported operating system: cannot resolve a kubectl / Argo CD download moniker."
        }

        switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
            ([System.Runtime.InteropServices.Architecture]::X64) {
                $arch = 'amd64'
            }
            ([System.Runtime.InteropServices.Architecture]::Arm64) {
                $arch = 'arm64'
            }
            default {
                throw "Unsupported CPU architecture '$([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)'. Only x64 and arm64 are supported."
            }
        }

        return [pscustomobject]@{
            Os        = $os
            Arch      = $arch
            ExeSuffix = $exeSuffix
        }
    }
}
