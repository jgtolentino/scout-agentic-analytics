#!/usr/bin/env bash
set -euo pipefail

# Load brand mappings to production BrandCategoryMapping table
# Uses category_id lookups from ref.NielsenCategories

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
CSV_PATH="${1:-$ROOT/data/brand-map-live.csv}"

if [[ ! -f "$CSV_PATH" ]]; then
    echo "❌ CSV file not found: $CSV_PATH" >&2
    exit 1
fi

echo "🚀 Loading brand mappings to production..."
echo "📁 CSV: $CSV_PATH"

# Get row count
ROWS=$(($(wc -l < "$CSV_PATH") - 1))
echo "📊 Loading $ROWS brand mappings..."

# Create production-compatible SQL
cat > "$ROOT/sql/temp_load_brands.sql" << 'EOF'
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Create staging table for production schema
IF OBJECT_ID('ref.stg_ProductionBrandMap','U') IS NOT NULL
    DROP TABLE ref.stg_ProductionBrandMap;

CREATE TABLE ref.stg_ProductionBrandMap(
    brand_name       nvarchar(100) NOT NULL,
    category_code    nvarchar(50)  NULL,
    department_code  nvarchar(50)  NULL
);

-- Load CSV data via bulk insert placeholder
-- (Will be replaced by actual data insertion)

-- Update production table with category_id lookups
;WITH mappings AS (
    SELECT
        s.brand_name,
        nc.hierarchy_level as category_id,
        100.0 as confidence_score,
        'Nielsen/Kantar Standard' as mapping_source,
        1 as is_mandatory,
        GETDATE() as created_date,
        GETDATE() as updated_date
    FROM ref.stg_ProductionBrandMap s
    LEFT JOIN ref.NielsenCategories nc ON nc.category_code = s.category_code
    WHERE s.category_code IS NOT NULL
      AND nc.category_code IS NOT NULL
)
MERGE dbo.BrandCategoryMapping AS T
USING mappings AS S
ON (LOWER(REPLACE(REPLACE(T.brand_name,' ',''),'-','')) = LOWER(REPLACE(REPLACE(S.brand_name,' ',''),'-','')))
WHEN MATCHED THEN
    UPDATE SET
        T.category_id = S.category_id,
        T.confidence_score = S.confidence_score,
        T.updated_date = S.updated_date
WHEN NOT MATCHED BY TARGET THEN
    INSERT (brand_name, category_id, confidence_score, mapping_source, is_mandatory, created_date, updated_date)
    VALUES (S.brand_name, S.category_id, S.confidence_score, S.mapping_source, S.is_mandatory, S.created_date, S.updated_date);

-- Report results
SELECT
    mapped_brands = COUNT(*)
FROM dbo.BrandCategoryMapping
WHERE category_id IS NOT NULL;

SELECT
    unmapped_brands = COUNT(*)
FROM dbo.BrandCategoryMapping
WHERE category_id IS NULL;

-- Clean up
DROP TABLE ref.stg_ProductionBrandMap;
EOF

# Insert CSV data into SQL - use QUOTENAME to handle apostrophes
{
    # Copy the base SQL first
    cp "$ROOT/sql/temp_load_brands.sql" "$ROOT/sql/temp_load_complete.sql"

    # Insert CSV data after the CREATE TABLE statement
    echo "" >> "$ROOT/sql/temp_load_complete.sql"
    echo "-- Insert brand mappings" >> "$ROOT/sql/temp_load_complete.sql"

    tail -n +2 "$CSV_PATH" | while IFS=',' read -r brand_name category_code department_code; do
        # Remove outer quotes and escape internal quotes
        brand_name=$(echo "$brand_name" | sed 's/^"//;s/"$//' | sed "s/'/''/g")
        category_code=$(echo "$category_code" | sed 's/^"//;s/"$//' | sed "s/'/''/g")
        department_code=$(echo "$department_code" | sed 's/^"//;s/"$//' | sed "s/'/''/g")

        if [[ -n "$category_code" && "$category_code" != "" ]]; then
            echo "INSERT INTO ref.stg_ProductionBrandMap VALUES ('$brand_name', '$category_code', '$department_code');" >> "$ROOT/sql/temp_load_complete.sql"
        else
            echo "INSERT INTO ref.stg_ProductionBrandMap VALUES ('$brand_name', NULL, NULL);" >> "$ROOT/sql/temp_load_complete.sql"
        fi
    done

    echo "" >> "$ROOT/sql/temp_load_complete.sql"
}

# Execute the script
echo "🔄 Executing brand mapping updates..."
"$ROOT/scripts/sql.sh" -i "$ROOT/sql/temp_load_complete.sql"

# Clean up temp files
rm -f "$ROOT/sql/temp_load_brands.sql" "$ROOT/sql/temp_load_complete.sql"

echo "✅ Brand mapping loading completed!"