-- ===================================================================
-- BRUNO COMMAND 4: EXECUTE DATA LOAD
-- Execute this fourth in Bruno - This loads the actual data
-- ===================================================================

PRINT '🚀 Executing Scout Store Data Load...';
PRINT '';

-- Check current state before load
PRINT '📊 PRE-LOAD STATUS:';
SELECT COUNT(*) as CurrentStoreCount FROM dbo.Stores;

SELECT COUNT(*) as StoresWithPolygons
FROM dbo.Stores
WHERE StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '';

SELECT COUNT(*) as StoresWithCoordinates
FROM dbo.Stores
WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL;

PRINT '';
PRINT '⏳ Starting enriched store data load...';

-- Execute the main load procedure
EXEC staging.sp_upsert_enriched_stores
    @blob_csv_path = N'gdrive-scout-ingest/out/stores_enriched_with_polygons.csv';

PRINT '';
PRINT '📊 POST-LOAD STATUS:';

-- Immediate post-load verification
SELECT COUNT(*) as TotalStoresAfterLoad FROM dbo.Stores;

SELECT COUNT(*) as StoresWithPolygonsAfterLoad
FROM dbo.Stores
WHERE StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '';

SELECT COUNT(*) as StoresWithCoordinatesAfterLoad
FROM dbo.Stores
WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL;

-- Check Scout stores specifically
PRINT '';
PRINT '🔍 SCOUT STORES VERIFICATION:';
SELECT
    StoreID,
    StoreName,
    MunicipalityName,
    BarangayName,
    CASE
        WHEN StorePolygon IS NOT NULL THEN 'HAS_POLYGON'
        WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 'HAS_COORDINATES'
        ELSE 'NO_GEOMETRY'
    END as GeometryStatus,
    CASE
        WHEN GeoLatitude BETWEEN 14.20 AND 14.90
             AND GeoLongitude BETWEEN 120.90 AND 121.20 THEN 'NCR_COMPLIANT'
        WHEN GeoLatitude IS NULL OR GeoLongitude IS NULL THEN 'NO_COORDINATES'
        ELSE 'OUT_OF_BOUNDS'
    END as BoundsStatus
FROM dbo.Stores
WHERE StoreID IN (102, 103, 104, 109, 110, 112)
ORDER BY StoreID;

-- Check load operation log
PRINT '';
PRINT '📋 LOAD OPERATION LOG:';
SELECT TOP 1
    LoadID,
    SourceFile,
    RowsIn,
    RowsUpserted,
    RowsSkipped,
    LoadStatus,
    DATEDIFF(second, StartedAt, EndedAt) as DurationSeconds,
    FORMAT(StartedAt, 'yyyy-MM-dd HH:mm:ss') as StartedAt,
    LEFT(Notes, 200) as NotesPreview
FROM ops.LocationLoadLog
ORDER BY LoadID DESC;

-- Quick validation checks
PRINT '';
PRINT '🛡️ ZERO-TRUST VALIDATION:';

-- Check for stores without required geometry
DECLARE @stores_without_geometry int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE (StorePolygon IS NULL OR LTRIM(RTRIM(StorePolygon)) = '')
      AND (GeoLatitude IS NULL OR GeoLongitude IS NULL)
);

-- Check for coordinates outside NCR bounds
DECLARE @stores_out_of_bounds int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE GeoLatitude IS NOT NULL
      AND GeoLongitude IS NOT NULL
      AND (GeoLatitude NOT BETWEEN 14.20 AND 14.90
           OR GeoLongitude NOT BETWEEN 120.90 AND 121.20)
);

SELECT
    @stores_without_geometry as StoresWithoutGeometry,
    @stores_out_of_bounds as StoresOutOfBounds,
    CASE
        WHEN @stores_without_geometry = 0 AND @stores_out_of_bounds = 0
        THEN '✅ VALIDATION PASSED'
        ELSE '❌ VALIDATION FAILED'
    END as ValidationStatus;

-- Municipality distribution
PRINT '';
PRINT '🏙️ MUNICIPALITY DISTRIBUTION:';
SELECT
    MunicipalityName,
    COUNT(*) as StoreCount,
    COUNT(CASE WHEN StorePolygon IS NOT NULL THEN 1 END) as WithPolygons,
    COUNT(CASE WHEN GeoLatitude IS NOT NULL THEN 1 END) as WithCoordinates
FROM dbo.Stores
WHERE MunicipalityName IS NOT NULL
GROUP BY MunicipalityName
ORDER BY COUNT(*) DESC;

PRINT '';
IF @stores_without_geometry = 0 AND @stores_out_of_bounds = 0
BEGIN
    PRINT '🎉 DATA LOAD SUCCESSFUL!';
    PRINT '✅ All zero-trust requirements satisfied';
    PRINT '🗺️ Choropleth mapping data ready';
    PRINT '';
    PRINT 'Next: Execute BRUNO_COMMAND_5_VALIDATION.sql for comprehensive validation';
END
ELSE
BEGIN
    PRINT '⚠️ DATA LOAD COMPLETED WITH WARNINGS';
    PRINT 'Run BRUNO_COMMAND_5_VALIDATION.sql for detailed analysis';
END

PRINT '';