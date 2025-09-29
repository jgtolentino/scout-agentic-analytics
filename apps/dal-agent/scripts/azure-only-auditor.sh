#!/usr/bin/env bash
set -euo pipefail

# Azure-only Bruno vault and Key Vault auditor
# Usage: ./scripts/azure-only-auditor.sh

need(){ command -v "$1" >/dev/null 2>&1 && echo "OK   $1" || echo "MISS $1"; }

echo "== Tools =="
need bruno || need bru
need az
need jq
need curl
need docker
need sqlcmd || true

echo
echo "== Bruno vault (path-style keys) =="
req=(
    openai/api-key
    openai/endpoint
    azure/subscription-id
    azure-sql/server
    azure-sql/database
    azure-sql/user
    azure-sql/password
    vercel/token
    github/token
)

for k in "${req[@]}"; do
    if [ -f ~/.bruno/vault/"$k" ]; then
        size=$(wc -c < ~/.bruno/vault/"$k" | tr -d ' ')
        echo "OK   $k ($size chars)"
    else
        echo "MISS $k"
    fi
done

echo
echo "== Keychain integration =="
if bash scripts/conn_default.sh >/dev/null 2>&1; then
    echo "OK   Azure SQL keychain connection"
else
    echo "MISS Azure SQL keychain connection"
fi

echo
echo "== Azure Key Vault (optional check) =="
KV_NAME="${KV_NAME:-kv-scout-tbwa-1750202017}"
if az keyvault show -n "$KV_NAME" >/dev/null 2>&1; then
    names="$(az keyvault secret list --vault-name "$KV_NAME" --query "[].name" -o tsv 2>/dev/null || true)"
    for n in OPENAI_API_KEY OPENAI_ENDPOINT AZURE_SQL_SERVER AZURE_SQL_DATABASE VERCEL_TOKEN GITHUB_TOKEN; do
        if echo "$names" | grep -qx "$n"; then
            echo "OK   $n"
        else
            echo "MISS $n"
        fi
    done
else
    echo "SKIP Key Vault not reachable ($KV_NAME)"
fi

echo
echo "== Azure login =="
if az account show >/dev/null 2>&1; then
    sub="$(az account show --query id -o tsv)"
    name="$(az account show --query name -o tsv)"
    echo "OK   Azure CLI logged in ($name)"
else
    echo "MISS Azure CLI login"
fi

echo
echo "== Forbidden: Supabase check =="
forbidden_keys=(
    supabase/url
    supabase/anon-key
    supabase/service-role
)

supabase_found=false
for k in "${forbidden_keys[@]}"; do
    if [ -f ~/.bruno/vault/"$k" ]; then
        echo "ERR  $k (should not exist in Azure-only setup)"
        supabase_found=true
    fi
done

if [ "$supabase_found" = false ]; then
    echo "OK   No Supabase keys found (Azure-only verified)"
fi

echo
echo "✅ Azure-only audit complete"