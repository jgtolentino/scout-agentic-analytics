#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SQL="$ROOT/scripts/sql.sh"
TPL_CSV="$ROOT/data/brand-map-live.csv"
REF_CSV="$ROOT/data/brand-map-reference.csv"

echo "🏭 Generating canonical 113-brand mapping templates..."

# Header
echo 'BrandName,CategoryCode,DepartmentCode' > "$TPL_CSV"
echo 'BrandName,CategoryCode,DepartmentCode,ObservedTx' > "$REF_CSV"

# Template (3 columns) — **restricted to canonical 113** from BrandCategoryMapping
$SQL -Q "SET NOCOUNT ON;
WITH canon AS (
  SELECT BrandNameNorm, BrandName = MAX(BrandName)
  FROM dbo.BrandCategoryMapping
  WHERE BrandNameNorm IS NOT NULL
  GROUP BY BrandNameNorm
),
obs AS (
  SELECT
    BrandNameNorm = LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')),
    ObservedTx    = COUNT_BIG(*)
  FROM dbo.TransactionItems ti
  WHERE ti.brand_name IS NOT NULL AND LTRIM(RTRIM(ti.brand_name)) <> ''
  GROUP BY LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-',''))
),
joined AS (
  SELECT
    c.BrandName,
    c.BrandNameNorm,
    o.ObservedTx,
    bcm.CategoryCode,
    COALESCE(bcm.DepartmentCode, nc.department_code) AS DepartmentCode
  FROM canon c
  LEFT JOIN obs o
         ON o.BrandNameNorm = c.BrandNameNorm
  LEFT JOIN dbo.BrandCategoryMapping bcm
         ON bcm.BrandNameNorm = c.BrandNameNorm
  LEFT JOIN ref.NielsenCategories nc
         ON nc.category_code = bcm.CategoryCode AND nc.is_active = 1
)
SELECT
  j.BrandName,
  ISNULL(j.CategoryCode, '')      AS CategoryCode,
  ISNULL(j.DepartmentCode, '')    AS DepartmentCode
FROM joined j
ORDER BY j.BrandName;" -s "," -W -h -1 >> "$TPL_CSV"

# Reference with counts (4 columns) — same 113 set, with ObservedTx
$SQL -Q "SET NOCOUNT ON;
WITH canon AS (
  SELECT BrandNameNorm, BrandName = MAX(BrandName)
  FROM dbo.BrandCategoryMapping
  WHERE BrandNameNorm IS NOT NULL
  GROUP BY BrandNameNorm
),
obs AS (
  SELECT
    BrandNameNorm = LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')),
    ObservedTx    = COUNT_BIG(*)
  FROM dbo.TransactionItems ti
  WHERE ti.brand_name IS NOT NULL AND LTRIM(RTRIM(ti.brand_name)) <> ''
  GROUP BY LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-',''))
),
joined AS (
  SELECT
    c.BrandName,
    c.BrandNameNorm,
    o.ObservedTx,
    bcm.CategoryCode,
    COALESCE(bcm.DepartmentCode, nc.department_code) AS DepartmentCode
  FROM canon c
  LEFT JOIN obs o
         ON o.BrandNameNorm = c.BrandNameNorm
  LEFT JOIN dbo.BrandCategoryMapping bcm
         ON bcm.BrandNameNorm = c.BrandNameNorm
  LEFT JOIN ref.NielsenCategories nc
         ON nc.category_code = bcm.CategoryCode AND nc.is_active = 1
)
SELECT
  j.BrandName,
  ISNULL(j.CategoryCode, '')      AS CategoryCode,
  ISNULL(j.DepartmentCode, '')    AS DepartmentCode,
  CAST(ISNULL(j.ObservedTx,0) AS bigint) AS ObservedTx
FROM joined j
ORDER BY j.BrandName;" -s "," -W -h -1 >> "$REF_CSV"

# Validate exactly 113 rows
ROWS=$(($(wc -l < "$TPL_CSV") - 1))
if [ "$ROWS" -ne 113 ]; then
  echo "❌ brand-map-live.csv has $ROWS rows; expected 113." >&2
  echo "Hint: Count of canonical brands is:"
  $SQL -Q "SET NOCOUNT ON; SELECT COUNT(DISTINCT BrandNameNorm) AS CanonicalBrands FROM dbo.BrandCategoryMapping;"
  exit 2
fi

echo "✅ Generated:"
echo "  - $TPL_CSV (113 rows)"
echo "  - $REF_CSV (113 rows + counts)"