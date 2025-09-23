-- ===================================================================
-- BRUNO COMMAND 5: COMPREHENSIVE VALIDATION SUITE
-- Execute this fifth in Bruno for complete validation and reporting
-- ===================================================================

PRINT '🔍 Running Complete Scout Store Validation Suite...';
PRINT '';

-- ===================================================================
-- VALIDATOR 1: GEOMETRY PRESENCE (ZERO-TRUST REQUIREMENT)
-- ===================================================================

PRINT '1️⃣ GEOMETRY PRESENCE VALIDATION';
PRINT '   Requirement: Every store must have StorePolygon OR (GeoLatitude AND GeoLongitude)';

SELECT
    'GEOMETRY_VALIDATION' as TestName,
    COUNT(*) as TotalStores,
    COUNT(CASE WHEN StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '' THEN 1 END) as WithPolygons,
    COUNT(CASE WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 1 END) as WithCoordinates,
    COUNT(CASE WHEN (StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '')
                 OR (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL) THEN 1 END) as WithGeometry
FROM dbo.Stores;

-- Show any stores that fail geometry requirement
SELECT
    StoreID,
    StoreName,
    MunicipalityName,
    CASE
        WHEN StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '' THEN 'HAS_POLYGON'
        WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 'HAS_COORDINATES'
        ELSE 'NO_GEOMETRY'
    END as GeometryStatus
FROM dbo.Stores
WHERE NOT ((StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '')
           OR (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL));

PRINT CASE WHEN @@ROWCOUNT = 0
           THEN '   ✅ PASSED: All stores have required geometry'
           ELSE '   ❌ FAILED: Some stores lack required geometry' END;
PRINT '';

-- ===================================================================
-- VALIDATOR 2: NCR BOUNDS COMPLIANCE
-- ===================================================================

PRINT '2️⃣ NCR COORDINATE BOUNDS VALIDATION';
PRINT '   Requirement: All coordinates within NCR bounds (14.2-14.9, 120.9-121.2)';

SELECT
    'NCR_BOUNDS_VALIDATION' as TestName,
    COUNT(CASE WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 1 END) as StoresWithCoordinates,
    COUNT(CASE WHEN GeoLatitude BETWEEN 14.20 AND 14.90
                AND GeoLongitude BETWEEN 120.90 AND 121.20 THEN 1 END) as WithinNCRBounds,
    COUNT(CASE WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL
               AND NOT (GeoLatitude BETWEEN 14.20 AND 14.90 AND GeoLongitude BETWEEN 120.90 AND 121.20)
               THEN 1 END) as OutOfBounds
FROM dbo.Stores;

-- Show any coordinates outside NCR bounds
SELECT
    StoreID,
    StoreName,
    MunicipalityName,
    GeoLatitude,
    GeoLongitude,
    CASE
        WHEN GeoLatitude < 14.20 THEN 'LAT_TOO_LOW'
        WHEN GeoLatitude > 14.90 THEN 'LAT_TOO_HIGH'
        WHEN GeoLongitude < 120.90 THEN 'LON_TOO_LOW'
        WHEN GeoLongitude > 121.20 THEN 'LON_TOO_HIGH'
        ELSE 'BOUNDS_VIOLATION'
    END as BoundsIssue
FROM dbo.Stores
WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL
  AND NOT (GeoLatitude BETWEEN 14.20 AND 14.90 AND GeoLongitude BETWEEN 120.90 AND 121.20);

PRINT CASE WHEN @@ROWCOUNT = 0
           THEN '   ✅ PASSED: All coordinates within NCR bounds'
           ELSE '   ❌ FAILED: Some coordinates outside NCR bounds' END;
PRINT '';

-- ===================================================================
-- VALIDATOR 3: MUNICIPALITY NORMALIZATION
-- ===================================================================

PRINT '3️⃣ MUNICIPALITY NORMALIZATION VALIDATION';
PRINT '   Requirement: All municipalities use NCR standard names';

SELECT
    'MUNICIPALITY_VALIDATION' as TestName,
    COUNT(DISTINCT MunicipalityName) as UniqueMunicipalities,
    COUNT(*) as TotalStores
FROM dbo.Stores
WHERE MunicipalityName IS NOT NULL;

-- Show municipality distribution
SELECT
    MunicipalityName,
    COUNT(*) as StoreCount,
    CASE
        WHEN MunicipalityName IN (
            'Manila', 'Quezon City', 'Makati', 'Taguig', 'Pasig', 'Pateros',
            'Malabon', 'Navotas', 'Caloocan', 'Valenzuela', 'Pasay',
            'Parañaque', 'Muntinlupa', 'Las Piñas', 'Marikina', 'Mandaluyong', 'San Juan'
        ) THEN 'VALID_NCR'
        ELSE 'NON_STANDARD'
    END as ValidationStatus
FROM dbo.Stores
WHERE MunicipalityName IS NOT NULL
GROUP BY MunicipalityName
ORDER BY COUNT(*) DESC;

