-- =====================================================
-- LOCATION-BASED PERSONA EXTENSION
-- Extends persona inference with geographic and demographic factors
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create location-based persona inference function
CREATE OR ALTER FUNCTION dbo.fn_infer_location_persona(
    @region_name NVARCHAR(100),
    @province_name NVARCHAR(100),
    @municipality_name NVARCHAR(100),
    @barangay_name NVARCHAR(100),
    @store_id INT,
    @transaction_hour TINYINT,
    @transaction_value DECIMAL(12,2),
    @age TINYINT,
    @gender NVARCHAR(10)
)
RETURNS TABLE
AS
RETURN (
    SELECT TOP 1
        location_persona,
        location_confidence_score,
        location_factors,
        economic_indicator,
        demographic_profile
    FROM (
        SELECT
            -- Urban vs Rural Classification
            CASE
                WHEN @region_name = 'NCR' THEN 'Metro-Urban-Professional'
                WHEN @region_name IN ('Region III', 'Region IV-A') AND @transaction_value > 150
                THEN 'Suburban-Affluent'
                WHEN @region_name IN ('Region I', 'Region II', 'Region V', 'Region VIII', 'Region IX', 'Region X', 'Region XI', 'Region XII')
                THEN 'Provincial-Traditional'
                WHEN @region_name IN ('CAR', 'ARMM', 'CARAGA')
                THEN 'Rural-Community-Oriented'
                WHEN @region_name IN ('Region VI', 'Region VII')
                THEN 'Island-Resilient'
                ELSE 'General-Regional'
            END AS location_persona,

            -- Confidence scoring based on data completeness
            CASE
                WHEN @region_name IS NOT NULL AND @province_name IS NOT NULL
                     AND @municipality_name IS NOT NULL AND @barangay_name IS NOT NULL
                THEN 0.9
                WHEN @region_name IS NOT NULL AND @province_name IS NOT NULL
                     AND @municipality_name IS NOT NULL
                THEN 0.8
                WHEN @region_name IS NOT NULL AND @province_name IS NOT NULL
                THEN 0.7
                WHEN @region_name IS NOT NULL
                THEN 0.6
                ELSE 0.3
            END AS location_confidence_score,

            -- Location factors influencing behavior
            CASE
                WHEN @region_name = 'NCR' THEN 'High-Density-Fast-Paced-Premium-Access'
                WHEN @region_name IN ('Region III', 'Region IV-A') THEN 'Semi-Urban-Growing-Middle-Class'
                WHEN @region_name IN ('Region VI', 'Region VII') THEN 'Island-Tourism-Service-Economy'
                WHEN @region_name IN ('Region I', 'Region II') THEN 'Agricultural-Traditional-Family-Oriented'
                WHEN @region_name IN ('CAR', 'ARMM') THEN 'Cultural-Community-Strong-Traditions'
                ELSE 'Mixed-Regional-Characteristics'
            END AS location_factors,

            -- Economic indicator based on region and transaction patterns
            CASE
                WHEN @region_name = 'NCR' AND @transaction_value > 200 THEN 'High-Income-Urban'
                WHEN @region_name = 'NCR' AND @transaction_value BETWEEN 100 AND 200 THEN 'Middle-Income-Urban'
                WHEN @region_name = 'NCR' AND @transaction_value < 100 THEN 'Working-Class-Urban'
                WHEN @region_name IN ('Region III', 'Region IV-A') AND @transaction_value > 150 THEN 'Emerging-Middle-Class'
                WHEN @region_name IN ('Region VI', 'Region VII') AND @transaction_value > 120 THEN 'Tourism-Service-Income'
                WHEN @transaction_value < 80 THEN 'Budget-Conscious-Rural'
                ELSE 'Standard-Regional-Income'
            END AS economic_indicator,

            -- Demographic profile based on location and customer attributes
            CASE
                WHEN @region_name = 'NCR' AND @age BETWEEN 25 AND 40 AND @gender = 'Female'
                THEN 'Urban-Professional-Female'
                WHEN @region_name = 'NCR' AND @age BETWEEN 20 AND 35 AND @transaction_hour BETWEEN 18 AND 22
                THEN 'Young-Urban-Night-Shopper'
                WHEN @region_name IN ('Region I', 'Region II', 'Region V') AND @age > 40
                THEN 'Rural-Family-Head'
                WHEN @region_name IN ('Region VI', 'Region VII') AND @age BETWEEN 18 AND 35
                THEN 'Island-Youth-Modern'
                WHEN @region_name IN ('CAR', 'ARMM') AND @age > 35
                THEN 'Traditional-Community-Elder'
                ELSE 'General-Regional-Demographic'
            END AS demographic_profile
    ) location_analysis
);
GO

