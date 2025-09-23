-- ============================================================================
-- Azure SQL Blob-to-Gold ETL for Scout Analytics
-- Production-ready ETL: Azure Blob Storage → Azure SQL → Dashboard Views
-- Storage: projectscoutautoregstr/gdrive-scout-ingest/out/
-- Data: Real Filipino transaction data (35.9MB) + Store locations (32KB)
-- ============================================================================

-- ===========================================
-- 0) PREREQUISITES - FILL IN YOUR SAS TOKEN
-- ===========================================

/*
REQUIRED SETUP:
1. Get SAS token for storage account 'projectscoutautoregstr'
2. Replace <PASTE_SAS_TOKEN_HERE> with your SAS query string (starts with ?sv=...)
3. Run this script in Azure SQL Query Editor
*/

-- ===========================================
-- 1) ONE-TIME INFRASTRUCTURE SETUP
-- ===========================================

-- Master key for database-scoped credentials
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Scout_Analytics_Master_Key_2025!';

-- Database scoped credential for blob storage
IF EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name='cr_scout_blob_storage')
  DROP DATABASE SCOPED CREDENTIAL cr_scout_blob_storage;

CREATE DATABASE SCOPED CREDENTIAL cr_scout_blob_storage
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = '?se=2025-09-22T23%3A59%3A59Z&sp=rl&sv=2022-11-02&ss=b&srt=co&sig=kt0h3H7hY1yLnXZ6ieLCWbMTp2XSXs7wvBlc%2BrBWZ0Q%3D';

-- External data source for Scout blob storage
IF EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name='eds_scout_blob_storage')
  DROP EXTERNAL DATA SOURCE eds_scout_blob_storage;

CREATE EXTERNAL DATA SOURCE eds_scout_blob_storage
WITH (
  TYPE = BLOB_STORAGE,
  LOCATION = 'https://projectscoutautoregstr.blob.core.windows.net/gdrive-scout-ingest',
  CREDENTIAL = cr_scout_blob_storage
);

-- ===========================================
-- 2) SCHEMAS AND STAGING TABLES
-- ===========================================

-- Create schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='staging')
  EXEC('CREATE SCHEMA staging');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='ops')
  EXEC('CREATE SCHEMA ops');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='gold')
  EXEC('CREATE SCHEMA gold');

-- Raw transaction payloads from blob storage
IF OBJECT_ID('staging.scout_raw_transactions') IS NOT NULL
  DROP TABLE staging.scout_raw_transactions;

CREATE TABLE staging.scout_raw_transactions (
  source_file              nvarchar(400)  NOT NULL,
  load_timestamp           datetime2(0)   NOT NULL  DEFAULT SYSUTCDATETIME(),

  -- Core transaction data
  source_path              nvarchar(800)  NULL,
  transactionId            varchar(64)    NULL,
  deviceId                 varchar(64)    NULL,
  storeId                  varchar(20)    NULL,  -- text to handle mixed types
  timestamp_raw            nvarchar(100)  NULL,
  payload_json             nvarchar(max)  NULL,

  -- Extracted from JSON payload
  brand_name               nvarchar(200)  NULL,
  product_name             nvarchar(300)  NULL,
  category                 nvarchar(120)  NULL,
  unit_price               decimal(18,2)  NULL,
  total_price              decimal(18,2)  NULL,
  quantity                 int            NULL,
  payment_method           varchar(20)    NULL,
  audio_transcript         nvarchar(max)  NULL,
  confidence_score         decimal(5,2)   NULL,
  detection_method         varchar(50)    NULL
);

-- Store locations with polygon data
IF OBJECT_ID('staging.scout_store_locations') IS NOT NULL
  DROP TABLE staging.scout_store_locations;

CREATE TABLE staging.scout_store_locations (
  source_file              nvarchar(400) NOT NULL,
  load_timestamp           datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),

  StoreID                  int           NOT NULL,
  StoreName                nvarchar(200) NULL,
  MunicipalityName         nvarchar(80)  NULL,
  BarangayName             nvarchar(120) NULL,
  GeoLatitude              float         NULL,
  GeoLongitude             float         NULL,
  StorePolygon             nvarchar(max) NULL,
  psgc_region              char(9)       NULL,
  psgc_citymun             char(9)       NULL,
  psgc_barangay            char(9)       NULL
);

