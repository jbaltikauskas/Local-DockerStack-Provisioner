# Install-Snowflake.ps1

`ghcr.io/nnnkkk7/snowflake-emulator:latest` on port `8080` with local account
settings from `config-snowflake.json`.

**Generated files:**

- `Start-Snowflake.ps1` and `Stop-Snowflake.ps1` (plus `Start-Snowflake.bat` and `Stop-Snowflake.bat`).
- `docker-compose.yml` binding `./snowflake-dat` to `/data` so `DB_PATH=/data/snowflake.db` persists.
- `config\.env` containing account, user, warehouse, database, schema, and role settings.
- Install-folder `README.md` documenting connection strings and drivers.

**Connection details:**

You can connect to the Snowflake emulator using the standard gosnowflake driver
or REST API. The default connection string/DSN is:

```text
user:pass@localhost:8080/TEST_DB/PUBLIC?account=test&protocol=http
```

`Install-Snowflake.ps1` generates `docker-compose.yml` like this:

```yaml
version: '3.8'

services:
  snowflake-emulator:
    image: ghcr.io/nnnkkk7/snowflake-emulator:latest
    container_name: local-snowflake
    ports:
      - "8080:8080"
    env_file:
      - ./config/.env
    volumes:
      - ./snowflake-dat:/data
    restart: unless-stopped
```
