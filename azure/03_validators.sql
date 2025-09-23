-- Scout Store Location Validation Queries for Azure SQL
-- Zero-trust validation suite to ensure data integrity after upsert

-- ===================================================================
-- VALIDATION SUITE: ZERO-TRUST INVARIANTS
-- ===================================================================

PRINT '🔍 Running Scout Store Location Validation Suite...';
PRINT '';

-- ===================================================================
-- VALIDATOR 1: GEOMETRY PRESENCE (ZERO-TRUST REQUIREMENT)
-- ===================================================================

PRINT '1️⃣ Validating geometry presence (polygon OR coordinates)...';

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
WHERE
    MunicipalityName IS NULL
    OR (
        (StorePolygon IS NULL OR LTRIM(RTRIM(StorePolygon)) = '')
        AND (GeoLatitude IS NULL OR GeoLongitude IS NULL)
    );

IF @@ROWCOUNT = 0
    PRINT '   ✅ All stores have required geometry (polygon OR coordinates)';
ELSE
    PRINT '   ❌ Some stores lack required geometry - VALIDATION FAILED';

PRINT '';

-- ===================================================================
-- VALIDATOR 2: NCR BOUNDS COMPLIANCE
-- ===================================================================

PRINT '2️⃣ Validating NCR coordinate bounds (14.2-14.9, 120.9-121.2)...';

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
WHERE
    GeoLatitude IS NOT NULL
    AND GeoLongitude IS NOT NULL
    AND (
        GeoLatitude NOT BETWEEN 14.20 AND 14.90
        OR GeoLongitude NOT BETWEEN 120.90 AND 121.20
    );

IF @@ROWCOUNT = 0
    PRINT '   ✅ All coordinates within NCR bounds';
ELSE
    PRINT '   ❌ Some coordinates outside NCR bounds - VALIDATION FAILED';

PRINT '';

-- ===================================================================
-- VALIDATOR 3: MUNICIPALITY NORMALIZATION
-- ===================================================================

PRINT '3️⃣ Validating municipality normalization...';

WITH normalized_municipalities AS (
    SELECT DISTINCT MunicipalityName
    FROM dbo.Stores
    WHERE MunicipalityName IS NOT NULL
),
expected_ncr_municipalities AS (
    SELECT municipality FROM (VALUES
        ('Manila'), ('Quezon City'), ('Makati'), ('Taguig'), ('Pasig'),
        ('Pateros'), ('Malabon'), ('Navotas'), ('Caloocan'), ('Valenzuela'),
        ('Pasay'), ('Parañaque'), ('Muntinlupa'), ('Las Piñas'),
        ('Marikina'), ('Mandaluyong'), ('San Juan')
    ) AS m(municipality)
)
SELECT
    nm.MunicipalityName,
    COUNT(*) as StoreCount,
    CASE
        WHEN EXISTS (SELECT 1 FROM expected_ncr_municipalities e WHERE e.municipality = nm.MunicipalityName)
        THEN 'VALID_NCR'
        ELSE 'UNKNOWN_MUNICIPALITY'
    END as ValidationStatus
FROM normalized_municipalities nm
LEFT JOIN dbo.Stores s ON s.MunicipalityName = nm.MunicipalityName
GROUP BY nm.MunicipalityName
ORDER BY
    CASE
        WHEN EXISTS (SELECT 1 FROM expected_ncr_municipalities e WHERE e.municipality = nm.MunicipalityName)
        THEN 0 ELSE 1
    END,
    COUNT(*) DESC;

PRINT '   ℹ️ Municipality distribution shown above';

-- Check for non-NCR municipalities
IF EXISTS (
    SELECT 1 FROM dbo.Stores
    WHERE MunicipalityName NOT IN (
        'Manila', 'Quezon City', 'Makati', 'Taguig', 'Pasig',
        'Pateros', 'Malabon', 'Navotas', 'Caloocan', 'Valenzuela',
        'Pasay', 'Parañaque', 'Muntinlupa', 'Las Piñas',
        'Marikina', 'Mandaluyong', 'San Juan'
    )
    AND MunicipalityName IS NOT NULL
)
    PRINT '   ⚠️ Some municipalities not in NCR standard list';
