#!/bin/bash
# Export v24 compatibility data to CSV
# Usage: ./scripts/export_v24_compatibility.sh [output_file]

set -e

OUTPUT_FILE="${1:-exports/flat_v24_$(date +%Y%m%d_%H%M%S).csv}"

# Ensure exports directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Exporting v24 compatibility data to: $OUTPUT_FILE"

sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_READER" -P "$AZSQL_PASS_READER" \
  -Q "SET NOCOUNT ON; SELECT * FROM dbo.v_transactions_flat_v24 ORDER BY Txn_TS DESC" \
  -s"," -h -1 -W -o "$OUTPUT_FILE"

echo "Export completed: $OUTPUT_FILE"
echo "Records exported: $(tail -n +1 "$OUTPUT_FILE" | wc -l)"