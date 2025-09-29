#!/usr/bin/env bash
# Chunked 45-column flat CSV export with header guard
# Exports all 12,192 rows reliably, avoiding JSON parsing issues

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
OUTPUT_FILE="out/flat/flat_dataframe_complete_45col_chunked.csv"
CHUNK_SIZE=1000
TEMP_DIR="out/flat/temp_chunks"

echo "🚀 Starting chunked 45-column flat CSV export..."
mkdir -p "$TEMP_DIR"
mkdir -p out/flat

# Get total row count from materialized table
TOTAL_ROWS=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM dbo.FlatExport_CSVSafe" | grep -E '^\s*[0-9]+\s*$' | tr -d ' \t\r\n')
echo "📊 Total rows to export: $TOTAL_ROWS"

# Calculate number of chunks
CHUNKS=$(( (TOTAL_ROWS + CHUNK_SIZE - 1) / CHUNK_SIZE ))
echo "📦 Will create $CHUNKS chunks of $CHUNK_SIZE rows each"

# Header guard - ensure only one header
if [ ! -s "$OUTPUT_FILE" ]; then
    echo "📋 Creating header..."
    echo "canonical_tx_id,canonical_tx_id_norm,canonical_tx_id_payload,transaction_date,year_number,month_number,month_name,quarter_number,day_name,weekday_vs_weekend,iso_week,amount,transaction_value,basket_size,was_substitution,store_id,product_id,barangay,age,gender,emotional_state,facial_id,role_id,persona_id,persona_confidence,persona_alternative_roles,persona_rule_source,primary_brand,secondary_brand,primary_brand_confidence,all_brands_mentioned,brand_switching_indicator,transcription_text,co_purchase_patterns,device_id,session_id,interaction_id,data_source_type,payload_data_status,payload_json_truncated,transaction_date_original,created_date,transaction_type,time_of_day_category,customer_segment" > "$OUTPUT_FILE"
else
    echo "📋 Header already exists, appending data..."
fi

# Export chunks
for ((i=0; i<CHUNKS; i++)); do
    OFFSET=$((i * CHUNK_SIZE))
    CHUNK_FILE="$TEMP_DIR/chunk_${i}.csv"

    echo "📤 Exporting chunk $((i+1))/$CHUNKS (rows $((OFFSET+1))-$((OFFSET+CHUNK_SIZE)))..."

    ./scripts/sql.sh -Q "SET NOCOUNT ON;
    WITH numbered AS (
        SELECT *, ROW_NUMBER() OVER (ORDER BY canonical_tx_id) as rn
        FROM dbo.FlatExport_CSVSafe
    )
    SELECT
        canonical_tx_id,canonical_tx_id_norm,canonical_tx_id_payload,
        transaction_date,year_number,month_number,month_name,quarter_number,day_name,weekday_vs_weekend,iso_week,
        amount,transaction_value,basket_size,was_substitution,
        store_id,product_id,barangay,
        age,gender,emotional_state,facial_id,role_id,
        persona_id,persona_confidence,persona_alternative_roles,persona_rule_source,
        primary_brand,secondary_brand,primary_brand_confidence,all_brands_mentioned,brand_switching_indicator,transcription_text,co_purchase_patterns,
        device_id,session_id,interaction_id,data_source_type,payload_data_status,payload_json_truncated,transaction_date_original,created_date,
        transaction_type,time_of_day_category,customer_segment
    FROM numbered
    WHERE rn > $OFFSET AND rn <= $((OFFSET + CHUNK_SIZE))
    ORDER BY canonical_tx_id" > "$CHUNK_FILE"

    # Append to main file (skip empty chunks)
    if [[ -s "$CHUNK_FILE" ]]; then
        cat "$CHUNK_FILE" >> "$OUTPUT_FILE"
    fi
done

# Cleanup temp files
rm -rf "$TEMP_DIR"

# Validate result
FINAL_ROWS=$(wc -l < "$OUTPUT_FILE")
EXPECTED_ROWS=$((TOTAL_ROWS + 1))  # +1 for header

echo "✅ Export complete!"
echo "📊 Final CSV: $FINAL_ROWS lines (expected: $EXPECTED_ROWS)"
echo "📁 Output: $OUTPUT_FILE"

if [[ $FINAL_ROWS -eq $EXPECTED_ROWS ]]; then
    echo "🎉 SUCCESS: All $TOTAL_ROWS rows exported successfully!"
else
    echo "⚠️  WARNING: Row count mismatch (got $FINAL_ROWS, expected $EXPECTED_ROWS)"
fi