ELSE
    PRINT '   ✅ All municipalities use NCR standard names';

PRINT '';

-- ===================================================================
-- VALIDATOR 4: PSGC CODE CONSISTENCY
-- ===================================================================

PRINT '4️⃣ Validating PSGC code consistency...';

SELECT
    COUNT(*) as TotalStores,
    COUNT(psgc_region) as WithRegionCode,
    COUNT(psgc_citymun) as WithCityCode,
    COUNT(psgc_barangay) as WithBarangayCode,
    ROUND(CAST(COUNT(psgc_region) AS float) / COUNT(*) * 100, 1) as RegionCodePct,
    ROUND(CAST(COUNT(psgc_citymun) AS float) / COUNT(*) * 100, 1) as CityCodePct,
    ROUND(CAST(COUNT(psgc_barangay) AS float) / COUNT(*) * 100, 1) as BarangayCodePct
FROM dbo.Stores;

-- Check for invalid region codes (should be 130000000 for NCR)
SELECT
    COUNT(*) as InvalidRegionCodes
FROM dbo.Stores
WHERE
    psgc_region IS NOT NULL
    AND psgc_region != '130000000';

IF EXISTS (SELECT 1 FROM dbo.Stores WHERE psgc_region IS NOT NULL AND psgc_region != '130000000')
    PRINT '   ⚠️ Some stores have non-NCR region codes';
ELSE
    PRINT '   ✅ All PSGC region codes are NCR (130000000)';

PRINT '';

-- ===================================================================
-- VALIDATOR 5: POLYGON FORMAT VALIDATION
-- ===================================================================

PRINT '5️⃣ Validating GeoJSON polygon format...';

SELECT
    COUNT(*) as TotalPolygons,
    COUNT(CASE WHEN ISJSON(StorePolygon) = 1 THEN 1 END) as ValidJSON,
    COUNT(CASE WHEN StorePolygon LIKE '%"type"%"Polygon"%' THEN 1 END) as HasPolygonType,
    COUNT(CASE WHEN StorePolygon LIKE '%"coordinates"%' THEN 1 END) as HasCoordinates
FROM dbo.Stores
WHERE StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '';

-- Check for invalid polygon formats
SELECT
    StoreID,
    StoreName,
    LEFT(StorePolygon, 100) + '...' as PolygonPreview,
    CASE
        WHEN ISJSON(StorePolygon) = 0 THEN 'INVALID_JSON'
        WHEN StorePolygon NOT LIKE '%"type"%"Polygon"%' THEN 'MISSING_TYPE'
        WHEN StorePolygon NOT LIKE '%"coordinates"%' THEN 'MISSING_COORDINATES'
        ELSE 'VALID'
    END as PolygonStatus
FROM dbo.Stores
WHERE
    StorePolygon IS NOT NULL
    AND LTRIM(RTRIM(StorePolygon)) != ''
    AND (
        ISJSON(StorePolygon) = 0
        OR StorePolygon NOT LIKE '%"type"%"Polygon"%'
        OR StorePolygon NOT LIKE '%"coordinates"%'
    );

IF @@ROWCOUNT = 0
    PRINT '   ✅ All polygons have valid GeoJSON format';
ELSE
    PRINT '   ❌ Some polygons have invalid GeoJSON format';

PRINT '';

-- ===================================================================
-- VALIDATOR 6: SCOUT STORES VERIFICATION (KNOWN GOOD STORES)
-- ===================================================================

PRINT '6️⃣ Validating known Scout stores (102, 103, 104, 109, 110, 112)...';

SELECT
    StoreID,
    StoreName,
    MunicipalityName,
    BarangayName,
    GeoLatitude,
    GeoLongitude,
    CASE
        WHEN StorePolygon IS NOT NULL THEN 'HAS_POLYGON'
        ELSE 'NO_POLYGON'
    END as PolygonStatus,
    psgc_citymun,
    CASE
        WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 'COMPLETE'
        WHEN StorePolygon IS NOT NULL THEN 'POLYGON_ONLY'
        ELSE 'INCOMPLETE'
    END as DataQuality
