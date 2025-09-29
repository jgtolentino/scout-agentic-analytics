-- All Categories Analytics
-- Comprehensive analytics for all 30+ product categories with cross-category insights
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: CATEGORY PERFORMANCE OVERVIEW
-- =====================================================

WITH category_performance AS (
    SELECT
        t.category,

        -- Basic metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,
        SUM(t.transaction_value) AS revenue,
        CAST(AVG(t.transaction_value) AS DECIMAL(10,2)) AS avg_transaction_value,
        SUM(t.quantity) AS total_items_sold,
        CAST(AVG(t.quantity) AS DECIMAL(8,2)) AS avg_items_per_transaction,

        -- Customer demographics breakdown
        COUNT(CASE WHEN t.demographics_gender = 'Male' THEN 1 END) AS male_customers,
        COUNT(CASE WHEN t.demographics_gender = 'Female' THEN 1 END) AS female_customers,

        -- Age distribution
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 18 AND 35 THEN 1 END) AS young_adults,
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 36 AND 55 THEN 1 END) AS middle_aged,
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) > 55 THEN 1 END) AS seniors,

        -- Temporal patterns
        COUNT(CASE WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 1 END) AS morning_sales,
        COUNT(CASE WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 1 END) AS afternoon_sales,
        COUNT(CASE WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 23 THEN 1 END) AS evening_sales,

        -- Pecha de peligro analysis
        COUNT(CASE WHEN DAY(t.transaction_date) BETWEEN 23 AND 30 THEN 1 END) AS pecha_transactions,
        COUNT(CASE WHEN DAY(t.transaction_date) BETWEEN 1 AND 15 THEN 1 END) AS early_month_transactions,

        -- Brand diversity
        COUNT(DISTINCT t.brand) AS unique_brands,

        -- AI confidence metrics
        CAST(AVG(CAST(t.brand_confidence AS FLOAT)) AS DECIMAL(5,3)) AS avg_brand_confidence,

        -- Calculate market share
        CAST(COUNT(DISTINCT t.transaction_id) * 100.0 /
             SUM(COUNT(DISTINCT t.transaction_id)) OVER() AS DECIMAL(5,2)) AS transaction_share,
        CAST(SUM(t.transaction_value) * 100.0 /
             SUM(SUM(t.transaction_value)) OVER() AS DECIMAL(5,2)) AS revenue_share

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t.category IS NOT NULL
        AND t.category != ''
    GROUP BY t.category
),

-- =====================================================
-- SECTION 2: CROSS-CATEGORY AFFINITY ANALYSIS
-- =====================================================

cross_category_affinity AS (
    SELECT
        t1.category AS category_1,
        t2.category AS category_2,
        COUNT(DISTINCT t1.transaction_id) AS co_occurrences,
        COUNT(DISTINCT t1.canonical_tx_id) AS unique_customers,

        -- Calculate support (how often categories appear together)
        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id)
             FROM canonical.v_transactions_flat_enhanced
             WHERE transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')) AS co_support,

        -- Calculate individual category support
        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id)
             FROM canonical.v_transactions_flat_enhanced
             WHERE category = t1.category
               AND transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')) AS category_1_support,

        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id)
             FROM canonical.v_transactions_flat_enhanced
             WHERE category = t2.category
               AND transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')) AS category_2_support

    FROM canonical.v_transactions_flat_enhanced t1
        INNER JOIN canonical.v_transactions_flat_enhanced t2
            ON t1.transaction_id = t2.transaction_id
            AND t1.category < t2.category  -- Avoid duplicates and self-joins
    WHERE t1.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t1.category IS NOT NULL AND t1.category != ''
        AND t2.category IS NOT NULL AND t2.category != ''
    GROUP BY t1.category, t2.category
    HAVING COUNT(DISTINCT t1.transaction_id) >= 3  -- Minimum occurrences for significance
),

-- =====================================================
-- SECTION 3: BRAND PERFORMANCE ACROSS CATEGORIES
-- =====================================================

