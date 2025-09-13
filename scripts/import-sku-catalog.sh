#!/bin/bash

# Import SKU Catalog CSV into Supabase
# This script loads the CSV into staging and processes it

echo "📦 Importing SKU Catalog into Masterdata"
echo "========================================"

# Check environment
if [ -z "$DATABASE_URL" ]; then
    echo "❌ DATABASE_URL not set"
    exit 1
fi

CSV_FILE="${1:-/Users/tbwa/Downloads/sku_catalog_with_telco_filled.csv}"

if [ ! -f "$CSV_FILE" ]; then
    echo "❌ CSV file not found: $CSV_FILE"
    echo "Usage: $0 [path/to/sku_catalog.csv]"
    exit 1
fi

echo "📁 CSV File: $CSV_FILE"
echo "📊 Total rows: $(wc -l < "$CSV_FILE")"

# Step 1: Apply migration if not already done
echo -e "\n1️⃣ Applying migration..."
psql "$DATABASE_URL" -f supabase/migrations/20250823_import_sku_catalog.sql

# Step 2: Clear staging table
echo -e "\n2️⃣ Clearing staging table..."
psql "$DATABASE_URL" -c "TRUNCATE staging.sku_catalog_upload;"

# Step 3: Import CSV
echo -e "\n3️⃣ Importing CSV to staging..."
psql "$DATABASE_URL" -c "\copy staging.sku_catalog_upload FROM '$CSV_FILE' WITH (FORMAT csv, HEADER true, DELIMITER ',');"

# Verify staging import
STAGING_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT count(*) FROM staging.sku_catalog_upload;")
echo "✅ Imported $STAGING_COUNT rows to staging"

# Step 4: Show preview
echo -e "\n4️⃣ Preview of staged data:"
psql "$DATABASE_URL" -c "
SELECT 
  brand_name,
  count(*) as products,
  count(distinct category_name) as categories
FROM staging.sku_catalog_upload
GROUP BY brand_name
ORDER BY products DESC
LIMIT 10;
"

# Step 5: Run import
echo -e "\n5️⃣ Processing import to masterdata..."
psql "$DATABASE_URL" -c "SELECT * FROM masterdata.import_sku_catalog();"

# Step 6: Verify results
echo -e "\n6️⃣ Import verification:"
psql "$DATABASE_URL" -c "SELECT * FROM masterdata.verify_catalog_import();"

# Step 7: Show catalog summary
echo -e "\n7️⃣ Catalog summary by brand:"
psql "$DATABASE_URL" -x -c "
SELECT * FROM masterdata.v_catalog_summary 
ORDER BY product_count DESC 
LIMIT 20;
"

# Step 8: Sample products
echo -e "\n8️⃣ Sample imported products:"
psql "$DATABASE_URL" -c "
SELECT 
  b.brand_name,
  p.product_name,
  p.category,
  p.pack_size,
  p.upc,
  p.metadata->>'list_price' as price
FROM masterdata.products p
JOIN masterdata.brands b ON b.id = p.brand_id
ORDER BY p.created_at DESC
LIMIT 15;
"

echo -e "\n✅ Import complete!"
echo ""
echo "Next steps:"
echo "1. Review imported data: SELECT * FROM masterdata.v_catalog_summary;"
echo "2. Link to Isko: SKUs will auto-match via brand_name trigger"
echo "3. Update monitors: Add brand/product anomaly detection"
echo "4. Test RPCs: masterdata.rpc_brands_list(), masterdata.rpc_products_list()"