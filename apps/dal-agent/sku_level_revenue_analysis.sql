-- SKU-Level Revenue Analysis with Nielsen Categories
-- Requires Nielsen taxonomy deployment + SKU backfill completion

-- 1. Revenue by Individual SKU with Nielsen Classification
SELECT
    sd.sku_id,
    sd.SkuCode,
    sd.SkuName,
    sd.BrandName,
    nb.nielsen_department,
    nb.nielsen_category,
    nb.nielsen_subcategory,
    nb.sari_sari_priority,
    COUNT(ti.TransactionItemID) as transaction_count,
    SUM(ti.TotalAmount) as sku_revenue,
    AVG(ti.TotalAmount) as avg_sku_transaction_value,
    COUNT(DISTINCT ti.InteractionID) as unique_transactions,
    COUNT(DISTINCT si.StoreID) as store_reach,
    MIN(si.InteractionTimestamp) as first_sale,
    MAX(si.InteractionTimestamp) as last_sale
FROM ref.SkuDimensions sd
INNER JOIN dbo.TransactionItems ti ON ti.sku_id = sd.sku_id
INNER JOIN dbo.SalesInteractions si ON si.InteractionID = ti.InteractionID
LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = sd.BrandName
WHERE sd.IsActive = 1
    AND ti.TotalAmount > 0
GROUP BY sd.sku_id, sd.SkuCode, sd.SkuName, sd.BrandName,
         nb.nielsen_department, nb.nielsen_category, nb.nielsen_subcategory, nb.sari_sari_priority
ORDER BY sku_revenue DESC;

-- 2. Top SKUs by Nielsen Department
SELECT
    nb.nielsen_department,
    sd.sku_id,
    sd.SkuCode,
    sd.SkuName,
    sd.BrandName,
    SUM(ti.TotalAmount) as sku_revenue,
    COUNT(ti.TransactionItemID) as transaction_count,
    RANK() OVER (PARTITION BY nb.nielsen_department ORDER BY SUM(ti.TotalAmount) DESC) as revenue_rank_in_dept
FROM ref.SkuDimensions sd
INNER JOIN dbo.TransactionItems ti ON ti.sku_id = sd.sku_id
INNER JOIN dbo.SalesInteractions si ON si.InteractionID = ti.InteractionID
LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = sd.BrandName
WHERE sd.IsActive = 1
    AND ti.TotalAmount > 0
    AND nb.nielsen_department IS NOT NULL
GROUP BY nb.nielsen_department, sd.sku_id, sd.SkuCode, sd.SkuName, sd.BrandName
HAVING COUNT(ti.TransactionItemID) >= 5  -- Only SKUs with 5+ transactions
ORDER BY nb.nielsen_department, revenue_rank_in_dept;

-- 3. SKU Performance within Brands (Brand Cannibalization Analysis)
SELECT
    sd.BrandName,
    nb.nielsen_category,
    sd.sku_id,
    sd.SkuCode,
    sd.SkuName,
    SUM(ti.TotalAmount) as sku_revenue,
    COUNT(ti.TransactionItemID) as transaction_count,
    ROUND((SUM(ti.TotalAmount) * 100.0 / SUM(SUM(ti.TotalAmount)) OVER(PARTITION BY sd.BrandName)), 2) as brand_revenue_share,
    COUNT(DISTINCT si.StoreID) as store_penetration
FROM ref.SkuDimensions sd
INNER JOIN dbo.TransactionItems ti ON ti.sku_id = sd.sku_id
INNER JOIN dbo.SalesInteractions si ON si.InteractionID = ti.InteractionID
LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = sd.BrandName
WHERE sd.IsActive = 1
    AND ti.TotalAmount > 0
GROUP BY sd.BrandName, nb.nielsen_category, sd.sku_id, sd.SkuCode, sd.SkuName
HAVING COUNT(ti.TransactionItemID) >= 3
ORDER BY sd.BrandName, sku_revenue DESC;

-- 4. SKU Size/Package Analysis (if package info available)
SELECT
    nb.nielsen_subcategory,
    sd.BrandName,
    sd.SkuCode,
    sd.SkuName,
    -- Extract size/package info from SKU name
    CASE
        WHEN sd.SkuName LIKE '%sachet%' THEN 'Sachet'
        WHEN sd.SkuName LIKE '%250g%' OR sd.SkuName LIKE '%250ml%' THEN 'Small (250g/ml)'
        WHEN sd.SkuName LIKE '%500g%' OR sd.SkuName LIKE '%500ml%' THEN 'Medium (500g/ml)'
        WHEN sd.SkuName LIKE '%1kg%' OR sd.SkuName LIKE '%1L%' THEN 'Large (1kg/L)'
        ELSE 'Unknown Size'
    END as package_size,
    COUNT(ti.TransactionItemID) as transaction_count,
    SUM(ti.TotalAmount) as package_revenue,
    AVG(ti.TotalAmount) as avg_transaction_value
FROM ref.SkuDimensions sd
INNER JOIN dbo.TransactionItems ti ON ti.sku_id = sd.sku_id
INNER JOIN dbo.SalesInteractions si ON si.InteractionID = ti.InteractionID
LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = sd.BrandName
WHERE sd.IsActive = 1
    AND ti.TotalAmount > 0
    AND nb.nielsen_subcategory IS NOT NULL
GROUP BY nb.nielsen_subcategory, sd.BrandName, sd.SkuCode, sd.SkuName
ORDER BY nb.nielsen_subcategory, package_revenue DESC;

