-- ===================================================================
-- BRUNO COMMAND 3: DEPLOY COMPLETE STORED PROCEDURE
-- Execute this third in Bruno
-- ===================================================================

PRINT '📦 Deploying Complete Store Upsert Procedure...';

CREATE OR ALTER PROCEDURE staging.sp_upsert_enriched_stores
    @blob_csv_path nvarchar(400)  -- e.g. 'gdrive-scout-ingest/out/stores_enriched_with_polygons.csv'
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variables for audit tracking
    DECLARE @start_time datetime2 = sysutcdatetime();
    DECLARE @rows_in int = 0;
    DECLARE @rows_upserted int = 0;
    DECLARE @rows_skipped int = 0;
    DECLARE @notes nvarchar(4000) = '';
    DECLARE @load_status varchar(20) = 'RUNNING';

    BEGIN TRY
        PRINT '🔄 Starting data load process...';

        -- ===================================================================
        -- STEP 1: TRUNCATE STAGING TABLE
        -- ===================================================================
        TRUNCATE TABLE staging.StoreLocationImport;
        SET @notes = @notes + 'Staging truncated. ';

        -- ===================================================================
        -- STEP 2: LOAD CSV FROM BLOB STORAGE
        -- ===================================================================
        PRINT '📥 Loading CSV from blob storage...';

        DECLARE @sql nvarchar(max);
        SET @sql = N'
        INSERT INTO staging.StoreLocationImport
            (StoreID, StoreName, AddressLine, MunicipalityName, BarangayName,
             Region, ProvinceName, GeoLatitude, GeoLongitude, StorePolygon,
             psgc_region, psgc_citymun, psgc_barangay, SourceFile)
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
            NULLIF(LTRIM(RTRIM([psgc_barangay])),''''),
            ''' + @blob_csv_path + '''
        FROM OPENROWSET(
            BULK ''' + @blob_csv_path + ''',
            DATA_SOURCE = ''SCOUT_BLOB'',
            FORMAT = ''CSV'',
            PARSER_VERSION = ''2.0'',
            FIRSTROW = 2
        ) WITH (
            [StoreID]          varchar(32),
            [StoreName]        nvarchar(200),
            [AddressLine]      nvarchar(400),
            [MunicipalityName] nvarchar(80),
            [BarangayName]     nvarchar(120),
            [Region]           varchar(8),
            [ProvinceName]     varchar(50),
            [GeoLatitude]      varchar(64),
            [GeoLongitude]     varchar(64),
            [StorePolygon]     nvarchar(max),
            [psgc_region]      varchar(16),
            [psgc_citymun]     varchar(16),
            [psgc_barangay]    varchar(16)
        ) AS src
        WHERE TRY_CAST([StoreID] AS int) IS NOT NULL;';

        EXEC sp_executesql @sql;
        SET @rows_in = @@ROWCOUNT;
        SET @notes = @notes + 'Loaded ' + CAST(@rows_in AS nvarchar(10)) + ' rows. ';
        PRINT '✅ Loaded ' + CAST(@rows_in AS nvarchar(10)) + ' rows from CSV';

        -- ===================================================================
        -- STEP 3: NORMALIZE MUNICIPALITY NAMES (NCR canonical spellings)
        -- ===================================================================
        PRINT '🏙️ Normalizing municipality names...';

        WITH normalization AS (
            SELECT
                StoreID,
                UPPER(LTRIM(RTRIM(MunicipalityName))) AS muni_upper
            FROM staging.StoreLocationImport
        )
        UPDATE s
        SET
            MunicipalityName = CASE
                WHEN n.muni_upper IN ('QUEZON CITY','QC') THEN 'Quezon City'
                WHEN n.muni_upper IN ('CITY OF MANILA','MANILA') THEN 'Manila'
                WHEN n.muni_upper IN ('MAKATI','MAKATI CITY') THEN 'Makati'
                WHEN n.muni_upper = 'TAGUIG' THEN 'Taguig'
                WHEN n.muni_upper IN ('PASIG','PASIG CITY') THEN 'Pasig'
                WHEN n.muni_upper = 'PATEROS' THEN 'Pateros'
                WHEN n.muni_upper IN ('MALABON','MALABON CITY') THEN 'Malabon'
                WHEN n.muni_upper IN ('NAVOTAS','NAVOTAS CITY') THEN 'Navotas'
                WHEN n.muni_upper IN ('CALOOCAN','CALOOCAN CITY') THEN 'Caloocan'
                WHEN n.muni_upper IN ('VALENZUELA','VALENZUELA CITY') THEN 'Valenzuela'
                WHEN n.muni_upper IN ('PASAY','PASAY CITY') THEN 'Pasay'
                WHEN n.muni_upper IN ('PARAÑAQUE','PARANAQUE','PARAÑAQUE CITY') THEN 'Parañaque'
                WHEN n.muni_upper IN ('MUNTINLUPA','MUNTINLUPA CITY') THEN 'Muntinlupa'
                WHEN n.muni_upper IN ('LAS PINAS','LAS PIÑAS','LAS PIÑAS CITY') THEN 'Las Piñas'
                WHEN n.muni_upper IN ('MARIKINA','MARIKINA CITY') THEN 'Marikina'
                WHEN n.muni_upper IN ('MANDALUYONG','MANDALUYONG CITY') THEN 'Mandaluyong'
                WHEN n.muni_upper IN ('SAN JUAN','SAN JUAN CITY') THEN 'San Juan'
                ELSE s.MunicipalityName
            END,
            Region = 'NCR',
            ProvinceName = 'Metro Manila'
        FROM staging.StoreLocationImport s
        JOIN normalization n ON n.StoreID = s.StoreID;

        SET @notes = @notes + 'Municipalities normalized. ';

        -- ===================================================================
        -- STEP 4: VALIDATE NCR BOUNDS (zero-trust)
        -- ===================================================================
        PRINT '🗺️ Validating NCR coordinate bounds...';

        UPDATE staging.StoreLocationImport
        SET
            GeoLatitude = NULL,
            GeoLongitude = NULL
        WHERE
            GeoLatitude IS NOT NULL
            AND GeoLongitude IS NOT NULL
            AND NOT (GeoLatitude BETWEEN 14.20 AND 14.90
                    AND GeoLongitude BETWEEN 120.90 AND 121.20);

        SET @notes = @notes + 'NCR bounds validated. ';

        -- ===================================================================
        -- STEP 5: ENFORCE GEOMETRY PRESENCE (ZERO-TRUST)
        -- ===================================================================
        PRINT '🛡️ Enforcing geometry requirements...';

        WITH invalid_geometry AS (
            SELECT StoreID
            FROM staging.StoreLocationImport
            WHERE
                (StorePolygon IS NULL OR LTRIM(RTRIM(StorePolygon)) = '')
                AND (GeoLatitude IS NULL OR GeoLongitude IS NULL)
        )
        DELETE FROM staging.StoreLocationImport
        WHERE StoreID IN (SELECT StoreID FROM invalid_geometry);

        SET @rows_skipped = @rows_in - (SELECT COUNT(*) FROM staging.StoreLocationImport);
        IF @rows_skipped > 0
            SET @notes = @notes + 'Skipped ' + CAST(@rows_skipped AS nvarchar(10)) + ' rows (no geometry). ';

        -- ===================================================================
        -- STEP 6: MERGE INTO DBO.STORES (NO REGRESSIONS)
        -- ===================================================================
        PRINT '🔄 Merging into dbo.Stores with no-regression strategy...';

        MERGE dbo.Stores AS tgt
        USING staging.StoreLocationImport AS src
            ON tgt.StoreID = src.StoreID
        WHEN MATCHED THEN
            UPDATE SET
                StoreName        = COALESCE(NULLIF(src.StoreName,''),        tgt.StoreName),
                AddressLine      = COALESCE(NULLIF(src.AddressLine,''),      tgt.AddressLine),
                MunicipalityName = COALESCE(NULLIF(src.MunicipalityName,''), tgt.MunicipalityName),
                BarangayName     = COALESCE(NULLIF(src.BarangayName,''),     tgt.BarangayName),
                Region           = COALESCE(NULLIF(src.Region,''),           tgt.Region),
                ProvinceName     = COALESCE(NULLIF(src.ProvinceName,''),     tgt.ProvinceName),
                GeoLatitude      = COALESCE(src.GeoLatitude,                 tgt.GeoLatitude),
                GeoLongitude     = COALESCE(src.GeoLongitude,                tgt.GeoLongitude),
                StorePolygon     = COALESCE(NULLIF(src.StorePolygon,''),     tgt.StorePolygon),
                psgc_region      = COALESCE(NULLIF(src.psgc_region,''),      tgt.psgc_region),
                psgc_citymun     = COALESCE(NULLIF(src.psgc_citymun,''),     tgt.psgc_citymun),
                psgc_barangay    = COALESCE(NULLIF(src.psgc_barangay,''),    tgt.psgc_barangay)
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                StoreID, StoreName, AddressLine, MunicipalityName, BarangayName,
                Region, ProvinceName, GeoLatitude, GeoLongitude, StorePolygon,
                psgc_region, psgc_citymun, psgc_barangay
            )
            VALUES (
                src.StoreID, src.StoreName, src.AddressLine, src.MunicipalityName,
                src.BarangayName, COALESCE(NULLIF(src.Region,''), 'NCR'),
                COALESCE(NULLIF(src.ProvinceName,''), 'Metro Manila'),
                src.GeoLatitude, src.GeoLongitude, src.StorePolygon,
                src.psgc_region, src.psgc_citymun, src.psgc_barangay
            );

        SET @rows_upserted = @@ROWCOUNT;
        SET @notes = @notes + 'Upserted ' + CAST(@rows_upserted AS nvarchar(10)) + ' stores. ';
        SET @load_status = 'SUCCESS';

        PRINT '✅ Successfully upserted ' + CAST(@rows_upserted AS nvarchar(10)) + ' stores';

        -- ===================================================================
        -- STEP 7: LOG RESULTS
        -- ===================================================================
        INSERT INTO ops.LocationLoadLog (
            SourceFile, RowsIn, RowsUpserted, RowsSkipped,
            StartedAt, EndedAt, Notes, LoadStatus
        )
        VALUES (
            @blob_csv_path, @rows_in, @rows_upserted, @rows_skipped,
            @start_time, sysutcdatetime(), @notes, @load_status
        );

        -- Return summary
        SELECT
            @load_status AS Status,
            @rows_in AS RowsLoaded,
            @rows_upserted AS RowsUpserted,
            @rows_skipped AS RowsSkipped,
            @notes AS Details,
            DATEDIFF(second, @start_time, sysutcdatetime()) AS DurationSeconds;

        PRINT '🎉 DATA LOAD COMPLETED SUCCESSFULLY!';

    END TRY
    BEGIN CATCH
        -- Error handling
        SET @load_status = 'ERROR';
        SET @notes = @notes + 'ERROR: ' + ERROR_MESSAGE();

        PRINT '❌ ERROR: ' + ERROR_MESSAGE();

        -- Log error
        INSERT INTO ops.LocationLoadLog (
            SourceFile, RowsIn, RowsUpserted, RowsSkipped,
            StartedAt, EndedAt, Notes, LoadStatus
        )
        VALUES (
            @blob_csv_path, @rows_in, 0, 0,
            @start_time, sysutcdatetime(), @notes, @load_status
        );

        -- Re-throw error
        THROW;
    END CATCH
END;
GO

PRINT '✅ Stored procedure staging.sp_upsert_enriched_stores created successfully';
PRINT '';
PRINT '🎯 STORED PROCEDURE DEPLOYED!';
PRINT 'Next: Execute BRUNO_COMMAND_4_LOAD_DATA.sql';
PRINT '';