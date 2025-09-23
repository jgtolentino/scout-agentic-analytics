-- File: sql/deploy_end_state.sql
-- Complete end-state Scout analytics deployment
-- Usage: SQLCMDSERVER="..." SQLCMDDBNAME="..." SQLCMDUSER="..." SQLCMDPASSWORD="..." sqlcmd -i sql/deploy_end_state.sql

PRINT 'Starting Scout Analytics End-State Deployment...';

-- =========================================================================
-- 0) Prerequisites: scout_reader user
-- =========================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='scout_reader')
BEGIN
  CREATE USER [scout_reader] WITHOUT LOGIN;
  EXEC sp_addrolemember 'db_datareader', 'scout_reader';
  PRINT 'Created scout_reader user';
END
ELSE PRINT 'scout_reader user already exists';

-- =========================================================================
-- 1) Authoritative Tables
-- =========================================================================

-- DeviceStoreMap (DB-driven mapping)
IF OBJECT_ID('dbo.DeviceStoreMap','U') IS NULL
BEGIN
  CREATE TABLE dbo.DeviceStoreMap (
    DeviceID        nvarchar(64)  NOT NULL,
    StoreID         int           NOT NULL,
    EffectiveFrom   datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME()),
    EffectiveTo     datetime2(0)  NULL,
    UpdatedBy       sysname       NOT NULL DEFAULT (SUSER_SNAME()),
    UpdatedAt       datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_DeviceStoreMap PRIMARY KEY CLUSTERED (DeviceID, EffectiveFrom)
  );
  PRINT 'Created DeviceStoreMap table';
END
ELSE PRINT 'DeviceStoreMap table already exists';

-- Stores table
IF OBJECT_ID('dbo.Stores','U') IS NULL
BEGIN
  CREATE TABLE dbo.Stores (
    StoreID           int           NOT NULL PRIMARY KEY,
    StoreName         nvarchar(200) NOT NULL,
    MunicipalityName  nvarchar(100) NULL,
    BarangayName      nvarchar(120) NULL,
    GeoLatitude       float         NULL,
    GeoLongitude      float         NULL,
    CreatedAt         datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME()),
    UpdatedAt         datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME())
  );
  PRINT 'Created Stores table';
END
ELSE PRINT 'Stores table already exists';

-- =========================================================================
-- 2) Performance Indexes
-- =========================================================================

-- DeviceStoreMap indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_DeviceStoreMap_Current' AND object_id = OBJECT_ID('dbo.DeviceStoreMap'))
BEGIN
  CREATE INDEX IX_DeviceStoreMap_Current ON dbo.DeviceStoreMap(DeviceID, EffectiveTo) WHERE EffectiveTo IS NULL;
  PRINT 'Created IX_DeviceStoreMap_Current index';
END

-- Stores indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Stores_Muni' AND object_id = OBJECT_ID('dbo.Stores'))
BEGIN
  CREATE INDEX IX_Stores_Muni ON dbo.Stores (MunicipalityName);
  PRINT 'Created IX_Stores_Muni index';
END

-- PayloadTransactions index for canonical derivation
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PayloadTransactions_sessionId' AND object_id = OBJECT_ID('dbo.PayloadTransactions'))
BEGIN
  CREATE INDEX IX_PayloadTransactions_sessionId ON dbo.PayloadTransactions(sessionId);
  PRINT 'Created IX_PayloadTransactions_sessionId index';
END

-- SalesInteractions index for join performance
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_SalesInteractions_InteractionID' AND object_id = OBJECT_ID('dbo.SalesInteractions'))
BEGIN
  CREATE INDEX IX_SalesInteractions_InteractionID ON dbo.SalesInteractions(InteractionID);
  PRINT 'Created IX_SalesInteractions_InteractionID index';
END

-- =========================================================================
-- 3) Seed Tables with Current Data
-- =========================================================================

-- Seed DeviceStoreMap from existing PayloadTransactions
IF NOT EXISTS (SELECT 1 FROM dbo.DeviceStoreMap)
BEGIN
  INSERT INTO dbo.DeviceStoreMap (DeviceID, StoreID)
  SELECT DISTINCT deviceId, TRY_CAST(storeId AS int)
  FROM dbo.PayloadTransactions
  WHERE deviceId IS NOT NULL AND TRY_CAST(storeId AS int) IS NOT NULL;

  PRINT 'Seeded DeviceStoreMap with ' + CAST(@@ROWCOUNT AS varchar(10)) + ' device-store mappings';
