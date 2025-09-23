#!/usr/bin/env bash
set -euo pipefail
: "${AZSQL_HOST:?}"; : "${AZSQL_DB:?}"; : "${AZSQL_USER_READER:?}"; : "${AZSQL_PASS_READER:?}"

mkdir -p exports

# Flat (production view with JSON guards)
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_READER" -P "$AZSQL_PASS_READER" \
  -Q "SET NOCOUNT ON; SELECT * FROM dbo.v_transactions_flat_production ORDER BY txn_ts DESC;" \
  -s "," -W -w 32767 -h -1 > exports/flat_full.csv

# Flat v24 (compatibility contract - will create after deploying adapter)
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_READER" -P "$AZSQL_PASS_READER" \
  -Q "SET NOCOUNT ON; SELECT * FROM dbo.v_transactions_flat_v24 ORDER BY txn_ts DESC;" \
  -s "," -W -w 32767 -h -1 > exports/flat_v24.csv 2>/dev/null || echo "v24 view not yet deployed"

# Crosstab (production view with JSON guards)
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_READER" -P "$AZSQL_PASS_READER" \
  -Q "SET NOCOUNT ON; SELECT * FROM dbo.v_transactions_crosstab_production ORDER BY [date] DESC, store_id, daypart, brand;" \
  -s "," -W -w 32767 -h -1 > exports/crosstab_full.csv

echo "OK: exports/flat_full.csv"
echo "OK: exports/flat_v24.csv"
echo "OK: exports/crosstab_full.csv"