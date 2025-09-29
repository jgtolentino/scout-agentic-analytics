-- =====================================================
-- Microsoft Fabric Warehouse Views Configuration
-- Cross-Database Views from Warehouse to Lakehouse
-- =====================================================

-- CONFIGURATION: Replace tokens with actual names
-- <LAKEHOUSE_SQL_NAME> -> Your Lakehouse SQL endpoint name
-- <WAREHOUSE_NAME> -> Your Fabric Warehouse name

-- =====================================================
-- CROSS-DATABASE VIEW CREATION
-- =====================================================

-- This script creates views in the Warehouse that reference
-- Silver tables in the Lakehouse SQL endpoint

USE [<WAREHOUSE_NAME>];
GO

-- =====================================================
-- VALIDATE LAKEHOUSE CONNECTION
-- =====================================================

-- Test query to verify Lakehouse connectivity
PRINT 'Testing Lakehouse connectivity...';

BEGIN TRY
    DECLARE @test_count INT;
    SELECT @test_count = COUNT(*)
    FROM [<LAKEHOUSE_SQL_NAME>].INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME LIKE 'silver_%';

    PRINT CONCAT('Found ', @test_count, ' Silver tables in Lakehouse');

    IF @test_count = 0
    BEGIN
        PRINT 'WARNING: No Silver tables found. Ensure Lakehouse ETL has completed.';
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR: Cannot connect to Lakehouse. Verify:';
    PRINT '1. Lakehouse SQL endpoint name is correct';
    PRINT '2. Cross-item queries are enabled in tenant';
    PRINT '3. Warehouse has permissions to Lakehouse';
    THROW;
END CATCH;

-- =====================================================
-- SILVER TABLE REFERENCES (Gold Layer Views)
-- =====================================================

-- Dimension Views
CREATE OR ALTER VIEW gold.dim_store_ref AS
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
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_store;

CREATE OR ALTER VIEW gold.dim_brand_ref AS
SELECT
    brand_id,
    brand_name,
    brand_category,
    nielsen_l1_category,
    nielsen_l2_category,
    nielsen_l3_category,
    is_premium,
    market_segment,
    created_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_brand;

CREATE OR ALTER VIEW gold.dim_category_ref AS
SELECT
    category_id,
    category_name,
    parent_category_id,
    category_level,
    nielsen_mapping,
    is_tobacco,
    is_laundry,
    created_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_category;

-- Fact Views
CREATE OR ALTER VIEW gold.fact_transactions_ref AS
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
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions;

CREATE OR ALTER VIEW gold.fact_transaction_items_ref AS
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
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transaction_items;

-- =====================================================
-- ALTERNATIVE: SQL SHORTCUTS (if cross-item disabled)
-- =====================================================

-- If your tenant has cross-item queries disabled,
-- create SQL shortcuts instead of views

/*
-- Create shortcuts from Warehouse to Lakehouse tables
CREATE EXTERNAL TABLE gold.silver_transactions_shortcut
WITH (LOCATION = 'sql://<LAKEHOUSE_SQL_NAME>/dbo/silver_transactions')

CREATE EXTERNAL TABLE gold.silver_transaction_items_shortcut
WITH (LOCATION = 'sql://<LAKEHOUSE_SQL_NAME>/dbo/silver_transaction_items')

CREATE EXTERNAL TABLE gold.silver_dim_store_shortcut
WITH (LOCATION = 'sql://<LAKEHOUSE_SQL_NAME>/dbo/silver_dim_store')

CREATE EXTERNAL TABLE gold.silver_dim_brand_shortcut
WITH (LOCATION = 'sql://<LAKEHOUSE_SQL_NAME>/dbo/silver_dim_brand')

CREATE EXTERNAL TABLE gold.silver_dim_category_shortcut
WITH (LOCATION = 'sql://<LAKEHOUSE_SQL_NAME>/dbo/silver_dim_category')
*/

-- =====================================================
-- ANALYTICS AGGREGATION VIEWS
-- =====================================================

