#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SQL_CONN_STR:?set AZURE_SQL_CONN_STR}"

OUT="out/analytics"
mkdir -p "$OUT"

run() { echo ">> $1"; shift; "$@"; }

echo "🚀 Starting Scout Analytics Infrastructure Deployment..."
echo "📅 Started: $(date)"
echo ""

run "🔧 Fix substitution keys" \
  sqlcmd -S "$AZURE_SQL_CONN_STR" -i sql/analytics/001_fix_substitution_keys.sql

run "🏗️ Create reference tables" \
  sqlcmd -S "$AZURE_SQL_CONN_STR" -i sql/analytics/002_create_reference_tables.sql

run "🌱 Seed reference data" \
  sqlcmd -S "$AZURE_SQL_CONN_STR" -i sql/analytics/003_seed_reference_data.sql

run "📊 Create marts" \
  sqlcmd -S "$AZURE_SQL_CONN_STR" -i sql/analytics/004_create_marts.sql

run "🔍 Validation gates" \
  sqlcmd -S "$AZURE_SQL_CONN_STR" -i sql/analytics/005_validation_gates.sql

echo ""
echo "💾 Exporting analytics to CSV files..."

# Exports
run "Export store_profiles"        sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM mart.v_store_profiles ORDER BY store_id"                                    -s "," -W -h -1 > "$OUT/store_profiles.csv"
run "Export demo_brand_cat"        sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM mart.v_demo_brand_cat WHERE category <> 'Unspecified' ORDER BY txn DESC" -s "," -W -h -1 > "$OUT/demo_brand_cat.csv"
run "Export time_spreads"          sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM mart.v_time_spreads ORDER BY yyyymm, weekday_name"                       -s "," -W -h -1 > "$OUT/time_spreads.csv"
run "Export tobacco_metrics"       sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM mart.v_tobacco_metrics ORDER BY store_id"                                 -s "," -W -h -1 > "$OUT/tobacco_metrics.csv"
run "Export tobacco_copurchases"   sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT TOP 200 * FROM mart.v_tobacco_copurchases ORDER BY tx DESC"                     -s "," -W -h -1 > "$OUT/tobacco_copurchases_top200.csv"
run "Export laundry_metrics"       sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM mart.v_laundry_metrics ORDER BY detergent_form"                          -s "," -W -h -1 > "$OUT/laundry_metrics.csv"
run "Export transcript_terms"      sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM mart.v_transcript_terms ORDER BY score DESC, baskets DESC"               -s "," -W -h -1 > "$OUT/transcript_terms.csv"

echo ""
echo "📋 Generating summary report..."

# Count files and sizes
echo "📊 Scout Analytics Export Summary" > "$OUT/SUMMARY.txt"
echo "Generated: $(date)" >> "$OUT/SUMMARY.txt"
echo "" >> "$OUT/SUMMARY.txt"
echo "Files Created:" >> "$OUT/SUMMARY.txt"

