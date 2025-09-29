# Claude Code — Default Executor: Bruno

**Policy:** All execution emitted by Claude must be wrapped in a `:bruno run` one-shot.
Claude never sees credentials; all sensitive material is read from Bruno Vault or Azure Key Vault.

## Command Template (deploy → validate)

```bash
:bruno run <<'BRUNO'
set -euo pipefail
scripts/check_bruno.sh
./scripts/deploy_scout_azure.sh
./scripts/smoke_e2e.sh
BRUNO
```

## Secrets in Commands

* Use vault file reads: `cat ~/.bruno/vault/azure_sql_server`
* Use keychain integration: `scripts/conn_default.sh`
* Use Azure Key Vault references for Function Apps

## Implementation Notes

This project uses a file-based Bruno vault since the standard Bruno CLI (v2.9.0) doesn't include built-in secret management. The vault operates through:

- Direct file access to `~/.bruno/vault/`
- Integration with macOS Keychain for connection strings
- Azure Key Vault for production environment secrets

## Security Patterns

```bash
# ✅ Safe: Use file-based vault access
SERVER=$(cat ~/.bruno/vault/azure_sql_server)

# ✅ Safe: Use keychain integration
CONN_STR=$(scripts/conn_default.sh)

# ❌ Unsafe: Never hardcode secrets
CONN_STR="Server=myserver;User=myuser;Password=mypass"
```

## Do Nots

* Do not paste keys/tokens in chats, logs, or files
* Do not run cloud commands without preflight (`scripts/check_bruno.sh`)
* Do not bypass the keychain integration for Azure SQL access

> **Azure-only profile:** This project uses Azure SQL, Azure Functions, Azure AI Search, Azure Key Vault, and Azure OpenAI. No Supabase components are required.