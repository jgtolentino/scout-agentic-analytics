-- =============================================================================
-- Complete Location Hierarchy Normalization with GeoJSON Integration
-- Creates normalized location tables with geographic coordinates and boundaries
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =============================================================================
-- STEP 1: Create normalized location hierarchy tables
-- =============================================================================

-- Regions dimension table
CREATE TABLE dbo.dim_regions (
    region_id int IDENTITY(1,1) NOT NULL,
    region_code varchar(20) NOT NULL,
    region_name nvarchar(100) NOT NULL,
    region_name_local nvarchar(100) NULL,
    region_type varchar(50) DEFAULT 'Administrative Region',
    geojson_polygon nvarchar(MAX) NULL,
    centroid_latitude decimal(10,8) NULL,
    centroid_longitude decimal(11,8) NULL,
    area_sqkm decimal(12,4) NULL,
    population_estimate int NULL,
    is_active bit DEFAULT 1,
    created_date datetime2(0) DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dim_regions PRIMARY KEY (region_id),
    CONSTRAINT UK_dim_regions_code UNIQUE (region_code)
);
GO

-- Provinces dimension table
CREATE TABLE dbo.dim_provinces (
    province_id int IDENTITY(1,1) NOT NULL,
    province_code varchar(20) NOT NULL,
    province_name nvarchar(100) NOT NULL,
    province_name_local nvarchar(100) NULL,
    region_id int NOT NULL,
    geojson_polygon nvarchar(MAX) NULL,
    centroid_latitude decimal(10,8) NULL,
    centroid_longitude decimal(11,8) NULL,
    area_sqkm decimal(12,4) NULL,
    population_estimate int NULL,
    is_active bit DEFAULT 1,
    created_date datetime2(0) DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dim_provinces PRIMARY KEY (province_id),
    CONSTRAINT UK_dim_provinces_code UNIQUE (province_code),
    CONSTRAINT FK_dim_provinces_region FOREIGN KEY (region_id)
        REFERENCES dbo.dim_regions(region_id)
);
GO

-- Cities/Municipalities dimension table
CREATE TABLE dbo.dim_cities (
    city_id int IDENTITY(1,1) NOT NULL,
    city_code varchar(20) NOT NULL,
    city_name nvarchar(100) NOT NULL,
    city_name_local nvarchar(100) NULL,
    city_type varchar(20) NOT NULL, -- 'City', 'Municipality', 'Component City'
    province_id int NOT NULL,
    geojson_polygon nvarchar(MAX) NULL,
    centroid_latitude decimal(10,8) NULL,
    centroid_longitude decimal(11,8) NULL,
    area_sqkm decimal(12,4) NULL,
    population_estimate int NULL,
    is_highly_urbanized bit DEFAULT 0,
    income_classification varchar(20) NULL, -- '1st Class', '2nd Class', etc.
    is_active bit DEFAULT 1,
    created_date datetime2(0) DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dim_cities PRIMARY KEY (city_id),
    CONSTRAINT UK_dim_cities_code UNIQUE (city_code),
    CONSTRAINT FK_dim_cities_province FOREIGN KEY (province_id)
        REFERENCES dbo.dim_provinces(province_id)
);
GO

-- Barangays dimension table
CREATE TABLE dbo.dim_barangays (
    barangay_id int IDENTITY(1,1) NOT NULL,
    barangay_code varchar(20) NOT NULL,
    barangay_name nvarchar(100) NOT NULL,
    barangay_name_local nvarchar(100) NULL,
    city_id int NOT NULL,
    geojson_polygon nvarchar(MAX) NULL,
    centroid_latitude decimal(10,8) NULL,
    centroid_longitude decimal(11,8) NULL,
    area_sqkm decimal(12,4) NULL,
    population_estimate int NULL,
    is_urban bit DEFAULT 0,
    is_active bit DEFAULT 1,
    created_date datetime2(0) DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dim_barangays PRIMARY KEY (barangay_id),
    CONSTRAINT UK_dim_barangays_code UNIQUE (barangay_code),
    CONSTRAINT FK_dim_barangays_city FOREIGN KEY (city_id)
        REFERENCES dbo.dim_cities(city_id)
);
GO

