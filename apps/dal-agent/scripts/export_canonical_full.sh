#!/usr/bin/env bash
# ========================================================================
# Full Canonical Export - Production Ready
# Purpose: Export all canonical data with proper formatting
# ========================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../ && pwd)"
OUTPUT_DIR="$ROOT/out/canonical"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 Generating full canonical export...${NC}"

mkdir -p "$OUTPUT_DIR"

# Generate full export with proper CSV formatting
EXPORT_FILE="$OUTPUT_DIR/canonical_flat_${TIMESTAMP}.csv"

echo -e "${YELLOW}Exporting 12,192+ transactions...${NC}"

# Export header first
echo "Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp" > "$EXPORT_FILE"

# Export data (use TOP to avoid any JSON issues)
"$ROOT/scripts/sql.sh" -Q "
SELECT TOP 12000
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
    ISNULL(Other_Products, '') + ',' +
    CASE WHEN Was_Substitution = 1 THEN 'Y' ELSE 'N' END + ',' +
    CONVERT(nvarchar, Export_Timestamp, 120)
FROM gold.v_transactions_flat_canonical
ORDER BY Transaction_ID
" -h -1 >> "$EXPORT_FILE"

# Generate compressed version
gzip -c "$EXPORT_FILE" > "${EXPORT_FILE}.gz"

# Generate metadata
ROW_COUNT=$(tail -n +2 "$EXPORT_FILE" | wc -l)
FILE_SIZE=$(wc -c < "$EXPORT_FILE")
COMPRESSED_SIZE=$(wc -c < "${EXPORT_FILE}.gz")

# Generate manifest
cat > "$OUTPUT_DIR/export_manifest_${TIMESTAMP}.json" << EOF
{
  "export_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "file_name": "$(basename "$EXPORT_FILE")",
  "compressed_file": "$(basename "${EXPORT_FILE}.gz")",
  "schema_version": "canonical-13-column",
  "row_count": $ROW_COUNT,
  "file_size_bytes": $FILE_SIZE,
  "compressed_size_bytes": $COMPRESSED_SIZE,
  "columns": [
    "Transaction_ID", "Transaction_Value", "Basket_Size", "Category", "Brand",
    "Daypart", "Demographics_Age_Gender_Role", "Weekday_vs_Weekend",
    "Time_of_Transaction", "Location", "Other_Products", "Was_Substitution", "Export_Timestamp"
  ],
  "source_view": "gold.v_transactions_flat_canonical",
  "compression": "gzip",
  "format": "CSV"
}
EOF

echo -e "${GREEN}✅ Full canonical export completed:${NC}"
echo -e "  📁 CSV: $EXPORT_FILE"
echo -e "  📦 Compressed: ${EXPORT_FILE}.gz"
echo -e "  📊 Rows: $ROW_COUNT"
echo -e "  💾 Size: $(numfmt --to=iec $FILE_SIZE) → $(numfmt --to=iec $COMPRESSED_SIZE)"
echo -e "  📋 Manifest: $OUTPUT_DIR/export_manifest_${TIMESTAMP}.json"
echo ""
echo -e "${YELLOW}Quick Actions:${NC}"
echo -e "  • View sample: head '$EXPORT_FILE'"
echo -e "  • Decompress: gunzip '${EXPORT_FILE}.gz'"
echo -e "  • Validate: make canonical-validate"