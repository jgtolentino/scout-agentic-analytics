#!/usr/bin/env bash
# Simple Bruno execution wrapper for Scout v7
set -euo pipefail

# Get Azure SQL connection string from Bruno vault
AZURE_SQL_CONN_STR=$(cat ~/.bruno/vault/azure_sql_connection_string 2>/dev/null || echo "")

if [[ -z "$AZURE_SQL_CONN_STR" ]]; then
    echo "❌ Azure SQL connection string not found in Bruno vault" >&2
    exit 1
fi

# Execute the command passed through stdin
eval "$AZURE_SQL_CONN_STR"