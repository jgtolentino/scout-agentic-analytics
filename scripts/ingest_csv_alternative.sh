#!/usr/bin/env bash
set -euo pipefail
: "${AZSQL_HOST:?}"; : "${AZSQL_DB:?}"; : "${AZSQL_USER_ADMIN:?}"; : "${AZSQL_PASS_ADMIN:?}"

CSV_PATH="${1:-/Users/tbwa/Downloads/transactions_flat_no_ts.csv}"
OUTDIR="${EXPORT_DIR:-exports}"

echo "🚀 Scout v7 CSV Ingestion (Alternative Method)"
echo "📂 CSV: $CSV_PATH"

# Verify CSV exists
if [[ ! -f "$CSV_PATH" ]]; then
  echo "❌ ERROR: CSV file not found: $CSV_PATH"
  exit 1
fi

mkdir -p "$OUTDIR"

echo "📋 Processing CSV data..."
python3 scripts/process_csv_for_upload.py "$CSV_PATH" "$OUTDIR/processed_payload.csv"

echo "🔧 Step 1: Create staging table..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
DROP TABLE IF EXISTS dbo.PayloadTransactionsStaging_csv;
CREATE TABLE dbo.PayloadTransactionsStaging_csv (
  source_path   nvarchar(400)    NULL,
  transactionId varchar(64)      NOT NULL,
  deviceId      varchar(64)      NULL,
  storeId       int              NULL,
  payload_json  nvarchar(max)    NOT NULL
);"

echo "📥 Step 2: Generate INSERT statements..."
python3 -c "
import csv
import sys

def generate_inserts(csv_path):
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        batch_size = 100
        batch = []

        for row in reader:
            if len(row) >= 5:
                source_path, txn_id, device_id, store_id, payload = row[:5]

                # Escape single quotes
                payload_escaped = payload.replace(\"'\", \"''\")

                insert_stmt = f\"('{source_path}', '{txn_id}', '{device_id}', {store_id if store_id.isdigit() else 'NULL'}, '{payload_escaped}')\"
                batch.append(insert_stmt)

                if len(batch) >= batch_size:
                    print(f'INSERT INTO dbo.PayloadTransactionsStaging_csv (source_path, transactionId, deviceId, storeId, payload_json) VALUES {', '.join(batch)};')
                    batch = []

        # Final batch
        if batch:
            print(f'INSERT INTO dbo.PayloadTransactionsStaging_csv (source_path, transactionId, deviceId, storeId, payload_json) VALUES {', '.join(batch)};')

generate_inserts('$OUTDIR/processed_payload.csv')
" > "$OUTDIR/insert_statements.sql"

echo "💾 Step 3: Execute INSERT statements..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -i "$OUTDIR/insert_statements.sql"

echo "🔄 Step 4: Merge into PayloadTransactions..."
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

/* Show staging count */
SELECT staging_count = COUNT(*) FROM dbo.PayloadTransactionsStaging_csv;

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

echo "🔗 Step 5: Force canonical ID matching..."
export AZSQL_HOST="$AZSQL_HOST" && export AZSQL_DB="$AZSQL_DB" && export AZSQL_USER_ADMIN="$AZSQL_USER_ADMIN" && export AZSQL_PASS_ADMIN="$AZSQL_PASS_ADMIN" && scripts/run_sql.sh sql/05_force_canonical_fixed.sql

echo "✅ Step 6: Final verification..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "
SELECT
  total_payload = (SELECT COUNT(*) FROM dbo.PayloadTransactions),
  stamped       = (SELECT COUNT(*) FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL),
  unstamped     = (SELECT COUNT(*) FROM dbo.v_transactions_flat_production WHERE txn_ts IS NULL);" -h -1

echo "📤 Step 7: Export enhanced data..."
export AZSQL_HOST="$AZSQL_HOST" && export AZSQL_DB="$AZSQL_DB" && export AZSQL_USER_ADMIN="$AZSQL_USER_ADMIN" && export AZSQL_PASS_ADMIN="$AZSQL_PASS_ADMIN" && ./scripts/export_full.sh

echo "🧹 Cleanup..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" -Q "DROP TABLE IF EXISTS dbo.PayloadTransactionsStaging_csv;"
rm -f "$OUTDIR/insert_statements.sql" "$OUTDIR/processed_payload.csv"

echo ""
echo "✨ CSV Ingestion Complete! Enhanced exports ready with rich payload data."