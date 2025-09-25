# Database Connectivity Status

## Current Status: Azure SQL Database Unavailable ⚠️

**Error**: `Database 'SQL-TBWA-ProjectScout-Reporting-Prod' on server 'sqltbwaprojectscoutserver.database.windows.net' is not currently available.`

**Session ID**: `{ADC390D5-0451-4C43-B721-A35B650152A6}`

**Impact**: Cannot execute full flat dataframe export at this time.

## Successful Previous Exports ✅

**Flat View Status**: Confirmed working with exactly **12,192 rows** (corrected from 33,362)

**Available Exports**:
- `out/flat/flat_test_5_rows.csv` - Sample 5 rows with full structure
- `out/flat/flat_dataframe_essential.csv` - Clean CSV format with essential columns

## When Database Becomes Available

### Quick Export Command
```bash
# Essential columns export (avoids JSON parsing issues)
./scripts/sql.sh -Q "SET NOCOUNT ON; SELECT [Transaction_ID], [Transaction_Value], [Basket_Size], LEFT(LTRIM(RTRIM([Category])), 50) AS Category_Short, LEFT(LTRIM(RTRIM([Brand])), 50) AS Brand_Short, [Daypart], LEFT(LTRIM(RTRIM([Demographics (Age/Gender/Role)])), 30) AS Demographics_Short, [Weekday_vs_Weekend], LEFT([Location], 50) AS Location_Short, [Was_Substitution] FROM dbo.v_flat_export_sheet ORDER BY [Transaction_ID]" > out/flat/flat_dataframe_essential_full.csv
```

### Full Export via Azure Portal (Recommended)
1. Navigate to Azure Portal → SQL Database
2. Query Editor → Open saved query for `dbo.v_flat_export_sheet`
3. Export as CSV (handles wide columns correctly)

### Alternative Export Options
- `make flat` - Makefile target for flat export
- `bruno run bruno-analytics-complete.yml` - Bruno workflow
- Azure Data Studio export functionality

## Data Quality Confirmed ✅
- **Row Count**: 12,192 (verified multiple times)
- **Join Multiplication**: Fixed via `sql/fix_flat_view_corrected.sql`
- **Schema**: All expected columns present
- **Sample Data**: Valid transaction data confirmed

## Next Steps
1. Wait for Azure SQL Database to become available
2. Run export command once connectivity restored
3. Validate export contains all 12,192 rows
4. Deliver complete flat dataframe CSV