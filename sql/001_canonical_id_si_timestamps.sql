-- Canonical ID + SI-Only Timestamp Enforcement for Scout v7
-- Rule: silver.Transactions.canonical_tx_id normalized (lowercase, hyphenless)
-- Timestamp = SalesInteractions.TransactionDate (never payload)

-- Canonical ID normalization trigger (insert/update)
IF OBJECT_ID('silver.trg_txn_canonical_norm', 'TR') IS NOT NULL
    DROP TRIGGER silver.trg_txn_canonical_norm;
GO

CREATE TRIGGER silver.trg_txn_canonical_norm
ON silver.Transactions
AFTER INSERT, UPDATE
AS
BEGIN
  SET NOCOUNT ON;

  -- Only process if canonical_tx_id was actually changed
  IF UPDATE(canonical_tx_id)
  BEGIN
    UPDATE t
    SET canonical_tx_id = LOWER(REPLACE(t.canonical_tx_id,'-',''))
    FROM silver.Transactions t
    JOIN inserted i ON i.transaction_id = t.transaction_id
    WHERE t.canonical_tx_id LIKE '%-%' OR t.canonical_tx_id COLLATE Latin1_General_CS_AS LIKE '%[A-Z]%';
  END
END;
GO

-- Enhanced export view with SI-only timestamps and proper joins
CREATE OR ALTER VIEW gold.vw_FlatExport
AS
SELECT
  -- IDs (normalized)
  LOWER(REPLACE(t.canonical_tx_id,'-',''))           AS canonical_tx_id,
  t.session_id,
  t.device_id,
  t.store_id,

  -- Store info
  COALESCE(s.StoreName, s.store_name, 'Unknown Store') AS store_name,

  -- Financial
  t.amount,
  t.basket_count,
  t.payment_method,

  -- Time (authoritative from SalesInteractions only)
  COALESCE(si.TransactionDate, t.transaction_timestamp) AS txn_ts,
  CONVERT(date, COALESCE(si.TransactionDate, t.transaction_timestamp)) AS transaction_date,

  -- Time dimensions
  CASE WHEN DATEPART(HOUR, COALESCE(si.TransactionDate, t.transaction_timestamp)) BETWEEN 6 AND 11 THEN 'Morning'
       WHEN DATEPART(HOUR, COALESCE(si.TransactionDate, t.transaction_timestamp)) BETWEEN 12 AND 17 THEN 'Afternoon'
       WHEN DATEPART(HOUR, COALESCE(si.TransactionDate, t.transaction_timestamp)) BETWEEN 18 AND 21 THEN 'Evening'
       ELSE 'Night' END AS daypart,

  CASE WHEN DATEPART(WEEKDAY, COALESCE(si.TransactionDate, t.transaction_timestamp)) IN (1,7)
       THEN 'Weekend' ELSE 'Weekday' END AS weekday_weekend,

  -- Demographics (if available in silver.Transactions)
  t.age,
  t.age_group,
  t.gender,
  t.emotion,
  t.customer_type,

  -- Audio/Text data
  t.audio_transcript,
  t.products_detected,

  -- Data lineage
  CASE WHEN si.TransactionDate IS NOT NULL THEN 'SalesInteractions'
       ELSE 'PayloadTransactions' END AS timestamp_source,

  t.transaction_timestamp AS payload_timestamp,
  si.TransactionDate AS si_timestamp

FROM silver.Transactions t
LEFT JOIN dbo.Stores s ON s.StoreID = t.store_id OR s.store_id = t.store_id
LEFT JOIN dbo.SalesInteractions si
  ON LOWER(REPLACE(CAST(si.InteractionID AS varchar(64)),'-','')) = LOWER(REPLACE(t.canonical_tx_id,'-',''))
  OR LOWER(REPLACE(CAST(si.canonical_tx_id_norm AS varchar(64)),'-','')) = LOWER(REPLACE(t.canonical_tx_id,'-',''));
GO

-- Quick consistency validation queries
-- 1) Check canonical ID normalization
SELECT
    'Canonical ID Check' AS test_name,
    COUNT(*) AS total_records,
    SUM(CASE WHEN canonical_tx_id LIKE '%-%' OR canonical_tx_id COLLATE Latin1_General_CS_AS LIKE '%[A-Z]%'
             THEN 1 ELSE 0 END) AS unnormalized_count
FROM silver.Transactions;

-- 2) Check timestamp sources
SELECT
    'Timestamp Sources' AS test_name,
    timestamp_source,
    COUNT(*) AS record_count,
    MIN(txn_ts) AS earliest_timestamp,
    MAX(txn_ts) AS latest_timestamp
FROM gold.vw_FlatExport
GROUP BY timestamp_source;

-- 3) Check join coverage
SELECT
    'Join Coverage' AS test_name,
    COUNT(*) AS total_records,
    SUM(CASE WHEN si_timestamp IS NOT NULL THEN 1 ELSE 0 END) AS si_matched,
    CAST(SUM(CASE WHEN si_timestamp IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS si_match_rate_pct
FROM gold.vw_FlatExport;