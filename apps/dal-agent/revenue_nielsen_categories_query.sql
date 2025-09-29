-- Revenue Analysis by Nielsen Categories and Subcategories
-- Using the extended Nielsen taxonomy (1,100+ categories)
-- Scout v7 Database with Nielsen Industry Standards

-- 1. Revenue Summary by Nielsen Department (Level 1)
SELECT
    nielsen_department,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as total_revenue,
    AVG(transaction_value) as avg_transaction_value,
    MIN(transaction_value) as min_transaction,
    MAX(transaction_value) as max_transaction,
    COUNT(DISTINCT store_id) as active_stores,
    COUNT(DISTINCT canonical_tx_id) as unique_transactions,
    ROUND((SUM(transaction_value) * 100.0 / (SELECT SUM(transaction_value) FROM v_nielsen_flat_export WHERE transaction_value > 0)), 2) as revenue_percentage
FROM v_nielsen_flat_export
WHERE nielsen_department IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY nielsen_department
ORDER BY total_revenue DESC;

-- 2. Revenue by Nielsen Category (Level 2) with Department Context
SELECT
    nielsen_department,
    nielsen_category,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as total_revenue,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / SUM(SUM(transaction_value)) OVER(PARTITION BY nielsen_department)), 2) as dept_revenue_percentage,
    COUNT(DISTINCT store_id) as active_stores,
    MIN(transaction_date) as first_transaction,
    MAX(transaction_date) as last_transaction
FROM v_nielsen_flat_export
WHERE nielsen_department IS NOT NULL
    AND nielsen_category IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY nielsen_department, nielsen_category
ORDER BY nielsen_department, total_revenue DESC;

-- 3. Revenue by Nielsen Subcategory (Level 3) - Top 25 Performers
SELECT TOP 25
    nielsen_department,
    nielsen_category,
    nielsen_subcategory,
    SUM(transaction_value) as total_revenue,
    COUNT(*) as transaction_count,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / (SELECT SUM(transaction_value) FROM v_nielsen_flat_export WHERE transaction_value > 0)), 2) as percentage_of_total_revenue,
    COUNT(DISTINCT brand_name) as unique_brands,
    COUNT(DISTINCT store_id) as store_reach
FROM v_nielsen_flat_export
WHERE nielsen_department IS NOT NULL
    AND nielsen_category IS NOT NULL
    AND nielsen_subcategory IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY nielsen_department, nielsen_category, nielsen_subcategory
ORDER BY total_revenue DESC;

-- 4. Sari-Sari Priority Revenue Analysis
SELECT
    sari_sari_priority,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as total_revenue,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / (SELECT SUM(transaction_value) FROM v_nielsen_flat_export WHERE transaction_value > 0)), 2) as revenue_percentage,
    COUNT(DISTINCT nielsen_department) as departments_covered,
    COUNT(DISTINCT nielsen_category) as categories_covered,
    COUNT(DISTINCT brand_name) as unique_brands
FROM v_nielsen_flat_export
WHERE sari_sari_priority IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY sari_sari_priority
ORDER BY
    CASE sari_sari_priority
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
        WHEN 'Rare' THEN 5
        ELSE 6
    END;

-- 5. Value Tier Revenue Performance
SELECT
    value_tier,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as total_revenue,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / (SELECT SUM(transaction_value) FROM v_nielsen_flat_export WHERE transaction_value > 0)), 2) as revenue_percentage,
    COUNT(DISTINCT nielsen_department) as departments,
    COUNT(DISTINCT brand_name) as brands,
    COUNT(DISTINCT store_id) as stores
FROM v_nielsen_flat_export
WHERE value_tier IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY value_tier
ORDER BY total_revenue DESC;

-- 6. Brand Performance within Nielsen Categories
SELECT
    nielsen_department,
    nielsen_category,
    brand_name,
    manufacturer,
    SUM(transaction_value) as brand_revenue,
    COUNT(*) as transaction_count,
    AVG(transaction_value) as avg_transaction_value,
    RANK() OVER (PARTITION BY nielsen_department, nielsen_category ORDER BY SUM(transaction_value) DESC) as rank_within_category,
    COUNT(DISTINCT store_id) as store_reach