-- Pre-aggregated views for common analytics queries
CREATE OR ALTER VIEW gold.daily_sales_summary AS
SELECT
    transaction_date,
    COUNT(*) AS transaction_count,
    SUM(transaction_value) AS total_revenue,
    AVG(transaction_value) AS avg_transaction_value,
    COUNT(DISTINCT facial_id) AS unique_customers,
    AVG(CAST(basket_size AS FLOAT)) AS avg_basket_size,
    COUNT(DISTINCT store_id) AS active_stores
FROM gold.fact_transactions_ref
GROUP BY transaction_date;

CREATE OR ALTER VIEW gold.store_performance_summary AS
SELECT
    s.store_id,
    s.store_name,
    s.region_name,
    s.province_name,
    s.municipality_name,
    COUNT(t.canonical_tx_id) AS transaction_count,
    SUM(t.transaction_value) AS total_revenue,
    AVG(t.transaction_value) AS avg_transaction_value,
    COUNT(DISTINCT t.facial_id) AS unique_customers,
    AVG(CAST(t.basket_size AS FLOAT)) AS avg_basket_size,
    MIN(t.transaction_date) AS first_transaction,
    MAX(t.transaction_date) AS last_transaction
FROM gold.dim_store_ref s
LEFT JOIN gold.fact_transactions_ref t ON s.store_id = t.store_id
WHERE s.is_active = 1
GROUP BY s.store_id, s.store_name, s.region_name, s.province_name, s.municipality_name;

CREATE OR ALTER VIEW gold.brand_performance_summary AS
SELECT
    b.brand_name,
    b.nielsen_l1_category,
    b.nielsen_l2_category,
    COUNT(i.canonical_tx_id) AS transaction_count,
    SUM(i.item_total) AS total_revenue,
    SUM(i.item_qty) AS total_quantity,
    AVG(i.item_unit_price) AS avg_unit_price,
    COUNT(DISTINCT t.facial_id) AS unique_customers,
    COUNT(DISTINCT t.store_id) AS store_presence
FROM gold.dim_brand_ref b
LEFT JOIN gold.fact_transaction_items_ref i ON b.brand_name = i.item_brand
LEFT JOIN gold.fact_transactions_ref t ON i.canonical_tx_id = t.canonical_tx_id
GROUP BY b.brand_name, b.nielsen_l1_category, b.nielsen_l2_category;

-- =====================================================
-- TIME INTELLIGENCE VIEWS
-- =====================================================

CREATE OR ALTER VIEW gold.monthly_trends AS
SELECT
    YEAR(transaction_date) AS year,
    MONTH(transaction_date) AS month,
    DATENAME(month, transaction_date) AS month_name,
    COUNT(*) AS transaction_count,
    SUM(transaction_value) AS total_revenue,
    COUNT(DISTINCT facial_id) AS unique_customers,
    AVG(CAST(basket_size AS FLOAT)) AS avg_basket_size,

    -- Year-over-year growth
    LAG(SUM(transaction_value), 12) OVER (ORDER BY YEAR(transaction_date), MONTH(transaction_date)) AS revenue_prev_year,

    -- Month-over-month growth
    LAG(SUM(transaction_value), 1) OVER (ORDER BY YEAR(transaction_date), MONTH(transaction_date)) AS revenue_prev_month
FROM gold.fact_transactions_ref
GROUP BY YEAR(transaction_date), MONTH(transaction_date), DATENAME(month, transaction_date);

CREATE OR ALTER VIEW gold.hourly_patterns AS
SELECT
    hour_24,
    time_of_day_category,
    business_time_period,
    weekday_vs_weekend,
    COUNT(*) AS transaction_count,
    SUM(transaction_value) AS total_revenue,
    AVG(transaction_value) AS avg_transaction_value,
    COUNT(DISTINCT facial_id) AS unique_customers
FROM gold.fact_transactions_ref
GROUP BY hour_24, time_of_day_category, business_time_period, weekday_vs_weekend;

-- =====================================================
-- CUSTOMER ANALYTICS VIEWS
-- =====================================================

