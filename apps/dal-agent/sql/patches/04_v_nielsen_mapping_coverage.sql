-- =============================================================================
-- Nielsen mapping coverage audit view
-- Provides KPIs for progress toward 1100+ SKU target
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create audit schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'audit')
BEGIN
    EXEC('CREATE SCHEMA audit');
END;
GO

-- Coverage audit view
CREATE OR ALTER VIEW audit.v_nielsen_mapping_coverage AS
WITH base AS (
    SELECT COUNT(*) AS total_rows FROM gold.v_nielsen_sku_transactions
),
unk AS (
    SELECT COUNT(*) AS unknown_rows
    FROM gold.v_nielsen_sku_transactions
    WHERE nielsen_category_name = 'Unknown'
),
mapped_stats AS (
    SELECT
        COUNT(DISTINCT sku_code) AS unique_mapped_skus,
        COUNT(DISTINCT brand_name) AS unique_mapped_brands,
        COUNT(DISTINCT nielsen_category_code) AS unique_nielsen_categories
    FROM gold.v_nielsen_sku_transactions
    WHERE nielsen_category_name != 'Unknown'
),
mapping_table_stats AS (
    SELECT
        COUNT(*) AS total_mapping_entries,
        COUNT(DISTINCT brand_name) AS mapped_brands_in_table,
        COUNT(DISTINCT nielsen_category_code) AS mapped_categories_in_table
    FROM dbo.nielsen_sku_map
),
expansion_progress AS (
    SELECT
        1100 AS target_sku_count,
        CASE
            WHEN ms.unique_mapped_skus < 100 THEN 'Phase 1: Core Brand Mapping'
            WHEN ms.unique_mapped_skus < 500 THEN 'Phase 2: Category Expansion'
            WHEN ms.unique_mapped_skus < 1000 THEN 'Phase 3: Detailed SKU Mapping'
            ELSE 'Phase 4: Premium SKU Addition'
        END AS current_phase,
        1100 - ms.unique_mapped_skus AS skus_remaining
    FROM mapped_stats ms
)
SELECT
    -- Transaction-level coverage
    b.total_rows,
    u.unknown_rows,
    (b.total_rows - u.unknown_rows) AS mapped_rows,
    CAST(100.0 * (b.total_rows - u.unknown_rows) / NULLIF(b.total_rows,0) AS decimal(5,2)) AS pct_mapped_transactions,

    -- SKU-level coverage
    ms.unique_mapped_skus,
    ms.unique_mapped_brands,
    ms.unique_nielsen_categories,

    -- Mapping table statistics
    mts.total_mapping_entries,
    mts.mapped_brands_in_table,
    mts.mapped_categories_in_table,

    -- Progress toward 1100 SKU target
    ep.target_sku_count,
    ep.skus_remaining,
    ep.current_phase,
    CAST(100.0 * ms.unique_mapped_skus / ep.target_sku_count AS decimal(5,2)) AS pct_toward_target

FROM base b
CROSS JOIN unk u
CROSS JOIN mapped_stats ms
CROSS JOIN mapping_table_stats mts
CROSS JOIN expansion_progress ep;
GO

-- Top unmapped analysis view
CREATE OR ALTER VIEW audit.v_unmapped_sku_analysis AS
SELECT TOP 50
    brand_name,
    brand_category,
    COUNT(*) AS transaction_count,
    COUNT(DISTINCT canonical_tx_id) AS unique_transactions,
    CASE
        WHEN brand_category LIKE '%Beverage%' OR brand_category LIKE '%Drink%' THEN 'SOFT_DRINKS'
        WHEN brand_category LIKE '%Food%' OR brand_category LIKE '%Meal%' THEN 'INST_MEALS'
        WHEN brand_category LIKE '%Tobacco%' OR brand_category LIKE '%Cigarette%' THEN 'TOBACCO_CIG'
        WHEN brand_category LIKE '%Personal%' OR brand_category LIKE '%Care%' THEN 'BODY_SOAP'
        WHEN brand_category LIKE '%Laundry%' OR brand_category LIKE '%Clean%' THEN 'LAUNDRY'
        WHEN brand_category LIKE '%Snack%' OR brand_category LIKE '%Chip%' THEN 'SALTY_SNACKS'
        ELSE 'GENERAL_MERCH'
    END AS suggested_nielsen_category,
    'HIGH' AS mapping_priority
FROM gold.v_nielsen_sku_transactions
WHERE nielsen_category_name = 'Unknown'
  AND brand_name != 'Unknown'
GROUP BY brand_name, brand_category
ORDER BY transaction_count DESC;
GO

PRINT 'Nielsen mapping coverage audit views created successfully.';