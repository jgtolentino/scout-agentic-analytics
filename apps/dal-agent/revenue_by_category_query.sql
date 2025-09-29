-- Revenue Analysis by Category and Subcategory
-- Scout v7 Database Revenue Breakdown

-- 1. Revenue Summary by Category
SELECT
    category,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as total_revenue,
    AVG(transaction_value) as avg_transaction_value,
    MIN(transaction_value) as min_transaction,
    MAX(transaction_value) as max_transaction,
    COUNT(DISTINCT store_id) as active_stores,
    COUNT(DISTINCT canonical_tx_id) as unique_transactions
FROM gold.v_export_projection
WHERE category IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY category
ORDER BY total_revenue DESC;

-- 2. Revenue Breakdown by Category and Subcategory
SELECT
    category,
    subcategory,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as total_revenue,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / SUM(SUM(transaction_value)) OVER()), 2) as revenue_percentage,
    COUNT(DISTINCT store_id) as active_stores,
    MIN(transaction_timestamp) as first_transaction,
    MAX(transaction_timestamp) as last_transaction
FROM gold.v_export_projection
WHERE category IS NOT NULL
    AND subcategory IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY category, subcategory
ORDER BY total_revenue DESC;

-- 3. Top Revenue Generating Subcategories (Top 20)
SELECT TOP 20
    category,
    subcategory,
    SUM(transaction_value) as total_revenue,
    COUNT(*) as transaction_count,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / (SELECT SUM(transaction_value) FROM gold.v_export_projection WHERE transaction_value > 0)), 2) as percentage_of_total_revenue
FROM gold.v_export_projection
WHERE category IS NOT NULL
    AND subcategory IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY category, subcategory
ORDER BY total_revenue DESC;

-- 4. Revenue by Category with Monthly Trends
SELECT
    category,
    YEAR(transaction_timestamp) as transaction_year,
    MONTH(transaction_timestamp) as transaction_month,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as monthly_revenue,
    AVG(transaction_value) as avg_monthly_transaction
FROM gold.v_export_projection
WHERE category IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
    AND transaction_timestamp >= '2025-01-01'
GROUP BY category, YEAR(transaction_timestamp), MONTH(transaction_timestamp)
ORDER BY category, transaction_year, transaction_month;

-- 5. Store Performance by Category
SELECT
    store_id,
    category,
    COUNT(*) as transaction_count,
    SUM(transaction_value) as store_category_revenue,
    AVG(transaction_value) as avg_transaction_value,
    ROUND((SUM(transaction_value) * 100.0 / SUM(SUM(transaction_value)) OVER(PARTITION BY store_id)), 2) as category_share_of_store_revenue
FROM gold.v_export_projection
WHERE category IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY store_id, category
HAVING COUNT(*) >= 5  -- Only categories with at least 5 transactions per store
ORDER BY store_id, store_category_revenue DESC;

-- 6. Category Revenue Comparison (Current vs Previous Period)
WITH monthly_revenue AS (
    SELECT
        category,
        YEAR(transaction_timestamp) as year,
        MONTH(transaction_timestamp) as month,
        SUM(transaction_value) as monthly_revenue
    FROM gold.v_export_projection
    WHERE category IS NOT NULL
        AND transaction_value > 0
        AND canonical_tx_id IS NOT NULL
        AND transaction_timestamp >= '2025-01-01'
    GROUP BY category, YEAR(transaction_timestamp), MONTH(transaction_timestamp)
),
current_vs_previous AS (
    SELECT
        category,
        year,
        month,
        monthly_revenue,
        LAG(monthly_revenue, 1) OVER (PARTITION BY category ORDER BY year, month) as previous_month_revenue
    FROM monthly_revenue
)
SELECT
    category,
    year,
    month,
    monthly_revenue,
    previous_month_revenue,
    CASE
        WHEN previous_month_revenue IS NOT NULL AND previous_month_revenue > 0
        THEN ROUND(((monthly_revenue - previous_month_revenue) * 100.0 / previous_month_revenue), 2)
        ELSE NULL
    END as month_over_month_growth_percentage
FROM current_vs_previous
WHERE year = 2025 AND month >= 8  -- Current period
ORDER BY category, year, month;

-- 7. Subcategory Performance within Categories
SELECT
    category,
    subcategory,
    SUM(transaction_value) as subcategory_revenue,
    COUNT(*) as transaction_count,
    ROUND((SUM(transaction_value) * 100.0 / SUM(SUM(transaction_value)) OVER(PARTITION BY category)), 2) as percentage_within_category,
    RANK() OVER (PARTITION BY category ORDER BY SUM(transaction_value) DESC) as rank_within_category
FROM gold.v_export_projection
WHERE category IS NOT NULL
    AND subcategory IS NOT NULL
    AND transaction_value > 0
    AND canonical_tx_id IS NOT NULL
GROUP BY category, subcategory
ORDER BY category, subcategory_revenue DESC;