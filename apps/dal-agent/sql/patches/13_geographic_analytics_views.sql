-- =============================================================================
-- Geographic Analytics Views and Functions
-- Advanced location-based analytics with spatial capabilities
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =============================================================================
-- STEP 1: Geographic utility functions
-- =============================================================================

-- Function to calculate distance between two points (Haversine formula)
CREATE OR ALTER FUNCTION dbo.fn_calculate_distance_km(
    @lat1 decimal(10,8),
    @lon1 decimal(11,8),
    @lat2 decimal(10,8),
    @lon2 decimal(11,8)
)
RETURNS decimal(12,4)
AS
BEGIN
    DECLARE @distance decimal(12,4);
    DECLARE @R decimal(12,4) = 6371; -- Earth's radius in km
    DECLARE @dLat decimal(12,8);
    DECLARE @dLon decimal(12,8);
    DECLARE @a decimal(12,8);
    DECLARE @c decimal(12,8);

    -- Convert degrees to radians
    SET @dLat = RADIANS(@lat2 - @lat1);
    SET @dLon = RADIANS(@lon2 - @lon1);
    SET @lat1 = RADIANS(@lat1);
    SET @lat2 = RADIANS(@lat2);

    -- Haversine formula
    SET @a = SIN(@dLat/2) * SIN(@dLat/2) +
             COS(@lat1) * COS(@lat2) *
             SIN(@dLon/2) * SIN(@dLon/2);
    SET @c = 2 * ATN2(SQRT(@a), SQRT(1-@a));
    SET @distance = @R * @c;

    RETURN @distance;
END;
GO

-- Function to determine if a point is within a bounding box
CREATE OR ALTER FUNCTION dbo.fn_point_in_bounds(
    @latitude decimal(10,8),
    @longitude decimal(11,8),
    @north_bound decimal(10,8),
    @south_bound decimal(10,8),
    @east_bound decimal(11,8),
    @west_bound decimal(11,8)
)
RETURNS bit
AS
BEGIN
    IF @latitude BETWEEN @south_bound AND @north_bound
       AND @longitude BETWEEN @west_bound AND @east_bound
        RETURN 1;
    RETURN 0;
END;
GO

-- =============================================================================
-- STEP 2: Complete location hierarchy view
-- =============================================================================

CREATE OR ALTER VIEW platinum.v_location_hierarchy_complete AS
SELECT
    -- Store information
    se.store_id,
    se.store_code,
    se.store_name,
    se.store_type,
    se.latitude,
    se.longitude,
    se.street_address,

    -- Barangay level
    b.barangay_id,
    b.barangay_code,
    b.barangay_name,
    b.barangay_name_local,
    b.is_urban,

    -- City level
    c.city_id,
    c.city_code,
    c.city_name,
    c.city_name_local,
    c.city_type,
    c.is_highly_urbanized,
    c.income_classification,

    -- Province level
    p.province_id,
    p.province_code,
    p.province_name,
    p.province_name_local,

    -- Region level
    r.region_id,
    r.region_code,
    r.region_name,
    r.region_name_local,
    r.region_type,

    -- Geographic data
    r.geojson_polygon as region_geojson,
    p.geojson_polygon as province_geojson,
    c.geojson_polygon as city_geojson,
    b.geojson_polygon as barangay_geojson,

    -- Centroids for region analysis
    r.centroid_latitude as region_lat,
    r.centroid_longitude as region_lon,
    p.centroid_latitude as province_lat,
    p.centroid_longitude as province_lon,
    c.centroid_latitude as city_lat,
    c.centroid_longitude as city_lon,

    -- Area information
    r.area_sqkm as region_area_sqkm,
    p.area_sqkm as province_area_sqkm,
    c.area_sqkm as city_area_sqkm,
    b.area_sqkm as barangay_area_sqkm,

    -- Population estimates
    r.population_estimate as region_population,
    p.population_estimate as province_population,
    c.population_estimate as city_population,
    b.population_estimate as barangay_population,

    -- Full address hierarchy
    CONCAT(
        ISNULL(se.street_address, ''),
        CASE WHEN b.barangay_name IS NOT NULL THEN ', Brgy. ' + b.barangay_name ELSE '' END,
        CASE WHEN c.city_name IS NOT NULL THEN ', ' + c.city_name ELSE '' END,
        CASE WHEN p.province_name IS NOT NULL THEN ', ' + p.province_name ELSE '' END,
        CASE WHEN r.region_name IS NOT NULL THEN ', ' + r.region_name ELSE '' END
    ) as full_address,

    -- Location classification
    CASE
        WHEN c.is_highly_urbanized = 1 THEN 'Highly Urbanized City'
        WHEN c.city_type = 'City' THEN 'City'
        WHEN c.city_type = 'Municipality' THEN 'Municipality'
        ELSE 'Other'
    END as location_classification,

    -- Status flags
    se.is_active as store_active,
    b.is_active as barangay_active,
    c.is_active as city_active,
    p.is_active as province_active,
    r.is_active as region_active

