-- Tobacco Category Analytics
-- Comprehensive tobacco analysis with conversation intelligence and purchase patterns
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: TOBACCO DEMOGRAPHICS ANALYSIS
-- =====================================================

WITH tobacco_demographics AS (
    SELECT
        -- Demographics
        t.demographics_gender AS gender,
        CASE
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 18 AND 25 THEN '18-25'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 26 AND 35 THEN '26-35'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 36 AND 45 THEN '36-45'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 46 AND 60 THEN '46-60'
            WHEN TRY_CAST(t.demographics_age AS INT) > 60 THEN '60+'
            ELSE 'Unknown'
        END AS age_band,
        t.brand,

        -- Location
        s.region,
        s.store_name,

        -- Metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.quantity) AS total_sticks,
        CAST(AVG(t.quantity) AS DECIMAL(8,2)) AS avg_sticks_per_visit,
        SUM(t.transaction_value) AS total_value,
        CAST(AVG(t.transaction_value) AS DECIMAL(10,2)) AS avg_transaction_value,

        -- Brand confidence from AI detection
        CAST(AVG(CAST(t.brand_confidence AS FLOAT)) AS DECIMAL(5,3)) AS avg_brand_confidence

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dim.stores s ON t.store_id = s.store_id
    WHERE t.category = 'Tobacco Products'
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY t.demographics_gender, age_band, t.brand, s.region, s.store_name
),

-- =====================================================
-- SECTION 2: PURCHASE PROFILE PATTERNS
-- =====================================================

tobacco_purchase_patterns AS (
    SELECT
        t.brand,

        -- Time patterns
        DATEPART(HOUR, t.transaction_datetime) AS hour_of_day,
        CASE
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS daypart,

        DATENAME(WEEKDAY, t.transaction_date) AS day_of_week,
        DATEPART(WEEKDAY, t.transaction_date) AS day_of_week_num,

        -- Pecha de peligro analysis (salary period impact)
        CASE
            WHEN DAY(t.transaction_date) BETWEEN 23 AND 30 THEN 'Pecha de Peligro (23-30)'
            WHEN DAY(t.transaction_date) BETWEEN 1 AND 7 THEN 'Start of Month (1-7)'
            WHEN DAY(t.transaction_date) BETWEEN 8 AND 15 THEN 'Mid Month Early (8-15)'
            ELSE 'Mid Month Late (16-22)'
        END AS salary_period,

        -- Month patterns (seasonal analysis)
        MONTH(t.transaction_date) AS month_number,
        DATENAME(MONTH, t.transaction_date) AS month_name,

        -- Demographics
        t.demographics_gender,
        t.demographics_age,

        -- Metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.quantity) AS total_sticks,
        CAST(AVG(t.quantity) AS DECIMAL(8,2)) AS avg_sticks_per_transaction,
        SUM(t.transaction_value) AS total_revenue,
        CAST(AVG(t.transaction_value) AS DECIMAL(10,2)) AS avg_revenue_per_transaction

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.category = 'Tobacco Products'
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY t.brand, hour_of_day, daypart, day_of_week, day_of_week_num,
             salary_period, month_number, month_name, t.demographics_gender, t.demographics_age
),

-- =====================================================
-- SECTION 3: TOBACCO CO-PURCHASE ANALYSIS
-- =====================================================

tobacco_copurchase AS (
    SELECT
        t1.brand AS tobacco_brand,
        t2.category AS copurchase_category,
        t2.brand AS copurchase_brand,
        t2.product_name AS copurchase_product,

        COUNT(DISTINCT t1.transaction_id) AS co_occurrence_count,
        COUNT(DISTINCT t1.canonical_tx_id) AS unique_customers,

        -- Calculate lift (how much more likely items are bought together)
        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id) FROM canonical.v_transactions_flat_enhanced
             WHERE category = 'Tobacco Products'
               AND transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')) AS tobacco_support,

        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id) FROM canonical.v_transactions_flat_enhanced
             WHERE category = t2.category
               AND transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')) AS copurchase_support

    FROM canonical.v_transactions_flat_enhanced t1
        INNER JOIN canonical.v_transactions_flat_enhanced t2
            ON t1.transaction_id = t2.transaction_id
            AND t1.category = 'Tobacco Products'
            AND t2.category != 'Tobacco Products'
    WHERE t1.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY t1.brand, t2.category, t2.brand, t2.product_name
),