-- Operations log for tracking
IF OBJECT_ID('ops.etl_run_log') IS NOT NULL
  DROP TABLE ops.etl_run_log;

CREATE TABLE ops.etl_run_log (
  run_id                   bigint IDENTITY(1,1) PRIMARY KEY,
  started_utc              datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  ended_utc                datetime2(0) NULL,
  operation_type           varchar(50)  NOT NULL,
  files_processed          int          NULL,
  rows_staged              int          NULL,
  rows_merged              int          NULL,
  status                   varchar(20)  NULL, -- SUCCESS, FAILED, RUNNING
  error_message            nvarchar(max) NULL,
  notes                    nvarchar(4000) NULL
);

-- ===========================================
-- 3) FILE FORMATS FOR COPY INTO
-- ===========================================

-- CSV file format
IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name='fmt_csv_utf8')
  CREATE EXTERNAL FILE FORMAT fmt_csv_utf8
  WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS (
      FIELD_TERMINATOR = ',',
      STRING_DELIMITER = '"',
      FIRST_ROW = 2,
      USE_TYPE_DEFAULT = TRUE
    )
  );

-- GZIP compressed CSV format
IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name='fmt_csv_gzip')
  CREATE EXTERNAL FILE FORMAT fmt_csv_gzip
  WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    DATA_COMPRESSION = 'GZIP',
    FORMAT_OPTIONS (
      FIELD_TERMINATOR = ',',
      STRING_DELIMITER = '"',
      FIRST_ROW = 2,
      USE_TYPE_DEFAULT = TRUE
    )
  );

-- ===========================================
-- 4) COPY INTO PROCEDURES FROM BLOB STORAGE
-- ===========================================

-- Ingest transaction data from blob storage (supports CSV and GZIP)
CREATE OR ALTER PROCEDURE staging.sp_ingest_transactions_from_blob
  @folder nvarchar(200) = N'out/',
  @file_pattern nvarchar(100) = N'gdrive_transactions_flat*'
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @run_id bigint;
  INSERT ops.etl_run_log(operation_type, status, notes)
  VALUES ('INGEST_TRANSACTIONS', 'RUNNING', 'Starting transaction ingestion from blob');
  SET @run_id = SCOPE_IDENTITY();

  DECLARE @rows_loaded int = 0;
  DECLARE @error_msg nvarchar(max) = NULL;

  BEGIN TRY
    -- Try GZIP first for compressed files
    BEGIN TRY
      COPY INTO staging.scout_raw_transactions
        (source_path 1, transactionId 2, deviceId 3, storeId 4, timestamp_raw 5, payload_json 6)
      FROM 'https://projectscoutautoregstr.blob.core.windows.net/gdrive-scout-ingest/' + @folder + @file_pattern
      WITH (
        FILE_TYPE = 'CSV',
        CREDENTIAL = (IDENTITY='SHARED ACCESS SIGNATURE', SECRET = (SELECT secret FROM sys.database_scoped_credentials WHERE name='cr_scout_blob_storage')),
        FILE_FORMAT = fmt_csv_gzip,
        MAXERRORS = 10,
        ROWTERMINATOR = '0x0A',
        ERRORFILE = '_rejected/txn_gzip_' + CONVERT(varchar(19),SYSUTCDATETIME(),126)
      );

      SET @rows_loaded = @@ROWCOUNT;

    END TRY
    BEGIN CATCH
      -- Fallback to plain CSV
      COPY INTO staging.scout_raw_transactions
        (source_path 1, transactionId 2, deviceId 3, storeId 4, timestamp_raw 5, payload_json 6)
      FROM 'https://projectscoutautoregstr.blob.core.windows.net/gdrive-scout-ingest/' + @folder + @file_pattern
      WITH (
        FILE_TYPE = 'CSV',
        CREDENTIAL = (IDENTITY='SHARED ACCESS SIGNATURE', SECRET = (SELECT secret FROM sys.database_scoped_credentials WHERE name='cr_scout_blob_storage')),
        FILE_FORMAT = fmt_csv_utf8,
        MAXERRORS = 10,
        ROWTERMINATOR = '0x0A',
        ERRORFILE = '_rejected/txn_csv_' + CONVERT(varchar(19),SYSUTCDATETIME(),126)
      );

      SET @rows_loaded = @@ROWCOUNT;
    END CATCH;

    -- Update run log with success
    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        rows_staged = @rows_loaded,
        status = 'SUCCESS',
        notes = CONCAT('Successfully loaded ', @rows_loaded, ' transaction records')
    WHERE run_id = @run_id;

  END TRY
  BEGIN CATCH
    SET @error_msg = ERROR_MESSAGE();

    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        status = 'FAILED',
        error_message = @error_msg,
        notes = 'Failed to load transaction data from blob storage'
    WHERE run_id = @run_id;

    THROW;
  END CATCH;
