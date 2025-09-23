-- ===================================================================
-- SQL TEMPLATE: Time of Day × Category Analysis
-- ID: time_of_day_category
-- Version: 1.0
-- Purpose: Analyze transaction patterns by time periods and product categories
-- ===================================================================

-- Template Parameters:
-- @date_from (date): Start date for analysis (default: 14 days ago)
-- @date_to (date): End date for analysis (default: today)
-- @category (nvarchar): Specific category filter (optional)
-- @municipality (nvarchar): Specific municipality filter (optional)
-- @store_id (int): Specific store filter (optional)

-- Business Question: "Which categories peak at different times of day?"
-- Use Cases: Inventory planning, staffing optimization, promotional timing

WITH time_category_analysis AS (
    SELECT
        CASE
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 6 AND 11 THEN 'Morning (6-11 AM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon (12-5 PM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 18 AND 21 THEN 'Evening (6-9 PM)'
            ELSE 'Night (10 PM-5 AM)'
        END as time_period,
        t.category,
        COUNT(*) as transaction_count,
        SUM(t.total_price) as total_revenue,
        AVG(t.total_price) as avg_transaction_value,
        COUNT(DISTINCT t.storeid) as store_count,
        COUNT(DISTINCT t.productid) as unique_products
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ISNULL(@date_from, DATEADD(day, -14, GETUTCDATE()))
      AND t.transactiondate <= ISNULL(@date_to, GETUTCDATE())
      AND t.location LIKE '%NCR%'
      AND (@category IS NULL OR t.category = @category)
      AND (@municipality IS NULL OR t.location LIKE '%' + @municipality + '%')
      AND (@store_id IS NULL OR t.storeid = @store_id)
      AND t.category IS NOT NULL
    GROUP BY
        CASE
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 6 AND 11 THEN 'Morning (6-11 AM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon (12-5 PM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 18 AND 21 THEN 'Evening (6-9 PM)'
            ELSE 'Night (10 PM-5 AM)'
        END,
        t.category
),
category_totals AS (
    SELECT
        category,
        SUM(transaction_count) as total_category_txns
    FROM time_category_analysis
    GROUP BY category
),
time_totals AS (
    SELECT
        time_period,
        SUM(transaction_count) as total_period_txns
    FROM time_category_analysis
    GROUP BY time_period
)
SELECT
    tca.time_period,
    tca.category,
    tca.transaction_count,
    ROUND(tca.total_revenue, 2) as total_revenue,
    ROUND(tca.avg_transaction_value, 2) as avg_transaction_value,
    tca.store_count,
    tca.unique_products,
    ROUND(100.0 * tca.transaction_count / ct.total_category_txns, 1) as category_share_pct,
    ROUND(100.0 * tca.transaction_count / tt.total_period_txns, 1) as time_period_share_pct,
    RANK() OVER (PARTITION BY tca.time_period ORDER BY tca.transaction_count DESC) as category_rank_in_period,
    RANK() OVER (PARTITION BY tca.category ORDER BY tca.transaction_count DESC) as period_rank_for_category
FROM time_category_analysis tca
JOIN category_totals ct ON tca.category = ct.category
JOIN time_totals tt ON tca.time_period = tt.time_period
WHERE tca.transaction_count >= 5 -- Statistical significance threshold
ORDER BY tca.time_period, tca.transaction_count DESC;

-- Template Metadata:
-- Expected Output: 12-48 rows (4 time periods × 3-12 categories)
-- Validation: SUM(category_share_pct) per category should = 100%
-- Validation: SUM(time_period_share_pct) per time period should = 100%
-- Performance: ~200ms on 30 days of data
-- Dependencies: public.scout_gold_transactions_flat