-- =====================================================
-- SECTION 4: FREQUENT TERMS ANALYSIS
-- =====================================================

tobacco_frequent_terms AS (
    SELECT
        value AS term,
        COUNT(*) AS frequency,
        STRING_AGG(DISTINCT t.brand, ', ') AS associated_brands,
        STRING_AGG(DISTINCT t.demographics_gender, ', ') AS user_genders,

        -- Calculate term confidence based on brand detection
        CAST(AVG(CAST(t.brand_confidence AS FLOAT)) AS DECIMAL(5,3)) AS avg_term_confidence

    FROM canonical.v_transactions_flat_enhanced t
        CROSS APPLY STRING_SPLIT(LOWER(COALESCE(t.transaction_context, '')), ' ')
    WHERE t.category = 'Tobacco Products'
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND LEN(value) > 2
        AND value NOT IN (
            'the', 'and', 'for', 'with', 'this', 'that', 'from', 'have', 'been',
            'they', 'were', 'said', 'each', 'what', 'will', 'when', 'your', 'how',
            'mga', 'ang', 'ng', 'sa', 'na', 'at', 'ay', 'ni', 'ka', 'pa', 'po'
        )
        AND value IS NOT NULL
        AND value != ''
    GROUP BY value
    HAVING COUNT(*) >= 3
),

-- =====================================================
-- SECTION 5: CONVERSATION INTELLIGENCE (IF AVAILABLE)
-- =====================================================

tobacco_conversation_analysis AS (
    SELECT
        t.brand,
        t.demographics_gender,
        t.demographics_age,

        -- Conversation metrics (from enhanced payload if available)
        COUNT(DISTINCT t.transaction_id) AS conversations,
        AVG(CAST(COALESCE(cs.duration_seconds, 0) AS FLOAT)) AS avg_conversation_duration,

        -- Intent patterns (if conversation segments exist)
        COUNT(CASE WHEN cs.intent_classification = 'brand_request' THEN 1 END) AS brand_requests,
        COUNT(CASE WHEN cs.intent_classification = 'price_inquiry' THEN 1 END) AS price_inquiries,
        COUNT(CASE WHEN cs.intent_classification = 'substitution_offered' THEN 1 END) AS substitution_offers,
        COUNT(CASE WHEN cs.intent_classification = 'purchase_completed' THEN 1 END) AS purchase_completions,

        -- Calculate conversation effectiveness
        CAST(COUNT(CASE WHEN cs.intent_classification = 'purchase_completed' THEN 1 END) * 100.0 /
             NULLIF(COUNT(CASE WHEN cs.intent_classification = 'brand_request' THEN 1 END), 0)
             AS DECIMAL(5,2)) AS request_to_purchase_rate

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dbo.conversation_segments cs ON t.transaction_id = cs.transaction_id
    WHERE t.category = 'Tobacco Products'
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY t.brand, t.demographics_gender, t.demographics_age
)

-- =====================================================
-- SECTION 6: EXPORT QUERIES
-- =====================================================

-- Export 1: Tobacco Demographics
SELECT
    'Tobacco Demographics' AS export_type,
    gender,
    age_band,
    brand,
    region,
    transactions,
    total_sticks,
    avg_sticks_per_visit,
    CAST(total_value AS DECIMAL(18,2)) AS total_value,
    avg_transaction_value,
    avg_brand_confidence,
    CAST(transactions * 100.0 / SUM(transactions) OVER(PARTITION BY gender, age_band) AS DECIMAL(5,2)) AS brand_share_within_demographic
FROM tobacco_demographics
ORDER BY gender, age_band, transactions DESC;