FROM dbo.dim_stores_enhanced se
LEFT JOIN dbo.dim_barangays b ON b.barangay_id = se.barangay_id
LEFT JOIN dbo.dim_cities c ON c.city_id = se.city_id
LEFT JOIN dbo.dim_provinces p ON p.province_id = se.province_id
LEFT JOIN dbo.dim_regions r ON r.region_id = se.region_id
WHERE se.is_active = 1;
GO

-- =============================================================================
-- STEP 3: Enhanced canonical view with complete location hierarchy
-- =============================================================================

CREATE OR ALTER VIEW canonical.v_transactions_enhanced_with_location AS
SELECT
    -- Transaction core
    vf.interaction_id,
    vf.TransactionID,
    vf.Amount,
    vf.Quantity,
    vf.TransactionDate,

    -- Product information
    vf.Category,
    vf.Brand,
    vf.SKU,
    vf.Barcode,
    vf.Brand_Logo,

    -- Demographics
    vf.Demographics_Age,
    vf.Demographics_Gender,
    vf.Demographics_Role,

    -- AI detection
    vf.Brand_Confidence,
    vf.Detection_Type,
    vf.Transaction_Context,

    -- Complete location hierarchy
    loc.store_id,
    loc.store_code,
    loc.store_name,
    loc.store_type,
    loc.full_address,
    loc.location_classification,

    -- Administrative hierarchy
    loc.barangay_name,
    loc.city_name,
    loc.city_type,
    loc.province_name,
    loc.region_name,
    loc.region_code,

    -- Geographic coordinates
    loc.latitude as store_latitude,
    loc.longitude as store_longitude,
    loc.region_lat,
    loc.region_lon,
    loc.province_lat,
    loc.province_lon,
    loc.city_lat,
    loc.city_lon,

    -- Nielsen integration
    dsn.nielsen_category_name,
    dsn.nielsen_group_name,
    dsn.nielsen_dept_name,
    dsn.parent_company,
    dsn.sari_sari_priority,
    dsn.ph_market_relevant,

    -- Computed geographic fields
    CASE
        WHEN loc.region_code = 'NCR' THEN 'Metro Manila'
        WHEN loc.region_code IN ('R03', 'R04A') THEN 'Greater Manila Area'
        WHEN loc.region_code IN ('R06', 'R07', 'R08') THEN 'Visayas'
        WHEN loc.region_code IN ('R09', 'R10', 'R11', 'R12', 'R13', 'BARMM') THEN 'Mindanao'
        ELSE 'Luzon'
    END as island_group,

    CASE
        WHEN loc.is_highly_urbanized = 1 THEN 'Urban'
        WHEN loc.city_type = 'City' THEN 'Semi-Urban'
        ELSE 'Rural'
    END as urbanization_level,

    -- Population density classification
    CASE
        WHEN loc.city_population > 1000000 THEN 'Mega City'
        WHEN loc.city_population > 500000 THEN 'Large City'
        WHEN loc.city_population > 100000 THEN 'Medium City'
        WHEN loc.city_population > 50000 THEN 'Small City'
        ELSE 'Town/Municipality'
    END as city_size_category