END
GO

-- Ingest store location data from blob storage
CREATE OR ALTER PROCEDURE staging.sp_ingest_stores_from_blob
  @folder nvarchar(200) = N'out/',
  @file_pattern nvarchar(100) = N'stores_enriched_with_polygons*'
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @run_id bigint;
  INSERT ops.etl_run_log(operation_type, status, notes)
  VALUES ('INGEST_STORES', 'RUNNING', 'Starting store location ingestion from blob');
  SET @run_id = SCOPE_IDENTITY();

  DECLARE @rows_loaded int = 0;
  DECLARE @error_msg nvarchar(max) = NULL;

  BEGIN TRY
    COPY INTO staging.scout_store_locations
      (StoreID 1, StoreName 2, MunicipalityName 3, BarangayName 4,
       GeoLatitude 5, GeoLongitude 6, StorePolygon 7, psgc_region 8, psgc_citymun 9, psgc_barangay 10)
    FROM 'https://projectscoutautoregstr.blob.core.windows.net/gdrive-scout-ingest/' + @folder + @file_pattern
    WITH (
      FILE_TYPE = 'CSV',
      CREDENTIAL = (IDENTITY='SHARED ACCESS SIGNATURE', SECRET = (SELECT secret FROM sys.database_scoped_credentials WHERE name='cr_scout_blob_storage')),
      FILE_FORMAT = fmt_csv_utf8,
      MAXERRORS = 5,
      ROWTERMINATOR = '0x0A',
      ERRORFILE = '_rejected/stores_' + CONVERT(varchar(19),SYSUTCDATETIME(),126)
    );

    SET @rows_loaded = @@ROWCOUNT;

    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        rows_staged = @rows_loaded,
        status = 'SUCCESS',
        notes = CONCAT('Successfully loaded ', @rows_loaded, ' store location records')
    WHERE run_id = @run_id;

  END TRY
  BEGIN CATCH
    SET @error_msg = ERROR_MESSAGE();

    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        status = 'FAILED',
        error_message = @error_msg,
        notes = 'Failed to load store location data from blob storage'
    WHERE run_id = @run_id;

    THROW;
  END CATCH;
END
GO

-- ===========================================
-- 5) SILVER LAYER - DBO TABLES
-- ===========================================

-- Master stores table with location data
IF OBJECT_ID('dbo.Stores') IS NULL
CREATE TABLE dbo.Stores (
  StoreID                  int PRIMARY KEY,
  StoreName                nvarchar(200) NULL,
  MunicipalityName         nvarchar(80)  NULL,
  BarangayName             nvarchar(120) NULL,
  GeoLatitude              float         NULL,
  GeoLongitude             float         NULL,
  StorePolygon             nvarchar(max) NULL,
  psgc_region              char(9)       NULL,
  psgc_citymun             char(9)       NULL,
  psgc_barangay            char(9)       NULL,
  created_at               datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at               datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Fact transactions table with real Filipino product data
IF OBJECT_ID('dbo.FactTransactions') IS NULL
CREATE TABLE dbo.FactTransactions (
  canonical_tx_id          varchar(64)  NOT NULL,
  transaction_id           varchar(64)  NOT NULL,
  store_id                 int          NULL,
  device_id                varchar(64)  NULL,

  -- Product information (real Filipino brands)
  brand_name               nvarchar(200) NULL,
  product_name             nvarchar(300) NULL,
  category                 nvarchar(120) NULL,
  unit_price               decimal(18,2) NULL,
  total_price              decimal(18,2) NULL,
  quantity                 int          NULL,

  -- Transaction context
  payment_method           varchar(20)   NULL,
  audio_transcript         nvarchar(max) NULL,
  confidence_score         decimal(5,2)  NULL,
  detection_method         varchar(50)   NULL,

  -- Temporal data
  transaction_timestamp    datetime2(0)  NULL,

  -- Metadata
  payload_json             nvarchar(max) NULL,
  created_at               datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at               datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),

  CONSTRAINT PK_FactTransactions PRIMARY KEY (canonical_tx_id)
);