CREATE OR ALTER VIEW gold.customer_segments AS
SELECT
    customer_age,
    customer_gender,
    persona_assigned,
    COUNT(*) AS transaction_count,
    SUM(transaction_value) AS total_spent,
    AVG(transaction_value) AS avg_transaction_value,
    AVG(CAST(basket_size AS FLOAT)) AS avg_basket_size,
    COUNT(DISTINCT store_id) AS store_variety,
    MIN(transaction_date) AS first_visit,
    MAX(transaction_date) AS last_visit,
    DATEDIFF(day, MIN(transaction_date), MAX(transaction_date)) AS customer_lifespan_days
FROM gold.fact_transactions_ref
WHERE facial_id IS NOT NULL
GROUP BY customer_age, customer_gender, persona_assigned;

-- =====================================================
-- GEOGRAPHICAL ANALYTICS VIEWS
-- =====================================================

CREATE OR ALTER VIEW gold.regional_performance AS
SELECT
    s.region_name,
    s.province_name,
    COUNT(t.canonical_tx_id) AS transaction_count,
    SUM(t.transaction_value) AS total_revenue,
    COUNT(DISTINCT t.facial_id) AS unique_customers,
    COUNT(DISTINCT s.store_id) AS store_count,
    AVG(t.transaction_value) AS avg_transaction_value,
    SUM(t.transaction_value) / COUNT(DISTINCT s.store_id) AS revenue_per_store
FROM gold.dim_store_ref s
LEFT JOIN gold.fact_transactions_ref t ON s.store_id = t.store_id
WHERE s.is_active = 1
GROUP BY s.region_name, s.province_name;

-- =====================================================
-- VALIDATION AND MONITORING VIEWS
-- =====================================================

CREATE OR ALTER VIEW gold.data_freshness_check AS
SELECT
    'transactions' AS table_name,
    COUNT(*) AS total_rows,
    MAX(transaction_date) AS latest_transaction_date,
    DATEDIFF(day, MAX(transaction_date), GETDATE()) AS days_since_last_data,
    CASE
        WHEN MAX(transaction_date) >= DATEADD(day, -2, GETDATE()) THEN 'Fresh'
        WHEN MAX(transaction_date) >= DATEADD(day, -7, GETDATE()) THEN 'Stale'
        ELSE 'Old'
    END AS freshness_status
FROM gold.fact_transactions_ref
UNION ALL
SELECT
    'transaction_items' AS table_name,
    COUNT(*) AS total_rows,
    NULL AS latest_transaction_date,
    NULL AS days_since_last_data,
    'N/A' AS freshness_status
FROM gold.fact_transaction_items_ref;

CREATE OR ALTER VIEW gold.cross_database_health AS
SELECT
    'lakehouse_connectivity' AS check_name,
    CASE
        WHEN EXISTS (SELECT 1 FROM gold.fact_transactions_ref) THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    CASE
        WHEN EXISTS (SELECT 1 FROM gold.fact_transactions_ref) THEN 'Lakehouse views accessible'
        ELSE 'Cannot access Lakehouse tables'
    END AS details
UNION ALL
SELECT
    'data_completeness' AS check_name,
    CASE
        WHEN (SELECT COUNT(*) FROM gold.fact_transactions_ref WHERE transaction_date >= DATEADD(day, -7, GETDATE())) > 0 THEN 'PASS'
        ELSE 'WARN'
    END AS status,
    CONCAT('Recent transactions: ', (SELECT COUNT(*) FROM gold.fact_transactions_ref WHERE transaction_date >= DATEADD(day, -7, GETDATE()))) AS details;

PRINT 'Cross-database views created successfully';

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

PRINT '========================================';
PRINT 'Warehouse Views Configuration Complete';
PRINT '========================================';
PRINT 'Views created:';
PRINT '- Dimension reference views (4)';
PRINT '- Fact reference views (2)';
PRINT '- Analytics summary views (6)';
PRINT '- Time intelligence views (2)';
PRINT '- Customer analytics views (1)';
PRINT '- Geographical views (1)';
PRINT '- Monitoring views (2)';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Replace <LAKEHOUSE_SQL_NAME> and <WAREHOUSE_NAME>';
PRINT '2. Test Lakehouse connectivity';
PRINT '3. Verify all views return data';
PRINT '4. Use shortcuts if cross-item queries disabled';
PRINT '========================================';