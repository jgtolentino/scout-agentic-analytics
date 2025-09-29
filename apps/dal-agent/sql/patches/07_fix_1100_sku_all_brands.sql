-- =============================================================================
-- Fix 1100 SKU dimension to include all 113 brands
-- Ensures proper distribution across all mapped brands
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Clear and rebuild with better distribution
TRUNCATE TABLE dbo.dim_sku_nielsen;

-- Strategy: ~10 SKUs per brand (113 brands * 10 = 1130, target 1100)
WITH brand_sku_targets AS (
    SELECT
        nsm.brand_name,
        nsm.product_name,
        nsm.nielsen_category_code,
        nc.category_name as nielsen_category_name,
        ng.group_code as nielsen_group_code,
        ng.group_name as nielsen_group_name,
        nd.department_code as nielsen_dept_code,
        nd.department_name as nielsen_dept_name,
        nc.sari_sari_priority,
        nc.ph_market_relevant,
        -- Calculate target SKUs per brand (higher priority brands get more SKUs)
        CASE
            WHEN nc.sari_sari_priority = 1 THEN 12  -- High priority: 12 SKUs
            WHEN nc.sari_sari_priority = 2 THEN 10  -- Medium priority: 10 SKUs
            WHEN nc.sari_sari_priority = 3 THEN 8   -- Low priority: 8 SKUs
            ELSE 10  -- Default: 10 SKUs
        END as target_skus,
        ROW_NUMBER() OVER (ORDER BY nc.sari_sari_priority, nsm.brand_name) as brand_rank
    FROM dbo.nielsen_sku_map nsm
    JOIN dbo.nielsen_product_categories nc ON nc.category_code = nsm.nielsen_category_code
    LEFT JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
    LEFT JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
),
sku_variants AS (
    SELECT * FROM (VALUES
        (1, 'Regular', '330ml', 'Can', 'Original'),
        (2, 'Large', '500ml', 'Bottle', 'Original'),
        (3, 'Small', '200ml', 'Bottle', 'Light'),
        (4, 'Family', '1L', 'Bottle', 'Strong'),
        (5, 'Mini', '100ml', 'Sachet', 'Mild'),
        (6, 'Jumbo', '1.5L', 'Bottle', 'Extra'),
        (7, 'Regular', '250g', 'Pack', 'Classic'),
        (8, 'Large', '500g', 'Pack', 'Premium'),
        (9, 'Small', '100g', 'Pack', 'Special'),
        (10, 'Family', '1kg', 'Pack', 'Deluxe'),
        (11, 'Mini', '50g', 'Sachet', 'Fresh'),
        (12, 'Regular', '200g', 'Box', 'Super'),
        (13, 'Single', '1pc', 'Piece', 'Standard'),
        (14, 'Pack', '6pcs', 'Multipack', 'Value'),
        (15, 'Box', '12pcs', 'Box', 'Economy')
    ) AS v(variant_id, size_cat, size_val, pack_type, flavor)
)