brand_category_performance AS (
    SELECT
        t.category,
        t.brand,

        -- Performance metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,
        SUM(t.transaction_value) AS revenue,
        CAST(AVG(t.transaction_value) AS DECIMAL(10,2)) AS avg_transaction_value,
        SUM(t.quantity) AS total_items,

        -- Brand ranking within category
        ROW_NUMBER() OVER (PARTITION BY t.category ORDER BY COUNT(DISTINCT t.transaction_id) DESC) AS brand_rank_by_transactions,
        ROW_NUMBER() OVER (PARTITION BY t.category ORDER BY SUM(t.transaction_value) DESC) AS brand_rank_by_revenue,

        -- Market share within category
        CAST(COUNT(DISTINCT t.transaction_id) * 100.0 /
             SUM(COUNT(DISTINCT t.transaction_id)) OVER(PARTITION BY t.category) AS DECIMAL(5,2)) AS category_transaction_share,
        CAST(SUM(t.transaction_value) * 100.0 /
             SUM(SUM(t.transaction_value)) OVER(PARTITION BY t.category) AS DECIMAL(5,2)) AS category_revenue_share,

        -- Customer loyalty (repeat purchases)
        COUNT(DISTINCT t.canonical_tx_id) * 1.0 / COUNT(DISTINCT t.transaction_id) AS customer_loyalty_ratio,

        -- AI confidence
        CAST(AVG(CAST(t.brand_confidence AS FLOAT)) AS DECIMAL(5,3)) AS avg_brand_confidence

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t.category IS NOT NULL AND t.category != ''
        AND t.brand IS NOT NULL AND t.brand != ''
    GROUP BY t.category, t.brand
),

-- =====================================================
-- SECTION 4: TEMPORAL PATTERNS BY CATEGORY
-- =====================================================

category_temporal_patterns AS (
    SELECT
        t.category,

        -- Day of week patterns
        DATENAME(WEEKDAY, t.transaction_date) AS day_of_week,
        DATEPART(WEEKDAY, t.transaction_date) AS day_of_week_num,

        -- Hour patterns
        DATEPART(HOUR, t.transaction_datetime) AS hour_of_day,
        CASE
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS daypart,

        -- Monthly patterns
        MONTH(t.transaction_date) AS month_number,
        DATENAME(MONTH, t.transaction_date) AS month_name,

        -- Salary period analysis
        CASE
            WHEN DAY(t.transaction_date) BETWEEN 23 AND 30 THEN 'Pecha de Peligro'
            WHEN DAY(t.transaction_date) BETWEEN 1 AND 7 THEN 'Start of Month'
            WHEN DAY(t.transaction_date) BETWEEN 8 AND 15 THEN 'Mid Month Early'
            ELSE 'Mid Month Late'
        END AS salary_period,

        -- Metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.transaction_value) AS revenue,
        COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,

        -- Calculate percentage within category
        CAST(COUNT(DISTINCT t.transaction_id) * 100.0 /
             SUM(COUNT(DISTINCT t.transaction_id)) OVER(PARTITION BY t.category) AS DECIMAL(5,2)) AS pct_within_category

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t.category IS NOT NULL AND t.category != ''
    GROUP BY t.category, day_of_week, day_of_week_num, hour_of_day, daypart,
             month_number, month_name, salary_period
),

-- =====================================================
-- SECTION 5: CUSTOMER JOURNEY MAPPING
-- =====================================================

