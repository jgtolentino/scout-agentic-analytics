#!/bin/bash
# Export crosstab production data to CSV
# Usage: ./scripts/export_crosstab_production.sh [output_file]

set -e

OUTPUT_FILE="${1:-exports/crosstab_production_$(date +%Y%m%d_%H%M%S).csv}"

# Ensure exports directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Exporting crosstab production data to: $OUTPUT_FILE"

sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_READER" -P "$AZSQL_PASS_READER" \
  -Q "SET NOCOUNT ON; SELECT [date],store_id,store_name,daypart,brand,txn_count,total_amount,avg_basket_amount,substitution_events FROM dbo.v_transactions_crosstab_production ORDER BY [date] DESC, total_amount DESC" \
  -s"," -h -1 -W -o "$OUTPUT_FILE"

echo "Export completed: $OUTPUT_FILE"
echo "Records exported: $(tail -n +1 "$OUTPUT_FILE" | wc -l)"