-- Create comprehensive location-based shopping patterns view
CREATE OR ALTER VIEW dbo.v_location_shopping_patterns AS
SELECT
    r.RegionName AS region_name,
    p.ProvinceName AS province_name,

    -- Regional shopping characteristics
    CASE
        WHEN r.RegionName = 'NCR' THEN 'Metro-Convenience-Premium'
        WHEN r.RegionName IN ('Region III', 'Region IV-A') THEN 'Suburban-Family-Value'
        WHEN r.RegionName IN ('Region VI', 'Region VII') THEN 'Island-Community-Social'
        WHEN r.RegionName IN ('Region I', 'Region II', 'Region V') THEN 'Agricultural-Traditional-Bulk'
        WHEN r.RegionName IN ('CAR', 'ARMM', 'CARAGA') THEN 'Rural-Community-Cooperative'
        ELSE 'Mixed-Regional-Pattern'
    END AS regional_shopping_pattern,

    -- Time-based regional preferences
    CASE
        WHEN r.RegionName = 'NCR' THEN 'Early-Morning-Rush-Evening-Peak'
        WHEN r.RegionName IN ('Region III', 'Region IV-A') THEN 'Morning-Family-Time-Weekend-Focus'
        WHEN r.RegionName IN ('Region VI', 'Region VII') THEN 'Tourist-Influenced-Flexible-Hours'
        WHEN r.RegionName IN ('Region I', 'Region II') THEN 'Agricultural-Schedule-Early-Evening'
        ELSE 'Standard-Regional-Hours'
    END AS regional_time_preference,

    -- Economic behavior patterns
    CASE
        WHEN r.RegionName = 'NCR' THEN 'Price-Convenience-Balance-Premium-Acceptance'
        WHEN r.RegionName IN ('Region III', 'Region IV-A') THEN 'Value-Seeking-Brand-Conscious'
        WHEN r.RegionName IN ('Region VI', 'Region VII') THEN 'Quality-Service-Tourism-Influenced'
        WHEN r.RegionName IN ('Region I', 'Region II', 'Region V') THEN 'Price-Sensitive-Bulk-Buying'
        WHEN r.RegionName IN ('CAR', 'ARMM') THEN 'Community-Sharing-Traditional-Values'
        ELSE 'Balanced-Regional-Economic'
    END AS economic_behavior_pattern,

    -- Cultural shopping influences
    CASE
        WHEN r.RegionName = 'NCR' THEN 'Western-Influenced-Fast-Paced-Individual'
        WHEN r.RegionName IN ('Region I', 'Region II') THEN 'Ilocano-Frugal-Family-Oriented'
        WHEN r.RegionName IN ('Region VI', 'Region VII') THEN 'Visayan-Social-Community-Centered'
        WHEN r.RegionName = 'CAR' THEN 'Indigenous-Traditional-Cooperative'
        WHEN r.RegionName = 'ARMM' THEN 'Islamic-Halal-Community-Values'
        ELSE 'Mixed-Cultural-Influences'
    END AS cultural_shopping_influence,

    -- Regional brand preferences
    CASE
        WHEN r.RegionName = 'NCR' THEN 'International-Premium-Innovation-Focused'
        WHEN r.RegionName IN ('Region III', 'Region IV-A') THEN 'National-Regional-Balance'
        WHEN r.RegionName IN ('Region VI', 'Region VII') THEN 'Local-National-Tourist-Brands'
        WHEN r.RegionName IN ('Region I', 'Region II') THEN 'Trusted-Local-Traditional-Brands'
        ELSE 'Standard-Brand-Mix'
    END AS regional_brand_preference

FROM dbo.Region r
LEFT JOIN dbo.Province p ON r.RegionID = p.RegionID
WHERE r.RegionName IS NOT NULL;
GO

