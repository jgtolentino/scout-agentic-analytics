-- Template: time_daypart_category_store_store_location
-- Business Question: "When do customers shop for specific Day Part, Product Category, Store, Store Location?"
-- Dimensional Analysis: Day Part × Product Category × Store × Store Location
-- Combination Type: 4-way cross-tabulation
-- Generated: 2025-09-22

-- Parameters:
-- ${{date_from}} - Start date (YYYY-MM-DD format)
-- ${{date_to}} - End date (YYYY-MM-DD format)
-- ${{limit}} - Maximum rows to return (default: 100)
-- ${{category}} - Optional category filter
-- ${{store_id}} - Optional store filter
-- ${{store_id}} - Optional store filter


WITH dimensional_base AS (
    SELECT
    CASE WHEN DATEPART(hour, transactiondate) BETWEEN 6 AND 11 THEN 'Morning' WHEN DATEPART(hour, transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon' WHEN DATEPART(hour, transactiondate) BETWEEN 18 AND 21 THEN 'Evening' ELSE 'Night' END AS time_daypart,
    category AS category,
    storename AS store,
    CONCAT(storename, ' (', municipalityname, ')') AS store_location,
        COUNT(*) AS transaction_count,
        SUM(total_price) AS total_revenue,
        AVG(total_price) AS avg_transaction_value,
        COUNT(DISTINCT productid) AS unique_products,
        COUNT(DISTINCT CAST(transactiondate AS date)) AS active_days,
        MIN(transactiondate) AS first_transaction,
        MAX(transactiondate) AS last_transaction,
        STDDEV(total_price) AS price_stddev
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ${date_from}
      AND t.transactiondate <= ${date_to}
      AND t.latitude BETWEEN 14.0 AND 15.0  -- NCR bounds
      AND t.longitude BETWEEN 120.5 AND 121.5
      {#store_filter}AND t.storeid = ${store_id}{/store_filter}
      {#category_filter}AND t.category = '${category}'{/category_filter}
      {#brand_filter}AND t.brand = '${brand}'{/brand_filter}
      {#payment_filter}AND t.payment_method = '${payment_method}'{/payment_filter}
      {#gender_filter}AND t.gender = '${gender}'{/gender_filter}
      {#age_filter}AND t.agebracket = '${agebracket}'{/age_filter}
    GROUP BY
    CASE WHEN DATEPART(hour, transactiondate) BETWEEN 6 AND 11 THEN 'Morning' WHEN DATEPART(hour, transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon' WHEN DATEPART(hour, transactiondate) BETWEEN 18 AND 21 THEN 'Evening' ELSE 'Night' END,
    category,
    storename,
    CONCAT(storename, ' (', municipalityname, ')')
    HAVING COUNT(*) >= 1  -- Minimum transaction threshold
),
dimensional_metrics AS (
    SELECT *,
        -- Ranking metrics
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        ROW_NUMBER() OVER (ORDER BY transaction_count DESC) AS volume_rank,
        ROW_NUMBER() OVER (ORDER BY avg_transaction_value DESC) AS value_rank,

        -- Share metrics
        ROUND(100.0 * total_revenue / SUM(total_revenue) OVER (), 2) AS revenue_share_pct,
        ROUND(100.0 * transaction_count / SUM(transaction_count) OVER (), 2) AS volume_share_pct,

        -- Performance metrics
        ROUND(total_revenue / active_days, 2) AS daily_avg_revenue,
        ROUND(transaction_count / active_days, 2) AS daily_avg_transactions,

        -- Efficiency metrics
        CASE
            WHEN avg_transaction_value > AVG(avg_transaction_value) OVER () THEN 'Above Average'
            WHEN avg_transaction_value < AVG(avg_transaction_value) OVER () THEN 'Below Average'
            ELSE 'Average'
        END AS value_tier
    FROM dimensional_base
),
dimensional_insights AS (
    SELECT *,
        -- Trend indicators
        CASE
            WHEN revenue_rank <= CEILING(COUNT(*) OVER () * 0.2) THEN 'Top 20%'
            WHEN revenue_rank <= CEILING(COUNT(*) OVER () * 0.5) THEN 'Top 50%'
            ELSE 'Bottom 50%'
        END AS performance_tier,

        -- Concentration analysis
        LAG(revenue_share_pct) OVER (ORDER BY revenue_rank) AS prev_revenue_share,
        LEAD(revenue_share_pct) OVER (ORDER BY revenue_rank) AS next_revenue_share

    FROM dimensional_metrics
)
SELECT
    -- Dimension columns
    CASE WHEN DATEPART(hour, transactiondate) BETWEEN 6 AND 11 THEN 'Morning' WHEN DATEPART(hour, transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon' WHEN DATEPART(hour, transactiondate) BETWEEN 18 AND 21 THEN 'Evening' ELSE 'Night' END AS time_daypart,
    category AS category,
    storename AS store,
    CONCAT(storename, ' (', municipalityname, ')') AS store_location,

    -- Core metrics
    transaction_count,
    total_revenue,
    avg_transaction_value,
    unique_products,
    active_days,

    -- Performance indicators
    revenue_rank,
    volume_rank,
    value_rank,
    revenue_share_pct,
    volume_share_pct,

    -- Business insights
    performance_tier,
    value_tier,
    daily_avg_revenue,
    daily_avg_transactions,

    -- Statistical measures
    price_stddev,
    first_transaction,
    last_transaction

FROM dimensional_insights
ORDER BY total_revenue DESC, time_daypart, category, store, store_location
LIMIT ${limit:=100};


-- Validation Rules:
-- 1. Date range should not exceed 1 year for performance
-- 2. Results are limited to NCR geographic bounds
-- 3. Minimum 1 transaction required per combination
-- 4. All monetary values in Philippine Pesos (₱)
-- 5. Time-based analysis may show patterns across different time zones