FROM canonical.v_transactions_flat_enhanced vf
LEFT JOIN dbo.Stores s ON s.StoreName = vf.Store
LEFT JOIN dbo.dim_stores_enhanced se ON se.store_code = 'Store_' + CAST(s.StoreID AS varchar)
LEFT JOIN platinum.v_location_hierarchy_complete loc ON loc.store_id = se.store_id
LEFT JOIN dbo.dim_sku_nielsen dsn ON dsn.brand_name = vf.Brand;
GO

-- =============================================================================
-- STEP 4: Geographic analytics views
-- =============================================================================

-- Regional performance analytics
CREATE OR ALTER VIEW gold.v_regional_performance_analytics AS
SELECT
    region_code,
    region_name,
    island_group,

    -- Transaction metrics
    COUNT(*) as total_transactions,
    COUNT(DISTINCT Brand) as unique_brands,
    COUNT(DISTINCT store_code) as active_stores,
    SUM(Amount) as total_revenue,
    AVG(Amount) as avg_transaction_value,
    SUM(Quantity) as total_quantity,

    -- Demographics
    COUNT(DISTINCT Demographics_Age) as age_diversity,
    COUNT(CASE WHEN Demographics_Gender = 'Male' THEN 1 END) as male_transactions,
    COUNT(CASE WHEN Demographics_Gender = 'Female' THEN 1 END) as female_transactions,

    -- Product categories
    COUNT(CASE WHEN nielsen_dept_name = 'Food & Beverages' THEN 1 END) as food_beverage_transactions,
    COUNT(CASE WHEN nielsen_dept_name = 'Personal Care' THEN 1 END) as personal_care_transactions,
    COUNT(CASE WHEN nielsen_dept_name = 'Household' THEN 1 END) as household_transactions,

    -- Urbanization analysis
    COUNT(CASE WHEN urbanization_level = 'Urban' THEN 1 END) as urban_transactions,
    COUNT(CASE WHEN urbanization_level = 'Semi-Urban' THEN 1 END) as semi_urban_transactions,
    COUNT(CASE WHEN urbanization_level = 'Rural' THEN 1 END) as rural_transactions,

    -- Market potential indicators
    region_lat,
    region_lon,
    AVG(CAST(city_population AS decimal)) as avg_city_population,
    COUNT(CASE WHEN city_size_category = 'Mega City' THEN 1 END) as mega_city_transactions,

    -- Data quality
    COUNT(CASE WHEN store_latitude IS NOT NULL THEN 1 END) as geocoded_transactions,
    ROUND(100.0 * COUNT(CASE WHEN store_latitude IS NOT NULL THEN 1 END) / COUNT(*), 1) as geocoding_rate

FROM canonical.v_transactions_enhanced_with_location
WHERE TransactionDate >= DATEADD(month, -12, GETDATE())
GROUP BY region_code, region_name, island_group, region_lat, region_lon;
GO

-- City-level market intelligence
CREATE OR ALTER VIEW gold.v_city_market_intelligence AS
SELECT
    city_name,
    city_type,
    province_name,
    region_name,
    city_size_category,
    urbanization_level,

    -- Store network
    COUNT(DISTINCT store_code) as store_count,
    COUNT(*) as total_transactions,
    SUM(Amount) as total_revenue,
    AVG(Amount) as avg_basket_value,

    -- Brand performance
    COUNT(DISTINCT Brand) as brand_variety,
    STRING_AGG(Brand, ', ') WITHIN GROUP (ORDER BY COUNT(*) DESC) as top_brands,

    -- Demographics insights
    AVG(CAST(Demographics_Age AS int)) as avg_customer_age,
    ROUND(100.0 * COUNT(CASE WHEN Demographics_Gender = 'Female' THEN 1 END) / COUNT(*), 1) as female_customer_pct,

    -- Category mix
    ROUND(100.0 * COUNT(CASE WHEN nielsen_dept_name = 'Food & Beverages' THEN 1 END) / COUNT(*), 1) as food_beverage_pct,
    ROUND(100.0 * COUNT(CASE WHEN nielsen_dept_name = 'Personal Care' THEN 1 END) / COUNT(*), 1) as personal_care_pct,

    -- Geographic data
    city_lat,
    city_lon,
    city_population,

    -- Market opportunity score
    CASE
        WHEN city_population > 500000 AND AVG(Amount) > 50 THEN 'High Opportunity'
        WHEN city_population > 100000 AND AVG(Amount) > 30 THEN 'Medium Opportunity'
        ELSE 'Standard Market'
    END as market_opportunity,

    -- Last transaction date
    MAX(TransactionDate) as last_transaction_date