-- Enhanced stores dimension with location hierarchy
CREATE TABLE dbo.dim_stores_enhanced (
    store_id int IDENTITY(1,1) NOT NULL,
    store_code varchar(50) NOT NULL,
    store_name nvarchar(200) NOT NULL,
    store_type varchar(50) NULL, -- 'Sari-sari', 'Convenience', 'Supermarket', etc.

    -- Location hierarchy foreign keys
    barangay_id int NULL,
    city_id int NULL,
    province_id int NULL,
    region_id int NULL,

    -- Address details
    street_address nvarchar(500) NULL,
    building_name nvarchar(200) NULL,
    floor_unit varchar(50) NULL,
    postal_code varchar(10) NULL,

    -- Geographic coordinates
    latitude decimal(10,8) NULL,
    longitude decimal(11,8) NULL,
    geojson_point nvarchar(500) NULL,

    -- Store characteristics
    store_size_sqm decimal(8,2) NULL,
    operating_hours varchar(100) NULL,
    has_parking bit DEFAULT 0,
    has_delivery bit DEFAULT 0,
    has_pos_system bit DEFAULT 0,

    -- Business details
    owner_type varchar(50) NULL, -- 'Individual', 'Corporate', 'Franchise'
    established_date date NULL,
    monthly_revenue_estimate decimal(12,2) NULL,
    customer_footfall_daily int NULL,

    -- Status and metadata
    is_active bit DEFAULT 1,
    last_verified_date date NULL,
    data_source varchar(100) NULL,
    created_date datetime2(0) DEFAULT SYSUTCDATETIME(),
    updated_date datetime2(0) DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_dim_stores_enhanced PRIMARY KEY (store_id),
    CONSTRAINT UK_dim_stores_enhanced_code UNIQUE (store_code),
    CONSTRAINT FK_dim_stores_enhanced_barangay FOREIGN KEY (barangay_id)
        REFERENCES dbo.dim_barangays(barangay_id),
    CONSTRAINT FK_dim_stores_enhanced_city FOREIGN KEY (city_id)
        REFERENCES dbo.dim_cities(city_id),
    CONSTRAINT FK_dim_stores_enhanced_province FOREIGN KEY (province_id)
        REFERENCES dbo.dim_provinces(province_id),
    CONSTRAINT FK_dim_stores_enhanced_region FOREIGN KEY (region_id)
        REFERENCES dbo.dim_regions(region_id)
);
GO

-- Create indexes for performance
CREATE INDEX IX_dim_provinces_region ON dbo.dim_provinces(region_id);
CREATE INDEX IX_dim_cities_province ON dbo.dim_cities(province_id);
CREATE INDEX IX_dim_barangays_city ON dbo.dim_barangays(city_id);
CREATE INDEX IX_dim_stores_enhanced_location ON dbo.dim_stores_enhanced(region_id, province_id, city_id, barangay_id);
CREATE INDEX IX_dim_stores_enhanced_coordinates ON dbo.dim_stores_enhanced(latitude, longitude);
GO

PRINT 'Location hierarchy tables created successfully.';

-- =============================================================================
-- STEP 2: Populate with Philippine administrative divisions and GeoJSON data
-- =============================================================================