FROM v_nielsen_flat_export
WHERE nielsen_department IS NOT NULL
    AND nielsen_category IS NOT NULL
    AND brand_name IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY nielsen_department, nielsen_category, brand_name, manufacturer
HAVING COUNT(*) >= 3  -- Only brands with at least 3 transactions
ORDER BY nielsen_department, nielsen_category, brand_revenue DESC;

-- 7. Monthly Revenue Trends by Nielsen Department
SELECT
    nielsen_department,
    YEAR(transaction_date) as transaction_year,
    MONTH(transaction_date) as transaction_month,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as monthly_revenue,
    AVG(transaction_value) as avg_monthly_transaction,
    COUNT(DISTINCT nielsen_category) as active_categories,
    COUNT(DISTINCT brand_name) as active_brands
FROM v_nielsen_flat_export
WHERE nielsen_department IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
    AND transaction_date >= '2025-01-01'
GROUP BY nielsen_department, YEAR(transaction_date), MONTH(transaction_date)
ORDER BY nielsen_department, transaction_year, transaction_month;

-- 8. Store Performance by Nielsen Department
SELECT
    store_id,
    nielsen_department,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as dept_revenue_per_store,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / SUM(SUM(transaction_value)) OVER(PARTITION BY store_id)), 2) as dept_share_of_store_revenue,
    COUNT(DISTINCT nielsen_category) as categories_sold,
    COUNT(DISTINCT brand_name) as brands_sold
FROM v_nielsen_flat_export
WHERE nielsen_department IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY store_id, nielsen_department
HAVING COUNT(*) >= 10  -- Only departments with at least 10 transactions per store
ORDER BY store_id, dept_revenue_per_store DESC;

-- 9. Data Quality Assessment - Nielsen Coverage
SELECT
    'Nielsen Coverage' as metric,
    COUNT(CASE WHEN nielsen_department IS NOT NULL THEN 1 END) as nielsen_mapped,
    COUNT(CASE WHEN nielsen_department IS NULL THEN 1 END) as unmapped,
    COUNT(*) as total_transactions,
    ROUND((COUNT(CASE WHEN nielsen_department IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)), 2) as coverage_percentage,
    SUM(CASE WHEN nielsen_department IS NOT NULL THEN transaction_value ELSE 0 END) as nielsen_revenue,
    SUM(CASE WHEN nielsen_department IS NULL THEN transaction_value ELSE 0 END) as unmapped_revenue,
    SUM(transaction_value) as total_revenue
FROM v_nielsen_flat_export
WHERE transaction_value > 0
    AND canonical_tx_id IS NOT NULL

UNION ALL

SELECT
    'Quality Flag Distribution' as metric,
    COUNT(CASE WHEN quality_flag = 'High_Quality' THEN 1 END) as high_quality,
    COUNT(CASE WHEN quality_flag <> 'High_Quality' THEN 1 END) as other_quality,
    COUNT(*) as total_transactions,
    ROUND((COUNT(CASE WHEN quality_flag = 'High_Quality' THEN 1 END) * 100.0 / COUNT(*)), 2) as quality_percentage,
    SUM(CASE WHEN quality_flag = 'High_Quality' THEN transaction_value ELSE 0 END) as high_quality_revenue,
    SUM(CASE WHEN quality_flag <> 'High_Quality' THEN transaction_value ELSE 0 END) as other_revenue,
    SUM(transaction_value) as total_revenue
FROM v_nielsen_flat_export
WHERE transaction_value > 0
    AND canonical_tx_id IS NOT NULL;

-- 10. Nielsen Department vs Legacy Category Comparison
SELECT
    nielsen_department,
    category as legacy_category,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as revenue,
    ROUND((SUM(transaction_value) * 100.0 / SUM(SUM(transaction_value)) OVER(PARTITION BY nielsen_department)), 2) as revenue_within_dept
FROM v_nielsen_flat_export nf
LEFT JOIN gold.v_export_projection gv ON nf.transaction_id = gv.canonical_tx_id
WHERE nielsen_department IS NOT NULL
    AND nf.transaction_value > 0
    AND nf.canonical_tx_id IS NOT NULL
GROUP BY nielsen_department, category
HAVING COUNT(*) >= 5
ORDER BY nielsen_department, revenue DESC;