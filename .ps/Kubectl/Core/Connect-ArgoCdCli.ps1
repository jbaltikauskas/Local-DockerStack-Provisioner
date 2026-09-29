function Connect-ArgoCdCli () {
    <#
    .SYNOPSIS
        Logs the Argo CD CLI in through the local port-forward.
    .DESCRIPTION
        Runs `argocd login` against WebHost:Port with --insecure (the server
        presents a self-signed cert) and --grpc-web (needed through a kubectl
        port-forward), retrying a few times while the freshly started server
        settles. Throws when every attempt fails. Password is used only for the
        login call and is never logged; parameters are not traced because this
        function handles a secret.
    .NOTES
        1. Attempt `argocd login` up to the retry limit, waiting between tries.
        2. Return on the first success.
        3. Throw when all attempts fail.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Host the port-forward listens on, for example localhost.")]
        [ValidateNotNullOrEmpty()]
        [string]$WebHost,

        [Parameter(Mandatory = $true, HelpMessage = "Local port the Argo CD server is forwarded to (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true, HelpMessage = "Argo CD login name, typically admin.")]
        [ValidateNotNullOrEmpty()]
        [string]$AdminLogin,

        [Parameter(Mandatory = $true, HelpMessage = "Admin password; never logged.")]
        [ValidateNotNullOrEmpty()]
        [string]$AdminPassword
    )

    Process {

        $server = "{0}:{1}" -f $WebHost, $Port
        $maxAttempts = 5
        for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
            try {

                & argocd login $server --username $AdminLogin --password $AdminPassword --insecure --grpc-web
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Logged in to Argo CD at $server as $AdminLogin." -ForegroundColor Green
                    return
                }
            }
            catch {
                Write-Host "  Argo CD login attempt $attempt/$maxAttempts failed; retrying ..." -ForegroundColor Yellow
            }

            Start-Sleep -Seconds 5
        }

        throw "Could not log in to Argo CD at $server after $maxAttempts attempts."
    }
}
