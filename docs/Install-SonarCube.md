# Install-SonarCube.ps1

Web UI defaults to `http://localhost:9000`; login uses the configured
`SONAR_ADMIN_USERNAME` and `SONAR_ADMIN_PASSWORD`. The password must be at
least 12 characters and include uppercase, lowercase, number, and
special-character content. SonarCube PostgreSQL credentials come from
`POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` in
`config-sonarcube.json`. The installer repairs the configured PostgreSQL
user's password in existing named volumes before SonarCube starts.

After the Web API is ready, the installer appends global `sonar.exclusions`
(`**/Scan-SonarCube.ps1,.ps1/**,.claude/**,.cursor/**,docs/**`), installs or
updates the global `dotnet-sonarscanner` tool (requires the .NET SDK) with
`dotnet tool install --global dotnet-sonarscanner` or
`dotnet tool update --global dotnet-sonarscanner`, verifies with
`dotnet sonarscanner --version`, generates a no-expiration Global Analysis
Token (`local-global-analysis`), and writes `SONAR_TOKEN` to the install folder
`config\.env.secrets`.

**Generated files:**

Each installation folder (for example, `<ServerNamePrefix>-SonarCube-yyyyMMdd`)
generates:

- `Scan-SonarCube.ps1`: Standalone scanner helper script with the Web UI URL and
  analysis token embedded (treat that file as secret).
- `SonarCube.url`: Windows Internet Shortcut pointing to the Web UI
  (`http://localhost:9000`).
- `Start-SonarCube.ps1` and `Stop-SonarCube.ps1` (plus `.cmd` wrappers).
- `docker-compose.yml`, `config\.env`, `config\.env.secrets`, and `README.md`.

**Using `Scan-SonarCube.ps1` and `SonarCube.url` in .NET projects:**

The generated `Scan-SonarCube.ps1` and `SonarCube.url` can be copied directly
into any .NET project repository containing a `.slnx` or `.sln` solution file
and run directly:

1. Copy `Scan-SonarCube.ps1` and `SonarCube.url` into the target .NET project
   root.
2. Run `.\Scan-SonarCube.ps1` in PowerShell directly from that project folder
   without passing parameters. The script automatically detects the first
   `*.slnx` in the current directory (or first `*.sln`, or inside a `src` folder),
   computes the SonarQube project key as `<solution-name>` (or
   `<solution-name>--<git-branch>`), passes standard exclusions, and runs
   `dotnet sonarscanner begin`, `dotnet build`, and `dotnet sonarscanner end`.
3. Double-click `SonarCube.url` (or open it from the terminal) to immediately
   launch the SonarQube dashboard in your browser and view the scan results.