FROM canonical.v_transactions_enhanced_with_location
WHERE TransactionDate >= DATEADD(month, -6, GETDATE())
  AND city_name IS NOT NULL
GROUP BY city_name, city_type, province_name, region_name, city_size_category,
         urbanization_level, city_lat, city_lon, city_population
HAVING COUNT(*) >= 10; -- Minimum transactions for statistical relevance
GO

-- Store proximity and clustering analysis
CREATE OR ALTER VIEW gold.v_store_proximity_analysis AS
SELECT
    s1.store_code as store_a,
    s1.store_name as store_a_name,
    s1.city_name as store_a_city,
    s2.store_code as store_b,
    s2.store_name as store_b_name,
    s2.city_name as store_b_city,

    -- Distance calculation
    dbo.fn_calculate_distance_km(s1.store_latitude, s1.store_longitude,
                                 s2.store_latitude, s2.store_longitude) as distance_km,

    -- Clustering indicators
    CASE
        WHEN dbo.fn_calculate_distance_km(s1.store_latitude, s1.store_longitude,
                                         s2.store_latitude, s2.store_longitude) <= 1 THEN 'Same Cluster (1km)'
        WHEN dbo.fn_calculate_distance_km(s1.store_latitude, s1.store_longitude,
                                         s2.store_latitude, s2.store_longitude) <= 5 THEN 'Nearby (5km)'
        WHEN dbo.fn_calculate_distance_km(s1.store_latitude, s1.store_longitude,
                                         s2.store_latitude, s2.store_longitude) <= 10 THEN 'Local Area (10km)'
        ELSE 'Distant'
    END as proximity_classification,

    -- Market overlap potential
    CASE
        WHEN s1.city_name = s2.city_name THEN 'Same City'
        WHEN s1.province_name = s2.province_name THEN 'Same Province'
        WHEN s1.region_name = s2.region_name THEN 'Same Region'
        ELSE 'Different Region'
    END as market_overlap

FROM platinum.v_location_hierarchy_complete s1
CROSS JOIN platinum.v_location_hierarchy_complete s2
WHERE s1.store_id < s2.store_id  -- Avoid duplicates
  AND s1.store_latitude IS NOT NULL
  AND s1.store_longitude IS NOT NULL
  AND s2.store_latitude IS NOT NULL
  AND s2.store_longitude IS NOT NULL
  AND dbo.fn_calculate_distance_km(s1.store_latitude, s1.store_longitude,
                                   s2.store_latitude, s2.store_longitude) <= 50; -- Within 50km only
GO

PRINT 'Geographic analytics views created successfully.';

-- =============================================================================
-- STEP 5: Sample GeoJSON export procedure
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_export_stores_geojson
    @region_code varchar(20) = NULL,
    @city_name nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        'Feature' as type,
        JSON_QUERY(CONCAT(
            '{"type":"Point","coordinates":[',
            store_longitude, ',', store_latitude,
            ']}'
        )) as geometry,
        JSON_QUERY(CONCAT(
            '{"store_code":"', store_code,
            '","store_name":"', store_name,
            '","store_type":"', store_type,
            '","city_name":"', city_name,
            '","region_name":"', region_name,
            '","full_address":"', REPLACE(full_address, '"', '\"'),
            '","classification":"', location_classification,
            '"}'
        )) as properties
    FROM platinum.v_location_hierarchy_complete
    WHERE (@region_code IS NULL OR region_code = @region_code)
      AND (@city_name IS NULL OR city_name = @city_name)
      AND store_latitude IS NOT NULL
      AND store_longitude IS NOT NULL
    FOR JSON PATH;
END;
GO

PRINT 'GeoJSON export procedure created successfully.';