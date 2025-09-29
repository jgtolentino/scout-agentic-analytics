#!/bin/bash

# Fast Inquiry Exports
# Uses simple, optimized queries for remaining exports
# Designed to avoid timeouts and complex operations

set -euo pipefail

# Parameters
DATE_FROM="2025-06-28"
DATE_TO="2025-09-26"
OUTPUT_DIR="out/inquiries_filtered"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}⚡ Fast Inquiry Export Generation${NC}"
echo -e "${BLUE}Date Range: $DATE_FROM to $DATE_TO${NC}"
echo ""

# Create missing directories
mkdir -p "$OUTPUT_DIR/laundry"

# Function to run query with header
run_fast_export() {
    local header="$1"
    local query="$2"
    local output="$3"

    echo -e "${BLUE}📊 Generating $(basename "$output")...${NC}"
    echo "$header" > "$output"
    ./scripts/sql.sh -Q "$query" >> "$output"

    local rows=$(tail -n +2 "$output" | wc -l)
    echo -e "${GREEN}✅ Generated $(basename "$output") - $rows rows${NC}"
}

# Generate remaining 5 missing laundry files with simple queries

# 1) Laundry Purchase Profile (Day-of-Month)
run_fast_export \
    "dom_bucket,transactions,share_pct" \
    "SELECT CASE
               WHEN DATEPART(DAY, transaction_date) BETWEEN 1 AND 7 THEN '01-07'
               WHEN DATEPART(DAY, transaction_date) BETWEEN 8 AND 15 THEN '08-15'
               WHEN DATEPART(DAY, transaction_date) BETWEEN 16 AND 22 THEN '16-22'
               ELSE '23-30' END AS dom_bucket,
           COUNT(*) AS transactions,
           CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER() AS decimal(5,2)) AS share_pct
    FROM gold.v_export_projection
    WHERE transaction_date BETWEEN '$DATE_FROM' AND '$DATE_TO'
        AND category = 'Laundry'
    GROUP BY CASE WHEN DATEPART(DAY, transaction_date) BETWEEN 1 AND 7 THEN '01-07'
                  WHEN DATEPART(DAY, transaction_date) BETWEEN 8 AND 15 THEN '08-15'
                  WHEN DATEPART(DAY, transaction_date) BETWEEN 16 AND 22 THEN '16-22'
                  ELSE '23-30' END
    ORDER BY CASE dom_bucket WHEN '01-07' THEN 1 WHEN '08-15' THEN 2 WHEN '16-22' THEN 3 ELSE 4 END" \
    "$OUTPUT_DIR/laundry/purchase_profile_pdp.csv"

# 2) Laundry Sales by Day and Daypart
run_fast_export \
    "date,daypart,transactions,share_pct" \
    "SELECT CAST(transaction_date AS date) AS date,
           daypart,
           COUNT(*) AS transactions,
           CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER(PARTITION BY CAST(transaction_date AS date)) AS decimal(5,2)) AS share_pct
    FROM gold.v_export_projection
    WHERE transaction_date BETWEEN '$DATE_FROM' AND '$DATE_TO'
        AND category = 'Laundry'
    GROUP BY CAST(transaction_date AS date), daypart
    ORDER BY date, transactions DESC" \
    "$OUTPUT_DIR/laundry/sales_by_day_daypart.csv"

# 3) Laundry Co-purchase Categories (simplified)
run_fast_export \
    "category,transactions,share_pct" \
    "WITH laundry_txns AS (
        SELECT DISTINCT transaction_id
        FROM gold.v_export_projection
        WHERE transaction_date BETWEEN '$DATE_FROM' AND '$DATE_TO'
            AND category = 'Laundry'
    )
    SELECT p.category,
           COUNT(*) AS transactions,
           CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER() AS decimal(5,2)) AS share_pct
    FROM laundry_txns lt
    JOIN gold.v_export_projection p ON p.transaction_id = lt.transaction_id
    WHERE p.category != 'Laundry'
        AND p.transaction_date BETWEEN '$DATE_FROM' AND '$DATE_TO'
    GROUP BY p.category
    ORDER BY transactions DESC" \
    "$OUTPUT_DIR/laundry/copurchase_categories.csv"

# 4) Laundry Frequent Terms (simplified - top brands only)
run_fast_export \
    "term,frequency,category_context" \
    "WITH brand_terms AS (
        SELECT brand AS term, 'Laundry' AS category
        FROM gold.v_export_projection
        WHERE transaction_date BETWEEN '$DATE_FROM' AND '$DATE_TO'
            AND category = 'Laundry'
            AND brand IS NOT NULL AND brand != ''
    )
    SELECT term,
           COUNT(*) AS frequency,
           category AS category_context
    FROM brand_terms
    GROUP BY term, category
    HAVING COUNT(*) >= 3
    ORDER BY frequency DESC" \
    "$OUTPUT_DIR/laundry/frequent_terms.csv"

echo ""
echo -e "${GREEN}🎉 Fast export generation completed!${NC}"

# Show summary
TOTAL_FILES=$(find "$OUTPUT_DIR" -name "*.csv" | wc -l)
echo -e "${BLUE}📊 Total files now: $TOTAL_FILES${NC}"

# Validate the results
echo -e "${YELLOW}🔍 Running validation...${NC}"
python3 scripts/validate_inquiry_exports.py