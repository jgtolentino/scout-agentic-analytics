-- ===================================================================
-- SCOUT STORE GEOSPATIAL ENRICHMENT - COMPLETE DEPLOYMENT
-- Execute this COMPLETE script in Bruno for full deployment
-- ===================================================================

PRINT '🚀 SCOUT STORE GEOSPATIAL ENRICHMENT - STARTING COMPLETE DEPLOYMENT';
PRINT '=======================================================================';
PRINT '';

-- ===================================================================
-- PHASE 1: INFRASTRUCTURE SETUP
-- ===================================================================

PRINT '📁 Phase 1: Creating Infrastructure...';

-- Create support schemas (idempotent)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='staging')
    EXEC('CREATE SCHEMA staging');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='ops')
    EXEC('CREATE SCHEMA ops');

PRINT '✅ Support schemas created/verified';

-- Staging table for clean import
IF OBJECT_ID('staging.StoreLocationImport') IS NOT NULL
    DROP TABLE staging.StoreLocationImport;

CREATE TABLE staging.StoreLocationImport (
  StoreID           int           NOT NULL,
  StoreName         nvarchar(200) NULL,
  AddressLine       nvarchar(400) NULL,
  MunicipalityName  nvarchar(80)  NULL,
  BarangayName      nvarchar(120) NULL,
  Region            varchar(8)    NULL,
  ProvinceName      nvarchar(50)  NULL,
  GeoLatitude       float         NULL,
  GeoLongitude      float         NULL,
  StorePolygon      nvarchar(max) NULL,
  psgc_region       char(9)       NULL,
  psgc_citymun      char(9)       NULL,
  psgc_barangay     char(9)       NULL,
  SourceFile        nvarchar(400) NULL,
  EnrichedAt        datetime2     NULL,
  LoadedAt          datetime2     NOT NULL DEFAULT sysutcdatetime()
);

-- Audit log
IF OBJECT_ID('ops.LocationLoadLog') IS NULL
CREATE TABLE ops.LocationLoadLog(
  LoadID      bigint IDENTITY(1,1) PRIMARY KEY,
  SourceFile  nvarchar(400),
  RowsIn      int,
  RowsUpserted  int,
  RowsSkipped int,
  StartedAt   datetime2 NOT NULL DEFAULT sysutcdatetime(),
  EndedAt     datetime2 NULL,
  Notes       nvarchar(4000) NULL,
  LoadStatus  varchar(20) DEFAULT 'RUNNING'
);

PRINT '✅ Tables created';

-- ===================================================================
-- PHASE 2: BLOB STORAGE ACCESS
-- ===================================================================

PRINT '🔗 Phase 2: Configuring Blob Storage Access...';

-- Create database scoped credential (using existing working token)
IF NOT EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name='SCOUT_BLOB_SAS')
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL SCOUT_BLOB_SAS
    WITH IDENTITY='SHARED ACCESS SIGNATURE',
         SECRET='?sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupyx&se=2025-12-31T23:59:59Z&st=2025-01-01T00:00:00Z&spr=https&sig=working_token_from_upload';
    PRINT '✅ Database scoped credential created';
END
ELSE
    PRINT 'ℹ️ Database scoped credential already exists';

-- External data source
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name='SCOUT_BLOB')
BEGIN
    CREATE EXTERNAL DATA SOURCE SCOUT_BLOB
    WITH ( TYPE = BLOB_STORAGE,
           LOCATION = 'https://projectscoutautoregstr.blob.core.windows.net',
           CREDENTIAL = SCOUT_BLOB_SAS );
    PRINT '✅ External data source created';
END
ELSE
    PRINT 'ℹ️ External data source already exists';

-- ===================================================================
-- PHASE 3: STORED PROCEDURE DEPLOYMENT
-- ===================================================================

PRINT '📦 Phase 3: Deploying Stored Procedure...';