END

-- Seed Stores from existing data
IF NOT EXISTS (SELECT 1 FROM dbo.Stores)
BEGIN
  INSERT INTO dbo.Stores (StoreID, StoreName)
  SELECT DISTINCT TRY_CAST(storeId AS int), CONCAT('Store_', storeId)
  FROM dbo.PayloadTransactions
  WHERE TRY_CAST(storeId AS int) IS NOT NULL;

  PRINT 'Seeded Stores with ' + CAST(@@ROWCOUNT AS varchar(10)) + ' store records';
END

GO

-- =========================================================================
-- 4) Production Views (JSON-safe, canonical joins, SI timestamp authority)
-- =========================================================================

-- Flat production view
CREATE OR ALTER VIEW dbo.v_transactions_flat_production
AS
WITH f AS (
  SELECT
    -- Canonical ID from payload JSON if valid else sessionId (normalized)
    LOWER(REPLACE(COALESCE(
      CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.transactionId') END,
      pt.sessionId
    ),'-','')) AS canonical_tx_id,

    CAST(pt.sessionId AS varchar(64)) AS transaction_id,
    CAST(pt.deviceId  AS varchar(64)) AS device_id,

    -- Resolve store via DB mapping first, else payload storeId
    COALESCE(
      CAST(dm.StoreID AS int),
      TRY_CAST(pt.storeId AS int)
    ) AS store_id,

    -- Prefer real Stores name if present
    COALESCE(s.StoreName, CONCAT(N'Store_', TRY_CAST(pt.storeId AS int))) AS store_name,

    -- Business fields from payload (JSON-guarded)
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.items[0].brandName') END AS brand,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.items[0].productName') END AS product_name,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.items[0].category') END AS category,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN TRY_CONVERT(decimal(12,2), JSON_VALUE(pt.payload_json,'$.totals.totalAmount')) END AS total_amount,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN TRY_CONVERT(int, JSON_VALUE(pt.payload_json,'$.totals.totalItems')) END AS total_items,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.transactionContext.paymentMethod') END AS payment_method,
    CASE WHEN ISJSON(pt.payload_json)=1 THEN JSON_VALUE(pt.payload_json,'$.transactionContext.audioTranscript') END AS audio_transcript
  FROM dbo.PayloadTransactions AS pt
  OUTER APPLY (
      SELECT TOP 1 dsm.StoreID
      FROM dbo.DeviceStoreMap dsm
      WHERE dsm.DeviceID = pt.deviceId AND dsm.EffectiveTo IS NULL
  ) AS dm
  LEFT JOIN dbo.Stores AS s
    ON s.StoreID = COALESCE(TRY_CAST(dm.StoreID AS int), TRY_CAST(pt.storeId AS int))
),
si AS (
  SELECT
    LOWER(REPLACE(CAST(InteractionID AS varchar(64)),'-','')) AS canonical_tx_id,
    CAST(TransactionDate AS datetime2(0)) AS txn_ts
  FROM dbo.SalesInteractions
)
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
  f.audio_transcript,
  -- Authoritative timestamp ONLY from SalesInteractions
  si.txn_ts,
  CONVERT(date, si.txn_ts) AS transaction_date,
  CASE WHEN si.txn_ts IS NULL THEN NULL
       WHEN DATEPART(HOUR, si.txn_ts) BETWEEN 6  AND 11 THEN 'Morning'
       WHEN DATEPART(HOUR, si.txn_ts) BETWEEN 12 AND 17 THEN 'Afternoon'
       WHEN DATEPART(HOUR, si.txn_ts) BETWEEN 18 AND 21 THEN 'Evening'
       ELSE 'Night' END AS daypart,
  CASE WHEN si.txn_ts IS NULL THEN NULL
       WHEN DATEPART(WEEKDAY, si.txn_ts) IN (1,7) THEN 'Weekend' ELSE 'Weekday' END AS weekday_weekend
FROM f
LEFT JOIN si ON si.canonical_tx_id = f.canonical_tx_id;

PRINT 'Created/Updated v_transactions_flat_production view';
GO

