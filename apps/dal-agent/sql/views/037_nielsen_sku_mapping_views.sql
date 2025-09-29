-- =============================================================================
-- Nielsen SKU-Level Mapping Views
-- Comprehensive Nielsen taxonomy integration at SKU level
-- Created: 2025-09-28
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =============================================================================
-- GOLD · Complete Nielsen SKU-level transaction mapping
-- =============================================================================
CREATE OR ALTER VIEW gold.v_nielsen_sku_transactions AS
SELECT
    si.canonical_tx_id,
    CONVERT(date, si.TransactionDate) AS transaction_date,

    -- Transaction details
    ISNULL(f.gender,'Unknown') AS gender,
    CASE
        WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN '18-24'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN '25-34'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN '35-44'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN '45-54'
        WHEN TRY_CONVERT(int,f.age) >= 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_band,
    TRY_CONVERT(decimal(18,2), f.transaction_value) AS transaction_value,
    TRY_CONVERT(decimal(18,2), f.basket_size) AS basket_size,

    -- Location details
    ISNULL(s.Region, 'Unknown') AS region,
    ISNULL(s.ProvinceName, 'Unknown') AS province,
    ISNULL(s.MunicipalityName, 'Unknown') AS city,

    -- SKU mapping details
    ISNULL(sku.brand_name, 'Unknown') AS brand_name,
    ISNULL(sku.category, 'Unknown') AS brand_category,
    ISNULL(sku.product_name, 'Unknown') AS product_name,
    ISNULL(sku.sku_code, 'Unknown') AS sku_code,

    -- Nielsen taxonomy (product categories)
    ISNULL(nc.category_code, 'Unknown') AS nielsen_category_code,
    ISNULL(nc.category_name, 'Unknown') AS nielsen_category_name,
    ISNULL(nc.category_desc, 'Unknown') AS nielsen_category_desc,
    nc.sari_sari_priority,
    nc.ph_market_relevant,

    -- Nielsen product groups
    ISNULL(ng.group_code, 'Unknown') AS nielsen_group_code,
    ISNULL(ng.group_name, 'Unknown') AS nielsen_group_name,

    -- Nielsen departments
    ISNULL(nd.department_code, 'Unknown') AS nielsen_dept_code,
    ISNULL(nd.department_name, 'Unknown') AS nielsen_dept_name,

    -- Brand catalog performance data
    bc.total_transactions AS brand_total_transactions,
    bc.total_sales AS brand_total_sales,
    bc.data_quality AS brand_data_quality

FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
LEFT JOIN dbo.Stores s ON s.StoreID = TRY_CONVERT(int, REPLACE(p.Location, 'Store_', ''))
LEFT JOIN dbo.tx_sku_mapping sku ON sku.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.nielsen_product_categories nc ON nc.category_name = sku.category
LEFT JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
LEFT JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
LEFT JOIN dbo.brand_sku_catalog bc ON bc.brand_name = sku.brand_name;
GO

-- =============================================================================
-- GOLD · Nielsen category performance by demographics
-- =============================================================================
CREATE OR ALTER VIEW gold.v_nielsen_category_demographics AS
SELECT
    nc.category_code,
    nc.category_name,
    ng.group_name AS nielsen_group,
    nd.department_name AS nielsen_department,
    nc.sari_sari_priority,
    nc.ph_market_relevant,

    -- Demographic breakdown
    COUNT(CASE WHEN nst.gender = 'Male' THEN 1 END) AS male_customers,
    COUNT(CASE WHEN nst.gender = 'Female' THEN 1 END) AS female_customers,
    COUNT(CASE WHEN nst.age_band = '18-24' THEN 1 END) AS gen_z_customers,
    COUNT(CASE WHEN nst.age_band = '25-34' THEN 1 END) AS millennial_customers,
    COUNT(CASE WHEN nst.age_band = '35-44' THEN 1 END) AS gen_x_customers,
    COUNT(CASE WHEN nst.age_band = '45-54' THEN 1 END) AS boomer_customers,
    COUNT(CASE WHEN nst.age_band = '55+' THEN 1 END) AS senior_customers,

    -- Geographic breakdown
    COUNT(CASE WHEN nst.region = 'NCR' THEN 1 END) AS ncr_customers,
    COUNT(CASE WHEN nst.region != 'NCR' AND nst.region != 'Unknown' THEN 1 END) AS provincial_customers,

    -- Performance metrics
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT nst.canonical_tx_id) AS unique_transactions,
    COUNT(DISTINCT nst.brand_name) AS unique_brands,
    SUM(nst.transaction_value) AS total_revenue,
    AVG(nst.transaction_value) AS avg_transaction_value,
    AVG(nst.basket_size) AS avg_basket_size,

    -- SKU diversity
    COUNT(DISTINCT nst.sku_code) AS unique_skus,
    COUNT(DISTINCT nst.product_name) AS unique_products

FROM dbo.nielsen_product_categories nc
LEFT JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
LEFT JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
LEFT JOIN gold.v_nielsen_sku_transactions nst ON nst.nielsen_category_code = nc.category_code

GROUP BY nc.category_code, nc.category_name, ng.group_name, nd.department_name,
         nc.sari_sari_priority, nc.ph_market_relevant;
GO