customer_journey_analysis AS (
    SELECT
        t.canonical_tx_id AS customer_id,
        COUNT(DISTINCT t.category) AS categories_purchased,
        COUNT(DISTINCT t.transaction_id) AS total_transactions,
        SUM(t.transaction_value) AS total_spend,
        CAST(AVG(t.transaction_value) AS DECIMAL(10,2)) AS avg_transaction_value,

        -- Customer categorization
        CASE
            WHEN COUNT(DISTINCT t.category) = 1 THEN 'Single Category'
            WHEN COUNT(DISTINCT t.category) BETWEEN 2 AND 3 THEN 'Multi Category'
            WHEN COUNT(DISTINCT t.category) >= 4 THEN 'Diverse Shopper'
        END AS customer_type,

        -- Category sequence (first 5 categories purchased)
        STRING_AGG(t.category, ' -> ') WITHIN GROUP (ORDER BY t.transaction_datetime) AS category_sequence,

        -- Time span of purchases
        DATEDIFF(DAY, MIN(t.transaction_date), MAX(t.transaction_date)) AS purchase_span_days,

        -- Loyalty indicators
        COUNT(DISTINCT t.brand) AS unique_brands_tried,
        COUNT(DISTINCT t.store_id) AS stores_visited

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t.category IS NOT NULL AND t.category != ''
        AND t.canonical_tx_id IS NOT NULL
    GROUP BY t.canonical_tx_id
    HAVING COUNT(DISTINCT t.transaction_id) >= 2  -- Multi-transaction customers only
),

-- =====================================================
-- SECTION 6: SEASONAL TRENDS ANALYSIS
-- =====================================================

seasonal_trends AS (
    SELECT
        t.category,
        YEAR(t.transaction_date) AS year,
        MONTH(t.transaction_date) AS month,
        DATENAME(MONTH, t.transaction_date) AS month_name,
        DATEPART(ISO_WEEK, t.transaction_date) AS iso_week,

        -- Weekly metrics
        COUNT(DISTINCT t.transaction_id) AS weekly_transactions,
        SUM(t.transaction_value) AS weekly_revenue,
        COUNT(DISTINCT t.canonical_tx_id) AS weekly_customers,

        -- Calculate growth rates (month-over-month)
        LAG(COUNT(DISTINCT t.transaction_id)) OVER (PARTITION BY t.category ORDER BY YEAR(t.transaction_date), MONTH(t.transaction_date)) AS prev_month_transactions,

        CASE
            WHEN LAG(COUNT(DISTINCT t.transaction_id)) OVER (PARTITION BY t.category ORDER BY YEAR(t.transaction_date), MONTH(t.transaction_date)) > 0
            THEN CAST((COUNT(DISTINCT t.transaction_id) - LAG(COUNT(DISTINCT t.transaction_id)) OVER (PARTITION BY t.category ORDER BY YEAR(t.transaction_date), MONTH(t.transaction_date))) * 100.0 /
                      LAG(COUNT(DISTINCT t.transaction_id)) OVER (PARTITION BY t.category ORDER BY YEAR(t.transaction_date), MONTH(t.transaction_date)) AS DECIMAL(8,2))
            ELSE NULL
        END AS mom_growth_rate

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t.category IS NOT NULL AND t.category != ''
    GROUP BY t.category, YEAR(t.transaction_date), MONTH(t.transaction_date),
             DATENAME(MONTH, t.transaction_date), DATEPART(ISO_WEEK, t.transaction_date)
)

-- =====================================================
-- SECTION 7: EXPORT QUERIES
-- =====================================================