FROM dbo.Stores
WHERE StoreID IN (102, 103, 104, 109, 110, 112)
ORDER BY StoreID;

-- Check if all Scout stores are present
DECLARE @scout_stores_count int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE StoreID IN (102, 103, 104, 109, 110, 112)
);

IF @scout_stores_count = 6
    PRINT '   ✅ All 6 Scout stores found in database';
ELSE
    PRINT '   ⚠️ Expected 6 Scout stores, found ' + CAST(@scout_stores_count AS nvarchar(10));

PRINT '';

-- ===================================================================
-- VALIDATOR 7: AUDIT TRAIL VERIFICATION
-- ===================================================================

PRINT '7️⃣ Checking recent load operations...';

SELECT TOP 5
    LoadID,
    SourceFile,
    RowsIn,
    RowsUpserted,
    RowsSkipped,
    DATEDIFF(second, StartedAt, EndedAt) as DurationSeconds,
    LoadStatus,
    LEFT(Notes, 100) + CASE WHEN LEN(Notes) > 100 THEN '...' ELSE '' END as NotesPreview,
    FORMAT(StartedAt, 'yyyy-MM-dd HH:mm:ss') as StartedAt
FROM ops.LocationLoadLog
ORDER BY LoadID DESC;

PRINT '   ℹ️ Recent load operations shown above';

-- ===================================================================
-- VALIDATION SUMMARY
-- ===================================================================

PRINT '';
PRINT '📊 VALIDATION SUMMARY:';

DECLARE @total_stores int = (SELECT COUNT(*) FROM dbo.Stores);
DECLARE @stores_with_coords int = (SELECT COUNT(*) FROM dbo.Stores WHERE GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL);
DECLARE @stores_with_polygons int = (SELECT COUNT(*) FROM dbo.Stores WHERE StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '');
DECLARE @stores_with_psgc int = (SELECT COUNT(*) FROM dbo.Stores WHERE psgc_citymun IS NOT NULL);
DECLARE @ncr_compliant_coords int = (
    SELECT COUNT(*)
    FROM dbo.Stores
    WHERE GeoLatitude IS NOT NULL
      AND GeoLongitude IS NOT NULL
      AND GeoLatitude BETWEEN 14.20 AND 14.90
      AND GeoLongitude BETWEEN 120.90 AND 121.20
);

PRINT 'Total stores: ' + CAST(@total_stores AS nvarchar(10));
PRINT 'Stores with coordinates: ' + CAST(@stores_with_coords AS nvarchar(10)) + ' (' + CAST(ROUND(CAST(@stores_with_coords AS float) / @total_stores * 100, 1) AS nvarchar(10)) + '%)';
PRINT 'Stores with polygons: ' + CAST(@stores_with_polygons AS nvarchar(10)) + ' (' + CAST(ROUND(CAST(@stores_with_polygons AS float) / @total_stores * 100, 1) AS nvarchar(10)) + '%)';
PRINT 'Stores with PSGC codes: ' + CAST(@stores_with_psgc AS nvarchar(10)) + ' (' + CAST(ROUND(CAST(@stores_with_psgc AS float) / @total_stores * 100, 1) AS nvarchar(10)) + '%)';
PRINT 'NCR-compliant coordinates: ' + CAST(@ncr_compliant_coords AS nvarchar(10)) + '/' + CAST(@stores_with_coords AS nvarchar(10));

-- Final validation status
IF @stores_with_coords + @stores_with_polygons >= @total_stores
   AND @ncr_compliant_coords = @stores_with_coords
BEGIN
    PRINT '';
    PRINT '✅ VALIDATION PASSED: Zero-trust invariants satisfied';
    PRINT '🗺️ Choropleth mapping data ready for visualization';
END
ELSE
BEGIN
    PRINT '';
    PRINT '❌ VALIDATION FAILED: Zero-trust requirements not met';
    PRINT 'Review validation results above for specific issues';
END

PRINT '';
PRINT '🏁 Validation suite complete!';