-- Crosstab production view
CREATE OR ALTER VIEW dbo.v_transactions_crosstab_production
AS
SELECT
  CONVERT(date, txn_ts) AS [date],
  store_id,
  store_name,
  daypart,
  ISNULL(brand,'Unknown') AS brand,
  COUNT(*) AS txn_count,
  SUM(COALESCE(total_amount,0)) AS total_amount,
  CAST(AVG(CAST(NULLIF(total_items,0) AS float)) AS decimal(12,2)) AS avg_basket_amount,
  0 AS substitution_events
FROM dbo.v_transactions_flat_production
WHERE txn_ts IS NOT NULL
GROUP BY CONVERT(date, txn_ts), store_id, store_name, daypart, ISNULL(brand,'Unknown');

PRINT 'Created/Updated v_transactions_crosstab_production view';
GO

-- v24 compatibility view
CREATE OR ALTER VIEW dbo.v_transactions_flat_v24
AS
SELECT
  CAST(transaction_id AS varchar(64)) AS TransactionID,
  CAST(canonical_tx_id AS varchar(64)) AS CanonicalTxID,
  CAST(device_id AS varchar(64)) AS DeviceID,
  CAST(store_id AS int) AS StoreID,
  CAST(store_name AS nvarchar(200)) AS StoreName,
  CAST(NULL AS varchar(8)) AS Region,
  CAST(NULL AS nvarchar(50)) AS ProvinceName,
  CAST(NULL AS nvarchar(80)) AS MunicipalityName,
  CAST(NULL AS nvarchar(120)) AS BarangayName,
  CAST(NULL AS char(9)) AS psgc_region,
  CAST(NULL AS char(9)) AS psgc_citymun,
  CAST(NULL AS char(9)) AS psgc_barangay,
  CAST(NULL AS float) AS GeoLatitude,
  CAST(NULL AS float) AS GeoLongitude,
  CAST(NULL AS nvarchar(max)) AS StorePolygon,
  CAST(total_amount AS decimal(12,2)) AS Amount,
  CAST(total_items AS int) AS Basket_Item_Count,
  CAST(weekday_weekend AS varchar(8)) AS WeekdayOrWeekend,
  CAST(daypart AS varchar(10)) AS TimeOfDay,
  CAST(NULL AS bit) AS BasketFlag,
  CAST(NULL AS nvarchar(50)) AS AgeBracket,
  CAST(NULL AS nvarchar(20)) AS Gender,
  CAST(NULL AS nvarchar(50)) AS Role,
  CAST(NULL AS bit) AS Substitution_Flag,
  CAST(txn_ts AS datetime2(0)) AS Txn_TS
FROM dbo.v_transactions_flat_production;

PRINT 'Created/Updated v_transactions_flat_v24 compatibility view';
GO

-- =========================================================================
-- 5) Operational Stored Procedures
-- =========================================================================

-- Device-store mapping upsert
CREATE OR ALTER PROCEDURE dbo.sp_upsert_device_store
  @DeviceID  nvarchar(64),
  @StoreID   int
AS
BEGIN
  SET NOCOUNT ON;

  -- Close any current mapping
  UPDATE dbo.DeviceStoreMap
    SET EffectiveTo = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME(), UpdatedBy = SUSER_SNAME()
  WHERE DeviceID=@DeviceID AND EffectiveTo IS NULL;

  -- Insert new current mapping
  INSERT dbo.DeviceStoreMap(DeviceID, StoreID, EffectiveFrom)
  VALUES (@DeviceID, @StoreID, SYSUTCDATETIME());
END

PRINT 'Created/Updated sp_upsert_device_store procedure';
GO

-- Refresh views metadata
CREATE OR ALTER PROCEDURE dbo.sp_refresh_analytics_views
AS
BEGIN
  SET NOCOUNT ON;
  EXEC sys.sp_refreshview N'dbo.v_transactions_flat_production';
  EXEC sys.sp_refreshview N'dbo.v_transactions_crosstab_production';
  EXEC sys.sp_refreshview N'dbo.v_transactions_flat_v24';
END

PRINT 'Created/Updated sp_refresh_analytics_views procedure';
GO

-- Parity check between flat and crosstab views
CREATE OR ALTER PROCEDURE dbo.sp_parity_flat_vs_crosstab
  @days_back int = 30