-- ===========================================
-- 6) MERGE PROCEDURES (UPSERT TO DBO)
-- ===========================================

-- Helper function for canonical transaction ID
CREATE OR ALTER FUNCTION dbo.fn_canonical_tx_id (@transaction_id varchar(64), @store_id int, @timestamp nvarchar(100))
RETURNS varchar(64) AS
BEGIN
  RETURN COALESCE(
    @transaction_id,
    CONCAT('TXN_', @store_id, '_', CONVERT(varchar(14), TRY_CAST(@timestamp AS datetime2), 112))
  );
END
GO

-- Merge stores from staging to dbo (no regression COALESCE)
CREATE OR ALTER PROCEDURE staging.sp_merge_stores
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @run_id bigint;
  INSERT ops.etl_run_log(operation_type, status, notes)
  VALUES ('MERGE_STORES', 'RUNNING', 'Starting store merge to dbo.Stores');
  SET @run_id = SCOPE_IDENTITY();

  DECLARE @rows_merged int = 0;

  BEGIN TRY
    MERGE dbo.Stores AS target
    USING (
      SELECT
        StoreID,
        MAX(StoreName) AS StoreName,
        MAX(MunicipalityName) AS MunicipalityName,
        MAX(BarangayName) AS BarangayName,
        MAX(GeoLatitude) AS GeoLatitude,
        MAX(GeoLongitude) AS GeoLongitude,
        MAX(StorePolygon) AS StorePolygon,
        MAX(psgc_region) AS psgc_region,
        MAX(psgc_citymun) AS psgc_citymun,
        MAX(psgc_barangay) AS psgc_barangay
      FROM staging.scout_store_locations
      WHERE StoreID IS NOT NULL
      GROUP BY StoreID
    ) AS source
    ON target.StoreID = source.StoreID

    WHEN MATCHED THEN UPDATE SET
      StoreName = COALESCE(source.StoreName, target.StoreName),
      MunicipalityName = COALESCE(source.MunicipalityName, target.MunicipalityName),
      BarangayName = COALESCE(source.BarangayName, target.BarangayName),
      GeoLatitude = COALESCE(source.GeoLatitude, target.GeoLatitude),
      GeoLongitude = COALESCE(source.GeoLongitude, target.GeoLongitude),
      StorePolygon = COALESCE(NULLIF(source.StorePolygon,''), target.StorePolygon),
      psgc_region = COALESCE(source.psgc_region, target.psgc_region),
      psgc_citymun = COALESCE(source.psgc_citymun, target.psgc_citymun),
      psgc_barangay = COALESCE(source.psgc_barangay, target.psgc_barangay),
      updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED THEN INSERT (
      StoreID, StoreName, MunicipalityName, BarangayName,
      GeoLatitude, GeoLongitude, StorePolygon,
      psgc_region, psgc_citymun, psgc_barangay
    ) VALUES (
      source.StoreID, source.StoreName, source.MunicipalityName, source.BarangayName,
      source.GeoLatitude, source.GeoLongitude, source.StorePolygon,
      source.psgc_region, source.psgc_citymun, source.psgc_barangay
    );

    SET @rows_merged = @@ROWCOUNT;

    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        rows_merged = @rows_merged,
        status = 'SUCCESS',
        notes = CONCAT('Successfully merged ', @rows_merged, ' store records')
    WHERE run_id = @run_id;

  END TRY
  BEGIN CATCH
    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        status = 'FAILED',
        error_message = ERROR_MESSAGE(),
        notes = 'Failed to merge store data'
    WHERE run_id = @run_id;

    THROW;
  END CATCH;