-- 5. SKU Velocity Analysis (Sales per Day)
SELECT
    sd.sku_id,
    sd.SkuCode,
    sd.SkuName,
    sd.BrandName,
    nb.nielsen_department,
    nb.sari_sari_priority,
    COUNT(ti.TransactionItemID) as total_transactions,
    DATEDIFF(day, MIN(si.InteractionTimestamp), MAX(si.InteractionTimestamp)) + 1 as days_on_sale,
    CAST(COUNT(ti.TransactionItemID) AS FLOAT) /
        (DATEDIFF(day, MIN(si.InteractionTimestamp), MAX(si.InteractionTimestamp)) + 1) as transactions_per_day,
    SUM(ti.TotalAmount) /
        (DATEDIFF(day, MIN(si.InteractionTimestamp), MAX(si.InteractionTimestamp)) + 1) as revenue_per_day
FROM ref.SkuDimensions sd
INNER JOIN dbo.TransactionItems ti ON ti.sku_id = sd.sku_id
INNER JOIN dbo.SalesInteractions si ON si.InteractionID = ti.InteractionID
LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = sd.BrandName
WHERE sd.IsActive = 1
    AND ti.TotalAmount > 0
    AND DATEDIFF(day, MIN(si.InteractionTimestamp), MAX(si.InteractionTimestamp)) >= 7  -- At least 7 days
GROUP BY sd.sku_id, sd.SkuCode, sd.SkuName, sd.BrandName, nb.nielsen_department, nb.sari_sari_priority
HAVING COUNT(ti.TransactionItemID) >= 10  -- Minimum volume for velocity calculation
ORDER BY transactions_per_day DESC;

-- 6. Cross-SKU Purchase Analysis (Market Basket)
SELECT
    s1.sku_id as primary_sku,
    s1.SkuCode as primary_sku_code,
    s1.BrandName as primary_brand,
    s2.sku_id as companion_sku,
    s2.SkuCode as companion_sku_code,
    s2.BrandName as companion_brand,
    COUNT(*) as co_purchase_frequency,
    COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT t1.InteractionID)
                        FROM dbo.TransactionItems t1
                        WHERE t1.sku_id = s1.sku_id) as companion_attach_rate
FROM ref.SkuDimensions s1
INNER JOIN dbo.TransactionItems t1 ON t1.sku_id = s1.sku_id
INNER JOIN dbo.TransactionItems t2 ON t2.InteractionID = t1.InteractionID AND t2.sku_id != s1.sku_id
INNER JOIN ref.SkuDimensions s2 ON s2.sku_id = t2.sku_id
WHERE s1.IsActive = 1
    AND s2.IsActive = 1
    AND t1.TotalAmount > 0
    AND t2.TotalAmount > 0
GROUP BY s1.sku_id, s1.SkuCode, s1.BrandName, s2.sku_id, s2.SkuCode, s2.BrandName
HAVING COUNT(*) >= 3  -- At least 3 co-purchases
ORDER BY co_purchase_frequency DESC;

-- 7. SKU Performance by Store Type/Location
SELECT
    st.StoreID,
    st.StoreName,
    st.Region,
    sd.sku_id,
    sd.SkuCode,
    sd.BrandName,
    nb.nielsen_department,
    COUNT(ti.TransactionItemID) as sku_transactions_at_store,
    SUM(ti.TotalAmount) as sku_revenue_at_store,
    AVG(ti.TotalAmount) as avg_sku_transaction_value,
    RANK() OVER (PARTITION BY st.StoreID ORDER BY SUM(ti.TotalAmount) DESC) as sku_rank_at_store
FROM dbo.Stores st
INNER JOIN dbo.SalesInteractions si ON si.StoreID = st.StoreID
INNER JOIN dbo.TransactionItems ti ON ti.InteractionID = si.InteractionID
INNER JOIN ref.SkuDimensions sd ON sd.sku_id = ti.sku_id
LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = sd.BrandName
WHERE sd.IsActive = 1
    AND ti.TotalAmount > 0
GROUP BY st.StoreID, st.StoreName, st.Region, sd.sku_id, sd.SkuCode, sd.BrandName, nb.nielsen_department
HAVING COUNT(ti.TransactionItemID) >= 2  -- At least 2 transactions per store
ORDER BY st.StoreID, sku_revenue_at_store DESC;

-- 8. SKU Coverage and Data Quality Assessment
SELECT
    'SKU Coverage Analysis' as metric_category,
    COUNT(DISTINCT sd.sku_id) as total_skus_in_system,
    COUNT(DISTINCT ti.sku_id) as skus_with_transactions,
    COUNT(DISTINCT CASE WHEN nb.nielsen_department IS NOT NULL THEN sd.sku_id END) as skus_with_nielsen_mapping,
    ROUND(COUNT(DISTINCT ti.sku_id) * 100.0 / COUNT(DISTINCT sd.sku_id), 2) as sku_transaction_coverage_pct,
    ROUND(COUNT(DISTINCT CASE WHEN nb.nielsen_department IS NOT NULL THEN sd.sku_id END) * 100.0 / COUNT(DISTINCT sd.sku_id), 2) as sku_nielsen_coverage_pct,
    SUM(ti.TotalAmount) as total_sku_mapped_revenue,
    COUNT(ti.TransactionItemID) as total_sku_mapped_transactions
FROM ref.SkuDimensions sd
LEFT JOIN dbo.TransactionItems ti ON ti.sku_id = sd.sku_id AND ti.TotalAmount > 0
LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = sd.BrandName
WHERE sd.IsActive = 1;