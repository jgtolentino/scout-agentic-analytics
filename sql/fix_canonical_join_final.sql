-- Fix canonical transaction ID normalization and timestamp linking

-- 1) Add normalized canonical ID columns (+indexes)
-- Payload side: canonical from payload JSON
IF COL_LENGTH('dbo.PayloadTransactions','canonical_tx_id_payload') IS NULL
ALTER TABLE dbo.PayloadTransactions ADD canonical_tx_id_payload AS (
  UPPER(REPLACE(LTRIM(RTRIM(TRY_CONVERT(nvarchar(128), JSON_VALUE(payload_json, '$.transactionId')))),'-',''))
) PERSISTED;

-- SalesInteractions side: normalize InteractionID
IF COL_LENGTH('dbo.SalesInteractions','canonical_tx_id_norm') IS NULL
ALTER TABLE dbo.SalesInteractions ADD canonical_tx_id_norm AS (
  UPPER(REPLACE(LTRIM(RTRIM(TRY_CONVERT(nvarchar(128), InteractionID))),'-',''))
) PERSISTED;

-- Helpful indexes (skip if they already exist)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payload_canon')
  CREATE INDEX IX_Payload_canon ON dbo.PayloadTransactions(canonical_tx_id_payload);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SI_canon')
  CREATE INDEX IX_SI_canon ON dbo.SalesInteractions(canonical_tx_id_norm);

GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
SELECT
  -- IDs / store
  CAST(pt.sessionId AS varchar(64)) AS transaction_id,
  CAST(pt.sessionId AS varchar(64)) AS canonical_tx_id_fallback,
  pt.canonical_tx_id_payload       AS canonical_tx_id,         -- the one we use
  CAST(pt.deviceId AS varchar(64))  AS device_id,
  CAST(pt.storeId  AS int)          AS store_id,
  CONCAT(N'Store_', pt.storeId)     AS store_name,

  -- business fields (fill as you wire dims)
  CAST(NULL AS nvarchar(200))       AS product_name,
  CAST(NULL AS nvarchar(120))       AS brand,
  CAST(NULL AS nvarchar(100))       AS category,
  CAST(pt.amount AS decimal(18,2))  AS total_amount,
  CAST(1 AS int)                    AS total_items,
  CAST(NULL AS nvarchar(40))        AS payment_method,
  CAST(si.TranscriptionText AS nvarchar(max)) AS audio_transcript,

  -- authoritative time from SalesInteractions only
  CAST(si.TransactionDate AS datetime2(0)) AS txn_ts,
  CASE
    WHEN CAST(si.TransactionDate AS time) >= '05:00' AND CAST(si.TransactionDate AS time) < '12:00' THEN 'Morning'
    WHEN CAST(si.TransactionDate AS time) >= '12:00' AND CAST(si.TransactionDate AS time) < '17:00' THEN 'Afternoon'
    WHEN CAST(si.TransactionDate AS time) >= '17:00' AND CAST(si.TransactionDate AS time) < '21:00' THEN 'Evening'
    WHEN si.TransactionDate IS NULL THEN NULL
    ELSE 'Night'
  END AS daypart,
  CASE
    WHEN si.TransactionDate IS NULL THEN NULL
    WHEN DATEPART(WEEKDAY, si.TransactionDate) IN (1,7) THEN 'Weekend' ELSE 'Weekday'
  END AS weekday_weekend,
  CONVERT(date, si.TransactionDate)       AS transaction_date
FROM dbo.PayloadTransactions AS pt
LEFT JOIN dbo.SalesInteractions AS si
  ON pt.canonical_tx_id_payload = si.canonical_tx_id_norm;
GO

GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
WHERE f.txn_ts IS NOT NULL             -- only stamped txns roll up
GROUP BY CONVERT(date, f.txn_ts), f.store_id, f.store_name, f.daypart, f.brand;
GO

-- Sanity checks
SELECT
  'Total PayloadTransactions' as metric,
  COUNT(*) as count
FROM dbo.PayloadTransactions
UNION ALL
SELECT
  'Records with timestamp (matched)',
  COUNT(*)
FROM dbo.v_transactions_flat_production WHERE txn_ts IS NOT NULL
UNION ALL
SELECT
  'Records without timestamp (unmatched)',
  COUNT(*)
FROM dbo.v_transactions_flat_production WHERE txn_ts IS NULL;