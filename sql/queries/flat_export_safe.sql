-- Safe flat export query with ISJSON guards
-- Purpose: Export transaction data without JSON parsing errors
-- Usage: sqlcmd -Q "SET NOCOUNT ON; $(cat sql/queries/flat_export_safe.sql)" -s"," -h -1 -W -o exports/flat_safe.csv

SELECT
  f.canonical_tx_id,
  f.transaction_id,
  f.device_id,
  f.store_id,
  f.store_name,
  f.brand,
  f.product_name,
  f.category,
  f.total_amount,
  f.total_items,
  f.payment_method,
  f.daypart,
  f.weekday_weekend,
  f.txn_ts,
  f.transaction_date,
  f.audio_transcript
FROM dbo.v_transactions_flat_production AS f
WHERE f.store_id IS NOT NULL
ORDER BY f.transaction_date DESC, f.txn_ts DESC;