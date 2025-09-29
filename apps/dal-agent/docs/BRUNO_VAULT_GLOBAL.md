# Bruno Vault — Global Availability

## Locations
- Vault home: `~/.bruno/vault` (source of truth for local/CI scripting)
- Project usage: scripts call `bruno secret ...` (or `${secret:...}` via the agentic CLI)

## Environment
Add to your shell profile (`~/.zshrc` / `~/.bashrc`):
```sh
export BRUNO_HOME="$HOME/.bruno"
export BRUNO_CMD="bruno"   # falls back to 'bru' via our shim
export PATH="$HOME/.local/bin:$PATH"
```

## Required Secrets (minimum)

* `azure/subscription-id`
* `azure-sql/server`, `azure-sql/database`, `azure-sql/user`, `azure-sql/password`
* `openai/endpoint`, `openai/api-key`
* `vercel/token`, `github/token`

## Audit (non-leaking)

```sh
bruno secret list  # Custom implementation only
ls ~/.bruno/vault  # Direct file listing

# Check existence without revealing values
for key in azure_sql_server azure_sql_database openai_api_key; do
  if [ -f ~/.bruno/vault/$key ]; then
    echo "OK   $key ($(wc -c < ~/.bruno/vault/$key) chars)"
  else
    echo "MISS $key"
  fi
done
```

## Current Implementation

Since the standard Bruno CLI doesn't include secret management, this project uses:
- File-based vault at `~/.bruno/vault/`
- Custom secret access via file reads
- Integration with macOS Keychain for sensitive connection strings

## Safe Usage

* **Never echo secrets**. Use `cat ~/.bruno/vault/KEY | cmd` or direct file reading
* Prefer **Managed Identity** on Azure; SQL user/pass only as fallback
* KV for runtime (Functions) via **Key Vault references**, not files
* Connection strings secured in macOS Keychain with `scripts/conn_default.sh` accessor

## Azure SQL Connection

The Azure SQL connection is managed through:
- **Server**: sqltbwaprojectscoutserver.database.windows.net
- **Database**: SQL-TBWA-ProjectScout-Reporting-Prod
- **Security**: Full connection string secured in macOS Keychain
- **Access**: Via `scripts/conn_default.sh` wrapper script

> **Azure-only profile:** This project uses Azure SQL, Azure Functions, Azure AI Search, Azure Key Vault, and Azure OpenAI. No Supabase components are required.