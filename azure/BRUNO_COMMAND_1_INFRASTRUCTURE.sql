-- ===================================================================
-- BRUNO COMMAND 1: AZURE SQL INFRASTRUCTURE SETUP
-- Execute this first in Bruno
-- ===================================================================

PRINT '🚀 Starting Scout Store Infrastructure Setup...';

-- Create support schemas (idempotent)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='staging')
    EXEC('CREATE SCHEMA staging');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='ops')
    EXEC('CREATE SCHEMA ops');

PRINT '✅ Support schemas created/verified';

-- Staging table for clean import (drop/create for simplicity)
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
  LoadedAt          datetime2     NOT NULL DEFAULT sysutcdatetime(),

  -- Zero-trust constraints
  CONSTRAINT chk_staging_ncr_bounds CHECK (
      (GeoLatitude IS NULL AND GeoLongitude IS NULL) OR
      (GeoLatitude BETWEEN 14.20 AND 14.90 AND GeoLongitude BETWEEN 120.90 AND 121.20)
  ),
  CONSTRAINT chk_staging_geometry_presence CHECK (
      (StorePolygon IS NOT NULL AND LTRIM(RTRIM(StorePolygon)) != '') OR
      (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL)
  )
);

PRINT '✅ Staging table created with zero-trust constraints';

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

PRINT '✅ Audit log table created';

-- Municipality normalization reference
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
    ('MANILA', 'Manila', '137401000'),
    ('CITY OF MANILA', 'Manila', '137401000'),
    ('MAKATI', 'Makati', '137405000'),
    ('MAKATI CITY', 'Makati', '137405000'),
    ('PATEROS', 'Pateros', '137414000'),
    ('MANDALUYONG', 'Mandaluyong', '137407000'),
    ('MANDALUYONG CITY', 'Mandaluyong', '137407000'),
    ('TAGUIG', 'Taguig', '137416000'),
    ('PASIG', 'Pasig', '137413000'),
    ('MALABON', 'Malabon', '137406000'),
    ('NAVOTAS', 'Navotas', '137410000'),
    ('PASAY', 'Pasay', '137412000'),
    ('PARAÑAQUE', 'Parañaque', '137411000'),
    ('PARANAQUE', 'Parañaque', '137411000'),
    ('MUNTINLUPA', 'Muntinlupa', '137409000'),
    ('MARIKINA', 'Marikina', '137408000'),
    ('LAS PINAS', 'Las Piñas', '137404000'),
    ('LAS PIÑAS', 'Las Piñas', '137404000'),
    ('SAN JUAN', 'San Juan', '137415000'),
    ('VALENZUELA', 'Valenzuela', '137417000'),
    ('CALOOCAN', 'Caloocan', '137403000');

    PRINT '✅ Municipality normalization reference created';
END;

-- Verify infrastructure
SELECT
    schema_name,
    COUNT(*) as table_count
FROM (
    SELECT 'staging' as schema_name, COUNT(*) as table_count
    FROM information_schema.tables
    WHERE table_schema = 'staging'
    UNION ALL
    SELECT 'ops' as schema_name, COUNT(*) as table_count
    FROM information_schema.tables
    WHERE table_schema = 'ops'
) t
GROUP BY schema_name;

PRINT '';
PRINT '🎯 INFRASTRUCTURE SETUP COMPLETE!';
PRINT 'Next: Execute BRUNO_COMMAND_2_BLOB_ACCESS.sql';
PRINT '';