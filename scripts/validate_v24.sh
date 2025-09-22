#!/usr/bin/env bash
set -euo pipefail
: "${AZSQL_HOST:?}"; : "${AZSQL_DB:?}"; : "${AZSQL_USER_READER:?}"; : "${AZSQL_PASS_READER:?}"

mkdir -p reports
# -b: exit non-zero on RAISERROR; -h -1: no headers; separate steps for clearer artifacts
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_READER" -P "$AZSQL_PASS_READER" -b -Q "EXEC dbo.sp_validate_v24;" -s "," -W -w 32767 > reports/v24_validation_raw.txt

# Split sections (best-effort): save parity summary separately
grep -i "rows_flat" -m1 -n reports/v24_validation_raw.txt >/dev/null 2>&1 || true
cp reports/v24_validation_raw.txt reports/v24_validation_$(date +%Y%m%dT%H%M%S).txt
echo "OK: reports/v24_validation_*.txt"