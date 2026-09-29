function Start-ArgoCdPortForward () {
    <#
    .SYNOPSIS
        Starts a background kubectl port-forward to the Argo CD server.
    .DESCRIPTION
        Launches `kubectl port-forward service/argocd-server -n <Namespace>
        <Port>:443` as a background job so the orchestrator can keep running,
        then waits until the local port accepts TCP connections. The job stays
        alive for the life of the PowerShell session, keeping the UI and CLI
        reachable at localhost:<Port>. Throws when the port does not open within
        TimeoutSeconds. Returns the background job so the caller can report or
        stop it.
    .NOTES
        1. Start the port-forward as a background job using the resolved kubectl path.
        2. Poll the local port until it accepts connections or the job ends.
        3. Return the job, or throw on timeout.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Namespace Argo CD is installed in.")]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace,

        [Parameter(Mandatory = $true, HelpMessage = "Local TCP port to forward to the Argo CD server (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true, HelpMessage = "Full path to the kubectl executable to run inside the job.")]
        [ValidateNotNullOrEmpty()]
        [string]$KubectlPath,

        [Parameter(Mandatory = $false, HelpMessage = "Seconds to wait for the local port to start accepting connections.")]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 30
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $job = Start-Job -Name 'argocd-port-forward' -ScriptBlock {
            param($kubectl, $namespace, $port)

            & $kubectl port-forward "service/argocd-server" -n $namespace ("{0}:443" -f $port)
        } -ArgumentList $KubectlPath, $Namespace, $Port

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while ((Get-Date) -lt $deadline) {
            if ($job.State -in @('Failed', 'Completed', 'Stopped')) {
                $detail = (Receive-Job -Job $job 2>&1 | Out-String).Trim()
                throw "The Argo CD port-forward job ended before the port opened. Detail: $detail"
            }

            $client = [System.Net.Sockets.TcpClient]::new()
            try {

                $client.Connect('127.0.0.1', $Port)
                if ($client.Connected) {
                    Write-Host "Port-forward is live at https://127.0.0.1:$Port (service/argocd-server 443)." -ForegroundColor Green
                    return $job
                }
            }
            catch {
                Start-Sleep -Seconds 1
            }
            finally {
                $client.Dispose()
            }
        }

        throw "The Argo CD port-forward did not open localhost:$Port within $TimeoutSeconds seconds."
    }
}
