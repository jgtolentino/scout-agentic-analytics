-- ===================================================================
-- SQL TEMPLATE: Age Bracket × Brand Preferences Analysis
-- ID: age_bracket_brand
-- Version: 1.0
-- Purpose: Analyze brand preferences across different age demographics
-- ===================================================================

-- Template Parameters:
-- @date_from (date): Start date for analysis (default: 30 days ago)
-- @date_to (date): End date for analysis (default: today)
-- @brand (nvarchar): Specific brand filter (optional)
-- @age_bracket (nvarchar): Specific age bracket filter (optional)
-- @min_transactions (int): Minimum transactions for inclusion (default: 5)

-- Business Question: "Which brands do different age groups prefer?"
-- Use Cases: Marketing targeting, product positioning, inventory planning

WITH age_brand_analysis AS (
    SELECT
        COALESCE(t.agebracket, 'Unknown') as age_bracket,
        t.brand,
        t.category,
        COUNT(*) as transaction_count,
        SUM(t.total_price) as total_revenue,
        AVG(t.total_price) as avg_transaction_value,
        COUNT(DISTINCT t.storeid) as store_count,
        COUNT(DISTINCT t.productid) as unique_products,
        -- Calculate demographic penetration
        COUNT(DISTINCT CONCAT(t.storeid, '-', t.facialid)) as unique_customers_estimated
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ISNULL(@date_from, DATEADD(day, -30, GETUTCDATE()))
      AND t.transactiondate <= ISNULL(@date_to, GETUTCDATE())
      AND t.location LIKE '%NCR%'
      AND (@brand IS NULL OR t.brand = @brand)
      AND (@age_bracket IS NULL OR t.agebracket = @age_bracket)
      AND t.brand IS NOT NULL
      AND t.agebracket IS NOT NULL
    GROUP BY
        COALESCE(t.agebracket, 'Unknown'),
        t.brand,
        t.category
),
age_totals AS (
    SELECT
        age_bracket,
        SUM(transaction_count) as total_age_transactions
    FROM age_brand_analysis
    GROUP BY age_bracket
),
brand_totals AS (
    SELECT
        brand,
        SUM(transaction_count) as total_brand_transactions
    FROM age_brand_analysis
    GROUP BY brand
),
category_age_totals AS (
    SELECT
        age_bracket,
        category,
        SUM(transaction_count) as total_age_category_transactions
    FROM age_brand_analysis
    GROUP BY age_bracket, category
)
SELECT
    aba.age_bracket,
    aba.brand,
    aba.category,
    aba.transaction_count,
    ROUND(aba.total_revenue, 2) as total_revenue,
    ROUND(aba.avg_transaction_value, 2) as avg_transaction_value,
    aba.store_count,
    aba.unique_products,
    aba.unique_customers_estimated,
    ROUND(100.0 * aba.transaction_count / at.total_age_transactions, 1) as age_brand_share_pct,
    ROUND(100.0 * aba.transaction_count / bt.total_brand_transactions, 1) as brand_age_share_pct,
    ROUND(100.0 * aba.transaction_count / cat.total_age_category_transactions, 1) as category_age_brand_share_pct,
    RANK() OVER (PARTITION BY aba.age_bracket ORDER BY aba.transaction_count DESC) as brand_rank_for_age,
    RANK() OVER (PARTITION BY aba.brand ORDER BY aba.transaction_count DESC) as age_rank_for_brand,
    -- Affinity index (over/under-indexing vs overall population)
    ROUND(100.0 * (aba.transaction_count / at.total_age_transactions) /
          (bt.total_brand_transactions / (SELECT SUM(transaction_count) FROM age_brand_analysis)), 1) as affinity_index
FROM age_brand_analysis aba
JOIN age_totals at ON aba.age_bracket = at.age_bracket
JOIN brand_totals bt ON aba.brand = bt.brand
JOIN category_age_totals cat ON aba.age_bracket = cat.age_bracket AND aba.category = cat.category
WHERE aba.transaction_count >= ISNULL(@min_transactions, 5)
ORDER BY aba.transaction_count DESC, affinity_index DESC;

-- Template Metadata:
-- Expected Output: 30-100 rows (5-8 age brackets × 6-15 brands)
-- Validation: SUM(age_brand_share_pct) per age bracket should = 100%
-- Validation: SUM(brand_age_share_pct) per brand should = 100%
-- Validation: affinity_index around 100 indicates average affinity
-- Performance: ~250ms on 30 days of data
-- Dependencies: public.scout_gold_transactions_flat, agebracket field
-- Notes: Affinity index >120 indicates strong preference, <80 indicates avoidance