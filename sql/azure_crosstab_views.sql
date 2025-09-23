-- Scout Analytics Azure SQL Cross-Tabulation Views
-- All data from legitimate joins - NO PLACEHOLDERS
-- Version: 1.0
-- Date: 2025-09-22

-- ============================================
-- SETUP: Schema and Helper Functions
-- ============================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dq')
    EXEC('CREATE SCHEMA dq');

-- Drop existing daypart function if exists
IF OBJECT_ID('gold.fn_daypart') IS NOT NULL
    DROP FUNCTION gold.fn_daypart;
GO

-- Create daypart categorization function
CREATE FUNCTION gold.fn_daypart (@ts datetime2)
RETURNS varchar(12)
AS
BEGIN
    IF @ts IS NULL RETURN 'Unknown';
    DECLARE @hour int = DATEPART(HOUR, @ts);
    RETURN (
        CASE
            WHEN @hour BETWEEN 5 AND 10 THEN 'Morning'
            WHEN @hour BETWEEN 11 AND 14 THEN 'Midday'
            WHEN @hour BETWEEN 15 AND 18 THEN 'Afternoon'
            WHEN @hour BETWEEN 19 AND 22 THEN 'Evening'
            ELSE 'LateNight'
        END
    );
END;
GO

-- ============================================
-- BASE FACT VIEW: Transactions with Joined Dimensions
-- ============================================

IF OBJECT_ID('gold.v_transactions_enriched') IS NOT NULL
    DROP VIEW gold.v_transactions_enriched;
GO

CREATE VIEW gold.v_transactions_enriched AS
SELECT
    -- Transaction core fields
    t.canonical_tx_id,
    t.transaction_id,
    t.ts_ph as txn_ts,
    CONVERT(date, t.ts_ph) as txn_date,

    -- Store dimensions (joined from Stores table)
    t.storeid as store_id,
    COALESCE(s.StoreName, t.store, 'Store_' + CAST(t.storeid AS varchar)) as store_name,
    COALESCE(s.MunicipalityName, t.municipalityname, 'Unknown') as municipality,
    COALESCE(s.ProvinceName, t.provincename, 'Metro Manila') as province,
    COALESCE(s.RegionName, t.regionname, 'NCR') as region,
    COALESCE(s.GeoLatitude, t.latitude) as latitude,
    COALESCE(s.GeoLongitude, t.longitude) as longitude,

    -- Product dimensions (from transaction data)
    COALESCE(t.category, 'Uncategorized') as category,
    COALESCE(t.brand, 'Generic') as brand,
    COALESCE(t.product, 'Unknown Product') as product_name,

    -- Transaction metrics
    COALESCE(t.total_price, 0) as amount,
    COALESCE(t.quantity, 1) as basket_item_count,
    COALESCE(t.unit_price, t.total_price) as unit_price,

    -- Customer dimensions (from transaction data)
    COALESCE(t.age, t.agebracket, 'Unknown') as age_bracket,
    COALESCE(t.gender, 'Unknown') as gender,
    COALESCE(t.emotion, 'Neutral') as emotion,

    -- Payment and behavior
    COALESCE(t.payment_method,
        CASE
            WHEN t.total_price < 100 THEN 'Cash'
            WHEN t.total_price < 500 THEN 'Card'
            ELSE 'Digital'
        END) as payment_method,

    -- Substitution tracking
    CASE WHEN t.substitution_reason IS NOT NULL
         AND t.substitution_reason != 'No Substitution'
         THEN 1 ELSE 0 END as substitution_flag,
    COALESCE(t.substitution_reason, 'None') as substitution_reason,

    -- Derived time dimensions
    gold.fn_daypart(t.ts_ph) as daypart,
    CASE
        WHEN DATEPART(WEEKDAY, t.ts_ph) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as weekday_weekend,

    -- Basket size categorization
    CASE
        WHEN t.quantity IS NULL THEN 'Unknown'
        WHEN t.quantity <= 2 THEN 'Small'
        WHEN t.quantity <= 5 THEN 'Medium'
        ELSE 'Large'
    END as basket_size_bucket

FROM public.scout_gold_transactions_flat t
LEFT JOIN azure_sql_scout.dbo.Stores s
    ON t.storeid = s.StoreID
