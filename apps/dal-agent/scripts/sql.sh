#!/usr/bin/env bash
set -euo pipefail

# Check if we're in mock mode
if [[ "${MOCK:-}" == "1" ]]; then
    exec "$(dirname "${BASH_SOURCE[0]}")/sql_mock_router.sh" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CONN_STR="$("$ROOT/scripts/conn_default.sh")"

# Parse connection string into individual parameters
if [[ "$CONN_STR" == *" -d "* ]]; then
  # Format: server -d database -U user -P password
  eval "sqlcmd -W -w 32767 -s"," -h -1 -S $CONN_STR \"\$@\""
else
  # Fallback to direct server parameter
  exec sqlcmd -W -w 32767 -s"," -h -1 -S "$CONN_STR" "$@"
fi