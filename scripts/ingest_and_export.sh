#!/usr/bin/env bash
set -euo pipefail
: "${AZSQL_HOST:?}"; : "${AZSQL_DB:?}"; : "${AZSQL_USER_ADMIN:?}"; : "${AZSQL_PASS_ADMIN:?}"

CSV_PATH="${1:-/Users/tbwa/Downloads/transactions_flat_no_ts.csv}"
OUTDIR="${EXPORT_DIR:-exports}"

echo "🚀 Scout v7 Complete CSV Ingestion Pipeline"
echo "📂 CSV: $CSV_PATH"
echo "📊 Target: $AZSQL_HOST/$AZSQL_DB"

# Verify CSV exists
if [[ ! -f "$CSV_PATH" ]]; then
  echo "❌ ERROR: CSV file not found: $CSV_PATH"
  exit 1
fi

echo "📋 Record count: $(wc -l < "$CSV_PATH") lines"
mkdir -p "$OUTDIR"

echo "🔧 Step 1: Create staging table..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
IF OBJECT_ID('dbo.PayloadTransactionsStaging_csv','U') IS NULL
CREATE TABLE dbo.PayloadTransactionsStaging_csv (
  source_path   nvarchar(400)    NULL,
  transactionId varchar(64)      NOT NULL,
  deviceId      varchar(64)      NULL,
  storeId       int              NULL,
  payload_json  nvarchar(max)    NOT NULL
);"

echo "📥 Step 2: Load CSV via sqlcmd (header skip)..."
# Use sqlcmd BULK INSERT instead of bcp for better compatibility
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
TRUNCATE TABLE dbo.PayloadTransactionsStaging_csv;
BULK INSERT dbo.PayloadTransactionsStaging_csv
FROM '$CSV_PATH'
WITH (
  FIELDTERMINATOR = ',',
  ROWTERMINATOR = '\n',
  FIRSTROW = 2,
  CODEPAGE = '65001'
);"

echo "🔄 Step 3: Merge into PayloadTransactions (upsert)..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
/* Ensure needed columns exist in PayloadTransactions */
IF COL_LENGTH('dbo.PayloadTransactions','sessionId') IS NULL
  ALTER TABLE dbo.PayloadTransactions ADD sessionId varchar(64) NULL;
IF COL_LENGTH('dbo.PayloadTransactions','deviceId') IS NULL
  ALTER TABLE dbo.PayloadTransactions ADD deviceId varchar(64) NULL;
IF COL_LENGTH('dbo.PayloadTransactions','storeId') IS NULL
  ALTER TABLE dbo.PayloadTransactions ADD storeId int NULL;
IF COL_LENGTH('dbo.PayloadTransactions','payload_json') IS NULL
  ALTER TABLE dbo.PayloadTransactions ADD payload_json nvarchar(max) NULL;

/* Merge */
MERGE dbo.PayloadTransactions AS tgt
USING (
  SELECT
    s.transactionId,
    s.deviceId,
    s.storeId,
    s.payload_json
  FROM dbo.PayloadTransactionsStaging_csv s
) AS src
ON (tgt.sessionId = src.transactionId)
WHEN MATCHED THEN UPDATE SET
  tgt.deviceId     = COALESCE(src.deviceId, tgt.deviceId),
  tgt.storeId      = COALESCE(src.storeId,  tgt.storeId),
  tgt.payload_json = COALESCE(src.payload_json, tgt.payload_json)
WHEN NOT MATCHED BY TARGET THEN
  INSERT (sessionId, deviceId, storeId, payload_json)
  VALUES (src.transactionId, src.deviceId, src.storeId, src.payload_json);"

echo "🔗 Step 4: Rebuild canonical ID matching..."
scripts/run_sql.sh sql/04_force_canonical_matching.sql

