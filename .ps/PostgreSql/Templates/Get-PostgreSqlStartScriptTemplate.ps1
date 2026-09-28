function Get-PostgreSqlStartScriptTemplate () {
    <#
    .SYNOPSIS
        Returns the generated Start-PostgreSql.bat script template.
    .DESCRIPTION
        The returned batch script starts the existing local compose containers and prints the connection string.
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

docker compose -f "%COMPOSE_PATH%" start
if errorlevel 1 (
    echo docker compose start failed. 1>&2
    call :WaitForClose
    exit /b 1
)

for /f "usebackq delims=" %%i in (`docker compose -f "%COMPOSE_PATH%" ps --filter status=running --quiet`) do (
    set "RUNNING_CONTAINER=%%i"
)

if not defined RUNNING_CONTAINER (
    echo No containers are running after docker compose start. Run the installer again to recreate the stack. 1>&2
    call :WaitForClose
    exit /b 1
)

docker compose -f "%COMPOSE_PATH%" ps
if errorlevel 1 (
    echo docker compose ps failed. 1>&2
    call :WaitForClose
    exit /b 1
)

echo.
echo PostgreSQL is starting. First start may take a few seconds.
echo Connection: __CONNECTION_STRING__
call :WaitForClose
exit /b 0

:WaitForClose
echo.
pause
exit /b 0
'@
    }
}
