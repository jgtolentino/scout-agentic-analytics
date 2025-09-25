#!/usr/bin/env bash
set -euo pipefail
CANDS=( "SQL-TBWA-ProjectScout-Reporting-Prod" "tbwa-scout-prod" "scout-analytics-prod" )
for s in "${CANDS[@]}"; do
  if CONN=$(security find-generic-password -s "$s" -a "scout-analytics" -w 2>/dev/null); then
    [[ -n "${CONN:-}" ]] && { printf '%s' "$CONN"; exit 0; }
  fi
done
[[ -n "${AZURE_SQL_CONN_STR:-}" ]] && { printf '%s' "$AZURE_SQL_CONN_STR"; exit 0; }
echo "No Azure SQL connection found (Keychain or AZURE_SQL_CONN_STR)." >&2; exit 1