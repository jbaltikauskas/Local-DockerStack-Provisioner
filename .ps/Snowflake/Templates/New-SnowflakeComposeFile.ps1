function New-SnowflakeComposeFile () {
    <#
    .SYNOPSIS
        Writes the Snowflake Docker Compose file.
    .DESCRIPTION
        Renders the local Snowflake emulator service and persists its database
        file in the install-folder snowflake-dat directory. Runtime values come
        from one env file at config/.env.
    .NOTES
        1. Render the single-service compose file.
        2. Attach config/.env and mount snowflake-dat to /data for emulator database persistence.
        3. Write UTF-8 without BOM, replacing any existing file.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Path to the stack's docker-compose.yml file.")]
        [ValidateNotNullOrEmpty()]
        [string]$ComposePath,

        [Parameter(Mandatory = $true, HelpMessage = "TCP port the service listens on (1-65535).")]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $true, HelpMessage = "Snowflake-compatible container image reference.")]
        [ValidateNotNullOrEmpty()]
        [string]$SnowflakeImage
    )

    Begin {
        Write-Verbose ("BEGIN: {0}" -f $MyInvocation.MyCommand.Name)
        Write-Verbose ($PSBoundParameters | Out-String)
    }

    Process {

        $content = @"
services:
  snowflake-emulator:
    image: $SnowflakeImage
    container_name: local-snowflake
    ports:
      - "${Port}:8080"
    env_file:
      - ./config/.env
    volumes:
      - ./snowflake-dat:/data
    restart: unless-stopped
"@

        Write-Utf8NoBom -Path $ComposePath -Content $content

        Write-Host "Compose file: $ComposePath"
        Write-Host $content
    }
}
