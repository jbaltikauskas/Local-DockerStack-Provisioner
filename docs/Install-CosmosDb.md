# Install-CosmosDb.ps1

`mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-latest` with
gateway port `8081`, health port `8080`, and Data Explorer port `1234`.
`PROTOCOL` defaults to `https` so the .NET SDK can connect. The well-known
emulator `ACCOUNT_KEY` comes from `config-cosmosdb.json`.

**Generated files:**

- `CosmosDb.url`: Windows Internet Shortcut to open the Cosmos DB Data Explorer directly at `https://localhost:1234`.
- `Start-CosmosDb.ps1` and `Stop-CosmosDb.ps1` (plus `Start-CosmosDb.bat` and `Stop-CosmosDb.bat`).
- `docker-compose.yml` binding `./cosmos-data` to `/data` and `./config/account.key` to `/account.key:ro`.
- `config\.env` and `config\account.key`.
- Install-folder `README.md` documenting connection options and C# code samples.

**Connection details:**

The Data Explorer defaults to `https://localhost:1234`. The gateway endpoint
defaults to `https://localhost:8081`. The default connection string is:

```text
AccountEndpoint=https://localhost:8081/;AccountKey=<ACCOUNT_KEY from config-cosmosdb.json>
```

The .NET SDK requires gateway mode. For `https`, ignore the emulator's local
certificate or use `PROTOCOL` `https-insecure`. Health probes stay on HTTP at
`http://localhost:8080/ready`.

`Install-CosmosDb.ps1` generates `docker-compose.yml` like this:

```yaml
services:
  cosmosdb-JB:
    image: mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-latest
    container_name: cosmosdb-jb-yyyyMMdd
    env_file:
      - ./config/.env
    ports:
      - "127.0.0.1:8081:8081"
      - "127.0.0.1:8080:8080"
      - "127.0.0.1:1234:1234"
    volumes:
      - ./cosmos-data:/data
      - ./config/account.key:/account.key:ro
    restart: unless-stopped
```