-- Export 2: Purchase Profile (Day, Time, Pecha de Peligro)
SELECT
    'Tobacco Purchase Profiles' AS export_type,
    brand,
    hour_of_day,
    daypart,
    day_of_week,
    salary_period,
    month_name,
    demographics_gender,
    transactions,
    total_sticks,
    avg_sticks_per_transaction,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    avg_revenue_per_transaction,

    -- Calculate percentage within each period type
    CAST(transactions * 100.0 / SUM(transactions) OVER(PARTITION BY salary_period) AS DECIMAL(5,2)) AS pct_within_salary_period,
    CAST(transactions * 100.0 / SUM(transactions) OVER(PARTITION BY daypart) AS DECIMAL(5,2)) AS pct_within_daypart

FROM tobacco_purchase_patterns
ORDER BY brand, hour_of_day;

-- Export 3: Sales × Days × Day Parting
SELECT
    'Tobacco Sales Daypart Analysis' AS export_type,
    brand,
    day_of_week,
    daypart,
    hour_of_day,
    COUNT(DISTINCT month_name) AS months_with_sales,
    SUM(transactions) AS total_transactions,
    SUM(total_sticks) AS total_sticks_sold,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS total_revenue,
    CAST(AVG(avg_sticks_per_transaction) AS DECIMAL(8,2)) AS overall_avg_sticks
FROM tobacco_purchase_patterns
GROUP BY brand, day_of_week, daypart, hour_of_day, day_of_week_num
ORDER BY brand, day_of_week_num, hour_of_day;

-- Export 4: Sticks Per Store Visit
SELECT
    'Tobacco Sticks Per Visit' AS export_type,
    brand,
    gender,
    age_band,
    store_name,
    region,
    transactions AS store_visits,
    total_sticks,
    avg_sticks_per_visit,
    CASE
        WHEN avg_sticks_per_visit >= 2 THEN 'Heavy Buyer (2+)'
        WHEN avg_sticks_per_visit >= 1.5 THEN 'Regular Buyer (1.5-2)'
        WHEN avg_sticks_per_visit >= 1 THEN 'Light Buyer (1-1.5)'
        ELSE 'Minimal Buyer (<1)'
    END AS buyer_category
FROM tobacco_demographics
ORDER BY avg_sticks_per_visit DESC;

-- Export 5: What is Purchased with Cigarettes
SELECT
    'Tobacco Co-Purchase Analysis' AS export_type,
    tobacco_brand,
    copurchase_category,
    copurchase_brand,
    copurchase_product,
    co_occurrence_count,
    unique_customers,
    CAST(tobacco_support * 100 AS DECIMAL(5,2)) AS tobacco_support_pct,
    CAST(copurchase_support * 100 AS DECIMAL(5,2)) AS copurchase_support_pct,

    -- Calculate lift (how much more likely items are bought together vs independently)
    CAST((tobacco_support / copurchase_support) AS DECIMAL(8,2)) AS lift_score,

    CASE
        WHEN (tobacco_support / copurchase_support) > 1.2 THEN 'Strong Association'
        WHEN (tobacco_support / copurchase_support) > 1.0 THEN 'Weak Association'
        ELSE 'No Association'
    END AS association_strength

FROM tobacco_copurchase
WHERE co_occurrence_count >= 3
ORDER BY co_occurrence_count DESC, tobacco_brand;

-- Export 6: Frequently Used Terms
SELECT
    'Tobacco Frequent Terms' AS export_type,
    term,
    frequency,
    associated_brands,
    user_genders,
    avg_term_confidence,
    CAST(frequency * 100.0 / SUM(frequency) OVER() AS DECIMAL(5,2)) AS term_share_pct
FROM tobacco_frequent_terms
ORDER BY frequency DESC;

-- Export 7: Conversation Intelligence (if data available)
SELECT
    'Tobacco Conversation Intelligence' AS export_type,
    brand,
    demographics_gender,
    demographics_age,
    conversations,
    CAST(avg_conversation_duration AS DECIMAL(8,2)) AS avg_conversation_seconds,
    brand_requests,
    price_inquiries,
    substitution_offers,
    purchase_completions,
    request_to_purchase_rate AS conversion_rate_pct
FROM tobacco_conversation_analysis
WHERE conversations > 0
ORDER BY conversations DESC;

PRINT 'Tobacco analytics completed successfully';