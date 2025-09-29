-- Final SKU Revenue Analysis Infrastructure
-- Using correct column names from database schema

-- 1. SKU Coverage Analysis
SELECT
    'SKU Analysis' as metric_type,
    COUNT(DISTINCT sd.sku_id) as total_skus_in_system,
    COUNT(DISTINCT ti.sku_id) as skus_with_transactions,
    CASE
        WHEN COUNT(DISTINCT sd.sku_id) > 0
        THEN CAST(COUNT(DISTINCT ti.sku_id) * 100.0 / COUNT(DISTINCT sd.sku_id) AS DECIMAL(5,2))
        ELSE 0
    END as sku_transaction_coverage_pct
FROM ref.SkuDimensions sd
LEFT JOIN dbo.TransactionItems ti ON ti.sku_id = sd.sku_id
WHERE sd.IsActive = 1;

-- 2. Top SKUs in System
SELECT TOP 10
    sd.sku_id,
    sd.SkuCode,
    sd.SkuName,
    sd.BrandName,
    sd.CategoryCode,
    sd.IsActive
FROM ref.SkuDimensions sd
WHERE sd.IsActive = 1
ORDER BY sd.sku_id;

-- 3. Transaction Items Status
SELECT
    COUNT(*) as total_transaction_items,
    COUNT(CASE WHEN sku_id IS NOT NULL THEN 1 END) as items_with_sku,
    COUNT(CASE WHEN sku_id IS NULL THEN 1 END) as items_without_sku,
    CASE
        WHEN COUNT(*) > 0
        THEN CAST(COUNT(CASE WHEN sku_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2))
        ELSE 0
    END as sku_coverage_percentage
FROM dbo.TransactionItems;

-- 4. Nielsen Taxonomy Status
SELECT
    'Departments' as taxonomy_level,
    COUNT(*) as count
FROM dbo.nielsen_departments
UNION ALL
SELECT
    'Product Groups' as taxonomy_level,
    COUNT(*) as count
FROM dbo.nielsen_product_groups
UNION ALL
SELECT
    'Categories' as taxonomy_level,
    COUNT(*) as count
FROM dbo.nielsen_product_categories;

-- 5. Nielsen Departments Available
SELECT
    department_id,
    department_code,
    department_name
FROM dbo.nielsen_departments
ORDER BY department_id;

-- 6. Critical Sari-Sari Categories (Priority 1)
SELECT
    nc.category_code,
    nc.category_name,
    nd.department_name,
    'Critical' as priority_level
FROM dbo.nielsen_product_categories nc
INNER JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
INNER JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
WHERE nc.sari_sari_priority = 1
ORDER BY nd.department_name, nc.category_name;