#!/usr/bin/env bash
set -euo pipefail
: "${AZSQL_HOST:?}"; : "${AZSQL_DB:?}"; : "${AZSQL_USER_ADMIN:?}"; : "${AZSQL_PASS_ADMIN:?}"

echo "🔍 Checking canonical ID matching improvement..."

# Health check
echo "📊 Running health check..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" \
  -Q "EXEC dbo.sp_scout_health_check;" -h -1

# Parity check: crosstab should equal stamped-flat
echo "✅ Verifying crosstab parity..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" \
  -Q "WITH c AS (SELECT SUM(txn_count) AS txn FROM dbo.v_transactions_crosstab_production)
      SELECT c.txn AS xtab_txn,
             (SELECT COUNT(*) FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL) AS flat_stamped
      FROM c;" -h -1

# Sample of normalized IDs
echo "🔗 Sample normalized canonical IDs..."
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_ADMIN" -P "$AZSQL_PASS_ADMIN" \
  -Q "SELECT TOP 5
        JSON_VALUE(payload_json,'$.transactionId') AS raw_payload,
        canonical_tx_id_payload AS norm_payload
      FROM dbo.PayloadTransactions
      WHERE canonical_tx_id_payload IS NOT NULL;" -h -1

echo "✨ Canonical ID matching analysis complete"