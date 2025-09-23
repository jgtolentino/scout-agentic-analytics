-- ============================================================================
-- Azure SQL Simple ETL for Scout Analytics
-- Compatible with Azure SQL Database - Step by Step Deployment
-- ============================================================================

-- ===========================================
-- 1) INFRASTRUCTURE SETUP
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
-- 2) CREATE SCHEMAS
-- ===========================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
  EXEC('CREATE SCHEMA staging');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
  EXEC('CREATE SCHEMA gold');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
  EXEC('CREATE SCHEMA audit');

-- ===========================================
-- 3) STAGING TABLES
-- ===========================================

-- Drop existing tables if they exist
IF OBJECT_ID('staging.transactions', 'U') IS NOT NULL
  DROP TABLE staging.transactions;

IF OBJECT_ID('staging.stores', 'U') IS NOT NULL
  DROP TABLE staging.stores;

-- Staging transactions table
CREATE TABLE staging.transactions (
    source_path NVARCHAR(500),
    canonical_tx_id NVARCHAR(100) NOT NULL,
    device_id NVARCHAR(50),
    store_id NVARCHAR(20),
    timestamp_raw NVARCHAR(50),
    raw_json NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETDATE(),
    INDEX IX_staging_transactions_tx_id (canonical_tx_id),
    INDEX IX_staging_transactions_store_id (store_id),
    INDEX IX_staging_transactions_created_at (created_at)
);

-- Staging stores table
CREATE TABLE staging.stores (
    store_id NVARCHAR(20) NOT NULL,
    store_name NVARCHAR(200),
    region_name NVARCHAR(100),
    city_name NVARCHAR(100),
    latitude FLOAT,
    longitude FLOAT,
    created_at DATETIME2 DEFAULT GETDATE(),
    INDEX IX_staging_stores_store_id (store_id)
);

-- ===========================================
-- 4) AUDIT TABLE
-- ===========================================

IF OBJECT_ID('audit.export_log', 'U') IS NOT NULL
  DROP TABLE audit.export_log;

CREATE TABLE audit.export_log (
    export_id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    export_timestamp DATETIME2 DEFAULT GETDATE(),
    operation_type NVARCHAR(50),
    record_count INT,
    file_hash NVARCHAR(100),
    validation_status NVARCHAR(20),
    notes NVARCHAR(500)
);

-- ===========================================
-- 5) TEST BLOB CONNECTIVITY
-- ===========================================

PRINT 'Testing blob storage connectivity...';

-- Test basic blob access with OPENROWSET
SELECT TOP 5 *
FROM OPENROWSET(
    BULK 'out/sample_100.csv',
    DATA_SOURCE = 'eds_scout_blob_storage',
    FORMAT = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
) AS [rows];

PRINT 'Blob connectivity test completed.';

-- ===========================================
-- 6) SIMPLE DATA LOADING PROCEDURE
-- ===========================================

CREATE OR ALTER PROCEDURE staging.sp_load_sample_data
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @record_count INT = 0;

    BEGIN TRY
        -- Clear existing staging data
        TRUNCATE TABLE staging.transactions;

        -- Load sample data from blob storage
        INSERT INTO staging.transactions (
            source_path,
            canonical_tx_id,
            device_id,
            store_id,
            timestamp_raw,
            raw_json
        )
        SELECT
            [1] as source_path,
            [2] as canonical_tx_id,
            [3] as device_id,
            [4] as store_id,
            [5] as timestamp_raw,
            [6] as raw_json
        FROM OPENROWSET(
            BULK 'out/sample_100.csv',
            DATA_SOURCE = 'eds_scout_blob_storage',
            FORMAT = 'CSV',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            FIRSTROW = 2
        ) AS [rows];

        SET @record_count = @@ROWCOUNT;

        -- Log success
        INSERT INTO audit.export_log (operation_type, record_count, validation_status, notes)
        VALUES ('LOAD_SAMPLE_DATA', @record_count, 'SUCCESS',
                'Loaded ' + CAST(@record_count AS NVARCHAR(10)) + ' records in ' +
                CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR(10)) + ' seconds');

        PRINT 'Successfully loaded ' + CAST(@record_count AS NVARCHAR(10)) + ' records';

    END TRY
    BEGIN CATCH
        -- Log error
        INSERT INTO audit.export_log (operation_type, record_count, validation_status, notes)
        VALUES ('LOAD_SAMPLE_DATA', 0, 'ERROR', ERROR_MESSAGE());

        PRINT 'Error loading data: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;

