#!/usr/bin/env bash
# BCP-based bullet-proof export (fastest and most reliable for large datasets)

set -euo pipefail

echo "🚀 BCP Bullet-Proof Export"
echo "=========================="

# Ensure output directory exists
mkdir -p out/flat

# BCP export with Azure AD authentication
echo "Exporting flat dataframe via BCP..."
bcp "SELECT * FROM dbo.v_flat_export_csvsafe ORDER BY Transaction_ID" queryout \
  out/flat/flat_dataframe_bulletproof_bcp.csv \
  -S "sqltbwaprojectscoutserver.database.windows.net" \
  -d "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -G -C -c -t ","

# Validate export
if [ -f "out/flat/flat_dataframe_bulletproof_bcp.csv" ]; then
  ROWS=$(wc -l < out/flat/flat_dataframe_bulletproof_bcp.csv)
  echo "✅ BCP Export completed: $ROWS rows"
  echo "📁 File: out/flat/flat_dataframe_bulletproof_bcp.csv"

  # Show sample
  echo ""
  echo "Sample (first 3 lines):"
  head -3 out/flat/flat_dataframe_bulletproof_bcp.csv

  if [ "$ROWS" = "12192" ]; then
    echo ""
    echo "🎉 Perfect! Exactly 12,192 rows exported."
  else
    echo ""
    echo "⚠️ Row count: $ROWS (expected 12,192)"
  fi
else
  echo "❌ BCP export failed - file not created"
  exit 1
fi