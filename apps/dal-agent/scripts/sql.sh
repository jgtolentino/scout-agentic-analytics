#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CONN="$("$ROOT/scripts/conn_default.sh")"
# Force SET NOCOUNT ON globally to prevent parsing regressions
sqlcmd -S "$CONN" -Q "SET NOCOUNT ON;" >/dev/null 2>&1 || true
exec sqlcmd -S "$CONN" "$@"