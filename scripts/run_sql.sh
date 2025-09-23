#!/usr/bin/env bash
set -euo pipefail
: "${AZSQL_HOST:?}"; : "${AZSQL_DB:?}"; : "${AZSQL_USER:?}"; : "${AZSQL_PASS:?}"

file="${1:?path to .sql required}"
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER" -P "$AZSQL_PASS" -l 60 -b -i "$file"
echo "OK: $file"