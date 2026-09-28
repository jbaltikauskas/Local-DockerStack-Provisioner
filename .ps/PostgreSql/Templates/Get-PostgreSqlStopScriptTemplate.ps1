function Get-PostgreSqlStopScriptTemplate () {
    <#
    .SYNOPSIS
        Returns the generated Stop-PostgreSql.bat script template.
    .DESCRIPTION
        The returned batch script stops the existing local compose containers without deleting the data volume.
    .NOTES
        1. Return the verbatim script template.
    #>
    [CmdletBinding()]
    Param ()

    Process {

        return @'
@echo off
setlocal

set "COMPOSE_PATH=%~dp0docker-compose.yml"

if not exist "%COMPOSE_PATH%" (
    echo docker-compose.yml not found: "%COMPOSE_PATH%". 1>&2
    call :WaitForClose
    exit /b 1
)

docker compose -f "%COMPOSE_PATH%" stop
if errorlevel 1 (
    echo docker compose stop failed. 1>&2
    call :WaitForClose
    exit /b 1
)
call :WaitForClose
exit /b 0

:WaitForClose
echo.
pause
exit /b 0
'@
    }
}
