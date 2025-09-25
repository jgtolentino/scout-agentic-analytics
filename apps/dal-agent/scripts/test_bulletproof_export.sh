#!/usr/bin/env bash
# Test script for bullet-proof export system
# Run this when database connectivity is restored

set -euo pipefail

echo "🛡️ Testing Bullet-Proof Export System"
echo "====================================="

# Step 1: Create CSV-safe view (first-time setup)
echo "Step 1: Creating CSV-safe view..."
sqlcmd -S "sqltbwaprojectscoutserver.database.windows.net" \
  -d "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -G -C -i sql/create_csv_safe_view.sql

# Step 2: Verify row count
echo "Step 2: Verifying row count..."
ROWS=$(sqlcmd -S "sqltbwaprojectscoutserver.database.windows.net" \
  -d "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -G -C -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.v_flat_export_csvsafe;" \
  -h -1 -W | tr -d ' \t\r\n')

echo "Row count: $ROWS"
if [ "$ROWS" = "12192" ]; then
  echo "✅ Row count verified: 12,192"
else
  echo "⚠️ Unexpected row count: $ROWS (expected 12,192)"
fi

# Step 3: Test bullet-proof export
echo "Step 3: Testing bullet-proof export..."
mkdir -p out/flat

sqlcmd -S "sqltbwaprojectscoutserver.database.windows.net" \
  -d "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -G -C -Q "SET NOCOUNT ON; SELECT * FROM dbo.v_flat_export_csvsafe ORDER BY Transaction_ID;" \
  -s "," -W -h -1 -y 0 -o out/flat/flat_dataframe_bulletproof.csv

# Step 4: Validate export
if [ -f "out/flat/flat_dataframe_bulletproof.csv" ]; then
  EXPORT_ROWS=$(wc -l < out/flat/flat_dataframe_bulletproof.csv)
  echo "Export rows: $EXPORT_ROWS"

  if [ "$EXPORT_ROWS" = "12192" ]; then
    echo "✅ Export successful: 12,192 rows"
    echo "📁 File: out/flat/flat_dataframe_bulletproof.csv"

    # Show sample
    echo "Sample (first 5 lines):"
    head -5 out/flat/flat_dataframe_bulletproof.csv

  else
    echo "⚠️ Export row count: $EXPORT_ROWS (expected 12,192)"
  fi
else
  echo "❌ Export file not created"
  exit 1
fi

echo ""
echo "🎉 Bullet-proof export system test complete!"