#!/usr/bin/env bash
# ========================================================================
# Canonical Sample Export - Numbers/Excel Friendly
# Purpose: Generate small sample for quick review in spreadsheet apps
# ========================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
OUTPUT_DIR="$ROOT/out/canonical"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 Generating Numbers/Excel-friendly canonical sample...${NC}"

mkdir -p "$OUTPUT_DIR"

# Generate sample (first 100 rows)
SAMPLE_FILE="$OUTPUT_DIR/canonical_sample_${TIMESTAMP}.csv"

"$ROOT/scripts/sql.sh" -Q "
-- Header row
SELECT 'Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp' as header
UNION ALL
-- Sample data (top 100 rows)
SELECT
    Transaction_ID + ',' +
    CAST(Transaction_Value AS nvarchar) + ',' +
    CAST(Basket_Size AS nvarchar) + ',' +
    ISNULL(Category, '') + ',' +
    ISNULL(Brand, '') + ',' +
    ISNULL(Daypart, '') + ',' +
    ISNULL(Demographics_Age_Gender_Role, '') + ',' +
    ISNULL(Weekday_vs_Weekend, '') + ',' +
    ISNULL(CAST(Time_of_Transaction AS nvarchar), '') + ',' +
    ISNULL(Location, '') + ',' +
    ISNULL(REPLACE(Other_Products, ',', ';'), '') + ',' +  -- Replace commas in Other_Products
    CASE WHEN Was_Substitution = 1 THEN 'Y' ELSE 'N' END + ',' +
    CONVERT(nvarchar, Export_Timestamp, 120)
FROM (
    SELECT TOP 100 *
    FROM gold.v_transactions_flat_canonical
    ORDER BY Transaction_ID
) sample
" -h -1 > "$SAMPLE_FILE"

# Generate metadata
ROW_COUNT=$(tail -n +2 "$SAMPLE_FILE" | wc -l)
FILE_SIZE=$(wc -c < "$SAMPLE_FILE")

cat > "$OUTPUT_DIR/sample_info_${TIMESTAMP}.txt" << EOF
Canonical Sample Export Info
============================
Generated: $(date)
File: $(basename "$SAMPLE_FILE")
Rows: $ROW_COUNT (plus header)
Size: $FILE_SIZE bytes
Schema: Canonical 13-column

Purpose: Quick review in Numbers/Excel
Usage: Open directly in spreadsheet application

Full Export: Use make canonical-export for complete data
EOF

echo -e "${GREEN}✅ Sample export completed:${NC}"
echo -e "  📁 File: $SAMPLE_FILE"
echo -e "  📊 Rows: $ROW_COUNT (sample)"
echo -e "  💾 Size: $(numfmt --to=iec $FILE_SIZE)"
echo ""
echo -e "${YELLOW}Quick Actions:${NC}"
echo -e "  • Open in Numbers: open '$SAMPLE_FILE'"
echo -e "  • View in terminal: head '$SAMPLE_FILE'"
echo -e "  • Full export: make canonical-export"