echo "📊 Step 5: Enhanced views with rich payload data..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
SELECT
  CAST(pt.sessionId AS varchar(64))  AS transaction_id,
  pt.canonical_tx_id_payload         AS canonical_tx_id,
  CAST(pt.deviceId AS varchar(64))   AS device_id,
  CAST(pt.storeId  AS int)           AS store_id,
  CONCAT(N'Store_', pt.storeId)      AS store_name,

  /* Enhanced: pull business fields directly from payload JSON */
  JSON_VALUE(pt.payload_json, '$.items[0].brandName')          AS brand,
  JSON_VALUE(pt.payload_json, '$.items[0].productName')        AS product_name,
  JSON_VALUE(pt.payload_json, '$.items[0].category')           AS category,
  TRY_CONVERT(decimal(18,2), JSON_VALUE(pt.payload_json, '$.totals.totalAmount')) AS total_amount,
  TRY_CONVERT(int, JSON_VALUE(pt.payload_json, '$.totals.totalItems'))            AS total_items,
  JSON_VALUE(pt.payload_json, '$.transactionContext.paymentMethod')               AS payment_method,
  JSON_VALUE(pt.payload_json, '$.transactionContext.audioTranscript')             AS audio_transcript,

  /* Authoritative timestamp from SI only */
  CAST(si.TransactionDate AS datetime2(0)) AS txn_ts,
  CASE
    WHEN si.TransactionDate IS NULL THEN NULL
    WHEN CAST(si.TransactionDate AS time) >= '05:00' AND CAST(si.TransactionDate AS time) < '12:00' THEN 'Morning'
    WHEN CAST(si.TransactionDate AS time) >= '12:00' AND CAST(si.TransactionDate AS time) < '17:00' THEN 'Afternoon'
    WHEN CAST(si.TransactionDate AS time) >= '17:00' AND CAST(si.TransactionDate AS time) < '21:00' THEN 'Evening'
    ELSE 'Night'
  END AS daypart,
  CASE
    WHEN si.TransactionDate IS NULL THEN NULL
    WHEN DATEPART(WEEKDAY, si.TransactionDate) IN (1,7) THEN 'Weekend' ELSE 'Weekday'
  END AS weekday_weekend,
  CONVERT(date, si.TransactionDate)  AS transaction_date
FROM dbo.PayloadTransactions AS pt
LEFT JOIN dbo.SalesInteractions AS si
  ON pt.canonical_tx_id_payload = si.canonical_tx_id_norm;
GO

CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production
AS
SELECT
  CONVERT(date, f.txn_ts)            AS [date],
  f.store_id,
  f.store_name,
  f.daypart,
  f.brand,
  COUNT(*)                           AS txn_count,
  SUM(COALESCE(f.total_amount,0))    AS total_amount
FROM dbo.v_transactions_flat_production AS f
WHERE f.txn_ts IS NOT NULL
GROUP BY CONVERT(date, f.txn_ts), f.store_id, f.store_name, f.daypart, f.brand;
GO"

echo "✅ Step 6: Verify enhanced match rate..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
SELECT
  total_payload = (SELECT COUNT(*) FROM dbo.PayloadTransactions),
  stamped       = (SELECT COUNT(*) FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL),
  unstamped     = (SELECT COUNT(*) FROM dbo.v_transactions_flat_production WHERE txn_ts IS NULL),
  match_pct     = ROUND(100.0 * (SELECT COUNT(*) FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL) / (SELECT COUNT(*) FROM dbo.PayloadTransactions), 1);" -h -1

echo "🎯 Step 7: Sample enhanced business data..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
SELECT TOP 5
  brand, product_name, category, total_amount, audio_transcript
FROM dbo.v_transactions_flat_production
WHERE brand IS NOT NULL
ORDER BY total_amount DESC;" -h -1

echo "📤 Step 8: Export enhanced datasets..."
./scripts/export_full.sh

echo "🧹 Cleanup: Drop staging table..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
DROP TABLE IF EXISTS dbo.PayloadTransactionsStaging_csv;"

echo ""
echo "✨ CSV Ingestion Complete!"
echo "📊 Enhanced exports available:"
echo "   - $OUTDIR/flat_full.csv (with rich business data)"
echo "   - $OUTDIR/crosstab_full.csv (brand-aware aggregations)"
echo ""
echo "🎉 All payload data loaded with canonical ID matching!"