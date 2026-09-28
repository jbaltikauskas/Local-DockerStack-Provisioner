# Local Docker stack project notes

This repo provisions local Docker stacks on Windows 11. Root installers create
self-contained dated install folders under the configured `INSTALL_ROOT_FOLDER`
with `docker-compose.yml`, config files, generated management scripts, and an
install-folder `README.md`. The checked-in configs default to
`..\Local-DockerStack-Provisioner--Installs`, a folder beside the repo.

Current root installers:

- `Install-SonarCube.ps1` with helpers under `.ps\SonarCube`
- `Install-MSSql.ps1` with helpers under `.ps\MSSql`
- `Install-AspireDashboard.ps1` with helpers under `.ps\AspireDashboard`
- `Install-PostgreSql.ps1` with helpers under `.ps\PostgreSql`
- `Install-Snowflake.ps1` with helpers under `.ps\Snowflake`
- `Install-CosmosDb.ps1` with helpers under `.ps\CosmosDb`

Each installer has a matching required root config file:

- `config-sonarcube.json`
- `config-mssql.json`
- `config-aspire-dashboard.json`
- `config-postgresql.json`
- `config-snowflake.json`
- `config-cosmosdb.json`

Edit the stack-specific helper modules when changing installer behavior.

Outside `Templates\`, every helper `.ps1` holds exactly one function and is named
after it (for example `Core\Resolve-PostgreSqlInstallerPort.ps1`). A private
helper that only one sibling function calls may share that caller's file, and the
file is named after the caller (for example `.ps\Core\Get-RequiredConfigString.ps1`
also holds `Get-RequiredConfigPort`, and SonarCube's
`Core\Repair-SonarCubePostgreSqlPassword.ps1` holds the psql helpers it alone
uses). See the one-function-per-file rule in `.claude\styles\powershell-style.md`.

Shared, installer-agnostic helpers live under `.ps\Core\`, one function per file,
and are dot-sourced by every installer: `Get-RequiredConfigString` (with
`Get-RequiredConfigPort`), `Get-RequiredConfigBool`, `Assert-DockerPrerequisites`,
`Start-ComposeStack`, `Test-TcpPortAvailable`, `Resolve-BindAddressFromHostName`,
`Write-Utf8NoBom` (writes UTF-8 without a BOM), and `Write-InternetShortcut`
(writes a `<Name>.url` Internet Shortcut for a `scheme://WebHost:Port` URL;
http by default, https via `-UseHttps`).
Keep these generic: no stack name prefixes and no literals tied to one installer
(config file names and settings come in as parameters).

