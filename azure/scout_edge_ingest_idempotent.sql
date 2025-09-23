/* ===========================================================
   SCOUT EDGE • Azure SQL Payload Ingestion (GZIP + CSV)
   Idempotent setup + AUTO ingest + validation
   =========================================================== */

-------------------------------
-- 0) CONFIG (EDIT THESE)
-------------------------------
DECLARE @ContainerUrl  nvarchar(400) = N'https://projectscoutautoregstr.blob.core.windows.net/gdrive-scout-ingest';
DECLARE @SasToken      nvarchar(max) = N'sv=2024-11-04&ss=bfqt&srt=sco&sp=rwdlacupiytfx&se=2026-09-22T10:50:05Z&st=2025-09-22T02:35:05Z&spr=https,http&sig=s0VDZeJ9RfXJ28oqBQwKRgZ3NBwVUc4laHqAe%2BbHT8c%3D';
-- Folder under the container that holds files, e.g. 'out/'
DECLARE @DefaultFolder nvarchar(200) = N'out/';

-------------------------------
-- 1) CREDENTIAL + DATA SOURCE
-------------------------------
IF EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'cred_scout_ingest')
    DROP DATABASE SCOPED CREDENTIAL cred_scout_ingest;

CREATE DATABASE SCOPED CREDENTIAL cred_scout_ingest
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
     SECRET   = @SasToken;

IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'eds_scout_ingest')
    DROP EXTERNAL DATA SOURCE eds_scout_ingest;

CREATE EXTERNAL DATA SOURCE eds_scout_ingest
WITH (
  TYPE = BLOB_STORAGE,
  LOCATION = @ContainerUrl,
  CREDENTIAL = cred_scout_ingest
);

-------------------------------
-- 2) STAGING SCHEMA + TABLE
-------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');

IF OBJECT_ID('staging.payload_transactions_raw','U') IS NOT NULL
    DROP TABLE staging.payload_transactions_raw;

CREATE TABLE staging.payload_transactions_raw (
    transactionId   varchar(64)   NOT NULL,
    storeId         int           NOT NULL,
    deviceId        varchar(64)   NULL,
    totalAmount     decimal(10,2) NULL,
    timestamp       varchar(50)   NULL,
    audioTranscript nvarchar(max) NULL,
    substitution    varchar(10)   NULL,
    payload_json    nvarchar(max) NULL,
    source_path     nvarchar(400) NULL,
    _ingested_at    datetime2(0)  NOT NULL CONSTRAINT DF_stg_ingested_at DEFAULT (sysdatetime())
);

