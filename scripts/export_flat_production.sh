#!/bin/bash
# Export flat production data to CSV
# Usage: ./scripts/export_flat_production.sh [output_file]

set -e

OUTPUT_FILE="${1:-exports/flat_production_$(date +%Y%m%d_%H%M%S).csv}"

# Ensure exports directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Exporting flat production data to: $OUTPUT_FILE"

sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_READER" -P "$AZSQL_PASS_READER" \
  -Q "SET NOCOUNT ON; SELECT canonical_tx_id,transaction_id,device_id,store_id,store_name,brand,product_name,category,total_amount,total_items,payment_method,txn_ts,transaction_date,daypart,weekday_weekend,audio_transcript FROM dbo.v_transactions_flat_production ORDER BY transaction_date DESC, txn_ts DESC" \
  -s"," -h -1 -W -o "$OUTPUT_FILE"

echo "Export completed: $OUTPUT_FILE"
echo "Records exported: $(tail -n +1 "$OUTPUT_FILE" | wc -l)"