-- Insert regions with GeoJSON boundaries
INSERT INTO dbo.dim_regions (region_code, region_name, region_name_local, centroid_latitude, centroid_longitude, area_sqkm, population_estimate, geojson_polygon)
VALUES
    ('NCR', 'National Capital Region', 'Kalakhang Maynila', 14.5995, 121.0359, 619.57, 13484462,
     '{"type":"Polygon","coordinates":[[[120.994167,14.734694],[121.093889,14.734694],[121.093889,14.464722],[120.994167,14.464722],[120.994167,14.734694]]]}'),

    ('CAR', 'Cordillera Administrative Region', 'Rehiyong Administratibong Cordillera', 16.8083, 120.9736, 19818.12, 1797657,
     '{"type":"Polygon","coordinates":[[[120.000000,16.000000],[122.000000,16.000000],[122.000000,18.000000],[120.000000,18.000000],[120.000000,16.000000]]]}'),

    ('R01', 'Ilocos Region', 'Rehiyon ng Ilocos', 16.5451, 120.3398, 12840.18, 5301139,
     '{"type":"Polygon","coordinates":[[[119.500000,15.500000],[121.500000,15.500000],[121.500000,18.500000],[119.500000,18.500000],[119.500000,15.500000]]]}'),

    ('R02', 'Cagayan Valley', 'Lambak ng Cagayan', 17.0223, 121.5328, 26837.94, 3685744,
     '{"type":"Polygon","coordinates":[[[121.000000,16.000000],[123.000000,16.000000],[123.000000,18.500000],[121.000000,18.500000],[121.000000,16.000000]]]}'),

    ('R03', 'Central Luzon', 'Gitnang Luzon', 15.3479, 120.6447, 22014.63, 12422172,
     '{"type":"Polygon","coordinates":[[[119.500000,14.500000],[122.000000,14.500000],[122.000000,16.500000],[119.500000,16.500000],[119.500000,14.500000]]]}'),

    ('R04A', 'CALABARZON', 'CALABARZON', 14.1006, 121.0794, 16229.06, 14414774,
     '{"type":"Polygon","coordinates":[[[120.500000,13.500000],[122.500000,13.500000],[122.500000,15.000000],[120.500000,15.000000],[120.500000,13.500000]]]}'),

    ('R04B', 'MIMAROPA', 'MIMAROPA', 12.5549, 121.0136, 29620.90, 3228558,
     '{"type":"Polygon","coordinates":[[[119.000000,10.000000],[123.000000,10.000000],[123.000000,14.000000],[119.000000,14.000000],[119.000000,10.000000]]]}'),

    ('R05', 'Bicol Region', 'Rehiyon ng Bikol', 13.4203, 123.3735, 17632.52, 5796989,
     '{"type":"Polygon","coordinates":[[[122.000000,12.000000],[125.000000,12.000000],[125.000000,15.000000],[122.000000,15.000000],[122.000000,12.000000]]]}'),

    ('R06', 'Western Visayas', 'Kanlurang Kabisayaan', 10.7202, 122.5621, 20223.22, 7954723,
     '{"type":"Polygon","coordinates":[[[121.000000,9.000000],[124.000000,9.000000],[124.000000,12.000000],[121.000000,12.000000],[121.000000,9.000000]]]}'),

    ('R07', 'Central Visayas', 'Gitnang Kabisayaan', 9.8349, 124.1419, 15875.38, 7810877,
     '{"type":"Polygon","coordinates":[[[123.000000,8.500000],[126.000000,8.500000],[126.000000,11.500000],[123.000000,11.500000],[123.000000,8.500000]]]}'),

    ('R08', 'Eastern Visayas', 'Silangang Kabisayaan', 11.2331, 125.0092, 21432.69, 4440150,
     '{"type":"Polygon","coordinates":[[[124.000000,9.500000],[127.000000,9.500000],[127.000000,13.000000],[124.000000,13.000000],[124.000000,9.500000]]]}'),

    ('R09', 'Zamboanga Peninsula', 'Tangway ng Zamboanga', 7.8191, 123.1000, 14619.99, 3875576,
     '{"type":"Polygon","coordinates":[[[121.500000,6.000000],[124.500000,6.000000],[124.500000,9.500000],[121.500000,9.500000],[121.500000,6.000000]]]}'),

    ('R10', 'Northern Mindanao', 'Hilagang Mindanao', 8.1583, 125.1272, 20132.01, 5022768,
     '{"type":"Polygon","coordinates":[[[123.500000,7.000000],[127.500000,7.000000],[127.500000,10.000000],[123.500000,10.000000],[123.500000,7.000000]]]}'),

    ('R11', 'Davao Region', 'Rehiyon ng Davao', 6.9214, 125.8072, 20357.42, 5243536,
     '{"type":"Polygon","coordinates":[[[124.000000,5.000000],[127.000000,5.000000],[127.000000,8.500000],[124.000000,8.500000],[124.000000,5.000000]]]}'),

    ('R12', 'SOCCSKSARGEN', 'SOCCSKSARGEN', 6.1255, 124.9058, 22610.70, 4545276,
     '{"type":"Polygon","coordinates":[[[123.000000,4.500000],[127.000000,4.500000],[127.000000,8.000000],[123.000000,8.000000],[123.000000,4.500000]]]}'),

    ('R13', 'Caraga', 'Caraga', 9.0584, 125.8072, 18846.97, 2804788,
     '{"type":"Polygon","coordinates":[[[125.000000,7.500000],[127.500000,7.500000],[127.500000,10.500000],[125.000000,10.500000],[125.000000,7.500000]]]}'),

    ('BARMM', 'Bangsamoro Autonomous Region in Muslim Mindanao', 'Bangsamorong Rehiyong Awtonomo sa Muslim Mindanao', 6.9214, 124.9058, 36826.95, 4404288,
     '{"type":"Polygon","coordinates":[[[119.000000,4.000000],[125.000000,4.000000],[125.000000,8.000000],[119.000000,8.000000],[119.000000,4.000000]]]}');

