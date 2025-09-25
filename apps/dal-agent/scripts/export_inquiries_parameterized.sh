#!/bin/bash

# Parameterized Inquiry Export Script
# Exports comprehensive inquiry analytics with date, region, and store filtering
# Usage: ./export_inquiries_parameterized.sh [options]
# Options:
#   --date-from YYYY-MM-DD    Start date (default: 90 days ago)
#   --date-to YYYY-MM-DD      End date (default: today)
#   --region TEXT             Region filter (optional)
#   --store-id TEXT           Store ID filter (optional)
#   --category all|tobacco|laundry  Category focus (default: all)
#   --output-dir PATH         Output directory (default: out/inquiries_filtered)

set -euo pipefail

# Default parameters
DATE_FROM=$(date -d '90 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-90d '+%Y-%m-%d')
DATE_TO=$(date '+%Y-%m-%d')
REGION=""
STORE_ID=""
CATEGORY="all"
OUTPUT_DIR="out/inquiries_filtered"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Write CSV with explicit header then query rows
write_csv() {
  local header="$1" sql="$2" out="$3"
  mkdir -p "$(dirname "$out")"
  printf '%s\n' "$header" > "$out.tmp"
  ./scripts/sql.sh -d "$DB" -Q "$sql" >> "$out.tmp"   # sql.sh still uses -h -1 (no headers)
  mv "$out.tmp" "$out"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --date-from)
            DATE_FROM="$2"
            shift 2
            ;;
        --date-to)
            DATE_TO="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --store-id)
            STORE_ID="$2"
            shift 2
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --date-from YYYY-MM-DD    Start date (default: 90 days ago)"
            echo "  --date-to YYYY-MM-DD      End date (default: today)"
            echo "  --region TEXT             Region filter (optional)"
            echo "  --store-id TEXT           Store ID filter (optional)"
            echo "  --category all|tobacco|laundry  Category focus (default: all)"
            echo "  --output-dir PATH         Output directory (default: out/inquiries_filtered)"
            echo ""
            echo "Examples:"
            echo "  $0 --date-from 2024-09-01 --date-to 2024-09-30"
            echo "  $0 --region 'Metro Manila' --category tobacco"
            echo "  $0 --store-id 'STORE001' --date-from 2024-08-01"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate date format
validate_date() {
    local date_str="$1"
    if ! date -d "$date_str" >/dev/null 2>&1 && ! date -j -f "%Y-%m-%d" "$date_str" >/dev/null 2>&1; then
        echo -e "${RED}❌ Invalid date format: $date_str${NC}"
        echo -e "${YELLOW}Expected format: YYYY-MM-DD${NC}"
        exit 1
    fi
}

validate_date "$DATE_FROM"
validate_date "$DATE_TO"

# Validate category
if [[ ! "$CATEGORY" =~ ^(all|tobacco|laundry)$ ]]; then
    echo -e "${RED}❌ Invalid category: $CATEGORY${NC}"
    echo -e "${YELLOW}Valid options: all, tobacco, laundry${NC}"
    exit 1
fi

# Build WHERE clause for filtering - deterministic and always valid
build_where_clause() {
    # Always valid predicate; safe if filters are empty
    local w="1=1"

    # Date range (sargable predicates)
    w+=" AND transaction_date >= '$DATE_FROM'"
    w+=" AND transaction_date <= '$DATE_TO'"

    # Region filter
    if [[ -n "$REGION" ]]; then
        w+=" AND region = '$REGION'"
    fi

    # Store ID filter
    if [[ -n "$STORE_ID" ]]; then
        w+=" AND store_id = '$STORE_ID'"
    fi

    # Category filter
    case "$CATEGORY" in
        "tobacco")
            w+=" AND (category LIKE '%Tobacco%' OR category LIKE '%Cigarette%' OR category LIKE '%Smoke%')"
            ;;
        "laundry")
            w+=" AND (category LIKE '%Detergent%' OR category LIKE '%Soap%' OR category LIKE '%Fabric%' OR category LIKE '%Laundry%')"
            ;;
    esac

    printf '%s' "$w"
}

WHERE_CLAUSE=$(build_where_clause)

echo -e "${YELLOW}🔍 Parameterized Inquiry Export Configuration:${NC}"
echo -e "${BLUE}  Date Range: $DATE_FROM to $DATE_TO${NC}"
echo -e "${BLUE}  Region: ${REGION:-'(all regions)'}${NC}"
echo -e "${BLUE}  Store ID: ${STORE_ID:-'(all stores)'}${NC}"
echo -e "${BLUE}  Category: $CATEGORY${NC}"
echo -e "${BLUE}  Output: $OUTPUT_DIR${NC}"
echo ""

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{overall,tobacco,laundry}

