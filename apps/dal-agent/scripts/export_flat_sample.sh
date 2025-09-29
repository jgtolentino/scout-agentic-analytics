#!/bin/bash
# Flat Export for Sample Sheet (13-column canonical format)
# Uses authoritative gold.v_export_projection with correct headers

set -euo pipefail

# Output setup
OUTPUT_DIR="out/flat"
mkdir -p "$OUTPUT_DIR"

echo "🔍 Generating flat sample sheet from gold.v_export_projection"

# One-shot SQL to produce the flat sheet (headers exactly as specified)
./scripts/sql.sh -Q "SET NOCOUNT ON;

SELECT
  p.transaction_id                                    AS [Transaction_ID],
  CAST(p.total_amount AS decimal(18,2))               AS [Transaction_Value],
  p.total_items                                       AS [Basket_Size],
  p.category                                          AS [Category],
  p.brand                                             AS [Brand],
  p.daypart                                           AS [Daypart],
  p.demographics                                      AS [Demographics (Age/Gender/Role)],
  p.emotions                                          AS [Emotions],
  p.weektype                                          AS [Weekday_vs_Weekend],
  CONVERT(varchar(10), p.transaction_date, 0)         AS [Time of transaction],
  p.region                                            AS [Location],
  CAST(NULL AS varchar(100))                          AS [Were there other product bought with it?],
  CAST(NULL AS varchar(100))                          AS [Was there substitution?]
FROM gold.v_export_projection AS p
ORDER BY p.transaction_id;" \
-o "$OUTPUT_DIR/sample_sheet.csv"

if [ $? -eq 0 ]; then
    rows=$(wc -l < "$OUTPUT_DIR/sample_sheet.csv")
    size=$(ls -lh "$OUTPUT_DIR/sample_sheet.csv" | awk '{print $5}')
    echo "✅ sample_sheet.csv written: $((rows-1)) rows ($size)"

    # Quick validation
    echo "📊 Running quick validity checks..."

    # Check first few lines to ensure headers are correct
    echo "🔍 Header check:"
    head -1 "$OUTPUT_DIR/sample_sheet.csv"

    # Check for data
    echo "🔍 Data sample:"
    head -3 "$OUTPUT_DIR/sample_sheet.csv" | tail -2

    # Compress the output
    gzip -f "$OUTPUT_DIR/sample_sheet.csv"
    echo "📦 Compressed: sample_sheet.csv.gz"
else
    echo "❌ Export failed"
    exit 1
fi