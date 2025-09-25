#!/usr/bin/env bash
set -euo pipefail

# Excel Pivot Data Exporter
# Exports Nielsen-backed gold views to CSV files for Excel pivot table integration

# Default values
DB="${DB:-SQL-TBWA-ProjectScout-Reporting-Prod}"
OUT="${OUT:-out/pivots}"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 Exporting Pivot Data from Nielsen-Backed Views${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""
echo -e "${YELLOW}Source Database: ${DB}${NC}"
echo -e "${YELLOW}Output Directory: ${OUT}${NC}"
echo ""

# Create output directory
mkdir -p "$OUT"

# Check if sql.sh script exists
if [ ! -f "./scripts/sql.sh" ]; then
    echo -e "${RED}❌ Error: scripts/sql.sh not found${NC}"
    echo -e "${YELLOW}Ensure you're running from dal-agent directory${NC}"
    exit 1
fi

echo -e "${YELLOW}🔍 Testing database connection...${NC}"
if ! ./scripts/sql.sh -Q "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}❌ Database connection failed${NC}"
    echo -e "${YELLOW}Check credentials in keychain or AZURE_SQL_CONN_STR environment variable${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Database connection verified${NC}"
echo ""

# Export main pivot data (Excel "scout_default_view" sheet)
echo -e "${YELLOW}📄 Exporting main pivot data (scout_default_view.csv)...${NC}"
./scripts/sql.sh -Q "
SELECT
    transaction_id,
    storeid,
    category,
    brand,
    product,
    payment_method,
    qty,
    unit_price,
    total_price,
    brand_raw,
    transaction_date,
    nielsen_level,
    nielsen_code
FROM gold.v_pivot_default
ORDER BY transaction_id, storeid
" -s "," -W -h -1 > "$OUT/scout_default_view.csv"

if [ $? -eq 0 ]; then
    ROWS=$(wc -l < "$OUT/scout_default_view.csv" || echo "0")
    echo -e "${GREEN}✅ Main pivot data exported: $ROWS rows${NC}"
else
    echo -e "${RED}❌ Failed to export main pivot data${NC}"
fi

# Export category lookup reference
echo -e "${YELLOW}📋 Exporting category lookup reference...${NC}"
./scripts/sql.sh -Q "
SELECT
    [Correct Category],
    [Category Code],
    [Level],
    [Example SKU],
    [Example Brand],
    [Department],
    [Product Group],
    [Mapped Products],
    [Department Code],
    [Group Code]
FROM gold.v_category_lookup_reference
ORDER BY [Department], [Product Group], [Correct Category]
" -s "," -W -h -1 > "$OUT/category_lookup_reference.csv"

if [ $? -eq 0 ]; then
    CATEGORIES=$(wc -l < "$OUT/category_lookup_reference.csv" || echo "0")
    echo -e "${GREEN}✅ Category lookup exported: $CATEGORIES categories${NC}"
else
    echo -e "${RED}❌ Failed to export category lookup${NC}"
fi

# Export category and brand aggregations
echo -e "${YELLOW}📊 Exporting category/brand aggregations...${NC}"
./scripts/sql.sh -Q "
SELECT
    category,
    brand,
    line_count,
    transaction_count,
    total_qty,
    total_sales,
    avg_line_amount,
    avg_unit_price
FROM gold.v_pivot_category_brand
ORDER BY total_sales DESC, category, brand
" -s "," -W -h -1 > "$OUT/category_brand.csv"

if [ $? -eq 0 ]; then
    COMBOS=$(wc -l < "$OUT/category_brand.csv" || echo "0")
    echo -e "${GREEN}✅ Category/brand data exported: $COMBOS combinations${NC}"
else
    echo -e "${RED}❌ Failed to export category/brand data${NC}"
fi

# Export tobacco analysis
echo -e "${YELLOW}🚬 Exporting tobacco category analysis...${NC}"
./scripts/sql.sh -Q "
SELECT
    weekday,
    tobacco_category,
    transactions,
    unique_transactions,
    total_qty,
    avg_qty,
    total_sales,
    avg_total_price,
    avg_unit_price,
    hour_of_day,
    transaction_date
FROM gold.v_pivot_tobacco
ORDER BY transaction_date DESC, hour_of_day, weekday
" -s "," -W -h -1 > "$OUT/tobacco.csv"

if [ $? -eq 0 ]; then
    TOBACCO_ROWS=$(wc -l < "$OUT/tobacco.csv" || echo "0")
    echo -e "${GREEN}✅ Tobacco analysis exported: $TOBACCO_ROWS rows${NC}"
else
    echo -e "${RED}❌ Failed to export tobacco analysis${NC}"
fi

# Export laundry analysis
echo -e "${YELLOW}🧺 Exporting laundry category analysis...${NC}"
./scripts/sql.sh -Q "
SELECT
    [Correct Category],
    [Laundry],
    [Total Qty],
    [Avg Qty],
    [Total Sales],
    [Avg Total Price],
    [Line Items],
    [Laundry Category],
    [Date]
FROM gold.v_pivot_laundry
ORDER BY [Date] DESC, [Correct Category]
" -s "," -W -h -1 > "$OUT/laundry.csv"

if [ $? -eq 0 ]; then
    LAUNDRY_ROWS=$(wc -l < "$OUT/laundry.csv" || echo "0")
    echo -e "${GREEN}✅ Laundry analysis exported: $LAUNDRY_ROWS rows${NC}"
else
    echo -e "${RED}❌ Failed to export laundry analysis${NC}"
fi

# Export Nielsen coverage summary
echo -e "${YELLOW}📈 Exporting Nielsen coverage summary...${NC}"
./scripts/sql.sh -Q "
SELECT
    report_type,
    departments,
    product_groups,
    categories,
    total_products,
    mapped_products,
    product_coverage_pct,
    total_transaction_items,
    mapped_transaction_items,
    transaction_coverage_pct,
    mapped_brands,
    nielsen_1100_brands
FROM gold.v_nielsen_coverage_summary
" -s "," -W -h -1 > "$OUT/nielsen_coverage_summary.csv"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Coverage summary exported${NC}"
else
    echo -e "${RED}❌ Failed to export coverage summary${NC}"
fi

echo ""
echo -e "${BLUE}📁 Generated Files Summary:${NC}"
ls -la "$OUT"/*.csv | awk -v green="$GREEN" -v nc="$NC" '{printf "  %s%s%s (%s bytes)\n", green, $9, nc, $5}'

echo ""
echo -e "${BLUE}🔗 Excel Integration Instructions:${NC}"
echo -e "${YELLOW}1. Open your Excel workbook with pivot tables${NC}"
echo -e "${YELLOW}2. Update data sources for each sheet:${NC}"
echo -e "   • 'Sheet 1 - scout_default_view' → $OUT/scout_default_view.csv"
echo -e "   • 'Category Lookup Reference' → $OUT/category_lookup_reference.csv"
echo -e "   • 'Category and Brand' → $OUT/category_brand.csv"
echo -e "   • 'Tobacco' → $OUT/tobacco.csv"
echo -e "   • 'Laundry' → $OUT/laundry.csv"
echo -e "${YELLOW}3. Refresh all pivot tables to see Nielsen categories${NC}"

echo ""
echo -e "${GREEN}🎉 Pivot data export completed successfully!${NC}"
echo -e "${GREEN}Excel pivot tables now have access to proper Nielsen taxonomy categories${NC}"