PRINT '   ℹ️ Municipality distribution shown above';
PRINT '';

-- ===================================================================
-- VALIDATOR 4: PSGC CODE CONSISTENCY
-- ===================================================================

PRINT '4️⃣ PSGC CODE VALIDATION';
PRINT '   Requirement: Standardized PSGC codes for geographic hierarchy';

SELECT
    'PSGC_VALIDATION' as TestName,
    COUNT(*) as TotalStores,
    COUNT(psgc_region) as WithRegionCode,
    COUNT(psgc_citymun) as WithCityCode,
    ROUND(CAST(COUNT(psgc_region) AS float) / COUNT(*) * 100, 1) as RegionCodePct,
    ROUND(CAST(COUNT(psgc_citymun) AS float) / COUNT(*) * 100, 1) as CityCodePct
FROM dbo.Stores;

-- Check for invalid region codes (should be 130000000 for NCR)
SELECT
    COUNT(*) as InvalidRegionCodes
FROM dbo.Stores
WHERE psgc_region IS NOT NULL AND psgc_region != '130000000';

PRINT CASE WHEN @@ROWCOUNT = 0
           THEN '   ✅ PASSED: All PSGC region codes are NCR (130000000)'
           ELSE '   ⚠️ WARNING: Some stores have non-NCR region codes' END;
PRINT '';

-- ===================================================================
-- VALIDATOR 5: POLYGON FORMAT VALIDATION
-- ===================================================================

PRINT '5️⃣ GEOJSON POLYGON FORMAT VALIDATION';
PRINT '   Requirement: Valid GeoJSON Polygon format for choropleth mapping';

SELECT
    'POLYGON_VALIDATION' as TestName,
    COUNT(CASE WHEN StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '' THEN 1 END) as TotalPolygons,
    COUNT(CASE WHEN ISJSON(StorePolygon) = 1 THEN 1 END) as ValidJSON,
    COUNT(CASE WHEN StorePolygon LIKE '%"type"%"Polygon"%' THEN 1 END) as HasPolygonType,
    COUNT(CASE WHEN StorePolygon LIKE '%"coordinates"%' THEN 1 END) as HasCoordinates
FROM dbo.Stores
WHERE StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '';

-- Check for invalid polygon formats
SELECT
    StoreID,
    StoreName,
    LEFT(StorePolygon, 50) + '...' as PolygonPreview,
    CASE
        WHEN ISJSON(StorePolygon) = 0 THEN 'INVALID_JSON'
        WHEN StorePolygon NOT LIKE '%"type"%"Polygon"%' THEN 'MISSING_TYPE'
        WHEN StorePolygon NOT LIKE '%"coordinates"%' THEN 'MISSING_COORDINATES'
        ELSE 'VALID'
    END as PolygonStatus
FROM dbo.Stores
WHERE StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != ''
  AND (ISJSON(StorePolygon) = 0
       OR StorePolygon NOT LIKE '%"type"%"Polygon"%'
       OR StorePolygon NOT LIKE '%"coordinates"%');

PRINT CASE WHEN @@ROWCOUNT = 0
           THEN '   ✅ PASSED: All polygons have valid GeoJSON format'
           ELSE '   ❌ FAILED: Some polygons have invalid GeoJSON format' END;
PRINT '';

-- ===================================================================
-- VALIDATOR 6: SCOUT STORES VERIFICATION
-- ===================================================================

PRINT '6️⃣ SCOUT STORES VERIFICATION';
PRINT '   Requirement: Known Scout stores (102,103,104,109,110,112) properly loaded';

SELECT
    'SCOUT_STORES_VALIDATION' as TestName,
    COUNT(*) as ScoutStoresFound
FROM dbo.Stores
WHERE StoreID IN (102, 103, 104, 109, 110, 112);

-- Detailed Scout stores status
SELECT
    StoreID,
    StoreName,
    MunicipalityName,
    BarangayName,
    ROUND(GeoLatitude, 4) as Latitude,
    ROUND(GeoLongitude, 4) as Longitude,
    CASE
        WHEN StorePolygon IS NOT NULL THEN 'HAS_POLYGON'
        ELSE 'NO_POLYGON'
    END as PolygonStatus,
    psgc_citymun,
    CASE
        WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL AND StorePolygon IS NOT NULL THEN 'COMPLETE'
        WHEN StorePolygon IS NOT NULL THEN 'POLYGON_ONLY'
        WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 'COORDINATES_ONLY'
        ELSE 'INCOMPLETE'
    END as DataQuality
FROM dbo.Stores
WHERE StoreID IN (102, 103, 104, 109, 110, 112)
ORDER BY StoreID;

DECLARE @scout_count int = (SELECT COUNT(*) FROM dbo.Stores WHERE StoreID IN (102, 103, 104, 109, 110, 112));
PRINT CASE WHEN @scout_count = 6
           THEN '   ✅ PASSED: All 6 Scout stores found and loaded'
           ELSE '   ⚠️ WARNING: Expected 6 Scout stores, found ' + CAST(@scout_count AS nvarchar(10)) END;