AS
BEGIN
  SET NOCOUNT ON;

  WITH f AS (
    SELECT COUNT(*) n, SUM(COALESCE(total_amount,0)) amt
    FROM dbo.v_transactions_flat_production
    WHERE transaction_date >= CONVERT(date, DATEADD(day, -@days_back, SYSUTCDATETIME()))
  ),
  c AS (
    SELECT SUM(txn_count) n, SUM(total_amount) amt
    FROM dbo.v_transactions_crosstab_production
    WHERE [date] >= CONVERT(date, DATEADD(day, -@days_back, SYSUTCDATETIME()))
  )
  SELECT f.n AS flat_n, c.n AS xtab_n,
         f.amt AS flat_amt, c.amt AS xtab_amt,
         CAST(ABS(1.0 - 1.0*c.n / NULLIF(f.n,0)) AS decimal(18,6)) AS n_diff_ratio,
         CAST(ABS(1.0 - 1.0*c.amt/ NULLIF(f.amt,0)) AS decimal(18,6)) AS amt_diff_ratio;
END

PRINT 'Created/Updated sp_parity_flat_vs_crosstab procedure';
GO

-- Health check procedure
CREATE OR ALTER PROCEDURE dbo.sp_scout_health_check
AS
BEGIN
  SET NOCOUNT ON;

  SELECT 'payload' AS src,
         COUNT(*) AS rows_total,
         SUM(CASE WHEN ISJSON(payload_json)=0 THEN 1 ELSE 0 END) AS bad_json
  FROM dbo.PayloadTransactions;

  SELECT 'flat' AS src,
         COUNT(*) AS rows_total,
         SUM(CASE WHEN txn_ts IS NOT NULL THEN 1 ELSE 0 END) AS with_ts
  FROM dbo.v_transactions_flat_production;

  SELECT MIN(txn_ts) AS min_ts, MAX(txn_ts) AS max_ts
  FROM dbo.v_transactions_flat_production;
END

PRINT 'Created/Updated sp_scout_health_check procedure';
GO

-- =========================================================================
-- 6) Reader Permissions
-- =========================================================================

GRANT SELECT ON OBJECT::dbo.v_transactions_flat_production TO [scout_reader];
GRANT SELECT ON OBJECT::dbo.v_transactions_crosstab_production TO [scout_reader];
GRANT SELECT ON OBJECT::dbo.v_transactions_flat_v24 TO [scout_reader];
GRANT SELECT ON OBJECT::dbo.Stores TO [scout_reader];
GRANT SELECT ON OBJECT::dbo.DeviceStoreMap TO [scout_reader];

GRANT EXECUTE ON OBJECT::dbo.sp_parity_flat_vs_crosstab TO [scout_reader];
GRANT EXECUTE ON OBJECT::dbo.sp_scout_health_check TO [scout_reader];

PRINT 'Granted permissions to scout_reader';

-- =========================================================================
-- 7) Final Validation
-- =========================================================================

PRINT 'Running final validation...';

-- Test views can be queried
DECLARE @flat_count int, @xtab_count int, @v24_count int;

SELECT @flat_count = COUNT(*) FROM dbo.v_transactions_flat_production;
SELECT @xtab_count = COUNT(*) FROM dbo.v_transactions_crosstab_production;
SELECT @v24_count = COUNT(*) FROM dbo.v_transactions_flat_v24;

PRINT 'Flat production view: ' + CAST(@flat_count AS varchar(10)) + ' records';
PRINT 'Crosstab production view: ' + CAST(@xtab_count AS varchar(10)) + ' records';
PRINT 'v24 compatibility view: ' + CAST(@v24_count AS varchar(10)) + ' records';

-- Test health check
PRINT 'Testing health check procedure...';
EXEC dbo.sp_scout_health_check;

PRINT 'Scout Analytics End-State Deployment COMPLETED SUCCESSFULLY!';
PRINT '';
PRINT 'Ready-to-use views:';
PRINT '  - dbo.v_transactions_flat_production (main dashboard view)';
PRINT '  - dbo.v_transactions_crosstab_production (aggregated view)';
PRINT '  - dbo.v_transactions_flat_v24 (compatibility view)';
PRINT '';
PRINT 'Available procedures:';
PRINT '  - EXEC dbo.sp_scout_health_check (system health)';
PRINT '  - EXEC dbo.sp_parity_flat_vs_crosstab (data consistency)';
PRINT '  - EXEC dbo.sp_upsert_device_store @DeviceID, @StoreID (device mapping)';

GO