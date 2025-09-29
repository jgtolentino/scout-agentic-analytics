-- =============================================================================
-- Simple 1100 SKU Dimension Table Creation
-- Reliable approach ensuring all 111 brands get proper SKU variants
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Clear existing and rebuild systematically
TRUNCATE TABLE dbo.dim_sku_nielsen;

-- Create SKUs systematically: 111 brands × ~10 variants each = 1110 SKUs
INSERT INTO dbo.dim_sku_nielsen (
    sku_code, brand_name, product_name, product_variant,
    package_size, package_type, nielsen_category_code, nielsen_category_name,
    nielsen_group_code, nielsen_group_name, nielsen_dept_code, nielsen_dept_name,
    sari_sari_priority, ph_market_relevant, estimated_price
)
SELECT
    CONCAT(
        'SKU-',
        REPLACE(REPLACE(REPLACE(UPPER(nsm.brand_name), ' ', ''), '''', ''), '&', 'AND'),
        '-V',
        FORMAT(variants.variant_num, '00')
    ) AS sku_code,

    nsm.brand_name,
    nsm.product_name,
    variants.variant_name AS product_variant,
    variants.size_value AS package_size,
    variants.package_type,
    nsm.nielsen_category_code,
    nc.category_name AS nielsen_category_name,
    ng.group_code AS nielsen_group_code,
    ng.group_name AS nielsen_group_name,
    nd.department_code AS nielsen_dept_code,
    nd.department_name AS nielsen_dept_name,
    nc.sari_sari_priority,
    nc.ph_market_relevant,
    variants.base_price AS estimated_price

FROM dbo.nielsen_sku_map nsm
JOIN dbo.nielsen_product_categories nc ON nc.category_code = nsm.nielsen_category_code
LEFT JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
LEFT JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
CROSS JOIN (
    SELECT * FROM (VALUES
        (1, 'Regular Size', '330ml', 'Can', 25.00),
        (2, 'Large Size', '500ml', 'Bottle', 35.00),
        (3, 'Small Size', '200ml', 'Bottle', 18.00),
        (4, 'Family Pack', '1L', 'Bottle', 55.00),
        (5, 'Mini Pack', '100ml', 'Sachet', 12.00),
        (6, 'Jumbo Size', '1.5L', 'Bottle', 75.00),
        (7, 'Standard Pack', '250g', 'Pack', 45.00),
        (8, 'Value Pack', '500g', 'Pack', 85.00),
        (9, 'Trial Size', '50g', 'Sachet', 8.00),
        (10, 'Economy Pack', '1kg', 'Pack', 165.00)
    ) AS v(variant_num, variant_name, size_value, package_type, base_price)
) AS variants;

PRINT 'SKU dimension created with ' + CAST(@@ROWCOUNT AS varchar(10)) + ' SKU variants.';

-- Verify results
SELECT
    COUNT(*) AS total_skus,
    COUNT(DISTINCT brand_name) AS unique_brands,
    COUNT(DISTINCT nielsen_category_code) AS nielsen_categories,
    MIN(estimated_price) AS min_price,
    MAX(estimated_price) AS max_price,
    AVG(estimated_price) AS avg_price
FROM dbo.dim_sku_nielsen;

-- Show sample SKUs by category
SELECT TOP 20
    sku_code,
    brand_name,
    product_variant,
    nielsen_category_name,
    estimated_price
FROM dbo.dim_sku_nielsen
ORDER BY nielsen_category_code, brand_name;