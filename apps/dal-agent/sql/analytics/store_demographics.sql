-- Store Demographics Analytics
-- Comprehensive store profiling with enhanced conversation intelligence
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: OVERALL STORE PROFILES
-- =====================================================

-- Store profiles with transaction counts and revenue metrics
WITH store_metrics AS (
    SELECT
        s.store_id,
        s.store_name,
        s.region,

        -- Basic transaction metrics
        COUNT(DISTINCT t.transaction_id) as total_transactions,
        COUNT(DISTINCT t.canonical_tx_id) as unique_customers,
        SUM(t.transaction_value) as total_revenue,
        AVG(t.transaction_value) as avg_transaction_value,
        AVG(t.basket_size) as avg_basket_size,

        -- Customer demographics breakdown
        COUNT(CASE WHEN t.demographics_gender = 'Male' THEN 1 END) as male_transactions,
        COUNT(CASE WHEN t.demographics_gender = 'Female' THEN 1 END) as female_transactions,

        -- Age distribution
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 18 AND 25 THEN 1 END) as age_18_25,
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 26 AND 35 THEN 1 END) as age_26_35,
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 36 AND 45 THEN 1 END) as age_36_45,
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 46 AND 60 THEN 1 END) as age_46_60,
        COUNT(CASE WHEN TRY_CAST(t.demographics_age AS INT) > 60 THEN 1 END) as age_60_plus,

        -- Purchase funnel metrics (if enhanced tables exist)
        COUNT(CASE WHEN f.stage_1_store_visit = 1 THEN 1 END) as store_visits,
        COUNT(CASE WHEN f.stage_2_browse = 1 THEN 1 END) as browse_events,
        COUNT(CASE WHEN f.stage_3_brand_request = 1 THEN 1 END) as brand_requests,
        COUNT(CASE WHEN f.stage_4_suggestion_accepted = 1 THEN 1 END) as suggestions_accepted,
        COUNT(CASE WHEN f.stage_5_purchase_completed = 1 THEN 1 END) as completed_purchases,

        -- Conversion metrics
        CAST(COUNT(CASE WHEN f.stage_5_purchase_completed = 1 THEN 1 END) * 100.0 /
             NULLIF(COUNT(CASE WHEN f.stage_1_store_visit = 1 THEN 1 END), 0) AS DECIMAL(5,2)) as conversion_rate,

        -- Temporal patterns
        COUNT(CASE WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 1 END) as morning_transactions,
        COUNT(CASE WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 1 END) as afternoon_transactions,
        COUNT(CASE WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 23 THEN 1 END) as evening_transactions,

        -- Payment method distribution (if available)
        COUNT(CASE WHEN t.payment_method = 'cash' THEN 1 END) as cash_transactions,
        COUNT(CASE WHEN t.payment_method = 'gcash' THEN 1 END) as gcash_transactions,
        COUNT(CASE WHEN t.payment_method = 'card' THEN 1 END) as card_transactions

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dim.stores s ON t.store_id = s.store_id
        LEFT JOIN dbo.purchase_funnel_tracking f ON t.transaction_id = f.transaction_id
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY s.store_id, s.store_name, s.region
),

-- =====================================================
-- SECTION 2: PURCHASE DEMOGRAPHICS PROFILE
-- =====================================================

purchase_demographics AS (
    SELECT
        COALESCE(t.payment_method, 'Unknown') AS payment_method,
        CASE
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS daypart,
        COALESCE(s.region, 'Unknown') AS region,
        t.demographics_gender,

        -- Age grouping
        CASE
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 18 AND 25 THEN '18-25'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 26 AND 35 THEN '26-35'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 36 AND 45 THEN '36-45'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 46 AND 60 THEN '46-60'
            WHEN TRY_CAST(t.demographics_age AS INT) > 60 THEN '60+'
            ELSE 'Unknown'
        END AS age_group,

        COUNT(*) AS transactions,
        CAST(AVG(t.transaction_value) AS DECIMAL(18,2)) AS avg_amount,
        SUM(t.transaction_value) AS total_amount,
        AVG(t.basket_size) AS avg_basket_size

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dim.stores s ON t.store_id = s.store_id
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY t.payment_method, daypart, s.region, t.demographics_gender, age_group
),

-- =====================================================
-- SECTION 3: SALES SPREAD ANALYSIS
-- =====================================================

sales_by_week AS (
    SELECT
        YEAR(t.transaction_date) AS year,
        DATEPART(ISO_WEEK, t.transaction_date) AS iso_week,
        CONCAT(YEAR(t.transaction_date), '-W',
               FORMAT(DATEPART(ISO_WEEK, t.transaction_date), '00')) AS week_label,

        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.transaction_value) AS total_revenue,
        COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,
        AVG(t.transaction_value) AS avg_transaction_value,

        -- Category breakdown
        COUNT(CASE WHEN t.category = 'Tobacco Products' THEN 1 END) AS tobacco_transactions,
        COUNT(CASE WHEN t.category = 'Beverages' THEN 1 END) AS beverage_transactions,
        COUNT(CASE WHEN t.category = 'Snacks & Confectionery' THEN 1 END) AS snacks_transactions,
        COUNT(CASE WHEN t.category = 'Personal Care' THEN 1 END) AS personal_care_transactions,
        COUNT(CASE WHEN t.category = 'Laundry' THEN 1 END) AS laundry_transactions

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY YEAR(t.transaction_date), DATEPART(ISO_WEEK, t.transaction_date)
),