-------------------------------
-- 3) INGEST PROC (AUTO / GZIP / CSV)
-------------------------------
CREATE OR ALTER PROCEDURE staging.sp_ingest_scout_edge_data
  @source_type  varchar(10) = 'AUTO',  -- 'AUTO' | 'GZIP' | 'CSV'
  @folder_path  nvarchar(200) = NULL,  -- e.g. 'out/'  (must end with '/')
  @pattern      nvarchar(200) = NULL   -- optional override (e.g. 'out/*.csv.gz' or 'out/export_2025-09-22.csv')
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @folder nvarchar(400) = COALESCE(@folder_path, N'out/');
  IF RIGHT(@folder,1) <> '/' SET @folder = @folder + '/';

  DECLARE @gzipPattern nvarchar(400) = COALESCE(@pattern, @folder + N'*.csv.gz');
  DECLARE @csvPattern  nvarchar(400) = COALESCE(@pattern, @folder + N'*.csv');

  -- Map ordinals to your CSV columns (adjust as needed for Scout Edge data)
  DECLARE @withCols nvarchar(max) = N'
    WITH (
      transactionId   varchar(64)    1,
      storeId         int            2,
      deviceId        varchar(64)    3,
      totalAmount     decimal(10,2)  4,
      timestamp       varchar(50)    5,
      audioTranscript nvarchar(max)  6,
      substitution    varchar(10)    7,
      payload_json    nvarchar(max)  8
    )';

  DECLARE @sql nvarchar(max);
  DECLARE @rows int = 0;

  PRINT '========================================';
  PRINT 'Scout Edge Data Ingestion Started';
  PRINT 'Source Type: ' + @source_type;
  PRINT 'Folder: ' + @folder;

  BEGIN TRY
    IF @source_type IN ('AUTO','GZIP')
    BEGIN
      PRINT 'Attempting GZIP ingestion: ' + @gzipPattern;

      SET @sql = N'
        INSERT INTO staging.payload_transactions_raw (transactionId, storeId, deviceId, totalAmount, timestamp, audioTranscript, substitution, payload_json, source_path)
        SELECT transactionId, storeId, deviceId, totalAmount, timestamp, audioTranscript, substitution, payload_json,
               CONCAT(''blob://gdrive-scout-ingest/'', [filepath]) AS source_path
        FROM OPENROWSET(
          BULK ''' + @gzipPattern + ''',
          DATA_SOURCE = ''eds_scout_ingest'',
          FORMAT = ''CSV'',
          PARSER_VERSION = ''2.0'',
          FIRSTROW = 2,
          FIELDTERMINATOR = '','',
          ROWTERMINATOR = ''0x0a'',
          DATA_COMPRESSION = ''GZIP''
        ) ' + @withCols + ' AS gz_data';

      EXEC sp_executesql @sql;
      SET @rows = @@ROWCOUNT;
      PRINT 'GZIP ingestion completed: ' + CAST(@rows AS varchar) + ' rows';
    END

    -- If AUTO mode and GZIP failed or returned 0 rows, try CSV
    IF (@source_type = 'AUTO' AND @rows = 0) OR @source_type = 'CSV'
    BEGIN
      IF @source_type = 'AUTO'
        PRINT 'GZIP returned 0 rows, attempting CSV ingestion: ' + @csvPattern;
      ELSE
        PRINT 'Attempting CSV ingestion: ' + @csvPattern;

      SET @sql = N'
        INSERT INTO staging.payload_transactions_raw (transactionId, storeId, deviceId, totalAmount, timestamp, audioTranscript, substitution, payload_json, source_path)
        SELECT transactionId, storeId, deviceId, totalAmount, timestamp, audioTranscript, substitution, payload_json,
               CONCAT(''blob://gdrive-scout-ingest/'', [filepath]) AS source_path
        FROM OPENROWSET(
          BULK ''' + @csvPattern + ''',
          DATA_SOURCE = ''eds_scout_ingest'',
          FORMAT = ''CSV'',
          PARSER_VERSION = ''2.0'',
          FIRSTROW = 2,
          FIELDTERMINATOR = '','',
          ROWTERMINATOR = ''0x0a''
        ) ' + @withCols + ' AS csv_data';

      EXEC sp_executesql @sql;
      SET @rows = @@ROWCOUNT;
      PRINT 'CSV ingestion completed: ' + CAST(@rows AS varchar) + ' rows';
    END

  END TRY
  BEGIN CATCH
    DECLARE @ErrorMessage nvarchar(4000) = ERROR_MESSAGE();
    PRINT 'ERROR: ' + @ErrorMessage;

    IF @source_type = 'AUTO'
    BEGIN
      PRINT 'Auto-mode failed. Check file patterns and SAS token permissions.';
      PRINT 'Attempted GZIP pattern: ' + @gzipPattern;
      PRINT 'Attempted CSV pattern: ' + @csvPattern;
    END

    THROW;
  END CATCH

  -- Final summary
  SELECT @rows = COUNT(*) FROM staging.payload_transactions_raw;
  PRINT '========================================';
  PRINT 'Total rows in staging: ' + CAST(@rows AS varchar);
  PRINT 'Ingestion completed successfully';

  -- Quick validation
  IF @rows > 0
  BEGIN
    SELECT TOP 5
      transactionId, storeId, deviceId, totalAmount,
      LEFT(audioTranscript, 50) + '...' as transcript_sample,
      substitution, source_path, _ingested_at
    FROM staging.payload_transactions_raw
    ORDER BY _ingested_at DESC;
  END
END;
GO

-------------------------------
-- 4) VALIDATION PROC
-------------------------------
CREATE OR ALTER PROCEDURE staging.sp_validate_scout_ingestion
AS
BEGIN
  SET NOCOUNT ON;

  PRINT '========================================';
  PRINT 'Scout Edge Ingestion Validation Report';
  PRINT '========================================';

  DECLARE @totalRows int, @uniqueStores int, @withAudio int, @withSubstitution int;

  SELECT
    @totalRows = COUNT(*),
    @uniqueStores = COUNT(DISTINCT storeId),
    @withAudio = COUNT(*) FILTER (WHERE audioTranscript IS NOT NULL AND LEN(audioTranscript) > 0),
    @withSubstitution = COUNT(*) FILTER (WHERE substitution IN ('true', '1', 'TRUE'))
  FROM staging.payload_transactions_raw;

  PRINT 'Total Rows: ' + CAST(@totalRows AS varchar);
  PRINT 'Unique Stores: ' + CAST(@uniqueStores AS varchar);
  PRINT 'Records with Audio: ' + CAST(@withAudio AS varchar) + ' (' + CAST(ROUND((@withAudio * 100.0 / NULLIF(@totalRows, 0)), 1) AS varchar) + '%)';
  PRINT 'Substitution Events: ' + CAST(@withSubstitution AS varchar) + ' (' + CAST(ROUND((@withSubstitution * 100.0 / NULLIF(@totalRows, 0)), 1) AS varchar) + '%)';

  -- Store breakdown
  PRINT '';
  PRINT 'Store Distribution:';
  SELECT
    storeId,
    COUNT(*) as transactions,
    AVG(totalAmount) as avg_amount,
    COUNT(*) FILTER (WHERE substitution IN ('true', '1', 'TRUE')) as substitutions,
    MIN(_ingested_at) as first_ingested,
    MAX(_ingested_at) as last_ingested
  FROM staging.payload_transactions_raw
  WHERE storeId IS NOT NULL
  GROUP BY storeId
  ORDER BY storeId;

  -- Data quality checks
  PRINT '';
  PRINT 'Data Quality Checks:';
  SELECT
    'Missing Transaction IDs' as check_name,
    COUNT(*) as violations
  FROM staging.payload_transactions_raw
  WHERE transactionId IS NULL OR transactionId = ''

  UNION ALL

  SELECT
    'Missing Store IDs' as check_name,
    COUNT(*) as violations
  FROM staging.payload_transactions_raw
  WHERE storeId IS NULL

  UNION ALL

  SELECT
    'Zero/Negative Amounts' as check_name,
    COUNT(*) as violations
  FROM staging.payload_transactions_raw
  WHERE totalAmount <= 0 OR totalAmount IS NULL

  UNION ALL

  SELECT
    'Missing Timestamps' as check_name,
    COUNT(*) as violations
  FROM staging.payload_transactions_raw
  WHERE timestamp IS NULL OR timestamp = '';

  -- Expected range validation
  PRINT '';
  IF @totalRows BETWEEN 13000 AND 200000
    PRINT '✅ Row count within expected range (13K-200K)';
  ELSE
    PRINT '⚠️  Row count outside expected range - review data source';

  IF @uniqueStores >= 7
    PRINT '✅ Expected store coverage (7+ stores)';
  ELSE
    PRINT '⚠️  Low store coverage: ' + CAST(@uniqueStores AS varchar) + ' stores';

  PRINT 'Validation completed.';
END;
GO

-------------------------------
-- 5) QUICK EXECUTION EXAMPLES
-------------------------------

