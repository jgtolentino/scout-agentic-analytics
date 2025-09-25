#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SQL_CONN_STR:?set AZURE_SQL_CONN_STR to your Azure SQL connection string}"

mkdir -p out/flat out/analytics out/catalog

# 1) FLAT CSV (12 cols) — from the view you deployed
sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "
SELECT
  Transaction_ID,
  Transaction_Value,
  Basket_Size,
  Category,
  Brand,
  Daypart,
  [Demographics (Age/Gender/Role)],
  Weekday_vs_Weekend,
  [Time of transaction],
  Location,
  Other_Products,
  Was_Substitution
FROM dbo.v_flat_export_sheet
ORDER BY Transaction_ID
" -s "," -W -h -1 > out/flat/flat_dataframe.csv

# 2) CROSS-TABS (absolute counts + units/sales/shares)
exportQ(){ sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "$1" -s "," -W -h -1 > "out/analytics/$2"; }
for v in \
  ct_timeXcategory ct_timeXbrand ct_timeXdemographics ct_timeXemotions \
  ct_basketsizeXcategory ct_basketsizeXpayment ct_basketsizeXcustomer ct_basketsizeXemotions \
  ct_substitutionXcategory ct_substitutionXreason ct_suggestionAcceptedXbrand \
  ct_ageXcategory ct_ageXbrand ct_ageXpacksize ct_genderXdaypart ct_paymentXdemographics \
  ct_timeXcategory_units ct_timeXbrand_units ct_basketsizeXcategory_units ct_paymentXdemographics_units \
  ct_timeXcategory_sales ct_timeXbrand_sales ct_basketsizeXcategory_sales ct_paymentXdemographics_sales \
  ct_timeXcategory_share ct_timeXbrand_share ct_timeXcategory_units_share ct_timeXcategory_sales_share
do
  exportQ "SELECT * FROM $v" "$v.csv"
done

# 3) ANALYTICS MARTS
exportQ "SELECT * FROM mart.v_store_profiles"                "mart_store_profiles.csv"
exportQ "SELECT * FROM mart.v_demo_brand_cat"                "mart_demo_brand_cat.csv"
exportQ "SELECT * FROM mart.v_time_spreads"                  "mart_time_spreads.csv"
exportQ "SELECT * FROM mart.v_tobacco_metrics"               "mart_tobacco_metrics.csv"
exportQ "SELECT TOP 200 * FROM mart.v_tobacco_copurchases"   "mart_tobacco_copurchases_top200.csv"
exportQ "SELECT * FROM mart.v_laundry_metrics"               "mart_laundry_metrics.csv"
exportQ "SELECT * FROM mart.v_transcript_terms"              "mart_transcript_terms.csv"

# 4) ~140 LIVE BRANDS (mapped AND observed) — no unmapped
sqlcmd -S "$AZURE_SQL_CONN_STR" -Q "
WITH observed AS (
  SELECT DISTINCT
    LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')) AS brand_norm
  FROM dbo.v_transactions_flat_production t
  LEFT JOIN dbo.TransactionItems ti
    ON ti.canonical_tx_id = t.canonical_tx_id
  WHERE t.txn_date >= DATEADD(day,-365,CAST(GETUTCDATE() AS date)) -- adjust window if needed
)
SELECT
  bcm.BrandName      AS Brand,
  bcm.BrandNameNorm  AS Brand_Norm,
  bcm.Department,
  bcm.NielsenCategory
FROM dbo.BrandCategoryMapping bcm
JOIN observed o
  ON o.brand_norm = bcm.BrandNameNorm
ORDER BY bcm.Department, bcm.NielsenCategory, bcm.BrandName
" -s "," -W -h -1 > out/catalog/00_brand_master_live.csv

zip -j out/flat/flat_export.zip out/flat/flat_dataframe.csv
zip -j out/analytics/analytics_exports.zip out/analytics/*.csv
zip -j out/catalog/brand_catalog_live.zip out/catalog/00_brand_master_live.csv

echo "✅ Wrote:"
echo " - out/flat/flat_dataframe.csv"
echo " - out/analytics/*.csv  (cross-tabs + marts)"
echo " - out/catalog/00_brand_master_live.csv"