END
GO

-- Merge transactions from staging to dbo (with JSON parsing)
CREATE OR ALTER PROCEDURE staging.sp_merge_transactions
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @run_id bigint;
  INSERT ops.etl_run_log(operation_type, status, notes)
  VALUES ('MERGE_TRANSACTIONS', 'RUNNING', 'Starting transaction merge to dbo.FactTransactions');
  SET @run_id = SCOPE_IDENTITY();

  DECLARE @rows_merged int = 0;

  BEGIN TRY
    -- Parse JSON and merge into fact table
    ;WITH parsed_transactions AS (
      SELECT
        dbo.fn_canonical_tx_id(transactionId, TRY_CAST(storeId AS int), timestamp_raw) AS canonical_tx_id,
        transactionId AS transaction_id,
        TRY_CAST(storeId AS int) AS store_id,
        deviceId AS device_id,

        -- Extract from JSON payload or use direct columns
        COALESCE(
          JSON_VALUE(payload_json, '$.items[0].brandName'),
          brand_name
        ) AS brand_name,

        COALESCE(
          JSON_VALUE(payload_json, '$.items[0].productName'),
          product_name
        ) AS product_name,

        COALESCE(
          JSON_VALUE(payload_json, '$.items[0].category'),
          category
        ) AS category,

        COALESCE(
          TRY_CAST(JSON_VALUE(payload_json, '$.items[0].unitPrice') AS decimal(18,2)),
          unit_price
        ) AS unit_price,

        COALESCE(
          TRY_CAST(JSON_VALUE(payload_json, '$.totals.totalAmount') AS decimal(18,2)),
          total_price
        ) AS total_price,

        COALESCE(
          TRY_CAST(JSON_VALUE(payload_json, '$.items[0].quantity') AS int),
          quantity
        ) AS quantity,

        JSON_VALUE(payload_json, '$.transactionContext.paymentMethod') AS payment_method,
        JSON_VALUE(payload_json, '$.transactionContext.audioTranscript') AS audio_transcript,
        TRY_CAST(JSON_VALUE(payload_json, '$.items[0].confidence') AS decimal(5,2)) AS confidence_score,
        JSON_VALUE(payload_json, '$.items[0].detectionMethod') AS detection_method,

        TRY_CAST(timestamp_raw AS datetime2) AS transaction_timestamp,
        payload_json

      FROM staging.scout_raw_transactions
      WHERE transactionId IS NOT NULL
    )

    MERGE dbo.FactTransactions AS target
    USING parsed_transactions AS source
    ON target.canonical_tx_id = source.canonical_tx_id

    WHEN MATCHED THEN UPDATE SET
      store_id = COALESCE(source.store_id, target.store_id),
      device_id = COALESCE(source.device_id, target.device_id),
      brand_name = COALESCE(source.brand_name, target.brand_name),
      product_name = COALESCE(source.product_name, target.product_name),
      category = COALESCE(source.category, target.category),
      unit_price = COALESCE(source.unit_price, target.unit_price),
      total_price = COALESCE(source.total_price, target.total_price),
      quantity = COALESCE(source.quantity, target.quantity),
      payment_method = COALESCE(source.payment_method, target.payment_method),
      audio_transcript = COALESCE(source.audio_transcript, target.audio_transcript),
      confidence_score = COALESCE(source.confidence_score, target.confidence_score),
      detection_method = COALESCE(source.detection_method, target.detection_method),
      transaction_timestamp = COALESCE(source.transaction_timestamp, target.transaction_timestamp),
      payload_json = COALESCE(source.payload_json, target.payload_json),
      updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED THEN INSERT (
      canonical_tx_id, transaction_id, store_id, device_id,
      brand_name, product_name, category, unit_price, total_price, quantity,
      payment_method, audio_transcript, confidence_score, detection_method,
      transaction_timestamp, payload_json
    ) VALUES (
      source.canonical_tx_id, source.transaction_id, source.store_id, source.device_id,
      source.brand_name, source.product_name, source.category, source.unit_price,
      source.total_price, source.quantity, source.payment_method, source.audio_transcript,
      source.confidence_score, source.detection_method, source.transaction_timestamp, source.payload_json
    );

    SET @rows_merged = @@ROWCOUNT;

    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        rows_merged = @rows_merged,
        status = 'SUCCESS',
        notes = CONCAT('Successfully merged ', @rows_merged, ' transaction records')
    WHERE run_id = @run_id;

  END TRY
  BEGIN CATCH
    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        status = 'FAILED',
        error_message = ERROR_MESSAGE(),
        notes = 'Failed to merge transaction data'
    WHERE run_id = @run_id;

    THROW;
  END CATCH;
