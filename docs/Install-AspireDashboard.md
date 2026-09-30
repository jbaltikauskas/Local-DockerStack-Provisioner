# Install-AspireDashboard.ps1

Standalone .NET Aspire Dashboard for OpenTelemetry traces, metrics, and logs.

**Endpoints:**

- Dashboard UI: `http://localhost:18888`
- OTLP gRPC endpoint: `http://localhost:4317`
- OTLP HTTP endpoint: `http://localhost:4318`

**Generated files:**

- `AspireDashboard.url`: Windows Internet Shortcut to open the dashboard UI directly in your browser.
- `Start-AspireDashboard.ps1` and `Stop-AspireDashboard.ps1` (plus `Start-AspireDashboard.bat` and `Stop-AspireDashboard.bat`).
- `docker-compose.yml` and `config\.env` (`DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true`).
- Install-folder `README.md` documenting telemetry endpoints and daily commands.