for file in "$OUT"/*.csv; do
  if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    size=$(wc -c < "$file" | tr -d ' ')
    rows=$(($(wc -l < "$file") - 1))  # Subtract header
    echo "  $filename: $size bytes, $rows rows" >> "$OUT/SUMMARY.txt"
  fi
done

echo "" >> "$OUT/SUMMARY.txt"
echo "🎉 Scout Analytics Infrastructure Successfully Deployed!" >> "$OUT/SUMMARY.txt"

# Display summary
cat "$OUT/SUMMARY.txt"

echo ""
echo "📊 Creating cross-tab views..."
run "🔗 Create cross-tab views" \
  sqlcmd -S "$AZURE_SQL_CONN_STR" -i sql/analytics/006_create_crosstabs.sql

echo ""
echo "💾 Exporting cross-tab CSVs..."

# Cross-tab exports
run "Export ct_timeXcategory"            sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_timeXcategory"            -s "," -W -h -1 > "$OUT/ct_timeXcategory.csv"
run "Export ct_timeXbrand"               sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_timeXbrand"               -s "," -W -h -1 > "$OUT/ct_timeXbrand.csv"
run "Export ct_timeXdemographics"        sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_timeXdemographics"        -s "," -W -h -1 > "$OUT/ct_timeXdemographics.csv"
run "Export ct_timeXemotions"            sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_timeXemotions"            -s "," -W -h -1 > "$OUT/ct_timeXemotions.csv"
run "Export ct_basketsizeXcategory"      sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_basketsizeXcategory"      -s "," -W -h -1 > "$OUT/ct_basketsizeXcategory.csv"
run "Export ct_basketsizeXpayment"       sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_basketsizeXpayment"       -s "," -W -h -1 > "$OUT/ct_basketsizeXpayment.csv"
run "Export ct_basketsizeXcustomer"      sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_basketsizeXcustomer"      -s "," -W -h -1 > "$OUT/ct_basketsizeXcustomer.csv"
run "Export ct_basketsizeXemotions"      sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_basketsizeXemotions"      -s "," -W -h -1 > "$OUT/ct_basketsizeXemotions.csv"
run "Export ct_substitutionXcategory"    sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_substitutionXcategory"    -s "," -W -h -1 > "$OUT/ct_substitutionXcategory.csv"
run "Export ct_substitutionXreason"      sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_substitutionXreason"      -s "," -W -h -1 > "$OUT/ct_substitutionXreason.csv"
run "Export ct_suggestionAcceptedXbrand" sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_suggestionAcceptedXbrand" -s "," -W -h -1 > "$OUT/ct_suggestionAcceptedXbrand.csv"
run "Export ct_ageXcategory"             sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_ageXcategory"             -s "," -W -h -1 > "$OUT/ct_ageXcategory.csv"
run "Export ct_ageXbrand"                sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_ageXbrand"                -s "," -W -h -1 > "$OUT/ct_ageXbrand.csv"
run "Export ct_ageXpacksize"             sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_ageXpacksize"             -s "," -W -h -1 > "$OUT/ct_ageXpacksize.csv"
run "Export ct_genderXdaypart"           sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_genderXdaypart"           -s "," -W -h -1 > "$OUT/ct_genderXdaypart.csv"
run "Export ct_paymentXdemographics"     sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "SELECT * FROM ct_paymentXdemographics"     -s "," -W -h -1 > "$OUT/ct_paymentXdemographics.csv"

echo ""
echo "🏷️ Exporting brand catalog for Dan/Jaymie..."

# Brand catalog exports
CATALOG="out/catalog"
mkdir -p "$CATALOG"

run "Export brand master" sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "
SELECT
  bcm.BrandName            AS Brand,
  bcm.BrandNameNorm        AS Brand_Norm,
  bcm.Department,
  bcm.NielsenCategory
FROM dbo.BrandCategoryMapping bcm
ORDER BY bcm.Department, bcm.NielsenCategory, bcm.BrandName
" -s "," -W -h -1 > "$CATALOG/00_brand_master.csv"

run "Export observed brands" sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "
WITH obs AS (
  SELECT
    LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')) AS brand_norm,
    MAX(NULLIF(LTRIM(RTRIM(ti.brand_name)),''))          AS brand_raw,
    COUNT(DISTINCT t.canonical_tx_id)                     AS baskets,
    SUM(TRY_CAST(ti.qty AS int))                          AS units
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id
  WHERE t.txn_date >= DATEADD(day,-90,CAST(GETUTCDATE() AS date))
  GROUP BY LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-',''))
)
SELECT
  o.brand_raw           AS Brand_Observed,
  o.baskets            AS Baskets_90d,
  o.units              AS Units_90d,
  bcm.Department,
  bcm.NielsenCategory
FROM obs o
LEFT JOIN dbo.BrandCategoryMapping bcm ON bcm.BrandNameNorm = o.brand_norm
ORDER BY COALESCE(bcm.Department,'(unmapped)'),
         COALESCE(bcm.NielsenCategory,'(unmapped)'),
         Brand_Observed
" -s "," -W -h -1 > "$CATALOG/01_observed_brand_volumes_90d.csv"

run "Export unmapped brands" sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "
WITH obs AS (
  SELECT DISTINCT
    LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')) AS brand_norm,
    NULLIF(LTRIM(RTRIM(ti.brand_name)), '')              AS brand_raw
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id
  WHERE t.txn_date >= DATEADD(day,-90,CAST(GETUTCDATE() AS date))
), gaps AS (
  SELECT o.brand_raw
  FROM obs o
  LEFT JOIN dbo.BrandCategoryMapping bcm ON bcm.BrandNameNorm = o.brand_norm
  WHERE bcm.BrandNameNorm IS NULL AND o.brand_raw IS NOT NULL
)
SELECT brand_raw AS Brand_Unmapped
FROM gaps
ORDER BY Brand_Unmapped
" -s "," -W -h -1 > "$CATALOG/02_unmapped_brands_90d.csv"

echo ""
echo "📋 Generating final summary report..."

# Count files and sizes (include cross-tabs and catalog)
echo "📊 Scout Analytics Export Summary" > "$OUT/SUMMARY.txt"
echo "Generated: $(date)" >> "$OUT/SUMMARY.txt"
echo "" >> "$OUT/SUMMARY.txt"
echo "Analytics Files:" >> "$OUT/SUMMARY.txt"

for file in "$OUT"/*.csv; do
  if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    size=$(wc -c < "$file" | tr -d ' ')
    rows=$(($(wc -l < "$file") - 1))
    echo "  $filename: $size bytes, $rows rows" >> "$OUT/SUMMARY.txt"
  fi
done

echo "" >> "$OUT/SUMMARY.txt"
echo "Brand Catalog Files:" >> "$OUT/SUMMARY.txt"

for file in "$CATALOG"/*.csv; do
  if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    size=$(wc -c < "$file" | tr -d ' ')
    rows=$(($(wc -l < "$file") - 1))
    echo "  $filename: $size bytes, $rows rows" >> "$OUT/SUMMARY.txt"
  fi
done

echo "" >> "$OUT/SUMMARY.txt"
echo "🎉 Complete Scout Analytics Infrastructure Successfully Deployed!" >> "$OUT/SUMMARY.txt"
echo "   ✅ 7 base analytics marts" >> "$OUT/SUMMARY.txt"
echo "   ✅ 16 cross-tabulation views" >> "$OUT/SUMMARY.txt"
echo "   ✅ 3 brand catalog files for Dan/Jaymie" >> "$OUT/SUMMARY.txt"

# Display summary
cat "$OUT/SUMMARY.txt"

echo ""
echo "✅ Complete Scout Analytics Infrastructure deployment finished!"
echo "📁 Analytics results: $OUT/"
echo "📁 Brand catalog: $CATALOG/"
echo "📅 Finished: $(date)"