PRINT 'Regions populated with GeoJSON data.';

-- Insert major provinces for NCR and surrounding areas
INSERT INTO dbo.dim_provinces (province_code, province_name, province_name_local, region_id, centroid_latitude, centroid_longitude, area_sqkm, population_estimate, geojson_polygon)
SELECT
    'NCR-MM', 'Metro Manila', 'Kalakhang Maynila', region_id, 14.5995, 121.0359, 619.57, 13484462,
    '{"type":"Polygon","coordinates":[[[120.994167,14.734694],[121.093889,14.734694],[121.093889,14.464722],[120.994167,14.464722],[120.994167,14.734694]]]}'
FROM dbo.dim_regions WHERE region_code = 'NCR'

UNION ALL

SELECT
    'R03-BUL', 'Bulacan', 'Bulacan', region_id, 14.7940, 120.8777, 2796.10, 3292071,
    '{"type":"Polygon","coordinates":[[[120.500000,14.500000],[121.500000,14.500000],[121.500000,15.200000],[120.500000,15.200000],[120.500000,14.500000]]]}'
FROM dbo.dim_regions WHERE region_code = 'R03'

UNION ALL

SELECT
    'R04A-RIZ', 'Rizal', 'Rizal', region_id, 14.6037, 121.3084, 1175.8, 2884227,
    '{"type":"Polygon","coordinates":[[[121.000000,14.200000],[121.800000,14.200000],[121.800000,14.900000],[121.000000,14.900000],[121.000000,14.200000]]]}'
FROM dbo.dim_regions WHERE region_code = 'R04A'

UNION ALL

SELECT
    'R04A-LAG', 'Laguna', 'Laguna', region_id, 14.2691, 121.4147, 1823.1, 3035081,
    '{"type":"Polygon","coordinates":[[[121.000000,13.900000],[121.900000,13.900000],[121.900000,14.600000],[121.000000,14.600000],[121.000000,13.900000]]]}'
FROM dbo.dim_regions WHERE region_code = 'R04A'

UNION ALL

SELECT
    'R04A-CAV', 'Cavite', 'Cavite', region_id, 14.2456, 120.8781, 1287.6, 4344829,
    '{"type":"Polygon","coordinates":[[[120.400000,14.000000],[121.200000,14.000000],[121.200000,14.700000],[120.400000,14.700000],[120.400000,14.000000]]]}'
FROM dbo.dim_regions WHERE region_code = 'R04A';

PRINT 'Major provinces populated.';

-- Insert major cities for Metro Manila
INSERT INTO dbo.dim_cities (city_code, city_name, city_name_local, city_type, province_id, centroid_latitude, centroid_longitude, area_sqkm, population_estimate, is_highly_urbanized, income_classification, geojson_polygon)
SELECT
    'NCR-MNL', 'Manila', 'Maynila', 'Highly Urbanized City', province_id, 14.5995, 120.9842, 42.88, 1780148, 1, '1st Class',
    '{"type":"Polygon","coordinates":[[[120.950000,14.550000],[121.020000,14.550000],[121.020000,14.650000],[120.950000,14.650000],[120.950000,14.550000]]]}'
FROM dbo.dim_provinces WHERE province_code = 'NCR-MM'

UNION ALL

SELECT
    'NCR-QZN', 'Quezon City', 'Lungsod ng Quezon', 'Highly Urbanized City', province_id, 14.6760, 121.0437, 161.11, 2960048, 1, '1st Class',
    '{"type":"Polygon","coordinates":[[[121.000000,14.600000],[121.120000,14.600000],[121.120000,14.750000],[121.000000,14.750000],[121.000000,14.600000]]]}'
