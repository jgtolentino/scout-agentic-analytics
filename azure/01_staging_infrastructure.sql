-- Scout Store Location Staging Infrastructure for Azure SQL
-- Zero-trust geospatial data loading with polygon support
-- Compatible with sqltbwaprojectscoutserver.database.windows.net

-- ===================================================================
-- 1. CREATE SUPPORT SCHEMAS (IDEMPOTENT)
-- ===================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')
    EXEC('CREATE SCHEMA ops');

PRINT 'ℹ️ Support schemas created/verified';

-- ===================================================================
-- 2. CREATE STAGING TABLE FOR ENRICHED IMPORT
-- ===================================================================

-- Drop and recreate for clean import
IF OBJECT_ID('staging.StoreLocationImport', 'U') IS NOT NULL
    DROP TABLE staging.StoreLocationImport;

CREATE TABLE staging.StoreLocationImport (
    -- Core Store Data
    StoreID             int             NOT NULL,
    StoreName           nvarchar(200)   NULL,
    AddressLine         nvarchar(400)   NULL,

    -- Geographic Hierarchy
    MunicipalityName    nvarchar(80)    NULL,
    BarangayName        nvarchar(120)   NULL,
    Region              varchar(8)      NULL,
    ProvinceName        nvarchar(50)    NULL,

    -- Coordinates & Geometry
    GeoLatitude         float           NULL,
    GeoLongitude        float           NULL,
    StorePolygon        nvarchar(max)   NULL,

    -- PSGC Standardized Codes
    psgc_region         char(9)         NULL,
    psgc_province       char(9)         NULL,
    psgc_citymun        char(9)         NULL,
    psgc_barangay       char(9)         NULL,

    -- Audit Fields
    SourceFile          nvarchar(400)   NULL,
    EnrichedAt          datetime2       NULL,
    LoadedAt            datetime2       NOT NULL DEFAULT sysutcdatetime(),

    -- Constraints
    CONSTRAINT chk_staging_ncr_bounds CHECK (
        (GeoLatitude IS NULL AND GeoLongitude IS NULL) OR
        (GeoLatitude BETWEEN 14.20 AND 14.90 AND GeoLongitude BETWEEN 120.90 AND 121.20)
    ),
    CONSTRAINT chk_staging_geometry_presence CHECK (
        (StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '') OR
        (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL)
    )
);

-- Create index for efficient lookups
CREATE INDEX IX_StoreLocationImport_StoreID ON staging.StoreLocationImport(StoreID);

PRINT '✅ Staging table staging.StoreLocationImport created';

-- ===================================================================
-- 3. CREATE AUDIT LOG TABLE
-- ===================================================================

IF OBJECT_ID('ops.LocationLoadLog', 'U') IS NULL
BEGIN
    CREATE TABLE ops.LocationLoadLog (
        LoadID          bigint IDENTITY(1,1) PRIMARY KEY,
        SourceFile      nvarchar(400)       NULL,
        RowsIn          int                 NULL,
        RowsUpserted    int                 NULL,
        RowsSkipped     int                 NULL,
        StartedAt       datetime2           NOT NULL DEFAULT sysutcdatetime(),
        EndedAt         datetime2           NULL,
        Notes           nvarchar(4000)      NULL,
        LoadStatus      varchar(20)         NULL DEFAULT 'RUNNING'
    );

    PRINT '✅ Audit table ops.LocationLoadLog created';
END
ELSE
    PRINT 'ℹ️ Audit table ops.LocationLoadLog already exists';

-- ===================================================================
-- 4. CREATE BLOB STORAGE ACCESS (EXTERNAL DATA SOURCE)
-- ===================================================================

-- Note: This requires a SAS token to be configured
-- The SAS token should be container-level with READ permissions
-- Format: ?sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupyx&se=2025-12-31T23:59:59Z&st=...

-- Check if credential exists
IF NOT EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name = 'SCOUT_BLOB_SAS')
BEGIN
    PRINT '⚠️ Database scoped credential SCOUT_BLOB_SAS not found';
    PRINT '📋 Create it manually with:';
    PRINT 'CREATE DATABASE SCOPED CREDENTIAL SCOUT_BLOB_SAS';
    PRINT 'WITH IDENTITY=''SHARED ACCESS SIGNATURE'', SECRET=''?sv=2022...your_sas_token'';';
END
ELSE
    PRINT '✅ Database scoped credential SCOUT_BLOB_SAS found';