Each stack's `Core\` folder then holds its own one-function-per-file helpers:
`Initialize-<Stack>InstallerFromConfig` (the config loader, which for SonarCube
also carries `Assert-SonarCubeAdminPasswordPolicy`), `Resolve-<Stack>InstallerPort`
(plus `Assert-<Stack>DistinctPorts` for the multi-port stacks),
`ConvertTo-<Stack>ContainerPrefix`, `Resolve-<Stack>InstallFolder`,
`New-<Stack>FolderLayout`, an optional secrets initializer, and one file per
template writer under `Templates\`. SonarCube additionally keeps its Docker
helpers (`Set-SonarCubeDockerVirtualMemory`, `Start-SonarCubeDatabaseService`,
`Start-SonarCubeApplicationServices`), `Install-SonarCubeDotNetScanner`, and the
Web-API/secret helpers formerly grouped in `Security.ps1`.

`ServerNamePrefix` is a required installer input. Never read it from config
files. Installers always create `<ServerNamePrefix>-<StackName>-yyyyMMdd`
under `INSTALL_ROOT_FOLDER` when configured, otherwise under `$PSScriptRoot`.
Relative `INSTALL_ROOT_FOLDER` values resolve from `$PSScriptRoot`. If the
configured install root folder does not exist, the installer creates it.

Installer-managed non-secret files and generated management scripts are always
overwritten when their writers run. Existing generated `.env.secrets` files are
preserved by secret initializers.

For end-user docs, see `Readme.md` (root) and the install-folder `README.md`
next to each generated `docker-compose.yml`.

## Stack-specific notes

`SONAR_ADMIN_USERNAME` and `SONAR_ADMIN_PASSWORD` from root
`config-sonarcube.json` control the built-in SonarQube Web UI admin login after
the Web API is ready. `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`
from root `config-sonarcube.json` control SonarQube's PostgreSQL database
connection secrets in generated `config\.env` and `config\.env.secrets`.
`SONAR_ADMIN_PASSWORD` must be at least 12 characters and include uppercase,
lowercase, number, and special-character content. After the admin password is
set, the installer appends global `sonar.exclusions`
(`**/Scan-SonarCube.ps1,.ps1/**,.claude/**,.cursor/**,docs/**`) through the Web
API, installs or updates the global `dotnet-sonarscanner` tool and verifies with
`dotnet sonarscanner --version`, then generates a no-expiration Global Analysis
Token named `local-global-analysis` and appends `SONAR_TOKEN` to
`config\.env.secrets`. It then writes `Scan-SonarCube.ps1` with the host URL
and analysis token embedded so the script can be copied into application
projects. Treat `Scan-SonarCube.ps1` as secret. The script resolves a solution
from the first `*.slnx` in the current directory, then the first `*.sln`, then
checks the `src` folder, and prompts only when none is found. The SonarQube
project key is computed at scan time as `<solution-name>` or
`<solution-name>--<git-branch>`. It passes the same `sonar.exclusions` list on begin and runs `dotnet sonarscanner begin`,
`dotnet build`, and `dotnet sonarscanner end`.

SonarCube starts PostgreSQL first and repairs the configured PostgreSQL user's
password inside existing named volumes before starting SonarQube. Do not remove
that repair step; PostgreSQL ignores changed `POSTGRES_PASSWORD` values after a
data volume has already been initialized.

`INSTALL_ROOT_FOLDER`, `PORT`, `BIND_ADDRESS`, `WEB_HOST`, `SONARQUBE_IMAGE`,
`POSTGRES_IMAGE`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`,
`SONAR_ADMIN_USERNAME`, and `SONAR_ADMIN_PASSWORD` come only from required root
`config-sonarcube.json`. Do not expose them as `Install-SonarCube.ps1`
parameters.

`config-mssql.json` owns `INSTALL_ROOT_FOLDER`, `PORT`, `HOST_NAME`, `MSSQL_IMAGE`,
`MSSQL_SA_PASSWORD`, and `MSSQL_PID` for `Install-MSSql.ps1`. Do not expose
them as installer parameters.

`config-aspire-dashboard.json` owns `INSTALL_ROOT_FOLDER`,
`DASHBOARD_UI_PORT`, `OTLP_GRPC_PORT`, `OTLP_HTTP_PORT`, `HOST_NAME`,
`ASPIRE_DASHBOARD_IMAGE`, and `ALLOW_ANONYMOUS` for
`Install-AspireDashboard.ps1`. Do not expose them as installer parameters.

`config-postgresql.json` owns `INSTALL_ROOT_FOLDER`, `PORT`, `HOST_NAME`,
`POSTGRES_IMAGE`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` for
`Install-PostgreSql.ps1`. Do not expose them as installer parameters.

`config-snowflake.json` owns `INSTALL_ROOT_FOLDER`, `PORT`, `HOST_NAME`,
`SNOWFLAKE_IMAGE`, `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`,
`SNOWFLAKE_PASSWORD`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`,
`SNOWFLAKE_SCHEMA`, and `SNOWFLAKE_ROLE` for `Install-Snowflake.ps1`. Do not
expose them as installer parameters.

`config-cosmosdb.json` owns `INSTALL_ROOT_FOLDER`, `PORT`, `HEALTH_PORT`,
`EXPLORER_PORT`, `HOST_NAME`, `COSMOSDB_IMAGE`, `PROTOCOL`, and `ACCOUNT_KEY`
for `Install-CosmosDb.ps1`. Do not expose them as installer parameters.

## What to ignore in this repo

Unless a task explicitly requires them, do not traverse or index:

- `.git/` — version control metadata only.
- Per-install folders whose names end with `-SonarCube-yyyyMMdd`,
  `-MSSql-yyyyMMdd`, `-AspireDashboard-yyyyMMdd`, or
  `-PostgreSql-yyyyMMdd`, or `-Snowflake-yyyyMMdd`, or `-CosmosDb-yyyyMMdd`
  (8-digit date). These are generated stacks and may contain local secrets or
  persistent-data references.

## `docker-compose.yml` generation and edits

When writing or generating a `docker-compose.yml` for this project, prefer
stack-specific unique names for services, containers, networks, and Docker
volumes so multiple dated installs can coexist.

Attach SonarQube and PostgreSQL to the named network
`sonarnet-<ServerNamePrefix>`.

Name top-level Compose services `sonarqube-<ServerNamePrefix>` and
`postgres-<ServerNamePrefix>`. The generated JDBC URL must use the PostgreSQL
service name as its hostname.

For an install folder named `<prefix>-SonarCube-yyyyMMdd`, name the SonarQube
container `sonarcube-<prefix>-yyyyMMdd`. Do not repeat `sonarcube` or append
`-app`.

SonarCube uses unique Docker named volumes for SonarQube data, extensions,
logs, and PostgreSQL data. SonarSource warns against bind mounts for SonarQube
persistence because plugins may not populate correctly.

Standalone PostgreSQL installs use a Docker named volume for
`/var/lib/postgresql/data`, with the volume name derived from the generated
container prefix. PostgreSQL uses one generated `config\.env` file containing
`POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`; do not generate a
separate `config\.env.secrets` for this stack.

Standalone Snowflake installs use the Snowflake emulator image and bind
`./snowflake-dat` to `/data` so `DB_PATH=/data/snowflake.db` persists on the
filesystem. Snowflake writes `DB_PATH`, connection values, and password to one
generated `config\.env` file; do not generate a separate `config\.env.secrets`
for this stack.

Standalone Cosmos DB installs use the Azure Cosmos DB vNext emulator image and
bind `./cosmos-data` to `/data` so emulator data persists on the filesystem.
The generated `config\.env` file contains gateway, protocol, explorer, and
`KEY_FILE` settings. The account key is written to `config\account.key` and
mounted read-only; do not generate a separate `config\.env.secrets` for this
stack.

MSSQL currently maps `./mssql_dev_data` to `/var/opt/mssql/data`.

Use `env_file` entries consistently:

- `./config/.env` for non-secret values.
- `./config/.env.secrets` for generated secret values when the stack has them.

Management scripts use `docker compose -f` next to the install root.

## Style guides

PowerShell scripts in this repo follow the style guide at:

@.claude/styles/powershell-style.md