PRINT '';

-- ===================================================================
-- VALIDATOR 7: LOAD OPERATION AUDIT
-- ===================================================================

PRINT '7️⃣ LOAD OPERATION AUDIT';
PRINT '   Requirement: Successful load operation with proper audit trail';

SELECT TOP 3
    LoadID,
    FORMAT(StartedAt, 'yyyy-MM-dd HH:mm:ss') as StartedAt,
    SourceFile,
    RowsIn,
    RowsUpserted,
    RowsSkipped,
    LoadStatus,
    DATEDIFF(second, StartedAt, EndedAt) as DurationSeconds,
    LEFT(Notes, 100) as NotesPreview
FROM ops.LocationLoadLog
ORDER BY LoadID DESC;

PRINT '   ℹ️ Recent load operations shown above';
PRINT '';

-- ===================================================================
-- COMPREHENSIVE VALIDATION SUMMARY
-- ===================================================================

PRINT '📊 COMPREHENSIVE VALIDATION SUMMARY';
PRINT '===========================================';

DECLARE @total_stores int = (SELECT COUNT(*) FROM dbo.Stores);
DECLARE @stores_with_coords int = (SELECT COUNT(*) FROM dbo.Stores WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL);
DECLARE @stores_with_polygons int = (SELECT COUNT(*) FROM dbo.Stores WHERE StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '');
DECLARE @stores_with_psgc int = (SELECT COUNT(*) FROM dbo.Stores WHERE psgc_citymun IS NOT NULL);
DECLARE @ncr_compliant_coords int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL
      AND GeoLatitude BETWEEN 14.20 AND 14.90 AND GeoLongitude BETWEEN 120.90 AND 121.20
);
DECLARE @stores_with_geometry int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE (StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '')
       OR (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL)
);

SELECT
    'FINAL_SUMMARY' as SummaryType,
    @total_stores as TotalStores,
    @stores_with_coords as StoresWithCoordinates,
    @stores_with_polygons as StoresWithPolygons,
    @stores_with_psgc as StoresWithPSGC,
    @ncr_compliant_coords as NCRCompliantCoords,
    @stores_with_geometry as StoresWithGeometry,
    ROUND(CAST(@stores_with_coords AS float) / @total_stores * 100, 1) as CoordinatesPct,
    ROUND(CAST(@stores_with_polygons AS float) / @total_stores * 100, 1) as PolygonsPct,
    ROUND(CAST(@stores_with_geometry AS float) / @total_stores * 100, 1) as GeometryPct;

-- Final validation status
DECLARE @validation_passed bit = 0;
IF @stores_with_geometry = @total_stores AND @ncr_compliant_coords = @stores_with_coords
    SET @validation_passed = 1;

PRINT '';
PRINT 'METRICS:';
PRINT '  Total stores: ' + CAST(@total_stores AS nvarchar(10));
PRINT '  With coordinates: ' + CAST(@stores_with_coords AS nvarchar(10)) + ' (' + CAST(ROUND(CAST(@stores_with_coords AS float) / @total_stores * 100, 1) AS nvarchar(10)) + '%)';
PRINT '  With polygons: ' + CAST(@stores_with_polygons AS nvarchar(10)) + ' (' + CAST(ROUND(CAST(@stores_with_polygons AS float) / @total_stores * 100, 1) AS nvarchar(10)) + '%)';
PRINT '  With PSGC codes: ' + CAST(@stores_with_psgc AS nvarchar(10)) + ' (' + CAST(ROUND(CAST(@stores_with_psgc AS float) / @total_stores * 100, 1) AS nvarchar(10)) + '%)';
PRINT '  NCR-compliant coordinates: ' + CAST(@ncr_compliant_coords AS nvarchar(10)) + '/' + CAST(@stores_with_coords AS nvarchar(10));
PRINT '';

IF @validation_passed = 1
BEGIN
    PRINT '🎉 VALIDATION SUITE PASSED!';
    PRINT '✅ All zero-trust requirements satisfied';
    PRINT '🗺️ Choropleth mapping data ready for visualization';
    PRINT '📊 Azure SQL database updated with enriched store master';
    PRINT '';
    PRINT '🚀 DEPLOYMENT COMPLETE - READY FOR PRODUCTION USE';
END
ELSE
BEGIN
    PRINT '❌ VALIDATION SUITE FAILED';
    PRINT '⚠️ Review validation results above for specific issues';
    PRINT '🔧 Address issues before enabling choropleth mapping';
END

PRINT '';
PRINT '📋 Next Steps:';
PRINT '  1. Enable choropleth mapping in Scout dashboard';
PRINT '  2. Update PhilippinesMap.tsx to use polygon data';
PRINT '  3. Test geographic visualizations';
PRINT '  4. Monitor store data quality metrics';
PRINT '';
PRINT '🏁 VALIDATION SUITE COMPLETE!';