-- =============================================================================
-- GOLD · SKU-level performance analysis with Nielsen classification
-- =============================================================================
CREATE OR ALTER VIEW gold.v_sku_nielsen_performance AS
SELECT
    sku.canonical_tx_id,
    sku.brand_name,
    sku.product_name,
    sku.sku_code,
    sku.category AS brand_category,

    -- Nielsen classification
    nc.category_code AS nielsen_category_code,
    nc.category_name AS nielsen_category_name,
    ng.group_name AS nielsen_group,
    nd.department_name AS nielsen_department,
    nc.sari_sari_priority,
    nc.ph_market_relevant,

    -- Transaction performance
    COUNT(*) AS transaction_frequency,
    AVG(nst.transaction_value) AS avg_transaction_value,
    SUM(nst.transaction_value) AS total_revenue,
    AVG(nst.basket_size) AS avg_basket_size,

    -- Demographic insights
    COUNT(CASE WHEN nst.gender = 'Male' THEN 1 END) AS male_transactions,
    COUNT(CASE WHEN nst.gender = 'Female' THEN 1 END) AS female_transactions,
    COUNT(CASE WHEN nst.region = 'NCR' THEN 1 END) AS ncr_transactions,

    -- Market positioning
    CASE
        WHEN nc.sari_sari_priority = 1 THEN 'High Priority'
        WHEN nc.sari_sari_priority = 2 THEN 'Medium Priority'
        WHEN nc.sari_sari_priority = 3 THEN 'Low Priority'
        ELSE 'Unclassified'
    END AS market_priority,

    CASE
        WHEN nc.ph_market_relevant = 1 THEN 'PH Market Relevant'
        ELSE 'Non-PH Specific'
    END AS market_relevance

FROM dbo.tx_sku_mapping sku
LEFT JOIN dbo.nielsen_product_categories nc ON nc.category_name = sku.category
LEFT JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
LEFT JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
LEFT JOIN gold.v_nielsen_sku_transactions nst ON nst.canonical_tx_id = sku.canonical_tx_id

GROUP BY sku.canonical_tx_id, sku.brand_name, sku.product_name, sku.sku_code, sku.category,
         nc.category_code, nc.category_name, ng.group_name, nd.department_name,
         nc.sari_sari_priority, nc.ph_market_relevant;
GO

-- =============================================================================
-- PLATINUM · Nielsen 1100+ SKU expansion analysis
-- =============================================================================
CREATE OR ALTER VIEW platinum.v_nielsen_sku_expansion_opportunities AS
WITH current_coverage AS (
    SELECT
        COUNT(DISTINCT sku.sku_code) AS mapped_skus,
        COUNT(DISTINCT sku.brand_name) AS mapped_brands,
        COUNT(DISTINCT nc.category_code) AS covered_nielsen_categories,
        COUNT(*) AS total_mapped_transactions
    FROM dbo.tx_sku_mapping sku
    LEFT JOIN dbo.nielsen_product_categories nc ON nc.category_name = sku.category
),
potential_expansion AS (
    SELECT
        COUNT(*) AS unmapped_nielsen_categories,
        COUNT(CASE WHEN nc.ph_market_relevant = 1 THEN 1 END) AS ph_relevant_categories,
        COUNT(CASE WHEN nc.sari_sari_priority = 1 THEN 1 END) AS high_priority_categories
    FROM dbo.nielsen_product_categories nc
    WHERE nc.category_code NOT IN (
        SELECT DISTINCT nielsen_category_code
        FROM gold.v_nielsen_sku_transactions
        WHERE nielsen_category_code != 'Unknown'
    )
),
brand_expansion AS (
    SELECT
        COUNT(*) AS unmapped_brands
    FROM dbo.brand_sku_catalog bc
    WHERE bc.brand_name NOT IN (
        SELECT DISTINCT brand_name
        FROM dbo.tx_sku_mapping
    )
)
SELECT
    -- Current state
    cc.mapped_skus,
    cc.mapped_brands,
    cc.covered_nielsen_categories,
    cc.total_mapped_transactions,

    -- Expansion potential
    pe.unmapped_nielsen_categories,
    pe.ph_relevant_categories,
    pe.high_priority_categories,
    be.unmapped_brands,

    -- Target: 1100 SKUs
    1100 AS target_sku_count,
    1100 - cc.mapped_skus AS skus_needed,

    -- Expansion recommendations
    CASE
        WHEN cc.mapped_skus < 100 THEN 'Phase 1: Core Brand Mapping'
        WHEN cc.mapped_skus < 500 THEN 'Phase 2: Category Expansion'
        WHEN cc.mapped_skus < 1000 THEN 'Phase 3: Detailed SKU Mapping'
        ELSE 'Phase 4: Premium SKU Addition'
    END AS expansion_phase,

    CASE
        WHEN pe.ph_relevant_categories > 10 THEN 'Focus on PH-relevant categories first'
        WHEN pe.high_priority_categories > 5 THEN 'Prioritize high-priority categories'
        ELSE 'Expand to remaining Nielsen categories'
    END AS expansion_strategy

FROM current_coverage cc
CROSS JOIN potential_expansion pe
CROSS JOIN brand_expansion be;
GO

PRINT 'Nielsen SKU-level mapping views created successfully for 1100+ SKU expansion.';