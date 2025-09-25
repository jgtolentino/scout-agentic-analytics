#!/usr/bin/env bash
set -euo pipefail
DB="${DB:?Set DB}"
MIN_PROD="${MIN_PROD:-90}"   # percent
MIN_LINE="${MIN_LINE:-85}"   # percent

# Query SQL Server with explicit column names and CSV format for easier parsing
row=$(./scripts/sql.sh -d "$DB" -Q "SELECT CAST(product_coverage_pct AS varchar(10)) + ',' + CAST(line_coverage_pct AS varchar(10)) AS coverage FROM gold.v_nielsen_coverage_summary;")

# Parse CSV result - extract coverage percentages
pct_prod=$(echo "$row" | grep -E '[0-9]+\.[0-9]+,[0-9]+\.[0-9]+' | cut -d',' -f1 | grep -Eo '[0-9]+\.[0-9]+' | head -1)
pct_line=$(echo "$row" | grep -E '[0-9]+\.[0-9]+,[0-9]+\.[0-9]+' | cut -d',' -f2 | grep -Eo '[0-9]+\.[0-9]+' | head -1)

# Fallback parsing if CSV format not detected
if [[ -z "$pct_prod" || -z "$pct_line" ]]; then
  pct_prod=$(echo "$row" | grep -Eo '[0-9]+\.[0-9]+' | sed -n '1p')
  pct_line=$(echo "$row" | grep -Eo '[0-9]+\.[0-9]+' | sed -n '2p')
fi

echo "Coverage: products=${pct_prod}% (min ${MIN_PROD}%), lines=${pct_line}% (min ${MIN_LINE}%)"

# Compare using awk instead of bc for better portability
ip=$(awk "BEGIN {printf \"%.0f\", $pct_prod * 100}")
il=$(awk "BEGIN {printf \"%.0f\", $pct_line * 100}")
mp=$(($MIN_PROD*100)); ml=$(($MIN_LINE*100))

if [[ $ip -lt $mp || $il -lt $ml ]]; then
  echo "❌ Coverage threshold not met: Products ${pct_prod}% < ${MIN_PROD}% OR Lines ${pct_line}% < ${MIN_LINE}%"
  exit 2
fi
echo "✅ Coverage thresholds satisfied."