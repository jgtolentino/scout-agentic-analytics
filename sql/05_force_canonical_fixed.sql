/* =========================================================================================
   Fixed: Force Canonical ID Matching + Rebuild Views
   Using actual PayloadTransactions schema
========================================================================================= */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =========================================================================================
   1) Flat production view (FORCED matching via normalized IDs, then overrides)
      - LEFT JOIN keeps all payload rows (12,192)
      - Timestamp comes ONLY from SalesInteractions.TransactionDate or override
      - Using actual PayloadTransactions columns only
========================================================================================= */
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
WITH base AS (
  SELECT
      /* IDs / store */
      JSON_VALUE(pt.payload_json, '$.transactionId') AS canonical_tx_id,
      CAST(pt.sessionId AS varchar(64))           AS transaction_id,
      CAST(pt.deviceId  AS varchar(64))           AS device_id,
      CAST(pt.storeId   AS int)                   AS store_id,
      CONCAT(N'Store_', pt.storeId)               AS store_name,

      /* business fields (wire up as data becomes available) */
      CAST(NULL AS nvarchar(200))                 AS product_name,
      CAST(NULL AS nvarchar(120))                 AS brand,
      CAST(NULL AS nvarchar(100))                 AS category,
      CAST(pt.amount       AS decimal(18,2))      AS total_amount,
      CAST(1 AS int)                              AS total_items,
      CAST(NULL AS nvarchar(40))                  AS payment_method,
      CAST(NULL AS nvarchar(max))                 AS audio_transcript,

      /* join keys */
      pt.canonical_tx_id_payload                   AS canon_payload
  FROM dbo.PayloadTransactions AS pt
)
, joined AS (
  SELECT
      b.*,
      si.TransactionDate                             AS official_ts,
      si.DeviceID                                    AS si_device,
      CAST(si.TranscriptionText AS nvarchar(max))    AS si_transcript
  FROM base AS b
  LEFT JOIN dbo.SalesInteractions AS si
    ON b.canon_payload = si.canonical_tx_id_norm       -- **FORCED normalized match**
)
, stamped AS (
  SELECT
      j.canonical_tx_id,
      j.transaction_id,
      j.device_id,
      j.store_id,
      j.store_name,
      j.brand,
      j.product_name,
      j.category,
      j.total_amount,
      j.total_items,
      j.payment_method,
      COALESCE(j.si_transcript, j.audio_transcript) AS audio_transcript,

      /* authoritative timestamp precedence: override > SalesInteractions */
      COALESCE(o.forced_ts, j.official_ts)            AS txn_ts,

      /* calendar derivations ONLY from authoritative ts (or NULL if none) */
      CAST(COALESCE(o.forced_ts, j.official_ts) AS date)     AS transaction_date,
      CASE
        WHEN COALESCE(o.forced_ts, j.official_ts) IS NULL THEN NULL
        WHEN DATENAME(weekday, COALESCE(o.forced_ts, j.official_ts)) IN (N'Saturday',N'Sunday') THEN 'Weekend'
        ELSE 'Weekday'
      END AS weekday_weekend,
      CASE
        WHEN COALESCE(o.forced_ts, j.official_ts) IS NULL THEN NULL
        WHEN DATEPART(HOUR, COALESCE(o.forced_ts, j.official_ts)) BETWEEN 5 AND 11  THEN 'Morning'
        WHEN DATEPART(HOUR, COALESCE(o.forced_ts, j.official_ts)) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN DATEPART(HOUR, COALESCE(o.forced_ts, j.official_ts)) BETWEEN 17 AND 21 THEN 'Evening'
        ELSE 'Night'
      END AS daypart
  FROM joined AS j
  LEFT JOIN dbo.txn_timestamp_overrides AS o
    ON j.canonical_tx_id = o.canonical_tx_id
)
SELECT *
FROM stamped;
GO

/* =========================================================================================
   2) Crosstab (long-form) over production flat view
========================================================================================= */
CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production
AS
SELECT
    CAST(transaction_date AS date)         AS [date],
    store_id,
    store_name,
    daypart,
    brand,
    COUNT(*)                               AS txn_count,
    SUM(total_amount)                      AS total_amount
FROM dbo.v_transactions_flat_production
WHERE txn_ts IS NOT NULL                         -- only stamped rows contribute
GROUP BY CAST(transaction_date AS date), store_id, store_name, daypart, brand;
GO

PRINT 'Fixed canonical matching views deployed successfully';
GO