-- Check if external data source exists
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'SCOUT_BLOB')
BEGIN
    -- Only create if credential exists
    IF EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name = 'SCOUT_BLOB_SAS')
    BEGIN
        CREATE EXTERNAL DATA SOURCE SCOUT_BLOB
        WITH (
            TYPE = BLOB_STORAGE,
            LOCATION = 'https://projectscoutautoregstr.blob.core.windows.net',
            CREDENTIAL = SCOUT_BLOB_SAS
        );
        PRINT '✅ External data source SCOUT_BLOB created';
    END
    ELSE
        PRINT '⚠️ Cannot create external data source without SAS credential';
END
ELSE
    PRINT '✅ External data source SCOUT_BLOB already exists';

-- ===================================================================
-- 5. CREATE MUNICIPALITY NORMALIZATION REFERENCE
-- ===================================================================

IF OBJECT_ID('staging.NCRMunicipalityNormalization', 'U') IS NULL
BEGIN
    CREATE TABLE staging.NCRMunicipalityNormalization (
        VariantName         nvarchar(80)    NOT NULL,
        CanonicalName       nvarchar(80)    NOT NULL,
        PSGCCode           char(9)         NOT NULL,
        PRIMARY KEY (VariantName)
    );

    -- Insert normalization rules
    INSERT INTO staging.NCRMunicipalityNormalization (VariantName, CanonicalName, PSGCCode) VALUES
    ('QUEZON CITY', 'Quezon City', '137402000'),
    ('QC', 'Quezon City', '137402000'),
    ('MANILA', 'City of Manila', '137401000'),
    ('City of Manila', 'City of Manila', '137401000'),
    ('MAKATI', 'Makati City', '137405000'),
    ('Makati City', 'Makati City', '137405000'),
    ('PATEROS', 'Pateros', '137414000'),
    ('MANDALUYONG', 'Mandaluyong City', '137407000'),
    ('Mandaluyong City', 'Mandaluyong City', '137407000'),
    ('TAGUIG', 'Taguig City', '137416000'),
    ('PASIG', 'Pasig City', '137413000'),
    ('MALABON', 'Malabon City', '137406000'),
    ('NAVOTAS', 'Navotas City', '137410000'),
    ('PASAY', 'Pasay City', '137412000'),
    ('PARAÑAQUE', 'Parañaque City', '137411000'),
    ('PARANAQUE', 'Parañaque City', '137411000'),
    ('MUNTINLUPA', 'Muntinlupa City', '137409000'),
    ('MARIKINA', 'Marikina City', '137408000'),
    ('LAS PINAS', 'Las Piñas City', '137404000'),
    ('LAS PIÑAS', 'Las Piñas City', '137404000'),
    ('SAN JUAN', 'San Juan City', '137415000'),
    ('VALENZUELA', 'Valenzuela City', '137417000'),
    ('CALOOCAN', 'Caloocan City', '137403000');

    PRINT '✅ Municipality normalization reference created';
END
ELSE
    PRINT 'ℹ️ Municipality normalization reference already exists';

-- ===================================================================
-- 6. CREATE UTILITY FUNCTIONS
-- ===================================================================

-- Function to validate JSON polygon format
IF OBJECT_ID('staging.fn_IsValidGeoJSONPolygon', 'FN') IS NOT NULL
    DROP FUNCTION staging.fn_IsValidGeoJSONPolygon;
GO

CREATE FUNCTION staging.fn_IsValidGeoJSONPolygon(@polygon_json nvarchar(max))
RETURNS bit
AS
BEGIN
    DECLARE @is_valid bit = 0;

    -- Basic validation
    IF @polygon_json IS NOT NULL
       AND LTRIM(RTRIM(@polygon_json)) != ''
       AND ISJSON(@polygon_json) = 1
    BEGIN
        -- Check if it contains required GeoJSON structure
        IF @polygon_json LIKE '%"type"%"Polygon"%'
           AND @polygon_json LIKE '%"coordinates"%'
            SET @is_valid = 1;
    END

    RETURN @is_valid;
END;
GO

PRINT '✅ Utility function staging.fn_IsValidGeoJSONPolygon created';

-- ===================================================================
-- 7. VERIFY INFRASTRUCTURE
-- ===================================================================

PRINT '';
PRINT '🔍 Infrastructure Verification:';

SELECT
    'staging' as schema_name,
    COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'staging'
UNION ALL
SELECT
    'ops' as schema_name,
    COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'ops';

PRINT '';
PRINT '📋 Next Steps:';
PRINT '1. Configure SAS token: CREATE DATABASE SCOPED CREDENTIAL SCOUT_BLOB_SAS';
PRINT '2. Upload enriched CSV to blob storage';
PRINT '3. Run 02_upsert_stores_procedure.sql';
PRINT '4. Execute EXEC staging.sp_upsert_enriched_stores @blob_csv_path';
PRINT '';
PRINT '✅ Staging infrastructure setup complete!';