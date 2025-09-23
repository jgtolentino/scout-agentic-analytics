-- ==========================================
-- Scout Edge Payload Ingestion - Azure SQL
-- Handles GZIP (.csv.gz) and CSV files from Azure Blob Storage
-- ==========================================

-- Prerequisites:
-- 1. Fresh SAS token for gdrive-scout-ingest container
-- 2. Scout Edge transaction files in blob storage
-- 3. Appropriate permissions for OPENROWSET operations

USE [ScoutEdgeDB];  -- Adjust database name as needed
GO

-- ==========================================
-- 1. SETUP: Database Scoped Credentials & External Data Source
-- ==========================================

-- Drop existing credential if it exists (for SAS token refresh)
IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'cred_scout_ingest')
    DROP DATABASE SCOPED CREDENTIAL cred_scout_ingest;
GO

-- Create database scoped credential with SAS token
-- IMPORTANT: Replace with fresh, short-lived SAS token
CREATE DATABASE SCOPED CREDENTIAL cred_scout_ingest
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = 'sv=2024-11-04&ss=bfqt&srt=sco&sp=rwdlacupiytfx&se=2026-09-22T10:50:05Z&st=2025-09-22T02:35:05Z&spr=https,http&sig=s0VDZeJ9RfXJ28oqBQwKRgZ3NBwVUc4laHqAe%2BbHT8c%3D';
GO

-- Drop existing external data source if it exists
IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'eds_scout_ingest')
    DROP EXTERNAL DATA SOURCE eds_scout_ingest;
GO

-- Create external data source to Scout Edge blob container
CREATE EXTERNAL DATA SOURCE eds_scout_ingest
WITH (
    TYPE = BLOB_STORAGE,
    LOCATION = 'https://projectscoutautoregstr.blob.core.windows.net/gdrive-scout-ingest',
    CREDENTIAL = cred_scout_ingest
);
GO

-- ==========================================
-- 2. CREATE STAGING SCHEMA & TABLE
-- ==========================================

-- Create staging schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO

-- Drop existing staging table if it exists (for clean reload)
IF OBJECT_ID('staging.scout_payload_transactions_raw','U') IS NOT NULL
    DROP TABLE staging.scout_payload_transactions_raw;
GO

-- Create staging table for Scout Edge transaction payloads
CREATE TABLE staging.scout_payload_transactions_raw (
    -- Core transaction identifiers
    canonical_tx_id     VARCHAR(64)     NOT NULL,
    transaction_id      VARCHAR(64)     NOT NULL,
    store_id            INT             NULL,
    device_id           VARCHAR(64)     NULL,

    -- Transaction details
    total_amount        DECIMAL(10,2)   NULL,
    transaction_timestamp DATETIMEOFFSET NULL,

    -- Audio processing results
    audio_transcript    NVARCHAR(MAX)   NULL,
    substitution_detected BIT           DEFAULT 0,
    substitution_reason VARCHAR(255)    NULL,
    brand_switching_score DECIMAL(5,2) NULL,

    -- Scout Edge metadata
    edge_version        VARCHAR(50)     NULL,
    processing_methods  NVARCHAR(500)   NULL,
    confidence_score    DECIMAL(5,4)    NULL,

    -- Privacy compliance flags
    audio_stored        BIT             DEFAULT 0,
    facial_recognition  BIT             DEFAULT 0,
    anonymization_level VARCHAR(20)     DEFAULT 'high',

    -- Geographic enrichment (will be populated later)
    municipality_name   VARCHAR(100)    NULL,
    province_name       VARCHAR(100)    NULL,
    region              VARCHAR(50)     NULL,
    latitude            DECIMAL(10,8)   NULL,
    longitude           DECIMAL(11,8)   NULL,

    -- Audit fields
    source_file_path    NVARCHAR(500)   NULL,
    ingestion_timestamp DATETIMEOFFSET  DEFAULT GETUTCDATE(),
    data_quality_score  DECIMAL(5,2)    NULL
);
GO

