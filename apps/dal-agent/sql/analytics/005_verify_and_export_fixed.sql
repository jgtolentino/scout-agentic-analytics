-- Verification and Export After Fix
-- Run this AFTER executing 004_fix_categories_and_backfill_skus.sql

-- 1) Verify category fixes
SELECT
    'CATEGORY FIX RESULTS' as check_type,
    brand_name,
    category,
    COUNT(*) as transaction_count,
    CASE
        WHEN category = 'unspecified' THEN '❌ Still broken'
        ELSE '✅ Fixed'
    END as status
FROM dbo.TransactionItems
WHERE brand_name IN (
    'Alaska', 'C2', 'Kopiko', 'Nido', 'Royal', 'Blend 45', 'Gatorade',
    'Great Taste', 'Selecta', 'Cobra', 'Cowhead', 'Ovaltine', 'Red Bull',
    'Extra Joss', 'Magnolia', 'Eight O''Clock', 'Nestea', 'Café Puro',
    'Tang', 'Nescafé', 'Presto'
)
GROUP BY brand_name, category
ORDER BY brand_name, category;

-- 2) SKU population statistics
SELECT
    'SKU BACKFILL RESULTS' as check_type,
    COUNT(*) as total_items,
    SUM(CASE WHEN sku_id IS NOT NULL THEN 1 ELSE 0 END) as items_with_sku,
    SUM(CASE WHEN sku_id IS NULL THEN 1 ELSE 0 END) as items_without_sku,
    CAST(100.0 * SUM(CASE WHEN sku_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) as pct_with_sku
FROM dbo.TransactionItems;

-- 3) Brand-level summary (clean, no duplicates)
WITH brand_summary AS (
    SELECT
        ti.brand_name,
        ti.category,
        COUNT(*) as transactions,
        SUM(TRY_CAST(si.TransactionValue AS DECIMAL(10,2))) as total_sales,
        COUNT(DISTINCT ti.sku_id) as unique_skus,
        ROW_NUMBER() OVER (
            PARTITION BY ti.brand_name
            ORDER BY COUNT(*) DESC
        ) as category_rank
    FROM dbo.TransactionItems ti
    LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = ti.canonical_tx_id
    GROUP BY ti.brand_name, ti.category
)
SELECT
    'CLEAN BRAND MAPPING' as export_type,
    brand_name as Brand,
    category as Category,
    transactions as Total_Transactions,
    ISNULL(total_sales, 0) as Total_Sales,
    unique_skus as Unique_SKUs,
    CASE
        WHEN transactions >= 200 THEN 'High Volume'
        WHEN transactions >= 50 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END as Volume_Tier
FROM brand_summary
WHERE category_rank = 1  -- Only primary category per brand
ORDER BY transactions DESC;

-- 4) SKU-level data (if available)
SELECT TOP 20
    'SKU LEVEL DATA' as export_type,
    ti.brand_name as Brand,
    ti.sku_id as SKU_ID,
    ti.item_desc as Product_Name,
    ti.category as Category,
    COUNT(*) as Transactions,
    COUNT(DISTINCT ti.canonical_tx_id) as Unique_Transactions
FROM dbo.TransactionItems ti
WHERE ti.sku_id IS NOT NULL
GROUP BY ti.brand_name, ti.sku_id, ti.item_desc, ti.category
ORDER BY COUNT(*) DESC;

-- 5) Categories with brand counts
SELECT
    'CATEGORY SUMMARY' as summary_type,
    category as Category,
    COUNT(DISTINCT brand_name) as Brand_Count,
    SUM(transaction_count) as Total_Transactions
FROM (
    SELECT
        brand_name,
        category,
        COUNT(*) as transaction_count,
        ROW_NUMBER() OVER (PARTITION BY brand_name ORDER BY COUNT(*) DESC) as rn
    FROM dbo.TransactionItems
    GROUP BY brand_name, category
) ranked
WHERE rn = 1  -- Primary category only
GROUP BY category
ORDER BY Total_Transactions DESC;