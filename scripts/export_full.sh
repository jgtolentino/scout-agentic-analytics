#!/bin/bash
# File: scripts/export_full.sh
# Export ALL rows from production views

set -e

# Ensure exports directory exists
mkdir -p /Users/tbwa/scout-v7/exports

echo "Exporting flat transactions (all rows)..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER" -P "$AZSQL_PASS" \
  -Q "SET NOCOUNT ON; SELECT * FROM dbo.v_transactions_flat_production ORDER BY txn_ts DESC;" \
  -s "," -W -w 32767 -h -1 > exports/flat_full.csv

echo "Exporting crosstab transactions (all rows)..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER" -P "$AZSQL_PASS" \
  -Q "SET NOCOUNT ON; SELECT * FROM dbo.v_transactions_crosstab_production ORDER BY [date] DESC, store_id, daypart, brand;" \
  -s "," -W -w 32767 -h -1 > exports/crosstab_full.csv

echo "Export complete:"
echo "- exports/flat_full.csv (15+ columns)"
echo "- exports/crosstab_full.csv (10 columns)"
ls -la exports/*.csv