-- ===========================================
-- 7) SIMPLE GOLD VIEW
-- ===========================================

CREATE OR ALTER VIEW gold.v_transactions_simple
AS
SELECT
    canonical_tx_id,
    device_id,
    store_id,
    created_at as load_timestamp,

    -- Extract brand from JSON
    JSON_VALUE(raw_json, '$.items[0].brandName') as brand,
    JSON_VALUE(raw_json, '$.items[0].productName') as product_name,
    JSON_VALUE(raw_json, '$.items[0].category') as category,

    -- Extract totals from JSON
    TRY_CAST(JSON_VALUE(raw_json, '$.totals.totalAmount') AS FLOAT) as total_amount,
    TRY_CAST(JSON_VALUE(raw_json, '$.totals.totalItems') AS INT) as total_items,

    -- Extract transaction context
    JSON_VALUE(raw_json, '$.transactionContext.paymentMethod') as payment_method,
    JSON_VALUE(raw_json, '$.transactionContext.audioTranscript') as audio_transcript,

    -- Source data
    source_path,
    raw_json

FROM staging.transactions
WHERE JSON_VALUE(raw_json, '$.items[0].brandName') IS NOT NULL;

-- ===========================================
-- 8) VALIDATION QUERIES
-- ===========================================

CREATE OR ALTER PROCEDURE staging.sp_validate_data
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== Scout ETL Validation Report ===';
    PRINT '';

    -- 1. Record counts
    DECLARE @staging_count INT = (SELECT COUNT(*) FROM staging.transactions);
    DECLARE @gold_count INT = (SELECT COUNT(*) FROM gold.v_transactions_simple);

    PRINT '1. RECORD COUNTS:';
    PRINT '   Staging: ' + CAST(@staging_count AS NVARCHAR(10)) + ' records';
    PRINT '   Gold: ' + CAST(@gold_count AS NVARCHAR(10)) + ' records';
    PRINT '';

    -- 2. Real Filipino brands check
    PRINT '2. FILIPINO BRANDS DETECTED:';
    SELECT TOP 10
        JSON_VALUE(raw_json, '$.items[0].brandName') as brand,
        COUNT(*) as transaction_count,
        ROUND(AVG(TRY_CAST(JSON_VALUE(raw_json, '$.totals.totalAmount') AS FLOAT)), 2) as avg_amount
    FROM staging.transactions
    WHERE JSON_VALUE(raw_json, '$.items[0].brandName') IS NOT NULL
    GROUP BY JSON_VALUE(raw_json, '$.items[0].brandName')
    ORDER BY COUNT(*) DESC;

    PRINT '';

    -- 3. Data freshness
    DECLARE @latest_record DATETIME2 = (SELECT MAX(created_at) FROM staging.transactions);
    DECLARE @hours_old INT = DATEDIFF(HOUR, @latest_record, GETDATE());

    PRINT '3. DATA FRESHNESS:';
    PRINT '   Latest record: ' + CAST(@latest_record AS NVARCHAR(30));
    PRINT '   Hours old: ' + CAST(@hours_old AS NVARCHAR(10));
    PRINT '';

    -- 4. Quality score
    DECLARE @valid_brands INT = (
        SELECT COUNT(*)
        FROM staging.transactions
        WHERE JSON_VALUE(raw_json, '$.items[0].brandName') IS NOT NULL
    );

    DECLARE @quality_score FLOAT = ROUND(CAST(@valid_brands AS FLOAT) / CAST(@staging_count AS FLOAT) * 100, 1);

    PRINT '4. DATA QUALITY:';
    PRINT '   Records with brands: ' + CAST(@valid_brands AS NVARCHAR(10));
    PRINT '   Quality score: ' + CAST(@quality_score AS NVARCHAR(10)) + '%';
    PRINT '';

    -- Overall status
    DECLARE @status NVARCHAR(20) = CASE
        WHEN @staging_count > 0 AND @quality_score > 80 THEN 'HEALTHY'
        WHEN @staging_count > 0 THEN 'NEEDS_ATTENTION'
        ELSE 'FAILED'
    END;

    PRINT '=== OVERALL STATUS: ' + @status + ' ===';
END;

-- ===========================================
-- DEPLOYMENT COMPLETE
-- ===========================================

PRINT '';
PRINT '=== Azure SQL ETL Deployment Complete ===';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Execute: EXEC staging.sp_load_sample_data';
PRINT '2. Validate: EXEC staging.sp_validate_data';
PRINT '3. Query: SELECT * FROM gold.v_transactions_simple';
PRINT '';