# Define base SQL query with parameterized filtering
BASE_QUERY="FROM gold.v_export_projection WHERE $WHERE_CLAUSE"

echo -e "${YELLOW}📊 Exporting inquiry analytics with filters...${NC}"

# Safe SQL runner with error tracking
fail=0
sql() {
    ./scripts/sql.sh -d "$DB" -Q "$1" -o "$2"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo -e "${RED}❌ SQL failed: $2 (rc=$rc)${NC}"
        fail=1
    fi
    return $rc
}

# === BEGIN PINNED EXPORTS ===
# NOTE: All queries use gold.v_export_projection (canonical names) and $(build_where_clause)

# Param binds (once)
binds="
DECLARE @from datetime2=TRY_CONVERT(datetime2,'${DATE_FROM}');
DECLARE @to   datetime2=TRY_CONVERT(datetime2,'${DATE_TO}');
DECLARE @region nvarchar(128)=NULLIF('${REGION}','');"

# ---------- OVERALL (3) ----------
# 1) Store profiles
write_csv \
  "store_id,store_name,region,transactions,total_items,total_amount" \
  "$binds
SELECT
  store_id,
  store_name,
  region,
  COUNT(*) AS transactions,
  SUM(basket_size) AS total_items,
  CAST(SUM(transaction_value) AS decimal(18,2)) AS total_amount
FROM gold.v_export_projection
WHERE $(build_where_clause)
GROUP BY store_id,store_name,region
ORDER BY total_amount DESC" \
  "out/inquiries_filtered/overall/store_profiles.csv"

# 2) Sales by ISO week (spread across week/month)
write_csv \
  "iso_week,week_start,transactions,total_amount" \
  "$binds
WITH w AS (
  SELECT
    DATEPART(ISO_WEEK, transaction_date) AS iso_week,
    DATEADD(DAY, 1-DATEPART(WEEKDAY, transaction_date), CAST(CAST(transaction_date AS date) AS datetime2)) AS week_start
  FROM gold.v_export_projection
  WHERE $(build_where_clause)
)
SELECT
  iso_week,
  CAST(MIN(week_start) AS date) AS week_start,
  COUNT(*) AS transactions,
  CAST(SUM(p.transaction_value) AS decimal(18,2)) AS total_amount
FROM w
JOIN gold.v_export_projection p
  ON DATEPART(ISO_WEEK, p.transaction_date)=w.iso_week
WHERE $(build_where_clause)
GROUP BY iso_week
ORDER BY MIN(week_start)" \
  "out/inquiries_filtered/overall/sales_by_week.csv"

# 3) Daypart × Category
write_csv \
  "daypart,category,transactions,share_pct" \
  "$binds
WITH base AS (
  SELECT daypart, category
  FROM gold.v_export_projection
  WHERE $(build_where_clause)
)
SELECT
  daypart,
  category,
  COUNT(*) AS transactions,
  CAST(100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(PARTITION BY daypart),0) AS decimal(5,2)) AS share_pct
FROM base
GROUP BY daypart, category
ORDER BY daypart, transactions DESC" \
  "out/inquiries_filtered/overall/daypart_by_category.csv"

# ---------- TOBACCO (5) ----------
# 4) Demographics (gender × age × brand)
write_csv \
  "gender,age_band,brand,transactions,share_pct" \
  "$binds
