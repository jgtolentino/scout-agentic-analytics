-- =====================================================
-- Scout Lakehouse Warehouse Views (Lakehouse → Gold)
-- Connects Warehouse Gold views to Lakehouse Silver tables
-- =====================================================

-- NOTE: scout-lakehouse is the locked Lakehouse SQL endpoint name
-- If your what.go CLI supports tokenization, it will replace <LAKEHOUSE_SQL_NAME>
-- Otherwise, this is pre-tokenized to scout-lakehouse

PRINT 'Creating Gold layer views from Lakehouse Silver tables...';

-- =====================================================
-- DIMENSION VIEWS
-- =====================================================

-- Store dimension with geographical hierarchy
CREATE OR ALTER VIEW gold.dim_store AS
SELECT
    store_id,
    store_name,
    region_name,
    province_name,
    municipality_name,
    barangay_name,
    store_type,
    latitude,
    longitude,
    is_active,
    created_date
FROM [scout-lakehouse].dbo.silver_dim_store;

-- Brand dimension with Nielsen category mappings
CREATE OR ALTER VIEW gold.dim_brand AS
SELECT
    brand_id,
    brand_name,
    brand_category,
    nielsen_l1_category,
    nielsen_l2_category,
    nielsen_l3_category,
    is_premium,
    market_segment,
    is_tobacco,
    is_laundry,
    created_date
FROM [scout-lakehouse].dbo.silver_dim_brand;

-- Category dimension with hierarchy
CREATE OR ALTER VIEW gold.dim_category AS
SELECT
    category_id,
    category_name,
    parent_category_id,
    category_level,
    nielsen_mapping,
    is_tobacco,
    is_laundry,
    created_date
FROM [scout-lakehouse].dbo.silver_dim_category;

-- Date dimension with business calendar
CREATE OR ALTER VIEW gold.dim_date AS
SELECT
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend,
    is_holiday,
    fiscal_year,
    fiscal_quarter,
    fiscal_month
FROM [scout-lakehouse].dbo.silver_dim_date;

-- Time dimension with business periods
CREATE OR ALTER VIEW gold.dim_time AS
SELECT
    time_key,
    hour_24,
    minute,
    time_of_day_category,
    business_time_period,
    is_business_hours,
    shift_category
FROM [scout-lakehouse].dbo.silver_dim_time;

-- =====================================================
-- FACT VIEWS
-- =====================================================

-- Core transaction fact table
CREATE OR ALTER VIEW gold.fact_transactions AS
SELECT
    canonical_tx_id,
    interaction_id,
    store_id,
    customer_id AS facial_id,
    transaction_date,        -- SINGLE authoritative date source
    transaction_time,
    date_key,
    time_key,
    transaction_value,
    basket_size,
    customer_age,
    customer_gender,
    device_id,
    was_substitution,
    conversation_score,
    emotional_state,
    transcript_text,
    hour_24,
    weekday_vs_weekend,
    time_of_day_category,
    business_time_period,
    persona_assigned,
    persona_confidence,
    created_ts
FROM [scout-lakehouse].dbo.silver_transactions;

-- Transaction items fact table (SKU level)
CREATE OR ALTER VIEW gold.fact_transaction_items AS
SELECT
    canonical_tx_id,
    item_sequence,
    sku,
    item_brand,
    item_category,
    item_qty,
    item_unit_price,
    item_total,
    nielsen_l1,
    nielsen_l2,
    nielsen_l3,
    is_substitution,
    original_sku,
    substitution_reason
FROM [scout-lakehouse].dbo.silver_transaction_items;

-- =====================================================
-- ANALYTICS MART VIEWS
-- =====================================================