sales_by_month AS (
    SELECT
        YEAR(t.transaction_date) AS year,
        MONTH(t.transaction_date) AS month,
        DATENAME(MONTH, t.transaction_date) AS month_name,

        -- Pecha de peligro analysis (salary period)
        CASE
            WHEN DAY(t.transaction_date) BETWEEN 23 AND 30 THEN 'Pecha de Peligro (23-30)'
            WHEN DAY(t.transaction_date) BETWEEN 1 AND 7 THEN 'Start of Month (1-7)'
            WHEN DAY(t.transaction_date) BETWEEN 8 AND 15 THEN 'Mid Month Early (8-15)'
            ELSE 'Mid Month Late (16-22)'
        END AS salary_period,

        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.transaction_value) AS total_revenue,
        COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,
        AVG(t.transaction_value) AS avg_transaction_value

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY YEAR(t.transaction_date), MONTH(t.transaction_date), DATENAME(MONTH, t.transaction_date), salary_period
),

-- =====================================================
-- SECTION 4: DAYPART ANALYSIS BY CATEGORY
-- =====================================================

sales_by_daypart_category AS (
    SELECT
        t.category,
        CASE
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 'Morning (6-11)'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 23 THEN 'Evening (18-23)'
            ELSE 'Night (0-5, 24)'
        END AS daypart,

        DATEPART(HOUR, t.transaction_datetime) AS hour_of_day,
        DATENAME(WEEKDAY, t.transaction_date) AS day_of_week,

        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.transaction_value) AS total_revenue,
        AVG(t.transaction_value) AS avg_transaction_value,
        COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,

        -- Calculate percentage within each category
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY t.category) AS DECIMAL(5,2)) AS pct_within_category

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t.category IS NOT NULL
    GROUP BY t.category, daypart, DATEPART(HOUR, t.transaction_datetime), DATENAME(WEEKDAY, t.transaction_date)
)

-- =====================================================
-- SECTION 5: EXPORT QUERIES
-- =====================================================

-- Export 1: Store Profiles
SELECT
    'Store Profiles' AS export_type,
    store_id,
    store_name,
    region,
    total_transactions,
    unique_customers,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,
    CAST(avg_basket_size AS DECIMAL(8,2)) AS avg_basket_size,

    -- Demographics percentages
    CAST(male_transactions * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS male_pct,
    CAST(female_transactions * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS female_pct,

    -- Age distribution percentages
    CAST(age_18_25 * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS age_18_25_pct,
    CAST(age_26_35 * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS age_26_35_pct,
    CAST(age_36_45 * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS age_36_45_pct,
    CAST(age_46_60 * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS age_46_60_pct,
    CAST(age_60_plus * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS age_60_plus_pct,

    -- Conversion metrics
    conversion_rate,

    -- Temporal distribution
    CAST(morning_transactions * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS morning_pct,
    CAST(afternoon_transactions * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS afternoon_pct,
    CAST(evening_transactions * 100.0 / NULLIF(total_transactions, 0) AS DECIMAL(5,2)) AS evening_pct

FROM store_metrics
ORDER BY total_revenue DESC;

-- Export 2: Purchase Demographics
SELECT
    'Purchase Demographics' AS export_type,
    payment_method,
    daypart,
    region,
    demographics_gender,
    age_group,
    transactions,
    avg_amount,
    total_amount,
    avg_basket_size,
    CAST(transactions * 100.0 / SUM(transactions) OVER() AS DECIMAL(5,2)) AS share_pct
FROM purchase_demographics
ORDER BY transactions DESC;

-- Export 3: Sales by Week
SELECT
    'Sales by Week' AS export_type,
    year,
    iso_week,
    week_label,
    transactions,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    unique_customers,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,
    tobacco_transactions,
    beverage_transactions,
    snacks_transactions,
    personal_care_transactions,
    laundry_transactions
FROM sales_by_week
ORDER BY year, iso_week;

-- Export 4: Sales by Month with Pecha de Peligro
SELECT
    'Sales by Month' AS export_type,
    year,
    month,
    month_name,
    salary_period,
    transactions,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    unique_customers,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,
    CAST(transactions * 100.0 / SUM(transactions) OVER(PARTITION BY year, month) AS DECIMAL(5,2)) AS pct_within_month
FROM sales_by_month
ORDER BY year, month, salary_period;

-- Export 5: Sales by Daypart and Category
SELECT
    'Sales by Daypart Category' AS export_type,
    category,
    daypart,
    hour_of_day,
    day_of_week,
    transactions,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,
    unique_customers,
    pct_within_category
FROM sales_by_daypart_category
ORDER BY category, hour_of_day;

PRINT 'Store demographics analytics completed successfully';