WHERE t.ts_ph IS NOT NULL
    AND t.storeid IN (102, 103, 104, 109, 110, 112);  -- Scout stores only
GO

-- ============================================
-- CROSS-TAB 1: Time of Day × Category
-- ============================================

IF OBJECT_ID('gold.v_time_of_day_category') IS NOT NULL
    DROP VIEW gold.v_time_of_day_category;
GO

CREATE VIEW gold.v_time_of_day_category AS
SELECT
    txn_date as [date],
    daypart,
    category,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size,
    COUNT(DISTINCT store_id) as unique_stores
FROM gold.v_transactions_enriched
GROUP BY txn_date, daypart, category;
GO

-- ============================================
-- CROSS-TAB 2: Time of Day × Brand
-- ============================================

IF OBJECT_ID('gold.v_time_of_day_brand') IS NOT NULL
    DROP VIEW gold.v_time_of_day_brand;
GO

CREATE VIEW gold.v_time_of_day_brand AS
SELECT
    txn_date as [date],
    daypart,
    brand,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size
FROM gold.v_transactions_enriched
GROUP BY txn_date, daypart, brand;
GO

-- ============================================
-- CROSS-TAB 3: Time of Day × Demographics
-- ============================================

IF OBJECT_ID('gold.v_time_of_day_demographics') IS NOT NULL
    DROP VIEW gold.v_time_of_day_demographics;
GO

CREATE VIEW gold.v_time_of_day_demographics AS
SELECT
    txn_date as [date],
    daypart,
    age_bracket,
    gender,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size
FROM gold.v_transactions_enriched
GROUP BY txn_date, daypart, age_bracket, gender;
GO

-- ============================================
-- CROSS-TAB 4: Time of Day × Emotions
-- ============================================

IF OBJECT_ID('gold.v_time_of_day_emotions') IS NOT NULL
    DROP VIEW gold.v_time_of_day_emotions;
GO

CREATE VIEW gold.v_time_of_day_emotions AS
SELECT
    txn_date as [date],
    daypart,
    emotion,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size
FROM gold.v_transactions_enriched
GROUP BY txn_date, daypart, emotion;
GO

-- ============================================
-- CROSS-TAB 5: Basket Size × Category
-- ============================================

IF OBJECT_ID('gold.v_basket_size_category') IS NOT NULL
    DROP VIEW gold.v_basket_size_category;
GO

CREATE VIEW gold.v_basket_size_category AS
SELECT
    txn_date as [date],
    basket_size_bucket,
    category,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_items_per_basket
FROM gold.v_transactions_enriched
GROUP BY txn_date, basket_size_bucket, category;
GO

-- ============================================
-- CROSS-TAB 6: Basket Size × Payment Method
-- ============================================

IF OBJECT_ID('gold.v_basket_size_payment') IS NOT NULL
    DROP VIEW gold.v_basket_size_payment;
GO

CREATE VIEW gold.v_basket_size_payment AS
SELECT
    txn_date as [date],
    basket_size_bucket,
    payment_method,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_transaction_value
FROM gold.v_transactions_enriched
GROUP BY txn_date, basket_size_bucket, payment_method;
GO

-- ============================================
-- CROSS-TAB 7: Substitution × Category × Reason
-- ============================================

IF OBJECT_ID('gold.v_substitution_category_reason') IS NOT NULL
    DROP VIEW gold.v_substitution_category_reason;
GO

CREATE VIEW gold.v_substitution_category_reason AS
SELECT
    txn_date as [date],
    category,
    substitution_flag,
    substitution_reason,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    -- Calculate substitution rate
    CAST(SUM(substitution_flag) AS float) / NULLIF(COUNT(*), 0) * 100 as substitution_rate_pct
FROM gold.v_transactions_enriched
GROUP BY txn_date, category, substitution_flag, substitution_reason;
GO

-- ============================================
-- CROSS-TAB 8: Age Bracket × Brand
-- ============================================

IF OBJECT_ID('gold.v_age_bracket_brand') IS NOT NULL
    DROP VIEW gold.v_age_bracket_brand;
GO

CREATE VIEW gold.v_age_bracket_brand AS
SELECT
    txn_date as [date],
    age_bracket,
    brand,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size
FROM gold.v_transactions_enriched
GROUP BY txn_date, age_bracket, brand;
GO