-- Comprehensive transaction mart for Power BI
CREATE OR ALTER VIEW gold.mart_transactions AS
SELECT
    t.canonical_tx_id,
    t.store_id,
    t.facial_id,
    t.transaction_date,               -- SINGLE authoritative date
    t.transaction_value,
    t.basket_size,
    t.customer_age,
    t.customer_gender,
    t.emotional_state,
    t.conversation_score,
    t.hour_24,
    t.weekday_vs_weekend,
    t.time_of_day_category,
    t.business_time_period,
    t.persona_assigned,
    -- Store attributes
    s.store_name,
    s.region_name,
    s.province_name,
    s.municipality_name,
    s.barangay_name,
    s.store_type,
    s.latitude,
    s.longitude,
    -- Derived metrics
    CASE
        WHEN t.transaction_value >= 1000 THEN 'High'
        WHEN t.transaction_value >= 500 THEN 'Medium'
        ELSE 'Low'
    END AS transaction_value_category,
    CASE
        WHEN t.basket_size >= 5 THEN 'Large'
        WHEN t.basket_size >= 3 THEN 'Medium'
        ELSE 'Small'
    END AS basket_size_category,
    CASE
        WHEN t.customer_age < 25 THEN 'Young'
        WHEN t.customer_age < 40 THEN 'Adult'
        WHEN t.customer_age < 60 THEN 'Middle-aged'
        ELSE 'Senior'
    END AS age_group
FROM [scout-lakehouse].dbo.silver_transactions t
LEFT JOIN [scout-lakehouse].dbo.silver_dim_store s
    ON t.store_id = s.store_id;

-- =====================================================
-- ADVANCED ANALYTICS VIEWS
-- =====================================================

-- Market basket analysis results
CREATE OR ALTER VIEW gold.market_basket_analysis AS
SELECT
    item_a,
    item_b,
    support,
    confidence,
    lift,
    co_occurrence_count
FROM [scout-lakehouse].dbo.silver_market_basket_analysis
WHERE lift > 1.0 AND support >= 0.01;

-- Nielsen category performance metrics
CREATE OR ALTER VIEW gold.nielsen_category_metrics AS
SELECT
    nielsen_l1_category,
    nielsen_l2_category,
    nielsen_l3_category,
    transaction_count,
    total_revenue,
    avg_transaction_value,
    unique_customers,
    store_presence,
    market_share_pct,
    growth_rate_mom
FROM [scout-lakehouse].dbo.silver_nielsen_category_metrics;

-- Brand performance metrics
CREATE OR ALTER VIEW gold.nielsen_brand_metrics AS
SELECT
    brand_name,
    nielsen_l1_category,
    nielsen_l2_category,
    transaction_count,
    total_revenue,
    avg_unit_price,
    unique_customers,
    store_presence,
    premium_tier,
    velocity_score
FROM [scout-lakehouse].dbo.silver_nielsen_brand_metrics;

-- Customer segmentation analytics
CREATE OR ALTER VIEW gold.customer_segments AS
SELECT
    facial_id,
    customer_age,
    customer_gender,
    transaction_count,
    total_spent,
    avg_transaction_value,
    avg_basket_size,
    store_variety,
    first_visit,
    last_visit,
    customer_lifespan_days,
    spending_category,
    loyalty_score,
    engagement_score,
    persona_assigned
FROM [scout-lakehouse].dbo.silver_customer_segments;

-- Store performance analytics
CREATE OR ALTER VIEW gold.store_performance AS
SELECT
    store_id,
    store_name,
    region_name,
    province_name,
    municipality_name,
    transaction_count,
    total_revenue,
    avg_transaction_value,
    unique_customers,
    avg_basket_size,
    operating_days,
    revenue_per_day,
    transactions_per_day,
    customer_retention,
    performance_tier,
    efficiency_score
FROM [scout-lakehouse].dbo.silver_store_performance;

-- =====================================================
-- TIME-BASED ANALYTICS VIEWS
-- =====================================================

-- Daily sales patterns
CREATE OR ALTER VIEW gold.daily_patterns AS
SELECT
    day_of_week,
    day_name,
    is_weekend,
    is_holiday,
    transaction_count,
    total_revenue,
    avg_transaction_value,
    unique_customers,
    revenue_index
FROM [scout-lakehouse].dbo.silver_daily_patterns;

-- Hourly sales patterns
CREATE OR ALTER VIEW gold.hourly_patterns AS
SELECT
    hour_24,
    time_of_day_category,
    business_time_period,
    transaction_count,
    total_revenue,
    avg_transaction_value,
    unique_customers,
    avg_conversation_score
FROM [scout-lakehouse].dbo.silver_hourly_patterns;

