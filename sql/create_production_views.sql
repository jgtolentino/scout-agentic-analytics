/* ===== Run this in SQL-TBWA-ProjectScout-Reporting-Prod ===== */

/* 0) Guards */
IF SCHEMA_ID('dbo') IS NULL THROW 50000, 'dbo schema missing', 1;
IF OBJECT_ID('dbo.PayloadTransactions','U') IS NULL THROW 50000, 'Missing dbo.PayloadTransactions', 1;
IF OBJECT_ID('dbo.SalesInteractions','U') IS NULL THROW 50000, 'Missing dbo.SalesInteractions', 1;

/* 1) Flat production view (15-col shape, safe NULLs for unknowns) */
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
WITH si_min AS (
  SELECT
    CAST(si.canonical_tx_id AS varchar(64)) AS txid,
    MIN(CAST(si.interaction_ts AS datetime2(0))) AS txn_ts
  FROM dbo.SalesInteractions si
  WHERE si.interaction_ts IS NOT NULL
  GROUP BY CAST(si.canonical_tx_id AS varchar(64))
)
SELECT
  -- IDs / store
  CAST(pt.sessionId AS varchar(64))         AS canonical_tx_id,
  CAST(pt.sessionId AS varchar(64))         AS transaction_id,
  CAST(pt.deviceId  AS varchar(64))         AS device_id,
  CAST(pt.storeId   AS int)                 AS store_id,
  CONCAT(N'Store_', pt.storeId)             AS store_name,

  -- Geo/demographics (not modeled here yet)
  CAST(NULL AS varchar(8))                  AS Region,
  CAST(NULL AS nvarchar(50))                AS ProvinceName,
  CAST(NULL AS nvarchar(80))                AS MunicipalityName,
  CAST(NULL AS nvarchar(120))               AS BarangayName,
  CAST(NULL AS char(9))                     AS psgc_region,
  CAST(NULL AS char(9))                     AS psgc_citymun,
  CAST(NULL AS char(9))                     AS psgc_barangay,
  CAST(NULL AS float)                       AS GeoLatitude,
  CAST(NULL AS float)                       AS GeoLongitude,
  CAST(NULL AS nvarchar(max))               AS StorePolygon,

  -- Merch / amounts (put NULLs until you wire real columns)
  CAST(NULL AS nvarchar(100))               AS category,
  CAST(NULL AS nvarchar(120))               AS brand,
  CAST(NULL AS nvarchar(200))               AS product_name,
  CAST(NULL AS decimal(18,2))               AS total_amount,
  CAST(NULL AS int)                         AS total_items,
  CAST(NULL AS nvarchar(50))                AS payment_method,
  CAST(NULL AS nvarchar(max))               AS audio_transcript,

  -- Authoritative time from SalesInteractions only
  si_min.txn_ts                              AS txn_ts,
  CASE
    WHEN CAST(si_min.txn_ts AS time) >= '05:00' AND CAST(si_min.txn_ts AS time) < '12:00' THEN 'Morning'
    WHEN CAST(si_min.txn_ts AS time) >= '12:00' AND CAST(si_min.txn_ts AS time) < '17:00' THEN 'Afternoon'
    WHEN CAST(si_min.txn_ts AS time) >= '17:00' AND CAST(si_min.txn_ts AS time) < '21:00' THEN 'Evening'
    ELSE 'Night'
  END                                        AS daypart,
  CASE WHEN DATEPART(WEEKDAY, si_min.txn_ts) IN (1,7) THEN 'Weekend' ELSE 'Weekday' END AS weekday_weekend,
  CONVERT(date, si_min.txn_ts)               AS transaction_date
FROM dbo.PayloadTransactions pt
JOIN si_min
  ON si_min.txid = CAST(pt.sessionId AS varchar(64))
WHERE si_min.txn_ts IS NOT NULL;
GO

/* 2) Long-form crosstab (date × store × daypart × brand [NULL]) */
CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production
AS
SELECT
  CONVERT(date, f.txn_ts)      AS [date],
  f.store_id,
  f.store_name,
  f.daypart,
  f.brand,                      -- will be NULL until you map brand in flat view
  COUNT(*)                      AS txn_count,
  SUM(COALESCE(f.total_amount,0)) AS total_amount
FROM dbo.v_transactions_flat_production f
GROUP BY CONVERT(date, f.txn_ts), f.store_id, f.store_name, f.daypart, f.brand;
GO

/* 3) Health check */
CREATE OR ALTER PROCEDURE dbo.sp_scout_health_check
AS
BEGIN
  SET NOCOUNT ON;
  SELECT 'flat_rows' AS metric, COUNT(*)::bigint AS value FROM dbo.v_transactions_flat_production;
  SELECT 'si_rows'   AS metric, COUNT(*)::bigint AS value FROM dbo.SalesInteractions;
  SELECT 'flat_min_ts' AS metric, MIN(txn_ts) FROM dbo.v_transactions_flat_production;
  SELECT 'flat_max_ts' AS metric, MAX(txn_ts) FROM dbo.v_transactions_flat_production;
END
GO

/* 4) Refresh wrapper (no-op for now; extend when you add materializations) */
CREATE OR ALTER PROCEDURE dbo.sp_refresh_analytics_views
AS
BEGIN
  SET NOCOUNT ON;
  -- Touch the views to ensure metadata is valid
  EXEC sys.sp_refreshview 'dbo.v_transactions_flat_production';
  EXEC sys.sp_refreshview 'dbo.v_transactions_crosstab_production';
END
GO

/* 5) Helpful indexes if missing */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_SalesInteractions_txid_ts' AND object_id=OBJECT_ID('dbo.SalesInteractions'))
  CREATE INDEX IX_SalesInteractions_txid_ts ON dbo.SalesInteractions(canonical_tx_id, interaction_ts DESC);
GO

/* 6) Smoke tests */
SELECT TOP (5) * FROM dbo.v_transactions_flat_production ORDER BY txn_ts DESC;
SELECT TOP (5) * FROM dbo.v_transactions_crosstab_production ORDER BY [date] DESC, store_id, daypart;
EXEC dbo.sp_scout_health_check;