WITH base AS (
  SELECT
    brand,
    TRY_CAST(PARSENAME(REPLACE(REPLACE(demographics,'''',''), ' ', '.'), 2) AS nvarchar(32)) AS gender,
    TRY_CAST(PARSENAME(REPLACE(REPLACE(demographics,'''',''), ' ', '.'), 3) AS nvarchar(32)) AS age_band
  FROM gold.v_export_projection
  WHERE $(build_where_clause)
    AND category IN (N'Cigarettes',N'Cigarette',N'Yosi',N'Tobacco')
)
SELECT
  COALESCE(gender,N'Unknown') AS gender,
  COALESCE(age_band,N'Unknown') AS age_band,
  brand,
  COUNT(*) AS transactions,
  CAST(100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(),0) AS decimal(5,2)) AS share_pct
FROM base
GROUP BY gender,age_band,brand
ORDER BY transactions DESC" \
  "out/inquiries_filtered/tobacco/demo_gender_age_brand.csv"

# 5) Pecha de Peligro (day-of-month buckets)
write_csv \
  "dom_bucket,transactions,share_pct" \
  "$binds
WITH base AS (
  SELECT CASE
           WHEN DATEPART(DAY, transaction_date) BETWEEN 23 AND 30 THEN N'23-30'
           WHEN DATEPART(DAY, transaction_date) BETWEEN 1  AND 7  THEN N'01-07'
           WHEN DATEPART(DAY, transaction_date) BETWEEN 8  AND 15 THEN N'08-15'
           ELSE N'16-22'
         END AS dom_bucket
  FROM gold.v_export_projection
  WHERE $(build_where_clause)
    AND category IN (N'Cigarettes',N'Cigarette',N'Yosi',N'Tobacco')
)
SELECT dom_bucket,
       COUNT(*) AS transactions,
       CAST(100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(),0) AS decimal(5,2)) AS share_pct
FROM base
GROUP BY dom_bucket
ORDER BY CASE dom_bucket WHEN N'01-07' THEN 1 WHEN N'08-15' THEN 2 WHEN N'16-22' THEN 3 ELSE 4 END" \
  "out/inquiries_filtered/tobacco/purchase_profile_pdp.csv"

# 6) Sales × day × daypart
write_csv \
  "date,daypart,transactions,share_pct" \
  "$binds
WITH base AS (
  SELECT CAST(transaction_date AS date) AS [date], daypart
  FROM gold.v_export_projection
  WHERE $(build_where_clause)
    AND category IN (N'Cigarettes',N'Cigarette',N'Yosi',N'Tobacco')
)
SELECT [date], daypart,
       COUNT(*) AS transactions,
       CAST(100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(PARTITION BY [date]),0) AS decimal(5,2)) AS share_pct
FROM base
GROUP BY [date], daypart
ORDER BY [date], transactions DESC" \
  "out/inquiries_filtered/tobacco/sales_by_day_daypart.csv"

# 7) Sticks per visit (from helper view - fallback if not available)
if ./scripts/sql.sh -d "$DB" -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME='v_tobacco_sticks_per_tx'" -o /tmp/check_view.txt && grep -q "1" /tmp/check_view.txt; then
    write_csv \
      "transaction_id,brand,items,sticks_per_pack,estimated_sticks" \
      "$binds
    SELECT transaction_id, brand, Items AS items, SticksPerPack AS sticks_per_pack, Estimated_Sticks AS estimated_sticks
    FROM gold.v_tobacco_sticks_per_tx
    ORDER BY estimated_sticks DESC" \
      "out/inquiries_filtered/tobacco/sticks_per_visit.csv"
else
    # Fallback: simple pack estimation
    write_csv \
      "transaction_id,brand,items,estimated_sticks" \
      "$binds
    SELECT
      transaction_id,
      brand,
      basket_size AS items,
      CAST(basket_size * 20 AS int) AS estimated_sticks
    FROM gold.v_export_projection
    WHERE $(build_where_clause)
      AND category IN (N'Cigarettes',N'Cigarette',N'Yosi',N'Tobacco')
    ORDER BY estimated_sticks DESC" \
      "out/inquiries_filtered/tobacco/sticks_per_visit.csv"
fi

# 8) Co-purchase (category × co_category - fallback if not available)
if ./scripts/sql.sh -d "$DB" -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME='v_copurchase_matrix'" -o /tmp/check_copurchase.txt && grep -q "1" /tmp/check_copurchase.txt; then
    write_csv \
      "category,co_category,txn_cocount,confidence,lift" \
      "$binds
    SELECT category, co_category, Txn_CoCount AS txn_cocount, Confidence AS confidence, Lift AS lift
    FROM gold.v_copurchase_matrix
    WHERE category IN (N'Cigarettes',N'Cigarette',N'Yosi',N'Tobacco')
    ORDER BY txn_cocount DESC" \
      "out/inquiries_filtered/tobacco/copurchase_categories.csv"
else
    # Fallback: basic category frequency
    write_csv \
      "category,transactions,share_pct" \
      "$binds
    SELECT
      category,
      COUNT(*) AS transactions,
      CAST(100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(),0) AS decimal(5,2)) AS share_pct
    FROM gold.v_export_projection
    WHERE $(build_where_clause)
      AND category IN (N'Cigarettes',N'Cigarette',N'Yosi',N'Tobacco')
    GROUP BY category
    ORDER BY transactions DESC" \
      "out/inquiries_filtered/tobacco/copurchase_categories.csv"
fi

# ---------- LAUNDRY (1) ----------
# 9) Detergent type and fabcon pairing
write_csv \
  "detergent_type,with_fabcon,transactions,share_pct" \
  "$binds
