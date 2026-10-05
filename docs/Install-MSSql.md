# Install-MSSql.ps1

SQL Server Developer Edition running on port `1433`.

**Generated files:**

- `Start-MSSql.ps1` and `Stop-MSSql.ps1` (plus `Start-MSSql.bat` and `Stop-MSSql.bat`).
- `docker-compose.yml` mapping `./mssql_dev_data` to `/var/opt/mssql/data`.
- `config\.env` (setting `ACCEPT_EULA=Y` and `MSSQL_PID`).
- `config\.env.secrets` (containing `MSSQL_SA_PASSWORD` from `config-mssql.json`).
- Install-folder `README.md` with complete connection strings and sample code.

**Connection details:**

- Standard connection string:
  ```text
  Server=localhost,1433;User Id=sa;Password=<MSSQL_SA_PASSWORD>;TrustServerCertificate=True;
  ```
- C# connection string:
  ```csharp
  var connectionString = "Server=localhost,1433;Database=master;User Id=sa;Password=<MSSQL_SA_PASSWORD>;Encrypt=False;TrustServerCertificate=True;";
  ```
