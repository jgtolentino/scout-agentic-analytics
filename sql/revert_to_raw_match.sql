-- Revert to raw matching - normalization broke the matches
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
SELECT
  -- IDs / store
  CAST(pt.sessionId AS varchar(64))                         AS transaction_id,
  JSON_VALUE(pt.payload_json, '$.transactionId')           AS canonical_tx_id,
  CAST(pt.deviceId AS varchar(64))                          AS device_id,
  CAST(pt.storeId AS int)                                   AS store_id,
  CONCAT(N'Store_', pt.storeId)                             AS store_name,

  -- business fields
  CAST(NULL AS nvarchar(200))                               AS product_name,
  CAST(NULL AS nvarchar(120))                               AS brand,
  CAST(NULL AS nvarchar(100))                               AS category,
  CAST(pt.amount AS decimal(18,2))                          AS total_amount,
  CAST(1 AS int)                                            AS total_items,
  CAST(NULL AS nvarchar(40))                                AS payment_method,
  CAST(si.TranscriptionText AS nvarchar(max))               AS audio_transcript,

  -- authoritative time from SalesInteractions only
  CAST(si.TransactionDate AS datetime2(0))                  AS txn_ts,
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
  CONVERT(date, si.TransactionDate)                         AS transaction_date
FROM dbo.PayloadTransactions AS pt
LEFT JOIN dbo.SalesInteractions AS si
  ON JSON_VALUE(pt.payload_json, '$.transactionId') = si.InteractionID  -- RAW to RAW match
WHERE pt.amount IS NOT NULL;
GO