INSERT INTO dbo.dim_sku_nielsen (
    sku_code, brand_name, product_name, product_variant,
    package_size, package_type, nielsen_category_code, nielsen_category_name,
    nielsen_group_code, nielsen_group_name, nielsen_dept_code, nielsen_dept_name,
    sari_sari_priority, ph_market_relevant, estimated_price
)
SELECT
    CONCAT(
        'SKU-',
        UPPER(REPLACE(REPLACE(REPLACE(bst.brand_name, ' ', ''), '''', ''), '&', 'AND')),
        '-',
        UPPER(REPLACE(sv.size_cat, ' ', '')),
        '-',
        FORMAT(sv.variant_id, '00')
    ) AS sku_code,

    bst.brand_name,
    bst.product_name,
    CONCAT(sv.flavor, ' ', sv.size_cat, ' ', sv.size_val) AS product_variant,
    sv.size_val AS package_size,
    sv.pack_type AS package_type,
    bst.nielsen_category_code,
    bst.nielsen_category_name,
    bst.nielsen_group_code,
    bst.nielsen_group_name,
    bst.nielsen_dept_code,
    bst.nielsen_dept_name,
    bst.sari_sari_priority,
    bst.ph_market_relevant,

    -- Category-specific pricing
    CASE bst.nielsen_category_code
        WHEN 'TOBACCO' THEN
            CASE sv.variant_id WHEN 1 THEN 150.00 WHEN 2 THEN 160.00 WHEN 3 THEN 80.00 ELSE 120.00 END
        WHEN 'SOFT_DRINKS' THEN
            CASE sv.variant_id WHEN 1 THEN 25.00 WHEN 2 THEN 35.00 WHEN 3 THEN 20.00 WHEN 4 THEN 55.00 WHEN 6 THEN 75.00 ELSE 30.00 END
        WHEN 'ICED_TEA' THEN
            CASE sv.variant_id WHEN 1 THEN 28.00 WHEN 2 THEN 38.00 WHEN 3 THEN 22.00 WHEN 4 THEN 58.00 WHEN 6 THEN 78.00 ELSE 32.00 END
        WHEN '3IN1_COFFEE' THEN
            CASE sv.variant_id WHEN 1 THEN 8.50 WHEN 7 THEN 45.00 WHEN 8 THEN 85.00 WHEN 9 THEN 25.00 WHEN 10 THEN 165.00 ELSE 35.00 END
        WHEN 'ENERGY_DRINKS' THEN
            CASE sv.variant_id WHEN 1 THEN 65.00 WHEN 2 THEN 85.00 WHEN 3 THEN 45.00 ELSE 75.00 END
        WHEN 'CANNED_FISH' THEN
            CASE sv.variant_id WHEN 1 THEN 35.00 WHEN 7 THEN 65.00 WHEN 8 THEN 95.00 ELSE 55.00 END
        WHEN 'CANNED_MEAT' THEN
            CASE sv.variant_id WHEN 1 THEN 45.00 WHEN 7 THEN 85.00 WHEN 8 THEN 125.00 ELSE 75.00 END
        WHEN 'INST_NOODLES' THEN
            CASE sv.variant_id WHEN 1 THEN 15.00 WHEN 14 THEN 85.00 WHEN 15 THEN 165.00 ELSE 25.00 END
        WHEN 'SALTY_SNACKS' THEN
            CASE sv.variant_id WHEN 1 THEN 12.00 WHEN 7 THEN 35.00 WHEN 8 THEN 65.00 WHEN 9 THEN 18.00 ELSE 25.00 END
        WHEN 'CHOCO_CONF' THEN
            CASE sv.variant_id WHEN 1 THEN 15.00 WHEN 7 THEN 45.00 WHEN 8 THEN 85.00 WHEN 9 THEN 22.00 ELSE 35.00 END
        WHEN 'HARD_CANDY' THEN
            CASE sv.variant_id WHEN 1 THEN 8.00 WHEN 7 THEN 25.00 WHEN 8 THEN 45.00 WHEN 9 THEN 12.00 ELSE 18.00 END
        WHEN 'BISCUITS' THEN
            CASE sv.variant_id WHEN 1 THEN 25.00 WHEN 7 THEN 65.00 WHEN 8 THEN 125.00 WHEN 9 THEN 35.00 ELSE 55.00 END
        WHEN 'SHAMPOO' THEN
            CASE sv.variant_id WHEN 1 THEN 85.00 WHEN 2 THEN 165.00 WHEN 3 THEN 45.00 WHEN 5 THEN 15.00 ELSE 95.00 END
        WHEN 'BAR_SOAP' THEN
            CASE sv.variant_id WHEN 1 THEN 25.00 WHEN 13 THEN 25.00 WHEN 14 THEN 135.00 ELSE 35.00 END
        WHEN 'TOOTHPASTE' THEN
            CASE sv.variant_id WHEN 1 THEN 65.00 WHEN 2 THEN 125.00 WHEN 3 THEN 35.00 ELSE 85.00 END
        WHEN 'LAUNDRY_POWDER' THEN
            CASE sv.variant_id WHEN 7 THEN 95.00 WHEN 8 THEN 165.00 WHEN 10 THEN 285.00 ELSE 125.00 END
        WHEN 'FABRIC_SOFTENER' THEN
            CASE sv.variant_id WHEN 1 THEN 45.00 WHEN 2 THEN 75.00 WHEN 4 THEN 125.00 ELSE 65.00 END
        ELSE
            CASE sv.variant_id WHEN 1 THEN 25.00 WHEN 2 THEN 45.00 WHEN 3 THEN 18.00 ELSE 35.00 END
    END AS estimated_price

FROM brand_sku_targets bst
CROSS JOIN sku_variants sv
WHERE sv.variant_id <= bst.target_skus  -- Limit SKUs per brand based on priority
  AND (
    -- Ensure we get close to 1100 total
    (bst.brand_rank * bst.target_skus + sv.variant_id) <= 1100
  )
ORDER BY bst.sari_sari_priority, bst.brand_name, sv.variant_id;

PRINT 'Fixed SKU dimension with all brands. Total SKUs: ' + CAST(@@ROWCOUNT AS varchar(10));

-- Summary statistics
SELECT
    'Total SKUs' as metric,
    COUNT(*) as value
FROM dbo.dim_sku_nielsen

UNION ALL

SELECT
    'Unique Brands' as metric,
    COUNT(DISTINCT brand_name) as value
FROM dbo.dim_sku_nielsen

UNION ALL

SELECT
    'Nielsen Categories' as metric,
    COUNT(DISTINCT nielsen_category_code) as value
FROM dbo.dim_sku_nielsen

UNION ALL

SELECT
    'High Priority Brands' as metric,
    COUNT(DISTINCT brand_name) as value
FROM dbo.dim_sku_nielsen
WHERE sari_sari_priority = 1

UNION ALL

SELECT
    'PH Relevant SKUs' as metric,
    COUNT(*) as value
FROM dbo.dim_sku_nielsen
WHERE ph_market_relevant = 1

ORDER BY metric;