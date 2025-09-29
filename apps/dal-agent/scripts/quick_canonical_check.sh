#!/usr/bin/env bash
# Quick 13-column canonical export validation
# Usage: ./scripts/quick_canonical_check.sh [export_file.csv.gz]

set -euo pipefail

EXPECTED_HEADER="Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp"

# Find latest canonical export if no file specified
if [[ $# -eq 0 ]]; then
    EXPORT_FILE=$(ls -1t out/canonical/canonical_flat_*.csv.gz 2>/dev/null | head -1 || echo "")
    if [[ -z "$EXPORT_FILE" ]]; then
        echo "❌ No canonical export file found"
        echo "Run: make canonical-export-prod"
        exit 1
    fi
else
    EXPORT_FILE="$1"
fi

if [[ ! -f "$EXPORT_FILE" ]]; then
    echo "❌ File not found: $EXPORT_FILE"
    exit 1
fi

echo "🔍 Checking canonical export: $EXPORT_FILE"

# Extract header from gzipped file
ACTUAL_HEADER=$(gunzip -c "$EXPORT_FILE" | head -1 | tr -d '\r\n')

# Compare headers
if [[ "$ACTUAL_HEADER" == "$EXPECTED_HEADER" ]]; then
    echo "✅ 13-column canonical header matches exactly"

    # Count total rows
    TOTAL_ROWS=$(gunzip -c "$EXPORT_FILE" | wc -l)
    DATA_ROWS=$((TOTAL_ROWS - 1))

    echo "✅ Total rows: $TOTAL_ROWS (including header)"
    echo "✅ Data rows: $DATA_ROWS"

    # Check for basic data integrity
    EMPTY_TRANSACTION_IDS=$(gunzip -c "$EXPORT_FILE" | tail -n +2 | cut -d',' -f1 | grep -c '^$' || true)
    EMPTY_TRANSACTION_IDS=${EMPTY_TRANSACTION_IDS:-0}

    if [[ "$EMPTY_TRANSACTION_IDS" -eq "0" ]]; then
        echo "✅ No empty Transaction_ID fields"
    else
        echo "⚠️ Found $EMPTY_TRANSACTION_IDS empty Transaction_ID fields"
    fi

    echo "✅ Canonical export validation passed"
else
    echo "❌ Header mismatch!"
    echo "Expected: $EXPECTED_HEADER"
    echo "Actual:   $ACTUAL_HEADER"
    exit 1
fi