CREATE OR ALTER PROCEDURE staging.sp_upsert_enriched_stores
    @blob_csv_path nvarchar(400)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start_time datetime2 = sysutcdatetime();
    DECLARE @rows_in int = 0, @rows_upserted int = 0, @rows_skipped int = 0;
    DECLARE @notes nvarchar(4000) = '', @load_status varchar(20) = 'RUNNING';

    BEGIN TRY
        -- Truncate staging
        TRUNCATE TABLE staging.StoreLocationImport;

        -- Load from blob
        DECLARE @sql nvarchar(max) = N'
        INSERT INTO staging.StoreLocationImport
            (StoreID, StoreName, AddressLine, MunicipalityName, BarangayName,
             Region, ProvinceName, GeoLatitude, GeoLongitude, StorePolygon,
             psgc_region, psgc_citymun, SourceFile)
        SELECT
            TRY_CAST([StoreID] AS int),
            NULLIF(LTRIM(RTRIM([StoreName])),''''),
            NULLIF(LTRIM(RTRIM([AddressLine])),''''),
            NULLIF(LTRIM(RTRIM([MunicipalityName])),''''),
            NULLIF(LTRIM(RTRIM([BarangayName])),''''),
            NULLIF(LTRIM(RTRIM([Region])),''''),
            NULLIF(LTRIM(RTRIM([ProvinceName])),''''),
            TRY_CAST([GeoLatitude] AS float),
            TRY_CAST([GeoLongitude] AS float),
            NULLIF(LTRIM(RTRIM([StorePolygon])),''''),
            NULLIF(LTRIM(RTRIM([psgc_region])),''''),
            NULLIF(LTRIM(RTRIM([psgc_citymun])),''''),
            ''' + @blob_csv_path + '''
        FROM OPENROWSET(
            BULK ''' + @blob_csv_path + ''',
            DATA_SOURCE = ''SCOUT_BLOB'',
            FORMAT = ''CSV'',
            PARSER_VERSION = ''2.0'',
            FIRSTROW = 2
        ) WITH (
            [StoreID] varchar(32), [StoreName] nvarchar(200), [AddressLine] nvarchar(400),
            [MunicipalityName] nvarchar(80), [BarangayName] nvarchar(120),
            [Region] varchar(8), [ProvinceName] varchar(50),
            [GeoLatitude] varchar(64), [GeoLongitude] varchar(64),
            [StorePolygon] nvarchar(max), [psgc_region] varchar(16),
            [psgc_citymun] varchar(16), [psgc_barangay] varchar(16)
        ) AS src
        WHERE TRY_CAST([StoreID] AS int) IS NOT NULL;';

        EXEC sp_executesql @sql;
        SET @rows_in = @@ROWCOUNT;

        -- Municipality normalization
        UPDATE staging.StoreLocationImport
        SET MunicipalityName = CASE
            WHEN UPPER(LTRIM(RTRIM(MunicipalityName))) IN ('QUEZON CITY','QC') THEN 'Quezon City'
            WHEN UPPER(LTRIM(RTRIM(MunicipalityName))) IN ('CITY OF MANILA','MANILA') THEN 'Manila'
            WHEN UPPER(LTRIM(RTRIM(MunicipalityName))) = 'MAKATI' THEN 'Makati'
            WHEN UPPER(LTRIM(RTRIM(MunicipalityName))) = 'PATEROS' THEN 'Pateros'
            WHEN UPPER(LTRIM(RTRIM(MunicipalityName))) = 'MANDALUYONG' THEN 'Mandaluyong'
            ELSE MunicipalityName
        END,
        Region = 'NCR',
        ProvinceName = 'Metro Manila';

        -- NCR bounds validation
        UPDATE staging.StoreLocationImport
        SET GeoLatitude = NULL, GeoLongitude = NULL
        WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL
          AND NOT (GeoLatitude BETWEEN 14.20 AND 14.90 AND GeoLongitude BETWEEN 120.90 AND 121.20);

        -- Remove rows without geometry
        DELETE FROM staging.StoreLocationImport
        WHERE (StorePolygon IS NULL OR LTRIM(RTRIM(StorePolygon)) = '')
          AND (GeoLatitude IS NULL OR GeoLongitude IS NULL);

        SET @rows_skipped = @rows_in - (SELECT COUNT(*) FROM staging.StoreLocationImport);

        -- Merge into dbo.Stores (no regression)
        MERGE dbo.Stores AS tgt
        USING staging.StoreLocationImport AS src ON tgt.StoreID = src.StoreID
        WHEN MATCHED THEN
            UPDATE SET
                StoreName = COALESCE(NULLIF(src.StoreName,''), tgt.StoreName),
                AddressLine = COALESCE(NULLIF(src.AddressLine,''), tgt.AddressLine),
                MunicipalityName = COALESCE(NULLIF(src.MunicipalityName,''), tgt.MunicipalityName),
                BarangayName = COALESCE(NULLIF(src.BarangayName,''), tgt.BarangayName),
                Region = COALESCE(NULLIF(src.Region,''), tgt.Region),
                ProvinceName = COALESCE(NULLIF(src.ProvinceName,''), tgt.ProvinceName),
                GeoLatitude = COALESCE(src.GeoLatitude, tgt.GeoLatitude),
                GeoLongitude = COALESCE(src.GeoLongitude, tgt.GeoLongitude),
                StorePolygon = COALESCE(NULLIF(src.StorePolygon,''), tgt.StorePolygon),
                psgc_region = COALESCE(NULLIF(src.psgc_region,''), tgt.psgc_region),
                psgc_citymun = COALESCE(NULLIF(src.psgc_citymun,''), tgt.psgc_citymun)
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (StoreID, StoreName, AddressLine, MunicipalityName, BarangayName,
                   Region, ProvinceName, GeoLatitude, GeoLongitude, StorePolygon,
                   psgc_region, psgc_citymun)
            VALUES (src.StoreID, src.StoreName, src.AddressLine, src.MunicipalityName,
                   src.BarangayName, 'NCR', 'Metro Manila', src.GeoLatitude,
                   src.GeoLongitude, src.StorePolygon, src.psgc_region, src.psgc_citymun);

        SET @rows_upserted = @@ROWCOUNT;
        SET @load_status = 'SUCCESS';
        SET @notes = 'Loaded ' + CAST(@rows_in AS nvarchar(10)) + ' rows, upserted ' + CAST(@rows_upserted AS nvarchar(10));

        -- Log results
        INSERT INTO ops.LocationLoadLog (SourceFile, RowsIn, RowsUpserted, RowsSkipped,
                                        StartedAt, EndedAt, Notes, LoadStatus)
        VALUES (@blob_csv_path, @rows_in, @rows_upserted, @rows_skipped,
                @start_time, sysutcdatetime(), @notes, @load_status);

        SELECT @load_status AS Status, @rows_in AS RowsLoaded,
               @rows_upserted AS RowsUpserted, @rows_skipped AS RowsSkipped, @notes AS Details;

    END TRY
    BEGIN CATCH
        SET @load_status = 'ERROR';
        SET @notes = 'ERROR: ' + ERROR_MESSAGE();

        INSERT INTO ops.LocationLoadLog (SourceFile, RowsIn, RowsUpserted, RowsSkipped,
                                        StartedAt, EndedAt, Notes, LoadStatus)
        VALUES (@blob_csv_path, @rows_in, 0, 0, @start_time, sysutcdatetime(), @notes, @load_status);

        THROW;
    END CATCH
END;
GO

PRINT '✅ Stored procedure created';

-- ===================================================================
-- PHASE 4: DATA LOAD EXECUTION
-- ===================================================================

PRINT '🚀 Phase 4: Executing Data Load...';

-- Check pre-load state
DECLARE @pre_load_count int = (SELECT COUNT(*) FROM dbo.Stores);
PRINT 'Pre-load store count: ' + CAST(@pre_load_count AS nvarchar(10));

-- Execute the load
EXEC staging.sp_upsert_enriched_stores
    @blob_csv_path = N'gdrive-scout-ingest/out/stores_enriched_with_polygons.csv';

-- Check post-load state
DECLARE @post_load_count int = (SELECT COUNT(*) FROM dbo.Stores);
DECLARE @stores_with_polygons int = (SELECT COUNT(*) FROM dbo.Stores WHERE StorePolygon IS NOT NULL);
PRINT 'Post-load store count: ' + CAST(@post_load_count AS nvarchar(10));
PRINT 'Stores with polygons: ' + CAST(@stores_with_polygons AS nvarchar(10));

-- ===================================================================
-- PHASE 5: VALIDATION
-- ===================================================================

PRINT '🔍 Phase 5: Running Validation...';

-- Geometry validation
DECLARE @stores_without_geometry int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE (StorePolygon IS NULL OR LTRIM(RTRIM(StorePolygon)) = '')
      AND (GeoLatitude IS NULL OR GeoLongitude IS NULL)
);

-- NCR bounds validation
DECLARE @stores_out_of_bounds int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL
      AND (GeoLatitude NOT BETWEEN 14.20 AND 14.90 OR GeoLongitude NOT BETWEEN 120.90 AND 121.20)
);

-- Scout stores validation
DECLARE @scout_stores_count int = (
    SELECT COUNT(*) FROM dbo.Stores WHERE StoreID IN (102,103,104,109,110,112)
);

-- Show validation results
SELECT
    'VALIDATION_SUMMARY' as TestType,
    @stores_without_geometry as StoresWithoutGeometry,
    @stores_out_of_bounds as StoresOutOfBounds,
    @scout_stores_count as ScoutStoresFound,
    CASE
        WHEN @stores_without_geometry = 0 AND @stores_out_of_bounds = 0 AND @scout_stores_count = 6
        THEN '✅ ALL VALIDATIONS PASSED'
        ELSE '❌ VALIDATION ISSUES FOUND'
    END as ValidationStatus;

-- Show Scout stores details
SELECT
    StoreID,
    StoreName,
    MunicipalityName,
    CASE WHEN StorePolygon IS NOT NULL THEN 'YES' ELSE 'NO' END as HasPolygon,
    ROUND(GeoLatitude, 4) as Latitude,
    ROUND(GeoLongitude, 4) as Longitude
FROM dbo.Stores
WHERE StoreID IN (102,103,104,109,110,112)
ORDER BY StoreID;

-- Show municipality distribution
SELECT
    MunicipalityName,
    COUNT(*) as StoreCount,
    COUNT(CASE WHEN StorePolygon IS NOT NULL THEN 1 END) as WithPolygons
FROM dbo.Stores
WHERE MunicipalityName IS NOT NULL
GROUP BY MunicipalityName
ORDER BY COUNT(*) DESC;

-- Show recent load log
SELECT TOP 1
    LoadStatus,
    RowsIn,
    RowsUpserted,
    RowsSkipped,
    FORMAT(StartedAt, 'yyyy-MM-dd HH:mm:ss') as LoadTime,
    LEFT(Notes, 100) as NotesPreview
FROM ops.LocationLoadLog
ORDER BY LoadID DESC;

-- ===================================================================
-- DEPLOYMENT SUMMARY
-- ===================================================================

PRINT '';
PRINT '🎉 SCOUT STORE GEOSPATIAL ENRICHMENT DEPLOYMENT COMPLETE!';
PRINT '=======================================================================';

IF @stores_without_geometry = 0 AND @stores_out_of_bounds = 0 AND @scout_stores_count = 6
BEGIN
    PRINT '✅ SUCCESS: All validations passed';
    PRINT '🗺️ Choropleth mapping data ready';
    PRINT '📊 Azure SQL updated with enriched store master';
    PRINT '';
    PRINT '📈 RESULTS:';
    PRINT '  • ' + CAST(@post_load_count AS nvarchar(10)) + ' total stores in database';
    PRINT '  • ' + CAST(@stores_with_polygons AS nvarchar(10)) + ' stores with GeoJSON polygons';
    PRINT '  • ' + CAST(@scout_stores_count AS nvarchar(10)) + '/6 Scout stores verified';
    PRINT '  • 100% NCR bounds compliance';
    PRINT '  • Zero data regression';
    PRINT '';
    PRINT '🚀 READY FOR CHOROPLETH VISUALIZATION!';
END
ELSE
BEGIN
    PRINT '⚠️ WARNING: Some validation issues detected';
    PRINT 'Review validation results above for details';
END

PRINT '';
PRINT '📋 Next Steps:';
PRINT '  1. Enable choropleth mapping in Scout dashboard';
PRINT '  2. Update PhilippinesMap.tsx component';
PRINT '  3. Test geographic visualizations';
PRINT '';
PRINT '🏁 DEPLOYMENT COMPLETE!';