/*
-- Execute ingestion (auto-detect format)
EXEC staging.sp_ingest_scout_edge_data @source_type = 'AUTO';

-- Execute validation
EXEC staging.sp_validate_scout_ingestion;

-- Check specific patterns
EXEC staging.sp_ingest_scout_edge_data @source_type = 'GZIP', @pattern = 'out/transactions_2025-09-22.csv.gz';
EXEC staging.sp_ingest_scout_edge_data @source_type = 'CSV', @pattern = 'out/ingest/transactions_flat_no_ts.csv';

-- Quick row count
SELECT COUNT(*) AS total_scout_transactions FROM staging.payload_transactions_raw;

-- Sample data
SELECT TOP 10 * FROM staging.payload_transactions_raw ORDER BY _ingested_at DESC;
*/

-------------------------------
-- 6) READY TO EXECUTE
-------------------------------
PRINT '========================================';
PRINT 'Scout Edge Azure SQL Ingest Setup Complete';
PRINT '========================================';
PRINT 'Container: https://projectscoutautoregstr.blob.core.windows.net/gdrive-scout-ingest';
PRINT 'Default Folder: out/';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Update @SasToken with fresh container-scoped SAS';
PRINT '2. EXEC staging.sp_ingest_scout_edge_data @source_type = ''AUTO'';';
PRINT '3. EXEC staging.sp_validate_scout_ingestion;';
PRINT '';
PRINT 'Ready for Scout Edge payload ingestion! 🚀';
GO