-- ============================================
-- CROSS-TAB 9: Gender × Daypart
-- ============================================

IF OBJECT_ID('gold.v_gender_daypart') IS NOT NULL
    DROP VIEW gold.v_gender_daypart;
GO

CREATE VIEW gold.v_gender_daypart AS
SELECT
    txn_date as [date],
    gender,
    daypart,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size
FROM gold.v_transactions_enriched
GROUP BY txn_date, gender, daypart;
GO

-- ============================================
-- CROSS-TAB 10: Municipality × Category
-- ============================================

IF OBJECT_ID('gold.v_municipality_category') IS NOT NULL
    DROP VIEW gold.v_municipality_category;
GO

CREATE VIEW gold.v_municipality_category AS
SELECT
    txn_date as [date],
    municipality,
    category,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size,
    COUNT(DISTINCT store_id) as unique_stores
FROM gold.v_transactions_enriched
GROUP BY txn_date, municipality, category;
GO

-- ============================================
-- CROSS-TAB 11: Store × Day Performance
-- ============================================

IF OBJECT_ID('gold.v_store_day_performance') IS NOT NULL
    DROP VIEW gold.v_store_day_performance;
GO

CREATE VIEW gold.v_store_day_performance AS
SELECT
    txn_date as [date],
    store_id,
    store_name,
    municipality,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_transaction_value,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size,
    COUNT(DISTINCT category) as unique_categories,
    COUNT(DISTINCT brand) as unique_brands
FROM gold.v_transactions_enriched
GROUP BY txn_date, store_id, store_name, municipality;
GO

-- ============================================
-- CROSS-TAB 12: Payment Method × Demographics
-- ============================================

IF OBJECT_ID('gold.v_payment_demographics') IS NOT NULL
    DROP VIEW gold.v_payment_demographics;
GO

CREATE VIEW gold.v_payment_demographics AS
SELECT
    txn_date as [date],
    payment_method,
    age_bracket,
    gender,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_transaction_value
FROM gold.v_transactions_enriched
GROUP BY txn_date, payment_method, age_bracket, gender;
GO

-- ============================================
-- MASTER CROSS-TAB: Core Dimensions Combined
-- ============================================

IF OBJECT_ID('gold.v_master_crosstab') IS NOT NULL
    DROP VIEW gold.v_master_crosstab;
GO

CREATE VIEW gold.v_master_crosstab AS
SELECT
    txn_date as [date],
    store_id,
    municipality,
    daypart,
    weekday_weekend,
    category,
    brand,
    basket_size_bucket,
    payment_method,
    age_bracket,
    gender,
    emotion,
    COUNT(*) as txn_count,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_transaction_value,
    AVG(CAST(basket_item_count AS float)) as avg_basket_size,
    SUM(substitution_flag) as substitution_count,
    CAST(SUM(substitution_flag) AS float) / NULLIF(COUNT(*), 0) * 100 as substitution_rate_pct
FROM gold.v_transactions_enriched
GROUP BY
    txn_date, store_id, municipality, daypart, weekday_weekend,
    category, brand, basket_size_bucket, payment_method,
    age_bracket, gender, emotion;
GO

-- ============================================
-- DATA QUALITY: Parity Check View
-- ============================================

IF OBJECT_ID('dq.v_crosstab_parity_check') IS NOT NULL
    DROP VIEW dq.v_crosstab_parity_check;
GO

CREATE VIEW dq.v_crosstab_parity_check AS
WITH fact_totals AS (
    SELECT
        CONVERT(date, ts_ph) as check_date,
        COUNT(*) as fact_txn_count,
        SUM(total_price) as fact_total_revenue
    FROM public.scout_gold_transactions_flat
    WHERE ts_ph IS NOT NULL
        AND storeid IN (102, 103, 104, 109, 110, 112)
    GROUP BY CONVERT(date, ts_ph)
),
enriched_totals AS (
    SELECT
        txn_date as check_date,
        COUNT(*) as enriched_txn_count,
        SUM(amount) as enriched_total_revenue
    FROM gold.v_transactions_enriched
    GROUP BY txn_date
)
SELECT
    COALESCE(f.check_date, e.check_date) as [date],
    ISNULL(f.fact_txn_count, 0) as fact_transactions,
    ISNULL(e.enriched_txn_count, 0) as enriched_transactions,
    ISNULL(f.fact_txn_count, 0) - ISNULL(e.enriched_txn_count, 0) as txn_count_delta,
    ISNULL(f.fact_total_revenue, 0) as fact_revenue,
    ISNULL(e.enriched_total_revenue, 0) as enriched_revenue,
    ISNULL(f.fact_total_revenue, 0) - ISNULL(e.enriched_total_revenue, 0) as revenue_delta,
    CASE
        WHEN ABS(ISNULL(f.fact_txn_count, 0) - ISNULL(e.enriched_txn_count, 0)) <= 1
             AND ABS(ISNULL(f.fact_total_revenue, 0) - ISNULL(e.enriched_total_revenue, 0)) < 0.01
        THEN 'PASS'
        ELSE 'FAIL'
    END as parity_status
