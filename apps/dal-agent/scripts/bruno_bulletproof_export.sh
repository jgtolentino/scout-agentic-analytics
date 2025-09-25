#!/usr/bin/env bash
# Bruno-orchestrated bullet-proof export system

set -euo pipefail

echo "🛡️ Bruno Bullet-Proof Export System"
echo "===================================="

# Ensure output directory exists
mkdir -p out/flat

# Step 1: Create CSV-safe view via Bruno
echo "Step 1: Creating CSV-safe view..."
:bruno sql name:"ensure-csv-safe-view" conn:"$AZURE_SQL_CONN_STR" script:"CREATE OR ALTER VIEW dbo.v_flat_export_csvsafe AS SELECT [Transaction_ID],[Transaction_Value],[Basket_Size],REPLACE(REPLACE(LTRIM(RTRIM([Category])),CHAR(13),' '),CHAR(10),' ') AS [Category],REPLACE(REPLACE(LTRIM(RTRIM([Brand])),CHAR(13),' '),CHAR(10),' ') AS [Brand],[Daypart],REPLACE(REPLACE(LTRIM(RTRIM([Demographics (Age/Gender/Role)])),CHAR(13),' '),CHAR(10),' ') AS [Demographics (Age/Gender/Role)],[Weekday_vs_Weekend],[Time of transaction],REPLACE(REPLACE(LTRIM(RTRIM([Location])),CHAR(13),' '),CHAR(10),' ') AS [Location],REPLACE(REPLACE(LTRIM(RTRIM([Other_Products])),CHAR(13),' '),CHAR(10),' ') AS [Other_Products],[Was_Substitution] FROM dbo.v_flat_export_sheet;"

echo "✅ CSV-safe view created"

# Step 2: Export via Bruno shell command
echo "Step 2: Exporting flat dataframe..."
:bruno shell name:"flat-export" run:"sqlcmd -S 'sqltbwaprojectscoutserver.database.windows.net' -d 'SQL-TBWA-ProjectScout-Reporting-Prod' -G -C -Q \"SET NOCOUNT ON; SELECT * FROM dbo.v_flat_export_csvsafe ORDER BY [Transaction_ID];\" -s \",\" -W -h -1 -y 0 -o out/flat/flat_dataframe_bulletproof.csv"

# Validate export
if [ -f "out/flat/flat_dataframe_bulletproof.csv" ]; then
  ROWS=$(wc -l < out/flat/flat_dataframe_bulletproof.csv)
  echo "✅ Export completed: $ROWS rows"
  echo "📁 File: out/flat/flat_dataframe_bulletproof.csv"

  if [ "$ROWS" = "12192" ]; then
    echo "🎉 Perfect! Exactly 12,192 rows exported."
  else
    echo "⚠️ Row count: $ROWS (expected 12,192)"
  fi

  # Show sample
  echo ""
  echo "Sample (first 3 lines):"
  head -3 out/flat/flat_dataframe_bulletproof.csv
else
  echo "❌ Export file not created"
  exit 1
fi

echo ""
echo "🎉 Bruno bullet-proof export completed!"