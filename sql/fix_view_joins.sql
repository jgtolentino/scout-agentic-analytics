GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Choose the transaction key once, here we assume PayloadTransactions.sessionId
   maps to SalesInteractions.canonical_tx_id. If your payload uses a different
   column (e.g., canonical_tx_id), switch CAST(pt.sessionId ...) accordingly. */

CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
;WITH si_min AS (
  SELECT
    CAST(si.canonical_tx_id AS varchar(64))      AS txid,
    MIN(CAST(si.interaction_ts AS datetime2(0))) AS txn_ts
  FROM dbo.SalesInteractions AS si
  WHERE si.interaction_ts IS NOT NULL
  GROUP BY CAST(si.canonical_tx_id AS varchar(64))
)
SELECT
  /* IDs + store */
  CAST(pt.sessionId AS varchar(64))         AS canonical_tx_id,
  CAST(pt.sessionId AS varchar(64))         AS transaction_id,
  CAST(pt.deviceId  AS varchar(64))         AS device_id,
  CAST(pt.storeId   AS int)                 AS store_id,
  CONCAT(N'Store_', pt.storeId)             AS store_name,

  /* placeholders (wire these later) */
  CAST(NULL AS varchar(8))        AS Region,
  CAST(NULL AS nvarchar(50))      AS ProvinceName,
  CAST(NULL AS nvarchar(80))      AS MunicipalityName,
  CAST(NULL AS nvarchar(120))     AS BarangayName,
  CAST(NULL AS char(9))           AS psgc_region,
  CAST(NULL AS char(9))           AS psgc_citymun,
  CAST(NULL AS char(9))           AS psgc_barangay,
  CAST(NULL AS float)             AS GeoLatitude,
  CAST(NULL AS float)             AS GeoLongitude,
  CAST(NULL AS nvarchar(max))     AS StorePolygon,

  /* merch & amounts — keep null-safe; we'll fill when you confirm column names */
  CAST(NULL AS nvarchar(100))     AS category,
  CAST(NULL AS nvarchar(120))     AS brand,
  CAST(NULL AS nvarchar(200))     AS product_name,
  CAST(pt.amount AS decimal(18,2)) AS total_amount,
  CAST(1 AS int)                  AS total_items,
  CAST(NULL AS nvarchar(50))      AS payment_method,
  CAST(NULL AS nvarchar(max))     AS audio_transcript,

  /* authoritative timestamp from SalesInteractions only */
  si_min.txn_ts                   AS txn_ts,
  CASE
    WHEN CAST(si_min.txn_ts AS time) >= '05:00' AND CAST(si_min.txn_ts AS time) < '12:00' THEN 'Morning'
    WHEN CAST(si_min.txn_ts AS time) >= '12:00' AND CAST(si_min.txn_ts AS time) < '17:00' THEN 'Afternoon'
    WHEN CAST(si_min.txn_ts AS time) >= '17:00' AND CAST(si_min.txn_ts AS time) < '21:00' THEN 'Evening'
    ELSE 'Night'
  END                              AS daypart,
  CASE WHEN DATEPART(WEEKDAY, si_min.txn_ts) IN (1,7) THEN 'Weekend' ELSE 'Weekday' END AS weekday_weekend,
  CONVERT(date, si_min.txn_ts)     AS transaction_date
FROM dbo.PayloadTransactions AS pt
JOIN si_min
  ON si_min.txid = CAST(pt.sessionId AS varchar(64))  -- << key fix
WHERE si_min.txn_ts IS NOT NULL;
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
  f.brand,                            -- remains NULL until we populate brand in flat view
  COUNT(*)                            AS txn_count,
  SUM(COALESCE(f.total_amount, 0))    AS total_amount
FROM dbo.v_transactions_flat_production AS f
GROUP BY CONVERT(date, f.txn_ts), f.store_id, f.store_name, f.daypart, f.brand;
GO

-- Sanity checks
SELECT
  SUM(CASE WHEN txn_ts IS NOT NULL THEN 1 ELSE 0 END)*1.0/NULLIF(COUNT(*),0) AS pct_non_null_ts,
  COUNT(*) AS rows_flat
FROM dbo.v_transactions_flat_production;

SELECT store_id, COUNT(*) AS rows_per_store
FROM dbo.v_transactions_flat_production
GROUP BY store_id
ORDER BY store_id;

SELECT TOP (10) *
FROM dbo.v_transactions_flat_production
ORDER BY txn_ts DESC;