-- Create indexes for performance
CREATE CLUSTERED INDEX IX_scout_payload_canonical_tx_id
    ON staging.scout_payload_transactions_raw (canonical_tx_id);

CREATE NONCLUSTERED INDEX IX_scout_payload_store_timestamp
    ON staging.scout_payload_transactions_raw (store_id, transaction_timestamp);

CREATE NONCLUSTERED INDEX IX_scout_payload_substitution
    ON staging.scout_payload_transactions_raw (substitution_detected, store_id)
    WHERE substitution_detected = 1;
GO

-- ==========================================
-- 3. INGESTION FUNCTIONS
-- ==========================================

-- Function to detect and load Scout Edge GZIP files
CREATE OR ALTER PROCEDURE staging.sp_ingest_scout_gzip_files
    @folder_path NVARCHAR(200) = 'out/',
    @file_pattern NVARCHAR(100) = '*.csv.gz'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @full_pattern NVARCHAR(300) = @folder_path + @file_pattern;

    PRINT 'Ingesting Scout Edge GZIP files from pattern: ' + @full_pattern;

    -- Build dynamic SQL for GZIP ingestion
    SET @sql = N'
    INSERT INTO staging.scout_payload_transactions_raw (
        canonical_tx_id, transaction_id, store_id, device_id, total_amount,
        transaction_timestamp, audio_transcript, substitution_detected,
        substitution_reason, brand_switching_score, edge_version,
        processing_methods, confidence_score, source_file_path
    )
    SELECT
        canonical_tx_id, transaction_id, store_id, device_id, total_amount,
        TRY_CAST(transaction_timestamp AS DATETIMEOFFSET) as transaction_timestamp,
        audio_transcript,
        CASE WHEN LOWER(substitution_detected) IN (''true'', ''1'', ''yes'') THEN 1 ELSE 0 END,
        substitution_reason, brand_switching_score, edge_version,
        processing_methods, confidence_score,
        CONCAT(''blob://gdrive-scout-ingest/'', [filepath]) AS source_file_path
    FROM OPENROWSET(
        BULK ''' + @full_pattern + ''',
        DATA_SOURCE = ''eds_scout_ingest'',
        FORMAT = ''CSV'',
        PARSER_VERSION = ''2.0'',
        FIRSTROW = 2,
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''0x0a'',
        DATA_COMPRESSION = ''GZIP''
    ) WITH (
        canonical_tx_id         VARCHAR(64)     1,
        transaction_id          VARCHAR(64)     2,
        store_id                INT             3,
        device_id               VARCHAR(64)     4,
        total_amount            DECIMAL(10,2)   5,
        transaction_timestamp   VARCHAR(50)     6,
        audio_transcript        NVARCHAR(MAX)   7,
        substitution_detected   VARCHAR(10)     8,
        substitution_reason     VARCHAR(255)    9,
        brand_switching_score   DECIMAL(5,2)    10,
        edge_version            VARCHAR(50)     11,
        processing_methods      NVARCHAR(500)   12,
        confidence_score        DECIMAL(5,4)    13
    ) AS gz_data;';

    BEGIN TRY
        EXEC sp_executesql @sql;
        PRINT 'GZIP ingestion completed successfully.';
    END TRY
    BEGIN CATCH
        PRINT 'Error in GZIP ingestion: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- Function to load Scout Edge CSV files (decompressed)
CREATE OR ALTER PROCEDURE staging.sp_ingest_scout_csv_files
    @folder_path NVARCHAR(200) = 'out/ingest/',
    @file_pattern NVARCHAR(100) = '*.csv'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @full_pattern NVARCHAR(300) = @folder_path + @file_pattern;

    PRINT 'Ingesting Scout Edge CSV files from pattern: ' + @full_pattern;

    -- Build dynamic SQL for CSV ingestion (same as GZIP but without compression)
    SET @sql = N'
    INSERT INTO staging.scout_payload_transactions_raw (
        canonical_tx_id, transaction_id, store_id, device_id, total_amount,
        transaction_timestamp, audio_transcript, substitution_detected,
        substitution_reason, brand_switching_score, edge_version,
        processing_methods, confidence_score, source_file_path
    )
    SELECT
        canonical_tx_id, transaction_id, store_id, device_id, total_amount,
        TRY_CAST(transaction_timestamp AS DATETIMEOFFSET) as transaction_timestamp,
        audio_transcript,
        CASE WHEN LOWER(substitution_detected) IN (''true'', ''1'', ''yes'') THEN 1 ELSE 0 END,
        substitution_reason, brand_switching_score, edge_version,
        processing_methods, confidence_score,
        CONCAT(''blob://gdrive-scout-ingest/'', [filepath]) AS source_file_path
    FROM OPENROWSET(
        BULK ''' + @full_pattern + ''',
        DATA_SOURCE = ''eds_scout_ingest'',
        FORMAT = ''CSV'',
        PARSER_VERSION = ''2.0'',
        FIRSTROW = 2,
        FIELDTERMINATOR = '','',
        ROWTERMINATOR = ''0x0a''
    ) WITH (
        canonical_tx_id         VARCHAR(64)     1,
        transaction_id          VARCHAR(64)     2,
        store_id                INT             3,
        device_id               VARCHAR(64)     4,
        total_amount            DECIMAL(10,2)   5,
        transaction_timestamp   VARCHAR(50)     6,
        audio_transcript        NVARCHAR(MAX)   7,
        substitution_detected   VARCHAR(10)     8,
        substitution_reason     VARCHAR(255)    9,
        brand_switching_score   DECIMAL(5,2)    10,
        edge_version            VARCHAR(50)     11,
        processing_methods      NVARCHAR(500)   12,
        confidence_score        DECIMAL(5,4)    13
    ) AS csv_data;';

    BEGIN TRY
        EXEC sp_executesql @sql;
        PRINT 'CSV ingestion completed successfully.';
    END TRY
    BEGIN CATCH
        PRINT 'Error in CSV ingestion: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ==========================================
-- 4. GEOGRAPHIC ENRICHMENT PROCEDURE
-- ==========================================

CREATE OR ALTER PROCEDURE staging.sp_enrich_scout_geography
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Enriching Scout Edge data with NCR geographic information...';

    -- Update records with NCR store mappings
    UPDATE staging.scout_payload_transactions_raw
    SET
        municipality_name = CASE store_id
            WHEN 102 THEN 'Manila'
            WHEN 103 THEN 'Quezon City'
            WHEN 104 THEN 'Makati'
            WHEN 108 THEN 'Pasig'
            WHEN 109 THEN 'Mandaluyong'
            WHEN 110 THEN 'Parañaque'
            WHEN 112 THEN 'Taguig'
            ELSE 'Unknown'
        END,
        province_name = 'Metro Manila',
        region = 'NCR',
        latitude = CASE store_id
            WHEN 102 THEN 14.5995
            WHEN 103 THEN 14.6760
            WHEN 104 THEN 14.5547
            WHEN 108 THEN 14.5764
            WHEN 109 THEN 14.5833
            WHEN 110 THEN 14.4793
            WHEN 112 THEN 14.5176
            ELSE NULL
        END,
        longitude = CASE store_id
            WHEN 102 THEN 120.9842
            WHEN 103 THEN 121.0437
            WHEN 104 THEN 121.0244
            WHEN 108 THEN 121.0851
            WHEN 109 THEN 121.0333
            WHEN 110 THEN 121.0195
            WHEN 112 THEN 121.0509
            ELSE NULL
        END
    WHERE municipality_name IS NULL
      AND store_id IN (102, 103, 104, 108, 109, 110, 112);

    PRINT 'Geographic enrichment completed.';
END;
GO

-- ==========================================
-- 5. DATA QUALITY ASSESSMENT PROCEDURE
-- ==========================================

CREATE OR ALTER PROCEDURE staging.sp_assess_scout_data_quality
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Assessing Scout Edge data quality...';

    -- Calculate data quality scores
    WITH quality_metrics AS (
        SELECT
            canonical_tx_id,
            -- Completeness score (0-100)
            (CASE WHEN canonical_tx_id IS NOT NULL THEN 10 ELSE 0 END +
             CASE WHEN transaction_id IS NOT NULL THEN 10 ELSE 0 END +
             CASE WHEN store_id IS NOT NULL THEN 15 ELSE 0 END +
             CASE WHEN device_id IS NOT NULL THEN 10 ELSE 0 END +
             CASE WHEN total_amount IS NOT NULL THEN 15 ELSE 0 END +
             CASE WHEN transaction_timestamp IS NOT NULL THEN 10 ELSE 0 END +
             CASE WHEN audio_transcript IS NOT NULL AND LEN(audio_transcript) > 0 THEN 20 ELSE 0 END +
             CASE WHEN municipality_name IS NOT NULL THEN 10 ELSE 0 END) AS quality_score
        FROM staging.scout_payload_transactions_raw
    )
    UPDATE staging.scout_payload_transactions_raw
    SET data_quality_score = q.quality_score
    FROM staging.scout_payload_transactions_raw s
    INNER JOIN quality_metrics q ON s.canonical_tx_id = q.canonical_tx_id;

    PRINT 'Data quality assessment completed.';
END;
GO

-- ==========================================
-- 6. MAIN INGESTION ORCHESTRATOR
-- ==========================================

CREATE OR ALTER PROCEDURE staging.sp_ingest_scout_edge_data
    @source_type NVARCHAR(10) = 'AUTO',  -- 'GZIP', 'CSV', or 'AUTO'
    @folder_path NVARCHAR(200) = 'out/',
    @clean_staging BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2 = GETUTCDATE();
    DECLARE @rows_before INT, @rows_after INT;

    PRINT '========================================';
    PRINT 'Scout Edge Data Ingestion Started';
    PRINT '========================================';
    PRINT 'Start Time: ' + CONVERT(VARCHAR, @start_time, 120);
    PRINT 'Source Type: ' + @source_type;
    PRINT 'Folder Path: ' + @folder_path;

    -- Clean staging table if requested
    IF @clean_staging = 1
    BEGIN
        SELECT @rows_before = COUNT(*) FROM staging.scout_payload_transactions_raw;
        TRUNCATE TABLE staging.scout_payload_transactions_raw;
        PRINT 'Staging table cleaned. Previous rows: ' + CAST(@rows_before AS VARCHAR);
    END;

    -- Determine ingestion method
    IF @source_type = 'AUTO'
    BEGIN
        -- Try GZIP first, fallback to CSV
        BEGIN TRY
            EXEC staging.sp_ingest_scout_gzip_files @folder_path, '*.csv.gz';
            PRINT 'Auto-detection: Used GZIP ingestion method.';
        END TRY
        BEGIN CATCH
            PRINT 'GZIP ingestion failed, trying CSV method...';
            EXEC staging.sp_ingest_scout_csv_files @folder_path, '*.csv';
            PRINT 'Auto-detection: Used CSV ingestion method.';
        END CATCH
    END
    ELSE IF @source_type = 'GZIP'
    BEGIN
        EXEC staging.sp_ingest_scout_gzip_files @folder_path, '*.csv.gz';
    END
    ELSE IF @source_type = 'CSV'
    BEGIN
        EXEC staging.sp_ingest_scout_csv_files @folder_path, '*.csv';
    END
    ELSE
    BEGIN
        RAISERROR('Invalid source_type. Use GZIP, CSV, or AUTO.', 16, 1);
        RETURN;
    END;

    -- Post-processing
    EXEC staging.sp_enrich_scout_geography;
    EXEC staging.sp_assess_scout_data_quality;

    -- Final statistics
    SELECT @rows_after = COUNT(*) FROM staging.scout_payload_transactions_raw;

    PRINT '========================================';
    PRINT 'Scout Edge Data Ingestion Completed';
    PRINT '========================================';
    PRINT 'Rows Ingested: ' + CAST(@rows_after AS VARCHAR);
    PRINT 'Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETUTCDATE()) AS VARCHAR) + ' seconds';
    PRINT 'End Time: ' + CONVERT(VARCHAR, GETUTCDATE(), 120);

    -- Quality summary
    SELECT
        COUNT(*) as total_rows,
        COUNT(DISTINCT store_id) as unique_stores,
        AVG(data_quality_score) as avg_quality_score,
        COUNT(*) - COUNT(municipality_name) as missing_geography,
        SUM(CASE WHEN substitution_detected = 1 THEN 1 ELSE 0 END) as substitution_events
    FROM staging.scout_payload_transactions_raw;
END;
GO

-- ==========================================
-- 7. QUICK VALIDATION QUERIES
-- ==========================================

-- Validation procedure
CREATE OR ALTER PROCEDURE staging.sp_validate_scout_ingestion
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '========================================';
    PRINT 'Scout Edge Ingestion Validation Report';
    PRINT '========================================';

    -- Row count check
    DECLARE @total_rows INT;
    SELECT @total_rows = COUNT(*) FROM staging.scout_payload_transactions_raw;
    PRINT 'Total rows ingested: ' + CAST(@total_rows AS VARCHAR);

    -- Expected range check (based on previous analysis)
    IF @total_rows BETWEEN 13000 AND 200000
        PRINT '✅ Row count within expected range (13K-200K)';
    ELSE
        PRINT '⚠️ Row count outside expected range - review data source';

    -- Store coverage
    SELECT
        'Store Coverage' as metric,
        store_id,
        COUNT(*) as transactions,
        AVG(data_quality_score) as avg_quality
    FROM staging.scout_payload_transactions_raw
    WHERE store_id IS NOT NULL
    GROUP BY store_id
    ORDER BY store_id;

    -- Data quality summary
    SELECT
        'Data Quality Summary' as metric,
        AVG(data_quality_score) as avg_quality_score,
        MIN(data_quality_score) as min_quality_score,
        MAX(data_quality_score) as max_quality_score,
        COUNT(*) FILTER (WHERE data_quality_score >= 80) as high_quality_rows,
        COUNT(*) FILTER (WHERE data_quality_score < 50) as low_quality_rows
    FROM staging.scout_payload_transactions_raw;

    PRINT 'Validation completed.';
END;
GO

-- ==========================================
-- 8. EXECUTION EXAMPLES
-- ==========================================

/*
-- Example 1: Ingest GZIP files from out/ folder
EXEC staging.sp_ingest_scout_edge_data @source_type = 'GZIP', @folder_path = 'out/';

-- Example 2: Ingest CSV files from out/ingest/ folder
EXEC staging.sp_ingest_scout_edge_data @source_type = 'CSV', @folder_path = 'out/ingest/';

-- Example 3: Auto-detect and ingest (recommended)
EXEC staging.sp_ingest_scout_edge_data @source_type = 'AUTO', @folder_path = 'out/';

-- Example 4: Validate ingestion
EXEC staging.sp_validate_scout_ingestion;

-- Example 5: Quick row count check
SELECT COUNT(*) AS total_scout_transactions FROM staging.scout_payload_transactions_raw;

-- Example 6: Sample data review
SELECT TOP 10 * FROM staging.scout_payload_transactions_raw ORDER BY ingestion_timestamp DESC;
*/

-- ==========================================
-- READY FOR EXECUTION
-- ==========================================

PRINT '========================================';
PRINT 'Scout Edge Payload Ingestion Setup Complete';
PRINT '========================================';
PRINT 'Ready to execute: EXEC staging.sp_ingest_scout_edge_data;';
PRINT 'For validation: EXEC staging.sp_validate_scout_ingestion;';
GO