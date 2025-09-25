#!/usr/bin/env bash
set -euo pipefail

# Load SKU mappings from CSV to production database
# Expected CSV format: SkuCode,SkuName,BrandName,CategoryCode,PackSize

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
SQL="$ROOT/scripts/sql.sh"
CSV_PATH="${1:?usage: load_sku_csv.sh path/to/sku_map.csv}"

if [[ ! -f "$CSV_PATH" ]]; then
    echo "❌ CSV file not found: $CSV_PATH" >&2
    exit 1
fi

echo "🚀 Loading SKU mappings from CSV..."
echo "📁 CSV: $CSV_PATH"

# Get row count (excluding header)
ROWS=$(($(wc -l < "$CSV_PATH") - 1))
echo "📊 Loading $ROWS SKU mappings..."

# Validate CSV has required columns
HEADER=$(head -n1 "$CSV_PATH")
if [[ ! "$HEADER" =~ SkuCode.*SkuName.*BrandName ]]; then
    echo "❌ Invalid CSV format. Expected header: SkuCode,SkuName,BrandName,CategoryCode,PackSize" >&2
    exit 1
fi

# Clear staging table
$SQL -Q "TRUNCATE TABLE ref.stg_SkuMap;" || {
    echo "⚠️  Staging table doesn't exist yet - will be created by migration"
}

# Convert CSV to SQL INSERT statements using Python
echo "🔄 Converting CSV to SQL statements..."

python3 - "$CSV_PATH" | $SQL -i - <<'PYTHON'
import csv
import sys

csv_path = sys.argv[1]

def sql_escape(value):
    """Escape single quotes and handle None values"""
    if not value or value.strip() == '':
        return 'NULL'
    # Escape single quotes by doubling them
    escaped = str(value).strip().replace("'", "''")
    return f"N'{escaped}'"

try:
    with open(csv_path, 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)

        # Validate required columns
        required_cols = ['SkuCode', 'SkuName', 'BrandName']
        missing_cols = [col for col in required_cols if col not in reader.fieldnames]
        if missing_cols:
            print(f"-- ERROR: Missing required columns: {missing_cols}")
            sys.exit(1)

        insert_count = 0

        for row in reader:
            # Skip rows with missing required fields
            if not all(row.get(col, '').strip() for col in required_cols):
                continue

            sku_code = sql_escape(row.get('SkuCode', ''))
            sku_name = sql_escape(row.get('SkuName', ''))
            brand_name = sql_escape(row.get('BrandName', ''))
            category_code = sql_escape(row.get('CategoryCode', ''))
            pack_size = sql_escape(row.get('PackSize', ''))

            # Generate INSERT statement
            print(f"INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES({sku_code},{sku_name},{brand_name},{category_code},{pack_size});")
            insert_count += 1

        print(f"-- Loaded {insert_count} SKU records into staging")

except Exception as e:
    print(f"-- ERROR processing CSV: {e}")
    sys.exit(1)
PYTHON

if [ $? -ne 0 ]; then
    echo "❌ Failed to convert CSV to SQL" >&2
    exit 1
fi

echo "✅ SKU CSV loaded into staging table ref.stg_SkuMap"
echo "🔄 Run 'make sku-load' to complete the upsert process"