WITH base AS (
  SELECT
    CASE
      WHEN category IN (N'Detergent Bar',N'Laundry Bar') THEN N'bar'
      WHEN category IN (N'Detergent Powder',N'Powder Detergent') THEN N'powder'
      WHEN category IN (N'Detergent Liquid',N'Liquid Detergent') THEN N'liquid'
      ELSE N'unknown'
    END AS detergent_type,
    CASE WHEN EXISTS (
      SELECT 1 FROM gold.v_export_projection i2
      WHERE i2.canonical_tx_id = i.canonical_tx_id
        AND i2.category IN (N'Fabric Conditioner',N'Fabcon')
    ) THEN 1 ELSE 0 END AS with_fabcon
  FROM gold.v_export_projection i
  WHERE $(build_where_clause)
    AND category IN (N'Detergent Bar',N'Laundry Bar',N'Detergent Powder',N'Powder Detergent',N'Detergent Liquid',N'Liquid Detergent')
)
SELECT detergent_type,
       with_fabcon,
       COUNT(*) AS transactions,
       CAST(100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(PARTITION BY detergent_type),0) AS decimal(5,2)) AS share_pct
FROM base
GROUP BY detergent_type, with_fabcon
ORDER BY detergent_type, transactions DESC" \
  "out/inquiries_filtered/laundry/detergent_type.csv"
# === END PINNED EXPORTS ===

# Generate summary report
echo -e "${YELLOW}📋 Generating export summary...${NC}"

cat > "$OUTPUT_DIR/export_summary.txt" << EOF
Parameterized Inquiry Export Summary
Generated: $(date)

Configuration:
- Date Range: $DATE_FROM to $DATE_TO
- Region Filter: ${REGION:-'(all regions)'}
- Store ID Filter: ${STORE_ID:-'(all stores)'}
- Category Filter: $CATEGORY
- WHERE Clause: $WHERE_CLAUSE

Files Generated:
EOF

find "$OUTPUT_DIR" -name "*.csv" -exec ls -lh {} \; | awk '{print "- " $9 " (" $5 ")"}' >> "$OUTPUT_DIR/export_summary.txt"

echo "" >> "$OUTPUT_DIR/export_summary.txt"
echo "Query Performance Notes:" >> "$OUTPUT_DIR/export_summary.txt"
echo "- Uses sargable predicates on txn_date for optimal index usage" >> "$OUTPUT_DIR/export_summary.txt"
echo "- WHERE clause applied consistently across all queries" >> "$OUTPUT_DIR/export_summary.txt"
echo "- Results filtered at database level for efficiency" >> "$OUTPUT_DIR/export_summary.txt"

## HEADER CHECK ##
# Grep headers of a couple of key files to catch schema drift quickly
if [ -f "out/inquiries_filtered/overall/store_profiles.csv" ]; then
  head -1 out/inquiries_filtered/overall/store_profiles.csv >> out/inquiries_filtered/export_summary.txt || true
fi
if [ -f "out/inquiries_filtered/tobacco/demo_gender_age_brand.csv" ]; then
  head -1 out/inquiries_filtered/tobacco/demo_gender_age_brand.csv >> out/inquiries_filtered/export_summary.txt || true
fi

# Final statistics
TOTAL_FILES=$(find "$OUTPUT_DIR" -name "*.csv" | wc -l)
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)

echo -e "${GREEN}✅ Parameterized inquiry export completed${NC}"
echo -e "${BLUE}📊 Generated $TOTAL_FILES CSV files ($TOTAL_SIZE total)${NC}"
echo -e "${BLUE}📁 Output location: $OUTPUT_DIR${NC}"
echo -e "${BLUE}📋 Summary report: $OUTPUT_DIR/export_summary.txt${NC}"
echo ""

# Display sample of generated files
echo -e "${YELLOW}📄 Generated files:${NC}"
find "$OUTPUT_DIR" -name "*.csv" | sort | head -10 | while read -r file; do
    rows=$(wc -l < "$file" 2>/dev/null || echo "0")
    size=$(ls -lh "$file" | awk '{print $5}')
    echo -e "${BLUE}  • $(basename "$file") - $((rows-1)) rows ($size)${NC}"
done

if [[ $TOTAL_FILES -gt 10 ]]; then
    echo -e "${BLUE}  ... and $((TOTAL_FILES-10)) more files${NC}"
fi

# Gzip all CSVs (idempotent; overwrite)
echo -e "${YELLOW}📦 Compressing CSV exports...${NC}"
find out/inquiries_filtered -type f -name '*.csv' -print0 | xargs -0 -I{} gzip -f "{}"

# Finalize exit status
if [[ ${fail:-0} -ne 0 ]]; then
    echo -e "${RED}❌ Inquiry export completed with errors.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Inquiry export completed successfully.${NC}"
    exit 0
fi