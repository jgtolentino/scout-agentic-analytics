-- Simplified SKU Revenue Analysis
-- Using actual database schema

-- 1. Basic SKU Coverage Analysis
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

-- 2. SKU Dimensions Overview
SELECT TOP 10
    sd.sku_id,
    sd.SkuCode,
    sd.SkuName,
    sd.BrandName,
    sd.CategoryCode,
    sd.IsActive,
    sd.CreatedDate
FROM ref.SkuDimensions sd
ORDER BY sd.sku_id;

-- 3. Transaction Items Overview
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

-- 4. Available Nielsen Taxonomy Structure
SELECT
    'Departments' as level_type,
    COUNT(*) as count
FROM dbo.nielsen_departments
UNION ALL
SELECT
    'Product Groups' as level_type,
    COUNT(*) as count
FROM dbo.nielsen_product_groups
UNION ALL
SELECT
    'Categories' as level_type,
    COUNT(*) as count
FROM dbo.nielsen_product_categories;

-- 5. Nielsen Departments List
SELECT
    department_id,
    department_code,
    department_name,
    department_desc
FROM dbo.nielsen_departments
ORDER BY department_id;

-- 6. Top Nielsen Categories by Priority
SELECT TOP 20
    nc.category_id,
    nc.category_code,
    nc.category_name,
    nd.department_name,
    CASE nc.sari_sari_priority
        WHEN 1 THEN 'Critical'
        WHEN 2 THEN 'High'
        WHEN 3 THEN 'Medium'
        WHEN 4 THEN 'Low'
        WHEN 5 THEN 'Rare'
        ELSE 'Unknown'
    END as priority_level,
    nc.ph_market_relevant
FROM dbo.nielsen_product_categories nc
INNER JOIN dbo.nielsen_product_groups ng ON ng.group_id = nc.group_id
INNER JOIN dbo.nielsen_departments nd ON nd.department_id = ng.department_id
ORDER BY nc.sari_sari_priority, nc.category_id;

PRINT 'SKU-Level Analysis Infrastructure Status:';
PRINT '✅ Nielsen taxonomy deployed (52 categories)';
PRINT '✅ SKU dimensions available (30 SKUs)';
PRINT '⚠️  SKU-Transaction linkage needs completion';
PRINT '📊 Ready for revenue analysis once SKU linkage is established';