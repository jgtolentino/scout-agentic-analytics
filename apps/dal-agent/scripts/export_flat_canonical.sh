#!/usr/bin/env bash
# =====================================================
# Canonical Flat Export Script - CI Ready
# =====================================================
# File: scripts/export_flat_canonical.sh
# Purpose: Complete export workflow with QA validation
# Usage: ./scripts/export_flat_canonical.sh [DATE_FROM] [DATE_TO]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUT_DIR="${PROJECT_ROOT}/out"
SQL_DIR="${PROJECT_ROOT}/sql"

# Default date range (last 30 days)
DATE_FROM="${1:-$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)}"
DATE_TO="${2:-$(date +%Y-%m-%d)}"

# Output file with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUT_DIR}/flat_enriched_canonical_${TIMESTAMP}.csv"
VALIDATION_LOG="${OUT_DIR}/validation_${TIMESTAMP}.log"

echo "=== Scout v7 Canonical Flat Export ==="
echo "Date Range: $DATE_FROM to $DATE_TO"
echo "Output: $OUTPUT_FILE"
echo "Validation Log: $VALIDATION_LOG"
echo

# Create output directory
mkdir -p "$OUT_DIR"

# Step 1: Deploy stored procedure if needed
echo "📦 Deploying stored procedure..."
if ! ./scripts/sql.sh -i "$SQL_DIR/procs/canonical.sp_export_flat.sql"; then
    echo "❌ Failed to deploy stored procedure"
    exit 1
fi
echo "✅ Stored procedure deployed"

# Step 2: Run export
echo "📊 Running canonical flat export..."
if ! ./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='$DATE_FROM', @DateTo='$DATE_TO'" > "$OUTPUT_FILE"; then
    echo "❌ Export failed"
    exit 1
fi

# Check if export produced data
if [[ ! -s "$OUTPUT_FILE" ]]; then
    echo "❌ Export produced empty file"
    exit 1
fi

EXPORT_ROWS=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
echo "✅ Export completed: $EXPORT_ROWS rows"

# Step 3: Run QA validation
echo "🔍 Running data quality validation..."
if ! ./scripts/sql.sh -Q "
DECLARE @DateFrom DATE = '$DATE_FROM';
DECLARE @DateTo DATE = '$DATE_TO';

-- Quick validation queries
SELECT 'ROW_COUNT' as metric, COUNT(*) as value
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo

UNION ALL

SELECT 'UNIQUE_TRANSACTIONS', COUNT(DISTINCT f.CanonicalTxID)
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo

UNION ALL

SELECT 'TOTAL_AMOUNT', CAST(SUM(f.TransactionValue) AS INT)
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo

UNION ALL

SELECT 'DUPLICATE_COUNT', COUNT(*) - COUNT(DISTINCT f.CanonicalTxID)
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo

UNION ALL

SELECT 'NEGATIVE_AMOUNTS', COUNT(CASE WHEN f.TransactionValue <= 0 THEN 1 END)
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;
" > "$VALIDATION_LOG"; then
    echo "❌ QA validation failed"
    exit 1
fi

# Parse validation results
DUPLICATE_COUNT=$(grep "DUPLICATE_COUNT" "$VALIDATION_LOG" | awk '{print $2}' || echo "0")
NEGATIVE_AMOUNTS=$(grep "NEGATIVE_AMOUNTS" "$VALIDATION_LOG" | awk '{print $2}' || echo "0")

echo "📋 Validation Results:"
cat "$VALIDATION_LOG"

# Check for critical errors
if [[ "$DUPLICATE_COUNT" -gt 0 ]]; then
    echo "❌ CRITICAL: Duplicate transactions detected ($DUPLICATE_COUNT)"
    exit 1
fi

if [[ "$NEGATIVE_AMOUNTS" -gt 0 ]]; then
    echo "❌ CRITICAL: Negative amounts detected ($NEGATIVE_AMOUNTS)"
    exit 1
fi

echo "✅ QA validation passed"

# Step 4: Generate export summary
UNIQUE_TRANSACTIONS=$(grep "UNIQUE_TRANSACTIONS" "$VALIDATION_LOG" | awk '{print $2}' || echo "0")
TOTAL_AMOUNT=$(grep "TOTAL_AMOUNT" "$VALIDATION_LOG" | awk '{print $2}' || echo "0")

echo
echo "=== Export Summary ==="
echo "📅 Date Range: $DATE_FROM to $DATE_TO"
echo "📊 Total Rows: $EXPORT_ROWS"
echo "🔢 Unique Transactions: $UNIQUE_TRANSACTIONS"
echo "💰 Total Amount: \$$(printf "%'d" "$TOTAL_AMOUNT")"
echo "📁 Output File: $OUTPUT_FILE"
echo "📝 Validation Log: $VALIDATION_LOG"
echo "⏰ Export Time: $(date)"

# Step 5: Optional - Create crosstab export
if [[ "${EXPORT_CROSSTAB:-}" == "1" ]]; then
    echo
    echo "📊 Creating crosstab export..."
    CROSSTAB_FILE="${OUT_DIR}/crosstab_daypart_brand_${TIMESTAMP}.csv"

    ./scripts/sql.sh -Q "
    DECLARE @DateFrom DATE = '$DATE_FROM';
    DECLARE @DateTo DATE = '$DATE_TO';

    SELECT
        'daypart' as daypart,
        'brand' as brand,
        'txn_count' as txn_count,
        'revenue' as revenue

    UNION ALL

    SELECT
        CASE
            WHEN dt.Hour24 BETWEEN 6 AND 11 THEN 'Morning'
            WHEN dt.Hour24 BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN dt.Hour24 BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS daypart,
        ISNULL(b.BrandName, 'Unknown') AS brand,
        CAST(COUNT(*) AS VARCHAR(10)) AS txn_count,
        CAST(CAST(SUM(f.TransactionValue) AS INT) AS VARCHAR(20)) AS revenue
    FROM canonical.SalesInteractionFact f
    JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
    LEFT JOIN dbo.DimTime dt ON dt.TimeKey = f.TimeKey
    LEFT JOIN dbo.Brands b ON f.BrandID = b.BrandID
    WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo
    GROUP BY
        CASE
            WHEN dt.Hour24 BETWEEN 6 AND 11 THEN 'Morning'
            WHEN dt.Hour24 BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN dt.Hour24 BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END,
        b.BrandName
    ORDER BY daypart, revenue DESC;
    " > "$CROSSTAB_FILE"

    echo "✅ Crosstab created: $CROSSTAB_FILE"
fi

echo
echo "🎯 Export workflow completed successfully!"
echo "Ready for CI artifact upload: $OUTPUT_FILE"