-- Export 1: Category Performance Overview
SELECT
    'Category Performance' AS export_type,
    category,
    transactions,
    unique_customers,
    CAST(revenue AS DECIMAL(18,2)) AS revenue,
    avg_transaction_value,
    total_items_sold,
    avg_items_per_transaction,

    -- Demographics percentages
    CAST(male_customers * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS male_pct,
    CAST(female_customers * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS female_pct,

    -- Age distribution
    CAST(young_adults * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS young_adults_pct,
    CAST(middle_aged * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS middle_aged_pct,
    CAST(seniors * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS seniors_pct,

    -- Temporal distribution
    CAST(morning_sales * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS morning_pct,
    CAST(afternoon_sales * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS afternoon_pct,
    CAST(evening_sales * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS evening_pct,

    -- Pecha de peligro impact
    CAST(pecha_transactions * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS pecha_impact_pct,

    -- Brand diversity and confidence
    unique_brands,
    avg_brand_confidence,

    -- Market share
    transaction_share,
    revenue_share

FROM category_performance
ORDER BY revenue DESC;

-- Export 2: Cross-Category Affinity Matrix
SELECT
    'Category Affinity Matrix' AS export_type,
    category_1,
    category_2,
    co_occurrences,
    unique_customers,
    CAST(co_support * 100 AS DECIMAL(5,2)) AS co_support_pct,

    -- Calculate lift (how much more likely categories are bought together vs independently)
    CAST((co_support / (category_1_support * category_2_support)) AS DECIMAL(8,2)) AS lift_score,

    CASE
        WHEN (co_support / (category_1_support * category_2_support)) > 1.5 THEN 'Very Strong'
        WHEN (co_support / (category_1_support * category_2_support)) > 1.2 THEN 'Strong'
        WHEN (co_support / (category_1_support * category_2_support)) > 1.0 THEN 'Moderate'
        ELSE 'Weak'
    END AS affinity_strength

FROM cross_category_affinity
WHERE co_occurrences >= 5
ORDER BY lift_score DESC;

-- Export 3: Top Brands by Category
SELECT
    'Top Brands by Category' AS export_type,
    category,
    brand,
    brand_rank_by_transactions,
    brand_rank_by_revenue,
    transactions,
    unique_customers,
    CAST(revenue AS DECIMAL(18,2)) AS revenue,
    avg_transaction_value,
    category_transaction_share,
    category_revenue_share,
    CAST(customer_loyalty_ratio AS DECIMAL(5,3)) AS loyalty_ratio,
    avg_brand_confidence
FROM brand_category_performance
WHERE brand_rank_by_transactions <= 5  -- Top 5 brands per category
ORDER BY category, brand_rank_by_transactions;

-- Export 4: Temporal Patterns by Category
SELECT
    'Category Temporal Patterns' AS export_type,
    category,
    day_of_week,
    daypart,
    hour_of_day,
    salary_period,
    month_name,
    transactions,
    CAST(revenue AS DECIMAL(18,2)) AS revenue,
    unique_customers,
    pct_within_category
FROM category_temporal_patterns
ORDER BY category, day_of_week_num, hour_of_day;

-- Export 5: Customer Journey Analysis
SELECT
    'Customer Journey Mapping' AS export_type,
    customer_type,
    COUNT(*) AS customer_count,
    CAST(AVG(categories_purchased) AS DECIMAL(5,2)) AS avg_categories,
    CAST(AVG(total_transactions) AS DECIMAL(5,2)) AS avg_transactions,
    CAST(AVG(total_spend) AS DECIMAL(10,2)) AS avg_total_spend,
    CAST(AVG(avg_transaction_value) AS DECIMAL(10,2)) AS avg_transaction_value,
    CAST(AVG(purchase_span_days) AS DECIMAL(8,2)) AS avg_purchase_span_days,
    CAST(AVG(unique_brands_tried) AS DECIMAL(5,2)) AS avg_brands_tried,
    CAST(AVG(stores_visited) AS DECIMAL(5,2)) AS avg_stores_visited
FROM customer_journey_analysis
GROUP BY customer_type
ORDER BY customer_count DESC;

-- Export 6: Seasonal Trends
SELECT
    'Seasonal Trends' AS export_type,
    category,
    year,
    month,
    month_name,
    iso_week,
    weekly_transactions,
    CAST(weekly_revenue AS DECIMAL(18,2)) AS weekly_revenue,
    weekly_customers,
    mom_growth_rate
FROM seasonal_trends
WHERE mom_growth_rate IS NOT NULL
ORDER BY category, year, month;

-- Export 7: Multi-Category Baskets (Top Combinations)
SELECT
    'Multi-Category Baskets' AS export_type,
    customer_id,
    categories_purchased,
    total_transactions,
    CAST(total_spend AS DECIMAL(18,2)) AS total_spend,
    avg_transaction_value,
    LEFT(category_sequence, 200) AS category_sequence_preview,  -- Limit for readability
    purchase_span_days,
    unique_brands_tried,
    stores_visited
FROM customer_journey_analysis
WHERE categories_purchased >= 3
ORDER BY total_spend DESC;

PRINT 'All categories analytics completed successfully';