-- Enhanced location-persona integration view
CREATE OR ALTER VIEW dbo.v_complete_location_persona_dataset AS
WITH store_location AS (
    -- Map stores to complete geographic hierarchy
    SELECT DISTINCT
        s.store_id,
        s.store_name,
        r.RegionName AS region_name,
        p.ProvinceName AS province_name,
        m.MunicipalityName AS municipality_name,
        b.BarangayName AS barangay_name
    FROM analytics.v_stg_stores s
    LEFT JOIN dbo.Region r ON r.RegionID = s.region
    LEFT JOIN dbo.Province p ON p.ProvinceID = s.province
    LEFT JOIN dbo.Municipality m ON m.MunicipalityID = s.city_municipality
    LEFT JOIN dbo.Barangay b ON b.BarangayID = s.barangay
),
location_personas AS (
    -- Apply location-based persona inference
    SELECT
        si.canonical_tx_id,
        sl.store_id,
        sl.region_name,
        sl.province_name,
        sl.municipality_name,
        sl.barangay_name,
        lp.location_persona,
        lp.location_confidence_score,
        lp.location_factors,
        lp.economic_indicator,
        lp.demographic_profile
    FROM dbo.SalesInteractions si
    LEFT JOIN store_location sl ON CAST(si.StoreID AS INT) = sl.store_id
    CROSS APPLY dbo.fn_infer_location_persona(
        sl.region_name,
        sl.province_name,
        sl.municipality_name,
        sl.barangay_name,
        sl.store_id,
        DATEPART(hour, si.CreatedDate),
        COALESCE(si.TransactionValue, 0),
        si.Age,
        si.Gender
    ) lp
)
SELECT
    -- Core identifiers
    si.canonical_tx_id,
    si.FacialID,
    si.Age,
    si.Gender,
    si.TransactionDate,
    si.StoreID,

    -- =====================================================
    -- LOCATION-BASED PERSONA DIMENSIONS
    -- =====================================================

    -- Geographic hierarchy
    lp.region_name,
    lp.province_name,
    lp.municipality_name,
    lp.barangay_name,

    -- Location-based personas
    lp.location_persona AS primary_location_persona,
    lp.location_confidence_score,
    lp.location_factors,
    lp.economic_indicator AS location_economic_profile,
    lp.demographic_profile AS location_demographic_profile,

    -- Regional shopping patterns (from lookup view)
    rsp.regional_shopping_pattern,
    rsp.regional_time_preference,
    rsp.economic_behavior_pattern,
    rsp.cultural_shopping_influence,
    rsp.regional_brand_preference,

    -- =====================================================
    -- LOCATION-SPECIFIC BUSINESS INTELLIGENCE
    -- =====================================================

    -- Urban/Rural classification
    CASE
        WHEN lp.region_name = 'NCR' THEN 'Urban-Metro'
        WHEN lp.region_name IN ('Region III', 'Region IV-A') THEN 'Semi-Urban'
        WHEN lp.region_name IN ('Region VI', 'Region VII') THEN 'Island-Urban'
        WHEN lp.region_name IN ('Region I', 'Region II', 'Region V', 'Region VIII', 'Region IX', 'Region X', 'Region XI', 'Region XII') THEN 'Rural-Provincial'
        WHEN lp.region_name IN ('CAR', 'ARMM', 'CARAGA') THEN 'Rural-Remote'
        ELSE 'Unknown-Classification'
    END AS urban_rural_classification,

    -- Market penetration opportunity
    CASE
        WHEN lp.region_name = 'NCR' AND si.Age BETWEEN 25 AND 40 THEN 'High-Penetration-Opportunity'
        WHEN lp.region_name IN ('Region III', 'Region IV-A') THEN 'Growing-Market-Opportunity'
        WHEN lp.region_name IN ('Region VI', 'Region VII') THEN 'Tourism-Market-Opportunity'
        WHEN lp.region_name IN ('Region I', 'Region II') THEN 'Traditional-Market-Stable'
        ELSE 'Standard-Market-Potential'
    END AS market_opportunity_classification,

    -- Distribution strategy recommendation
    CASE
        WHEN lp.region_name = 'NCR' THEN 'High-Frequency-Premium-Fast-Delivery'
        WHEN lp.region_name IN ('Region III', 'Region IV-A') THEN 'Regular-Distribution-Family-Packs'
        WHEN lp.region_name IN ('Region VI', 'Region VII') THEN 'Island-Logistics-Tourism-Seasonal'
        WHEN lp.region_name IN ('Region I', 'Region II') THEN 'Bulk-Distribution-Agricultural-Cycles'
        ELSE 'Standard-Distribution-Strategy'
    END AS distribution_strategy_recommendation,

    -- Cultural marketing approach
    CASE
        WHEN lp.region_name = 'NCR' THEN 'Modern-International-English-Tagalog'
        WHEN lp.region_name IN ('Region I', 'Region II') THEN 'Traditional-Family-Ilocano-Values'
        WHEN lp.region_name IN ('Region VI', 'Region VII') THEN 'Community-Social-Visayan-Warmth'
        WHEN lp.region_name = 'CAR' THEN 'Indigenous-Respectful-Mountain-Culture'
        WHEN lp.region_name = 'ARMM' THEN 'Islamic-Halal-Community-Respect'
        ELSE 'General-Filipino-Values'
    END AS cultural_marketing_approach,

    -- Seasonal behavior patterns
    CASE
        WHEN lp.region_name = 'NCR' THEN 'Year-Round-Consistent-Holiday-Spikes'
        WHEN lp.region_name IN ('Region I', 'Region II', 'Region V') THEN 'Agricultural-Seasonal-Harvest-Dependent'
        WHEN lp.region_name IN ('Region VI', 'Region VII') THEN 'Tourist-Season-Weather-Dependent'
        WHEN lp.region_name IN ('Region VIII', 'Region IX', 'Region X', 'Region XI', 'Region XII') THEN 'Typhoon-Seasonal-Weather-Resilient'
        ELSE 'Standard-Seasonal-Patterns'
    END AS seasonal_behavior_pattern,

    -- Composite location-persona score
    (lp.location_confidence_score * 0.6 +
     CASE WHEN lp.region_name IS NOT NULL THEN 0.4 ELSE 0.0 END) AS composite_location_persona_score