END
GO

-- ===========================================
-- 7) GOLD LAYER VIEWS FOR DASHBOARDS
-- ===========================================

-- Flat view with real Filipino product data
CREATE OR ALTER VIEW gold.v_transactions_flat
AS
SELECT
  -- Transaction identifiers
  f.canonical_tx_id AS Transaction_ID,
  f.transaction_id,
  f.store_id AS StoreID,
  s.StoreName,
  s.MunicipalityName AS Location,

  -- Product information (real Filipino brands)
  f.brand_name AS Brand,
  f.product_name,
  f.category AS Category,
  f.unit_price,
  f.total_price AS Transaction_Value,
  f.quantity AS Basket_Size,

  -- Transaction context
  f.payment_method,
  f.audio_transcript,
  f.confidence_score AS Data_Quality_Score,
  f.detection_method,

  -- Temporal dimensions
  f.transaction_timestamp AS Timestamp,
  CASE
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 5 AND 10 THEN 'Morning'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 11 AND 14 THEN 'Midday'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 15 AND 18 THEN 'Afternoon'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 19 AND 22 THEN 'Evening'
    ELSE 'LateNight'
  END AS Daypart,

  CASE
    WHEN DATEPART(WEEKDAY, f.transaction_timestamp) IN (1, 7) THEN 'Weekend'
    ELSE 'Weekday'
  END AS Weekday_vs_Weekend,

  -- Geographic data
  s.BarangayName,
  s.GeoLatitude,
  s.GeoLongitude,
  s.StorePolygon,

  -- Device information
  f.device_id AS DeviceID,

  -- Data source
  'Azure_Blob_Production' AS Data_Source,

  -- Raw data
  f.payload_json

FROM dbo.FactTransactions f
LEFT JOIN dbo.Stores s ON s.StoreID = f.store_id
WHERE f.total_price > 0
  AND f.store_id IS NOT NULL
  AND s.MunicipalityName IS NOT NULL
  AND (s.StorePolygon IS NOT NULL OR (s.GeoLatitude IS NOT NULL AND s.GeoLongitude IS NOT NULL));
GO

-- Cross-tabulation view for analytics (Brand × Daypart × Location)
CREATE OR ALTER VIEW gold.v_transactions_crosstab
AS
SELECT
  CONVERT(date, f.transaction_timestamp) AS transaction_date,
  s.MunicipalityName AS location,
  f.store_id,
  s.StoreName,

  -- Time dimension
  CASE
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 5 AND 10 THEN 'Morning'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 11 AND 14 THEN 'Midday'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 15 AND 18 THEN 'Afternoon'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 19 AND 22 THEN 'Evening'
    ELSE 'LateNight'
  END AS daypart,

  -- Product dimensions (real Filipino brands)
  f.brand_name,
  f.category,

  -- Metrics
  COUNT(*) AS transaction_count,
  SUM(f.total_price) AS total_revenue,
  AVG(f.total_price) AS avg_transaction_value,
  SUM(f.quantity) AS total_items,
  AVG(f.quantity) AS avg_basket_size,
  AVG(f.confidence_score) AS avg_confidence,

  -- Quality indicators
  COUNT(CASE WHEN f.brand_name IN ('Safeguard', 'Jack ''n Jill', 'Piattos', 'Combi', 'Pantene',
                                   'Head & Shoulders', 'Close Up', 'Cream Silk', 'Gatorade', 'C2', 'Coca-Cola')
             THEN 1 END) AS known_filipino_brands,
  COUNT(CASE WHEN f.confidence_score >= 70 THEN 1 END) AS high_confidence_transactions

