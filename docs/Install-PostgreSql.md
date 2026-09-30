# Install-PostgreSql.ps1

Standalone PostgreSQL (`postgres:16-alpine`) running on port `5432` with
database credentials from `config-postgresql.json`.

**Generated files:**

- `Start-PostgreSql.ps1` and `Stop-PostgreSql.ps1` (plus `Start-PostgreSql.bat` and `Stop-PostgreSql.bat`).
- `docker-compose.yml` utilizing a dedicated Docker named volume for `/var/lib/postgresql/data`.
- `config\.env` containing `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`.
- Install-folder `README.md` with connection strings and management commands.

**Connection details:**

- Standard connection string:
  ```text
  Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=<POSTGRES_PASSWORD>;
  ```
- C# connection string:
  ```csharp
  var connectionString = "Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=<POSTGRES_PASSWORD>;";
  ```