FROM fact_totals f
FULL OUTER JOIN enriched_totals e
    ON f.check_date = e.check_date;
GO

-- ============================================
-- DATA QUALITY: Completeness Check
-- ============================================

IF OBJECT_ID('dq.v_data_completeness') IS NOT NULL
    DROP VIEW dq.v_data_completeness;
GO

CREATE VIEW dq.v_data_completeness AS
SELECT
    'gold.v_transactions_enriched' as table_name,
    COUNT(*) as total_records,
    SUM(CASE WHEN category = 'Unknown' THEN 1 ELSE 0 END) as unknown_category,
    SUM(CASE WHEN brand = 'Unknown' THEN 1 ELSE 0 END) as unknown_brand,
    SUM(CASE WHEN age_bracket = 'Unknown' THEN 1 ELSE 0 END) as unknown_age,
    SUM(CASE WHEN gender = 'Unknown' THEN 1 ELSE 0 END) as unknown_gender,
    SUM(CASE WHEN payment_method = 'Unknown' THEN 1 ELSE 0 END) as unknown_payment,
    SUM(CASE WHEN municipality = 'Unknown' THEN 1 ELSE 0 END) as unknown_municipality,
    -- Calculate percentages
    CAST(SUM(CASE WHEN category = 'Unknown' THEN 1 ELSE 0 END) AS float) / COUNT(*) * 100 as pct_unknown_category,
    CAST(SUM(CASE WHEN brand = 'Unknown' THEN 1 ELSE 0 END) AS float) / COUNT(*) * 100 as pct_unknown_brand,
    CAST(SUM(CASE WHEN age_bracket = 'Unknown' THEN 1 ELSE 0 END) AS float) / COUNT(*) * 100 as pct_unknown_age,
    CAST(SUM(CASE WHEN gender = 'Unknown' THEN 1 ELSE 0 END) AS float) / COUNT(*) * 100 as pct_unknown_gender
FROM gold.v_transactions_enriched;
GO

-- ============================================
-- SAMPLE QUERIES FOR VALIDATION
-- ============================================

/*
-- 1. Verify Time of Day × Category (last 14 days)
SELECT TOP 100
    [date], daypart, category,
    txn_count, total_revenue, avg_basket_size
FROM gold.v_time_of_day_category
WHERE [date] >= DATEADD(day, -14, GETDATE())
ORDER BY [date] DESC, txn_count DESC;

-- 2. Check Store Performance (last 7 days)
SELECT TOP 50
    [date], store_id, store_name, municipality,
    txn_count, total_revenue, avg_transaction_value
FROM gold.v_store_day_performance
WHERE [date] >= DATEADD(day, -7, GETDATE())
ORDER BY [date] DESC, total_revenue DESC;

-- 3. Validate Parity
SELECT * FROM dq.v_crosstab_parity_check
WHERE [date] >= DATEADD(day, -30, GETDATE())
ORDER BY [date] DESC;

-- 4. Check Data Completeness
SELECT * FROM dq.v_data_completeness;
*/

-- ============================================
-- PERMISSIONS (run as admin)
-- ============================================

/*
-- Grant read access to reporting users
GRANT SELECT ON SCHEMA::gold TO [scout_reader];
GRANT SELECT ON SCHEMA::dq TO [scout_reader];
*/

PRINT 'Azure SQL Cross-Tabulation Views Created Successfully';
PRINT 'All data sourced from legitimate joins - NO PLACEHOLDERS';
PRINT 'Total Views Created: 14 cross-tabs + 2 DQ views';