FROM dbo.SalesInteractions si
LEFT JOIN location_personas lp ON si.canonical_tx_id = lp.canonical_tx_id
LEFT JOIN dbo.v_location_shopping_patterns rsp ON lp.region_name = rsp.region_name
WHERE si.canonical_tx_id IS NOT NULL;

GO

-- Performance indexes for location-based queries
CREATE NONCLUSTERED INDEX IX_SalesInteractions_StoreLocation
ON dbo.SalesInteractions (StoreID, TransactionDate)
INCLUDE (canonical_tx_id, Age, Gender, TransactionValue);

CREATE NONCLUSTERED INDEX IX_Stores_Geographic
ON analytics.v_stg_stores (region, province, city_municipality, barangay)
INCLUDE (store_id, store_name);

GO

-- Sample usage queries for location-based personas
/*
-- Query 1: Regional persona distribution
SELECT primary_location_persona, region_name, COUNT(*) as customer_count,
       AVG(composite_location_persona_score) as avg_confidence
FROM dbo.v_complete_location_persona_dataset
WHERE composite_location_persona_score > 0.6
GROUP BY primary_location_persona, region_name
ORDER BY avg_confidence DESC;

-- Query 2: Market opportunity by location
SELECT market_opportunity_classification, urban_rural_classification,
       COUNT(*) as transaction_count,
       AVG(CAST(Age AS FLOAT)) as avg_age
FROM dbo.v_complete_location_persona_dataset
GROUP BY market_opportunity_classification, urban_rural_classification
ORDER BY transaction_count DESC;

-- Query 3: Cultural marketing insights
SELECT cultural_marketing_approach, regional_brand_preference,
       COUNT(*) as frequency,
       STRING_AGG(DISTINCT primary_location_persona, '; ') as common_personas
FROM dbo.v_complete_location_persona_dataset
GROUP BY cultural_marketing_approach, regional_brand_preference
ORDER BY frequency DESC;

-- Query 4: Distribution strategy analysis
SELECT distribution_strategy_recommendation, seasonal_behavior_pattern,
       region_name, COUNT(*) as transaction_volume
FROM dbo.v_complete_location_persona_dataset
GROUP BY distribution_strategy_recommendation, seasonal_behavior_pattern, region_name
ORDER BY transaction_volume DESC;
*/