-- Monthly trends
CREATE OR ALTER VIEW gold.monthly_trends AS
SELECT
    year,
    month,
    month_name,
    quarter,
    transaction_count,
    total_revenue,
    unique_customers,
    active_stores,
    month_year
FROM [scout-lakehouse].dbo.silver_monthly_trends;

-- =====================================================
-- DATA QUALITY AND MONITORING VIEWS
-- =====================================================

-- Data freshness monitoring
CREATE OR ALTER VIEW gold.data_freshness AS
SELECT
    'transactions' AS table_name,
    COUNT(*) AS total_rows,
    MAX(transaction_date) AS latest_transaction_date,
    DATEDIFF(day, MAX(transaction_date), GETDATE()) AS days_since_last_data,
    CASE
        WHEN MAX(transaction_date) >= DATEADD(day, -1, GETDATE()) THEN 'Fresh'
        WHEN MAX(transaction_date) >= DATEADD(day, -7, GETDATE()) THEN 'Acceptable'
        ELSE 'Stale'
    END AS freshness_status
FROM gold.fact_transactions
UNION ALL
SELECT
    'transaction_items' AS table_name,
    COUNT(*) AS total_rows,
    NULL AS latest_transaction_date,
    NULL AS days_since_last_data,
    'N/A' AS freshness_status
FROM gold.fact_transaction_items;

-- Business metrics summary
CREATE OR ALTER VIEW gold.business_metrics_summary AS
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT facial_id) AS unique_customers,
    COUNT(DISTINCT store_id) AS active_stores,
    SUM(transaction_value) AS total_revenue,
    AVG(transaction_value) AS avg_transaction_value,
    AVG(CAST(basket_size AS FLOAT)) AS avg_basket_size,
    MIN(transaction_date) AS earliest_transaction,
    MAX(transaction_date) AS latest_transaction,
    DATEDIFF(day, MIN(transaction_date), MAX(transaction_date)) AS data_span_days,
    COUNT(*) / NULLIF(DATEDIFF(day, MIN(transaction_date), MAX(transaction_date)), 0) AS avg_transactions_per_day
FROM gold.fact_transactions;

-- =====================================================
-- CROSS-DATABASE HEALTH CHECK
-- =====================================================

CREATE OR ALTER VIEW gold.system_health AS
SELECT
    'lakehouse_connectivity' AS check_name,
    CASE
        WHEN EXISTS (SELECT 1 FROM gold.fact_transactions) THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    CASE
        WHEN EXISTS (SELECT 1 FROM gold.fact_transactions) THEN 'Lakehouse views accessible'
        ELSE 'Cannot access Lakehouse tables'
    END AS details
UNION ALL
SELECT
    'data_completeness' AS check_name,
    CASE
        WHEN (SELECT COUNT(*) FROM gold.fact_transactions WHERE transaction_date >= DATEADD(day, -7, GETDATE())) > 0 THEN 'PASS'
        ELSE 'WARN'
    END AS status,
    CONCAT('Recent transactions: ', (SELECT COUNT(*) FROM gold.fact_transactions WHERE transaction_date >= DATEADD(day, -7, GETDATE()))) AS details
UNION ALL
SELECT
    'single_date_authority' AS check_name,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM gold.fact_transactions WHERE transaction_date IS NULL) THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    'All transactions have authoritative transaction_date' AS details;

PRINT 'Created Gold layer views successfully';

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

PRINT '';
PRINT '========================================';
PRINT 'Warehouse Views Deployment Complete';
PRINT '========================================';
PRINT 'Gold views created:';
PRINT '  - Dimension views (5): store, brand, category, date, time';
PRINT '  - Fact views (2): transactions, transaction_items';
PRINT '  - Analytics marts (1): mart_transactions';
PRINT '  - Advanced analytics (5): market_basket, nielsen_metrics, customer_segments, store_performance';
PRINT '  - Time-based views (3): daily, hourly, monthly patterns';
PRINT '  - Monitoring views (3): data_freshness, business_metrics, system_health';
PRINT '';
PRINT 'All views reference scout-lakehouse Silver tables';
PRINT 'Single date authority enforced: transaction_date';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Run Silver ETL notebook in Lakehouse';
PRINT '2. Validate with validation/validate_fabric.sql';
PRINT '3. Connect Power BI to Gold views';
PRINT '========================================';