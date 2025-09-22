# Scout v7 CSV Export Guide

## Production Views Status ✅

**Views Created**: `dbo.v_transactions_flat_production`, `dbo.v_transactions_crosstab_production`
**Health Check**: `dbo.sp_scout_health_check`
**Data Volume**: 12,192 total transactions, 6,146 with timestamps (50.4% stamped)
**Date Range**: May 2, 2025 - September 5, 2025

## Canonical Join Implementation

**Join Logic**: `LOWER(REPLACE($.transactionId,'-','')) = LOWER(REPLACE(SalesInteractions.InteractionID,'-',''))`
**Timestamp Source**: ONLY `SalesInteractions.TransactionDate` (payload timestamps ignored)
**No Device Mapping**: Views read deviceId as label only, no joins to mapping tables

## CSV Export Commands

### Basic Export (Clean Data)
```bash
# Core transaction data (6,146 stamped rows)
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER" -P "$AZSQL_PASS" \
  -Q "SELECT sessionId AS transaction_id, deviceId, TRY_CAST(storeId AS int) AS store_id,
      CAST(txn_ts AS datetime2(0)) AS txn_ts, daypart, weekday_weekend
      FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL
      ORDER BY txn_ts DESC;" \
  -s "," -W -w 32767 -h -1 > exports/scout_clean.csv
```

### Full Flat Export (All Columns)
```bash
# All available columns from flat view
./scripts/export_full.sh
```

## Health Monitoring

```sql
-- Run health check
EXEC dbo.sp_scout_health_check;

-- Check date window
SELECT MIN(txn_ts) AS min_ts, MAX(txn_ts) AS max_ts
FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL;

-- Row counts
SELECT COUNT(*) as total_rows FROM dbo.v_transactions_flat_production;
SELECT COUNT(*) as stamped_rows FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL;
```

## Power BI Connection

**Server**: `sqltbwaprojectscoutserver.database.windows.net`
**Database**: `SQL-TBWA-ProjectScout-Reporting-Prod`
**Primary Views**:
- `dbo.v_transactions_flat_production` (detailed transactions)
- `dbo.v_transactions_crosstab_production` (aggregated by date/store/daypart/brand)

## Raising Stamped Coverage

Current: 50.4% (6,146 of 12,192 transactions have timestamps)
**Root Cause**: Missing InteractionIDs in SalesInteractions table
**Solution**: Backfill SalesInteractions with missing transaction IDs

## File Locations

- **Views**: `/sql/02_views.sql`
- **Health**: `/sql/03_health.sql`
- **Export Script**: `/scripts/export_full.sh`
- **Latest Export**: `/exports/minimal_working.csv` (479KB, 6,146 rows)