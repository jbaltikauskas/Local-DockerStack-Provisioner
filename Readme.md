# Local DockerStack Provisioner

This repo provisions self-contained local Docker stacks on Windows 11 with
Docker Desktop. Each installer creates a dated install folder under the
configured `INSTALL_ROOT_FOLDER`. The checked-in config files default to
`..\Local-DockerStack-Provisioner--Installs`, which is a folder beside this
repo. Each install folder has its own `docker-compose.yml`, generated
management scripts, configuration, and install-folder `README.md`.

One installer, `Install-Kubectl.ps1`, is different: instead of a Docker Compose
stack it bootstraps [Argo CD](https://argo-cd.readthedocs.io/en/stable/getting_started/)
on a local Kubernetes cluster and deploys applications from a Git repository.
See [docs/Install-Kubectl.md](docs/Install-Kubectl.md).

## Prerequisites

Before running the installers, ensure the following prerequisites are installed and running:

### 1. PowerShell 7 (`pwsh`)

The installer scripts require PowerShell 7 or higher.

- **Documentation**: [Install PowerShell on Windows (MSI)](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.6#msi)
- **Manual Installation (MSI)**:
  1. Download the latest `x64` MSI package from the [PowerShell GitHub Releases](https://github.com/PowerShell/PowerShell/releases/latest) (for example, `PowerShell-7.x.x-win-x64.msi`).
  2. Double-click the downloaded `.msi` file and follow the setup wizard prompts to complete the installation.
- **Alternative (WinGet MSI install)**:
  ```powershell
  winget install --id Microsoft.PowerShell --source winget --installer-type wix
  ```
- **Verification**:
  Open a terminal and verify the version:
  ```powershell
  pwsh --version
  ```

### 2. Docker Desktop for Windows

Docker Desktop with Docker Compose v2 is required to run the local container stacks.

- **Documentation**: [Install Docker Desktop on Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
- **System Requirements**:
  - Windows 11 or Windows 10 64-bit (Pro, Enterprise, or Home).
  - Hardware virtualization enabled in BIOS/UEFI.
  - WSL 2 (Windows Subsystem for Linux) enabled.
- **Manual Installation**:
  1. Download the installer: [Docker Desktop for Windows - x86_64](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe).
  2. Double-click `Docker Desktop Installer.exe` to start the installation.
  3. Select your preferred installation mode (per-user is recommended and does not require administrator privileges).
  4. On the Configuration screen, ensure **Use WSL 2 instead of Hyper-V** is selected.
  5. Follow the remaining prompts, click **Close** once finished, and launch **Docker Desktop** from the Windows Start menu.
- **Verification**:
  Once Docker Desktop is started and the engine is running, verify Docker and Docker Compose v2:
  ```powershell
  docker --version
  docker compose version
  ```

## Available Installers

```powershell
pwsh -File .\Install-SonarCube.ps1 -ServerNamePrefix CustomName
pwsh -File .\Install-MSSql.ps1 -ServerNamePrefix CustomName
pwsh -File .\Install-AspireDashboard.ps1 -ServerNamePrefix CustomName
pwsh -File .\Install-PostgreSql.ps1 -ServerNamePrefix CustomName
pwsh -File .\Install-Snowflake.ps1 -ServerNamePrefix CustomName
pwsh -File .\Install-CosmosDb.ps1 -ServerNamePrefix CustomName
pwsh -File .\Install-Kubectl.ps1 -ServerNamePrefix CustomName
```

Each installer reads runtime settings from its matching required config file:

- `config-sonarcube.json`
- `config-mssql.json`
- `config-aspire-dashboard.json`
- `config-postgresql.json`
- `config-snowflake.json`
- `config-cosmosdb.json`
- `config-kubectl.json`

`ServerNamePrefix` is always supplied directly to the installer. It is not read
from config files. Install folders use the pattern
`<ServerNamePrefix>-<StackName>-yyyyMMdd`.

Each stack is self-contained and meant to run on its own. Several default to
overlapping host ports — `8080` is used by Snowflake (`PORT`), Cosmos DB
(`HEALTH_PORT`), and the Argo CD port-forward (`PORT_FORWARD_PORT`) — so change
a port in the relevant config file before running two such stacks at once.

Each config file sets `INSTALL_ROOT_FOLDER` to control where the dated install
folder is created. Relative paths are resolved from the installer script
folder. Leave it empty to use the installer script folder. If the configured
root folder does not exist, the installer creates it.

```json
"INSTALL_ROOT_FOLDER": "..\\Local-DockerStack-Provisioner--Installs"
```

## Generated Files

Generated install folders include stack-specific files such as:

- `docker-compose.yml`
- Stack-specific start and stop scripts (`.ps1` and `.cmd` / `.bat`)
- Windows Internet Shortcuts (`*.url`) for 1-click browser navigation (`SonarCube.url`, `AspireDashboard.url`, `CosmosDb.url`). `Install-Kubectl.ps1` writes a cross-platform `ArgoCD` shortcut (`.url` / `.webloc` / `.desktop`); see [docs/Install-Kubectl.md](docs/Install-Kubectl.md)
- Standalone helper utilities, such as `Scan-SonarCube.ps1` with embedded credentials
- `config\.env`
- `config\.env.secrets` when the stack needs secrets
- `config\account.key` for Cosmos DB
- Install-folder `README.md` with connection strings and daily commands

Installer-managed non-secret files and generated management scripts are
overwritten when their writers run. Existing `.env.secrets` files are preserved
when the installer creates secrets.

## Data Persistence

SonarCube and PostgreSQL use Docker named volumes for persistent database and
application data. PostgreSQL uses a single generated `config\.env` file and
Windows batch start/stop scripts. Snowflake uses one `config\.env` file and
stores emulator data in an install-local `snowflake-dat` folder. Cosmos DB uses
one `config\.env` file, writes the account key to `config\account.key`, and
stores emulator data in an install-local `cosmos-data` folder. MSSQL
currently uses an install-local `mssql_dev_data` folder beside its generated
compose file. Aspire Dashboard does not create persistent data storage.

Do not run `docker compose down -v` or `docker volume prune` unless you intend
to delete persistent data.

## Installer Details

Per-installer defaults, generated files, and connection details live in the
[`docs`](docs) folder:

- [Install-SonarCube.ps1](docs/Install-SonarCube.md)
- [Install-MSSql.ps1](docs/Install-MSSql.md)
- [Install-AspireDashboard.ps1](docs/Install-AspireDashboard.md)
- [Install-PostgreSql.ps1](docs/Install-PostgreSql.md)
- [Install-Snowflake.ps1](docs/Install-Snowflake.md)
- [Install-CosmosDb.ps1](docs/Install-CosmosDb.md)
- [Install-Kubectl.ps1](docs/Install-Kubectl.md)
