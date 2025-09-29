#!/usr/bin/env bash
# =====================================================
# Wait for Database and Execute Complete Export
# =====================================================

set -euo pipefail

DATE_FROM="${1:-2025-09-01}"
DATE_TO="${2:-2025-09-23}"
OUTPUT_FILE="complete_export_$(date +%Y%m%d_%H%M%S).csv"

echo "🔄 Waiting for database connectivity..."
echo "📅 Export Range: $DATE_FROM to $DATE_TO"
echo "📁 Output File: $OUTPUT_FILE"
echo

# Wait for database to be available
while true; do
    echo -n "⏳ Testing connection... "
    if ./scripts/sql.sh -Q "SELECT GETDATE()" >/dev/null 2>&1; then
        echo "✅ Connected!"
        break
    else
        echo "❌ Unavailable, retrying in 30 seconds..."
        sleep 30
    fi
done

echo
echo "🚀 Database is online! Executing complete export..."
echo

# Execute the complete export
if ./scripts/sql.sh -Q "EXEC canonical.sp_export_complete @DateFrom='$DATE_FROM', @DateTo='$DATE_TO'" > "$OUTPUT_FILE"; then

    # Validate export
    ROWS=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

    echo "✅ Complete export successful!"
    echo "📊 File: $OUTPUT_FILE"
    echo "📈 Rows: $ROWS"
    echo "💾 Size: $SIZE"
    echo

    # Add proper headers
    echo "canonical_tx_id,transaction_date,amount,basket_size,store_id,age,gender,weekday_vs_weekend,day_name,substitution_flag,data_source_type,primary_brand,secondary_brand,primary_brand_confidence,all_brands_mentioned,transaction_type,brand_switching_indicator,payload_data_status,device_id,session_id,export_timestamp" > "${OUTPUT_FILE%.csv}_with_headers.csv"
    cat "$OUTPUT_FILE" >> "${OUTPUT_FILE%.csv}_with_headers.csv"

    echo "📋 Headers added to: ${OUTPUT_FILE%.csv}_with_headers.csv"
    echo

    # Quick validation
    echo "🔍 Quick validation:"
    echo "Enhanced transactions: $(grep -c "Enhanced-Analytics" "$OUTPUT_FILE" || echo "0")"
    echo "Payload-only transactions: $(grep -c "Payload-Only" "$OUTPUT_FILE" || echo "0")"
    echo "JSON available: $(grep -c "JSON-Available" "$OUTPUT_FILE" || echo "0")"

    # Show sample data
    echo
    echo "📄 Sample enhanced transaction:"
    grep "Enhanced-Analytics" "$OUTPUT_FILE" | head -1 || echo "No enhanced transactions found"

    echo
    echo "📄 Sample payload-only transaction:"
    grep "Payload-Only" "$OUTPUT_FILE" | head -1 || echo "No payload-only transactions found"

    echo
    echo "🎯 Complete export ready for analysis!"

else
    echo "❌ Export failed!"
    exit 1
fi