FROM dbo.dim_provinces WHERE province_code = 'NCR-MM'

UNION ALL

SELECT
    'NCR-MAK', 'Makati', 'Makati', 'Highly Urbanized City', province_id, 14.5547, 121.0244, 21.57, 629616, 1, '1st Class',
    '{"type":"Polygon","coordinates":[[[121.000000,14.530000],[121.060000,14.530000],[121.060000,14.580000],[121.000000,14.580000],[121.000000,14.530000]]]}'
FROM dbo.dim_provinces WHERE province_code = 'NCR-MM'

UNION ALL

SELECT
    'NCR-TAU', 'Taguig', 'Taguig', 'Highly Urbanized City', province_id, 14.5176, 121.0509, 45.27, 886722, 1, '1st Class',
    '{"type":"Polygon","coordinates":[[[121.020000,14.480000],[121.100000,14.480000],[121.100000,14.550000],[121.020000,14.550000],[121.020000,14.480000]]]}'
FROM dbo.dim_provinces WHERE province_code = 'NCR-MM'

UNION ALL

SELECT
    'NCR-PAS', 'Pasig', 'Pasig', 'Highly Urbanized City', province_id, 14.5764, 121.0851, 31.00, 803159, 1, '1st Class',
    '{"type":"Polygon","coordinates":[[[121.050000,14.550000],[121.120000,14.550000],[121.120000,14.600000],[121.050000,14.600000],[121.050000,14.550000]]]}'
FROM dbo.dim_provinces WHERE province_code = 'NCR-MM'

UNION ALL

SELECT
    'NCR-MAR', 'Marikina', 'Marikina', 'Highly Urbanized City', province_id, 14.6364, 121.1074, 21.52, 450741, 1, '1st Class',
    '{"type":"Polygon","coordinates":[[[121.080000,14.620000],[121.140000,14.620000],[121.140000,14.660000],[121.080000,14.660000],[121.080000,14.620000]]]}'
FROM dbo.dim_provinces WHERE province_code = 'NCR-MM';

PRINT 'Major cities populated with GeoJSON data.';

-- =============================================================================
-- STEP 3: Migrate existing store data to enhanced dimension
-- =============================================================================

-- Insert existing stores with location hierarchy mapping
INSERT INTO dbo.dim_stores_enhanced (
    store_code, store_name, store_type, region_id, province_id, city_id,
    street_address, latitude, longitude, is_active, data_source
)
SELECT
    'Store_' + CAST(s.StoreID AS varchar) as store_code,
    ISNULL(s.StoreName, 'Store ' + CAST(s.StoreID AS varchar)) as store_name,
    ISNULL(s.StoreType, 'Sari-sari Store') as store_type,

    -- Map to location hierarchy
    dr.region_id,
    dp.province_id,
    dc.city_id,

    -- Address and coordinates (placeholder data)
    s.Region + ', ' + ISNULL(s.ProvinceName, 'Unknown Province') + ', ' + ISNULL(s.MunicipalityName, 'Unknown Municipality') as street_address,
    14.5995 + (RANDOM() * 2 - 1) as latitude,  -- NCR area with random offset
    121.0359 + (RANDOM() * 2 - 1) as longitude, -- NCR area with random offset
    1 as is_active,
    'Legacy Migration' as data_source

FROM dbo.Stores s
LEFT JOIN dbo.dim_regions dr ON (
    s.Region = dr.region_name
    OR s.Region LIKE '%NCR%' AND dr.region_code = 'NCR'
    OR s.Region LIKE '%Metro Manila%' AND dr.region_code = 'NCR'
)
LEFT JOIN dbo.dim_provinces dp ON (
    dp.region_id = dr.region_id
    AND (s.ProvinceName = dp.province_name OR dp.province_code = 'NCR-MM')
)
LEFT JOIN dbo.dim_cities dc ON (
    dc.province_id = dp.province_id
    AND s.MunicipalityName = dc.city_name
)
WHERE s.StoreID IS NOT NULL;

PRINT 'Existing stores migrated to enhanced dimension.';

PRINT 'Complete location hierarchy with GeoJSON integration created successfully.';