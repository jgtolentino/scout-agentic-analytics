/* =========================================================================================
   T-SQL: Force Canonical ID Matching + Rebuild Views
   - Normalizes canonical transaction IDs on both sides
   - Indexes for performance
   - Override table for manual fixes
   - Rebuilds views to use normalized matching
========================================================================================= */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =========================================================================================
   1) Add normalized canonical transaction IDs (computed) + indexes
      - We DO NOT use any payload timestamp.
      - We only use SalesInteractions.TransactionDate.
========================================================================================= */

/* PayloadTransactions: canonical_tx_id_payload (computed from JSON $.transactionId) */
IF COL_LENGTH('dbo.PayloadTransactions','canonical_tx_id_payload') IS NULL
BEGIN
  ALTER TABLE dbo.PayloadTransactions
  ADD canonical_tx_id_payload AS
    LOWER(REPLACE(REPLACE(JSON_VALUE(payload_json,'$.transactionId'),'-',''),'_',''));
END
GO

/* SalesInteractions: canonical_tx_id_norm (computed from InteractionID) */
IF COL_LENGTH('dbo.SalesInteractions','canonical_tx_id_norm') IS NULL
BEGIN
  ALTER TABLE dbo.SalesInteractions
  ADD canonical_tx_id_norm AS
    LOWER(REPLACE(REPLACE(CAST(InteractionID AS nvarchar(200)),'-',''),'_',''));
END
GO

/* Helpful indexes for join */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PayloadTransactions_canonid')
  CREATE INDEX IX_PayloadTransactions_canonid ON dbo.PayloadTransactions(canonical_tx_id_payload);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesInteractions_canonid')
  CREATE INDEX IX_SalesInteractions_canonid ON dbo.SalesInteractions(canonical_tx_id_norm) INCLUDE (TransactionDate, DeviceID);
GO

/* =========================================================================================
   2) Optional: manual overrides table for edge cases (force map specific txids)
========================================================================================= */
IF OBJECT_ID('dbo.txn_timestamp_overrides','U') IS NULL
BEGIN
  CREATE TABLE dbo.txn_timestamp_overrides
  (
    canonical_tx_id  varchar(64)  NOT NULL PRIMARY KEY,
    forced_ts        datetime2(0)  NOT NULL,
    note             nvarchar(200) NULL,
    updated_at       datetime2(0)  NOT NULL DEFAULT (sysutcdatetime())
  );
END
GO

/* =========================================================================================
   3) Flat production view (FORCED matching via normalized IDs, then overrides)
      - LEFT JOIN keeps all payload rows (12,192)
      - Timestamp comes ONLY from SalesInteractions.TransactionDate or override
========================================================================================= */
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
WITH base AS (
  SELECT
      /* IDs / store */
      CAST(pt.sessionId AS varchar(64))           AS canonical_tx_id,
      CAST(pt.sessionId AS varchar(64))           AS transaction_id,
      CAST(pt.deviceId  AS varchar(64))           AS device_id,
      CAST(pt.storeId   AS int)                   AS store_id,
      CONCAT(N'Store_', pt.storeId)               AS store_name,

      /* merch */
      CAST(pt.brand        AS nvarchar(120))      AS brand,
      CAST(pt.productName  AS nvarchar(200))      AS product_name,
      CAST(pt.category     AS nvarchar(100))      AS category,

      /* basket/value */
      CAST(pt.amount       AS decimal(18,2))      AS total_amount,
      CAST(pt.itemCount    AS int)                AS total_items,

      /* payment + voice */
      CAST(pt.paymentMethod AS nvarchar(60))      AS payment_method,
      CAST(pt.transcript    AS nvarchar(max))     AS audio_transcript,

      /* join keys */
      pt.canonical_tx_id_payload                   AS canon_payload
  FROM dbo.PayloadTransactions AS pt
)
, joined AS (
  SELECT
      b.*,
      si.TransactionDate                             AS official_ts,
      si.DeviceID                                    AS si_device
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
      j.audio_transcript,

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
   4) Crosstab (long-form) over production flat view
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

/* =========================================================================================
   5) Health quickcheck (counts + stamped ratio)
========================================================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_scout_health_check
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    total_flat      = COUNT(*),
    stamped_flat    = SUM(CASE WHEN txn_ts IS NOT NULL THEN 1 ELSE 0 END),
    pct_stamped     = AVG(CASE WHEN txn_ts IS NOT NULL THEN 1.0 ELSE 0.0 END)
  FROM dbo.v_transactions_flat_production;

  SELECT MIN(txn_ts) AS min_ts, MAX(txn_ts) AS max_ts
  FROM dbo.v_transactions_flat_production
  WHERE txn_ts IS NOT NULL;
END
GO