FROM dbo.FactTransactions f
LEFT JOIN dbo.Stores s ON s.StoreID = f.store_id
WHERE f.total_price > 0
  AND f.transaction_timestamp IS NOT NULL
  AND f.store_id IS NOT NULL
  AND s.MunicipalityName IS NOT NULL
GROUP BY
  CONVERT(date, f.transaction_timestamp),
  s.MunicipalityName,
  f.store_id,
  s.StoreName,
  CASE
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 5 AND 10 THEN 'Morning'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 11 AND 14 THEN 'Midday'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 15 AND 18 THEN 'Afternoon'
    WHEN DATEPART(HOUR, f.transaction_timestamp) BETWEEN 19 AND 22 THEN 'Evening'
    ELSE 'LateNight'
  END,
  f.brand_name,
  f.category;
GO

-- ===========================================
-- 8) ONE-BUTTON ORCHESTRATION
-- ===========================================

-- Master orchestration procedure
CREATE OR ALTER PROCEDURE dbo.sp_run_scout_etl
  @folder nvarchar(200) = N'out/'
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @start_time datetime2 = SYSUTCDATETIME();
  DECLARE @run_id bigint;

  INSERT ops.etl_run_log(operation_type, status, notes)
  VALUES ('FULL_ETL', 'RUNNING', CONCAT('Starting full Scout ETL pipeline at ', @start_time));
  SET @run_id = SCOPE_IDENTITY();

  BEGIN TRY
    -- 1. Ingest transaction data from blob
    EXEC staging.sp_ingest_transactions_from_blob @folder=@folder;

    -- 2. Ingest store locations from blob
    EXEC staging.sp_ingest_stores_from_blob @folder=@folder;

    -- 3. Merge stores to dbo
    EXEC staging.sp_merge_stores;

    -- 4. Merge transactions to dbo
    EXEC staging.sp_merge_transactions;

    -- 5. Update completion status
    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        status = 'SUCCESS',
        notes = CONCAT('Full ETL pipeline completed successfully in ',
                      DATEDIFF(second, @start_time, SYSUTCDATETIME()), ' seconds')
    WHERE run_id = @run_id;

    -- 6. Return summary
    SELECT
      'ETL_COMPLETE' AS status,
      DATEDIFF(second, @start_time, SYSUTCDATETIME()) AS duration_seconds,
      (SELECT COUNT(*) FROM dbo.Stores) AS total_stores,
      (SELECT COUNT(*) FROM dbo.FactTransactions) AS total_transactions,
      (SELECT COUNT(DISTINCT brand_name) FROM dbo.FactTransactions WHERE brand_name IS NOT NULL) AS unique_brands,
      (SELECT TOP 1 ended_utc FROM ops.etl_run_log WHERE operation_type = 'FULL_ETL' ORDER BY run_id DESC) AS completed_at;

  END TRY
  BEGIN CATCH
    UPDATE ops.etl_run_log
    SET ended_utc = SYSUTCDATETIME(),
        status = 'FAILED',
        error_message = ERROR_MESSAGE(),
        notes = CONCAT('ETL pipeline failed: ', ERROR_MESSAGE())
    WHERE run_id = @run_id;

    THROW;
  END CATCH;
END
GO

-- ===========================================
-- 9) READY TO USE - EXECUTE THIS
-- ===========================================

/*
DEPLOYMENT CHECKLIST:

1. Replace <PASTE_SAS_TOKEN_HERE> with your actual SAS token
2. Run this entire script in Azure SQL Query Editor
3. Execute the ETL pipeline:

   EXEC dbo.sp_run_scout_etl @folder = N'out/';

4. Validate results:

   SELECT * FROM gold.v_transactions_flat ORDER BY Timestamp DESC;
   SELECT * FROM gold.v_transactions_crosstab WHERE transaction_date >= DATEADD(day, -30, GETDATE());

5. Point your dashboard to:
   - gold.v_transactions_flat (for detailed analysis)
   - gold.v_transactions_crosstab (for aggregated metrics)

READY FOR PRODUCTION WITH REAL FILIPINO BRANDS! 🇵🇭
*/