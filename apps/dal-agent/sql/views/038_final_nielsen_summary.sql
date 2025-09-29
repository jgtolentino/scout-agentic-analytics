-- =============================================================================
-- Final Nielsen 1100+ SKU Summary Views
-- Complete summary of achieved Nielsen SKU mapping system
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =============================================================================
-- PLATINUM · Complete Nielsen SKU achievement summary
-- =============================================================================
CREATE OR ALTER VIEW platinum.v_nielsen_1100_achievement AS
SELECT
    'Nielsen SKU Mapping System' AS system_name,
    GETDATE() AS report_date,

    -- SKU Metrics
    (SELECT COUNT(*) FROM dbo.dim_sku_nielsen) AS total_skus,
    1100 AS target_skus,
    CASE
        WHEN (SELECT COUNT(*) FROM dbo.dim_sku_nielsen) >= 1100 THEN 'ACHIEVED ✅'
        ELSE 'IN PROGRESS'
    END AS target_status,

    -- Brand Coverage
    (SELECT COUNT(DISTINCT brand_name) FROM dbo.dim_sku_nielsen) AS covered_brands,
    (SELECT COUNT(DISTINCT brand_name) FROM dbo.nielsen_sku_map) AS mapped_brands,
    113 AS target_brands,

    -- Nielsen Taxonomy Coverage
    (SELECT COUNT(DISTINCT nielsen_category_code) FROM dbo.dim_sku_nielsen) AS covered_categories,
    (SELECT COUNT(*) FROM dbo.nielsen_product_categories) AS total_categories,

    -- Price Range
    (SELECT MIN(estimated_price) FROM dbo.dim_sku_nielsen) AS min_price,
    (SELECT MAX(estimated_price) FROM dbo.dim_sku_nielsen) AS max_price,
    (SELECT ROUND(AVG(estimated_price), 2) FROM dbo.dim_sku_nielsen) AS avg_price,

    -- PH Market Relevance
    (SELECT COUNT(*) FROM dbo.dim_sku_nielsen WHERE ph_market_relevant = 1) AS ph_relevant_skus,
    (SELECT ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM dbo.dim_sku_nielsen), 0), 1)
     FROM dbo.dim_sku_nielsen WHERE ph_market_relevant = 1) AS ph_relevance_pct;
GO

-- =============================================================================
-- GOLD · Nielsen category distribution analysis
-- =============================================================================
CREATE OR ALTER VIEW gold.v_nielsen_category_distribution AS
SELECT
    ds.nielsen_category_code,
    ds.nielsen_category_name,
    ds.nielsen_group_name,
    ds.nielsen_dept_name,
    COUNT(*) AS sku_count,
    COUNT(DISTINCT ds.brand_name) AS brand_count,
    MIN(ds.estimated_price) AS min_price,
    MAX(ds.estimated_price) AS max_price,
    ROUND(AVG(ds.estimated_price), 2) AS avg_price,

    -- Market priority distribution
    COUNT(CASE WHEN ds.sari_sari_priority = 1 THEN 1 END) AS high_priority_skus,
    COUNT(CASE WHEN ds.sari_sari_priority = 2 THEN 1 END) AS medium_priority_skus,
    COUNT(CASE WHEN ds.sari_sari_priority = 3 THEN 1 END) AS low_priority_skus,

    -- PH market relevance
    COUNT(CASE WHEN ds.ph_market_relevant = 1 THEN 1 END) AS ph_relevant_skus,

    -- Percentage of total SKUs
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.dim_sku_nielsen), 1) AS pct_of_total_skus

FROM dbo.dim_sku_nielsen ds
GROUP BY ds.nielsen_category_code, ds.nielsen_category_name,
         ds.nielsen_group_name, ds.nielsen_dept_name;
GO

-- =============================================================================
-- GOLD · Brand SKU expansion summary
-- =============================================================================
CREATE OR ALTER VIEW gold.v_brand_sku_expansion AS
SELECT
    ds.brand_name,
    ds.nielsen_category_name,
    COUNT(*) AS total_skus,

    -- Price analysis
    MIN(ds.estimated_price) AS min_price,
    MAX(ds.estimated_price) AS max_price,
    ROUND(AVG(ds.estimated_price), 2) AS avg_price,

    -- Variant types
    COUNT(DISTINCT ds.package_size) AS size_variants,
    COUNT(DISTINCT ds.package_type) AS package_variants,

    -- Market classification
    MAX(ds.sari_sari_priority) AS sari_sari_priority,
    MAX(CAST(ds.ph_market_relevant AS int)) AS ph_market_relevant,

    -- Sample SKUs (first 3)
    STRING_AGG(ds.sku_code, ', ') WITHIN GROUP (ORDER BY ds.sku_id) AS sample_skus

FROM dbo.dim_sku_nielsen ds
GROUP BY ds.brand_name, ds.nielsen_category_name;
GO

PRINT 'Final Nielsen 1100+ SKU summary views created successfully.';

-- Show achievement summary
SELECT * FROM platinum.v_nielsen_1100_achievement;