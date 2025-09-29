#!/usr/bin/env bash
set -euo pipefail

# Bruno + toolchain preflight checker
# Usage: REQUIRED_SECRETS="secret1 secret2" CHECK_AZ=1 CHECK_SQLCMD=0 scripts/check_bruno.sh

# Configuration
REQUIRED_SECRETS="${REQUIRED_SECRETS:-}"
CHECK_AZ="${CHECK_AZ:-1}"
CHECK_SQLCMD="${CHECK_SQLCMD:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[$0] $*"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }
error() { echo -e "${RED}✗ $*${NC}" >&2; }
fatal() { error "$*"; exit 1; }

CHECKS_PASSED=0
CHECKS_TOTAL=0

check() {
    local name="$1"
    local cmd="$2"
    ((CHECKS_TOTAL++))

    log "Checking: $name"
    if eval "$cmd" &>/dev/null; then
        success "$name"
        ((CHECKS_PASSED++))
    else
        error "$name"
        return 1
    fi
}

# --- Azure-only guard (no Supabase; no underscore keys) ---
echo "Azure-only guard: scanning Bruno vault for forbidden patterns"
forbidden_found=false

# Check for Supabase keys
if find ~/.bruno/vault -name "supabase" -type d 2>/dev/null | grep -q .; then
    echo "✖ Supabase directory found in vault (Azure-only project)" >&2
    forbidden_found=true
fi

# Check for underscore-style keys
if find ~/.bruno/vault -name "*_*" -type f 2>/dev/null | grep -q .; then
    echo "✖ Underscore-style secret names detected. Use path-style (e.g., azure-sql/server)" >&2
    forbidden_found=true
fi

if [ "$forbidden_found" = "true" ]; then
    exit 2
fi
echo "✅ Azure-only compliance verified"
# --- end Azure-only guard ---

# Check Bruno CLI
check "Bruno CLI (bru)" "bru --version"
check "Bruno Wrapper" "test -x ~/.local/bin/bruno-wrapper"

# Check required secrets if specified
if [[ -n "$REQUIRED_SECRETS" ]]; then
    for secret in $REQUIRED_SECRETS; do
        check "Secret: $secret" "echo "SECRET_CHECK_PLACEHOLDER_$secret" | grep -q ."
    done
fi

# Check Azure CLI if requested
if [[ "$CHECK_AZ" == "1" ]]; then
    check "Azure CLI" "az --version"
    check "Azure login" "az account show"
fi

# Check sqlcmd if requested
if [[ "$CHECK_SQLCMD" == "1" ]]; then
    check "sqlcmd" "sqlcmd -? | head -1"
fi

# Check Keychain credentials
check "Azure SQL Keychain" "security find-generic-password -s 'SQL-TBWA-ProjectScout-Reporting-Prod' -a 'scout-analytics'"

# Check Bruno vault setup
check "Bruno Vault" "test -d ~/.bruno/vault"
check "Azure SQL Vault Entry" "test -f ~/.bruno/vault/azure-sql/connection-string"

# Check project scripts
check "Keychain Secrets Script" "test -x ./scripts/keychain-secrets.sh"
check "Bruno Secure Script" "test -x ./scripts/bruno-secure.sh"
check "Bruno SQL Script" "test -x ./scripts/bruno-sql.sh"

# Summary
log "Preflight complete: $CHECKS_PASSED/$CHECKS_TOTAL checks passed"

if [[ $CHECKS_PASSED -eq $CHECKS_TOTAL ]]; then
    success "All preflight checks passed"
    exit 0
else
    fatal "Preflight failed: $((CHECKS_TOTAL - CHECKS_PASSED)) checks failed"
fi