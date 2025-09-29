-- =============================================================================
-- Fix text/ntext casting issues in Nielsen views
-- Ensures safe comparisons and aggregations
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Update the Nielsen SKU transactions view with safe casts
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

    -- SKU mapping details (safe casts)
    ISNULL(CAST(sku.brand_name AS nvarchar(200)), 'Unknown') AS brand_name,
    ISNULL(CAST(sku.category AS nvarchar(200)), 'Unknown') AS brand_category,
    ISNULL(CAST(sku.product_name AS nvarchar(400)), 'Unknown') AS product_name,
    ISNULL(CAST(sku.sku_code AS varchar(128)), 'Unknown') AS sku_code,

    -- Nielsen taxonomy (safe casts to prevent text/ntext issues)
    COALESCE(CAST(nc.category_code AS varchar(64)), 'Unknown') AS nielsen_category_code,
    COALESCE(CAST(nc.category_name AS nvarchar(200)), 'Unknown') AS nielsen_category_name,
    COALESCE(CAST(ng.group_code AS varchar(64)), 'Unknown') AS nielsen_group_code,
    COALESCE(CAST(ng.group_name AS nvarchar(200)), 'Unknown') AS nielsen_group_name,
    COALESCE(CAST(nd.department_code AS varchar(64)), 'Unknown') AS nielsen_dept_code,
    COALESCE(CAST(nd.department_name AS nvarchar(200)), 'Unknown') AS nielsen_dept_name,

    -- Market classification
    nc.sari_sari_priority,
    nc.ph_market_relevant,

    -- Brand catalog performance data
    bc.total_transactions AS brand_total_transactions,
    bc.total_sales AS brand_total_sales,
    bc.data_quality AS brand_data_quality

FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
LEFT JOIN dbo.Stores s ON s.StoreID = TRY_CONVERT(int, REPLACE(p.Location, 'Store_', ''))
LEFT JOIN dbo.tx_sku_mapping sku ON sku.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.nielsen_product_categories nc ON CAST(nc.category_name AS nvarchar(200)) = CAST(sku.category AS nvarchar(200))
LEFT JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
LEFT JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
LEFT JOIN dbo.brand_sku_catalog bc ON CAST(bc.brand_name AS nvarchar(200)) = CAST(sku.brand_name AS nvarchar(200));
GO

PRINT 'Text/ntext casting fixes applied successfully.';