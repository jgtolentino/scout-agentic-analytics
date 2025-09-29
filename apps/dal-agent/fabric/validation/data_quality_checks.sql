-- =====================================================
-- Microsoft Fabric - Data Quality Validation Script
-- Scout v7 Analytics - Medallion Architecture Validation
-- =====================================================

-- Configuration: Replace with your actual names
-- <LAKEHOUSE_SQL_NAME> -> Your Lakehouse SQL endpoint name
-- <WAREHOUSE_NAME> -> Your Fabric Warehouse name

PRINT '========================================';
PRINT 'Scout v7 Data Quality Validation Suite';
PRINT '========================================';

-- =====================================================
-- BRONZE LAYER VALIDATION
-- =====================================================

PRINT '';
PRINT '=== BRONZE LAYER VALIDATION ===';

-- Check Bronze table row counts
SELECT
    'Bronze Layer Row Counts' AS validation_type,
    COUNT(*) AS sales_interactions_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_payload_transactions_raw) AS payload_transactions_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_stores_raw) AS stores_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_brands_raw) AS brands_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_categories_raw) AS categories_count
FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_sales_interactions_raw;

-- Data freshness check
SELECT
    'Bronze Data Freshness' AS validation_type,
    MAX(transaction_date) AS latest_transaction_date,
    DATEDIFF(day, MAX(transaction_date), GETDATE()) AS days_since_last_data,
    CASE
        WHEN MAX(transaction_date) >= DATEADD(day, -1, GETDATE()) THEN 'Fresh'
        WHEN MAX(transaction_date) >= DATEADD(day, -7, GETDATE()) THEN 'Acceptable'
        ELSE 'Stale'
    END AS freshness_status
FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_sales_interactions_raw;

-- =====================================================
-- SILVER LAYER VALIDATION
-- =====================================================

PRINT '';
PRINT '=== SILVER LAYER VALIDATION ===';

-- Silver table completeness
SELECT
    'Silver Layer Completeness' AS validation_type,
    COUNT(*) AS silver_transactions_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transaction_items) AS silver_items_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_store) AS dim_store_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_brand) AS dim_brand_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_category) AS dim_category_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_date) AS dim_date_count,
    (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_time) AS dim_time_count
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions;

-- Data quality checks
SELECT
    'Silver Data Quality' AS validation_type,
    COUNT(*) AS total_transactions,
    COUNT(canonical_tx_id) AS non_null_tx_ids,
    COUNT(DISTINCT canonical_tx_id) AS unique_tx_ids,
    COUNT(*) - COUNT(DISTINCT canonical_tx_id) AS duplicate_transactions,
    SUM(CASE WHEN transaction_value <= 0 THEN 1 ELSE 0 END) AS zero_value_transactions,
    SUM(CASE WHEN basket_size <= 0 THEN 1 ELSE 0 END) AS zero_basket_transactions,
    COUNT(facial_id) AS transactions_with_customers,
    CAST(COUNT(facial_id) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS customer_identification_rate
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions;

-- Date consistency validation (CRITICAL)
SELECT
    'Date Consistency Check' AS validation_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN t.transaction_date = d.full_date THEN 1 ELSE 0 END) AS matching_dates,
    SUM(CASE WHEN t.transaction_date != d.full_date THEN 1 ELSE 0 END) AS mismatched_dates,
    CASE
        WHEN SUM(CASE WHEN t.transaction_date != d.full_date THEN 1 ELSE 0 END) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS date_integrity_status
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions t
LEFT JOIN [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_date d ON t.date_key = d.date_key;

-- Transaction items validation
SELECT
    'Transaction Items Quality' AS validation_type,
    COUNT(*) AS total_items,
    COUNT(DISTINCT canonical_tx_id) AS unique_transactions_with_items,
    SUM(item_qty) AS total_quantity,
    SUM(item_total) AS total_item_value,
    AVG(item_qty) AS avg_quantity_per_item,
    AVG(item_unit_price) AS avg_unit_price,
    SUM(CASE WHEN item_qty <= 0 THEN 1 ELSE 0 END) AS invalid_quantities,
    SUM(CASE WHEN item_unit_price <= 0 THEN 1 ELSE 0 END) AS invalid_prices
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transaction_items;

-- =====================================================
-- GOLD LAYER VALIDATION
-- =====================================================

PRINT '';
PRINT '=== GOLD LAYER VALIDATION ===';

-- Gold views accessibility check
SELECT
    'Gold Views Accessibility' AS validation_type,
    COUNT(*) AS fact_transactions_count,
    (SELECT COUNT(*) FROM gold.fact_transaction_items_ref) AS fact_items_count,
    (SELECT COUNT(*) FROM gold.dim_store_ref) AS dim_store_count,
    (SELECT COUNT(*) FROM gold.dim_brand_ref) AS dim_brand_count,
    (SELECT COUNT(*) FROM gold.dim_category_ref) AS dim_category_count
FROM gold.fact_transactions_ref;

-- Business metrics validation
SELECT
    'Business Metrics Summary' AS validation_type,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT facial_id) AS unique_customers,
    COUNT(DISTINCT store_id) AS active_stores,
    SUM(transaction_value) AS total_revenue,
    AVG(transaction_value) AS avg_transaction_value,
    AVG(CAST(basket_size AS FLOAT)) AS avg_basket_size,
    MIN(transaction_date) AS earliest_transaction,
    MAX(transaction_date) AS latest_transaction
FROM gold.fact_transactions_ref;

-- Store performance validation
SELECT
    'Store Performance Summary' AS validation_type,
    COUNT(DISTINCT s.store_id) AS total_stores,
    COUNT(DISTINCT s.region_name) AS regions_covered,
    COUNT(DISTINCT s.province_name) AS provinces_covered,
    AVG(store_metrics.transaction_count) AS avg_transactions_per_store,
    AVG(store_metrics.total_revenue) AS avg_revenue_per_store
FROM gold.dim_store_ref s
CROSS APPLY (
    SELECT
        COUNT(*) AS transaction_count,
        SUM(transaction_value) AS total_revenue
    FROM gold.fact_transactions_ref t
    WHERE t.store_id = s.store_id
) store_metrics;

-- =====================================================
-- PLATINUM LAYER VALIDATION
-- =====================================================

PRINT '';
PRINT '=== PLATINUM LAYER VALIDATION ===';

-- Check Platinum tables
BEGIN TRY
    SELECT
        'Platinum Layer Status' AS validation_type,
        (SELECT COUNT(*) FROM platinum.model_registry) AS model_registry_count,
        (SELECT COUNT(*) FROM platinum.model_versions) AS model_versions_count,
        (SELECT COUNT(*) FROM platinum.predictions) AS predictions_count,
        (SELECT COUNT(*) FROM platinum.insights) AS insights_count,
        (SELECT COUNT(*) FROM platinum.experiments) AS experiments_count,
        (SELECT COUNT(*) FROM platinum.feature_store) AS feature_store_count,
        (SELECT COUNT(*) FROM platinum.ml_metadata) AS ml_metadata_count;

    PRINT '✅ Platinum layer accessible';
END TRY
BEGIN CATCH
    PRINT '⚠️ Platinum layer not yet implemented or accessible';
    SELECT
        'Platinum Layer Status' AS validation_type,
        'Not Implemented' AS status,
        ERROR_MESSAGE() AS error_details;
END CATCH;

-- =====================================================
-- CROSS-LAYER CONSISTENCY VALIDATION
-- =====================================================

PRINT '';
PRINT '=== CROSS-LAYER CONSISTENCY ===';

-- Transaction count consistency across layers
WITH layer_counts AS (
    SELECT
        (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_sales_interactions_raw) AS bronze_count,
        (SELECT COUNT(*) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions) AS silver_count,
        (SELECT COUNT(*) FROM gold.fact_transactions_ref) AS gold_count
)
SELECT
    'Cross-Layer Consistency' AS validation_type,
    bronze_count,
    silver_count,
    gold_count,
    CASE
        WHEN bronze_count = silver_count AND silver_count = gold_count THEN 'CONSISTENT'
        WHEN ABS(bronze_count - silver_count) <= bronze_count * 0.05 THEN 'ACCEPTABLE'
        ELSE 'INCONSISTENT'
    END AS consistency_status,
    ABS(bronze_count - silver_count) AS bronze_silver_diff,
    ABS(silver_count - gold_count) AS silver_gold_diff
FROM layer_counts;

-- Revenue consistency check
WITH revenue_check AS (
    SELECT
        (SELECT SUM(ISNULL(CAST(JSON_VALUE(payload_json, '$.amount') AS DECIMAL(18,2)), 0))
         FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_payload_transactions_raw
         WHERE payload_json IS NOT NULL) AS bronze_revenue,
        (SELECT SUM(transaction_value) FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions) AS silver_revenue,
        (SELECT SUM(transaction_value) FROM gold.fact_transactions_ref) AS gold_revenue
)
SELECT
    'Revenue Consistency' AS validation_type,
    bronze_revenue,
    silver_revenue,
    gold_revenue,
    CASE
        WHEN ABS(silver_revenue - gold_revenue) <= silver_revenue * 0.01 THEN 'CONSISTENT'
        ELSE 'REVIEW REQUIRED'
    END AS revenue_consistency_status
FROM revenue_check;

-- =====================================================
-- NIELSEN CATEGORY VALIDATION
-- =====================================================

PRINT '';
PRINT '=== NIELSEN CATEGORY VALIDATION ===';

-- Check Nielsen category coverage
SELECT
    'Nielsen Category Coverage' AS validation_type,
    COUNT(DISTINCT nielsen_l1) AS l1_categories,
    COUNT(DISTINCT nielsen_l2) AS l2_categories,
    COUNT(DISTINCT nielsen_l3) AS l3_categories,
    SUM(CASE WHEN nielsen_l1 = 'Tobacco Products' THEN item_total ELSE 0 END) AS tobacco_revenue,
    SUM(CASE WHEN nielsen_l2 = 'Laundry Care' THEN item_total ELSE 0 END) AS laundry_revenue,
    COUNT(CASE WHEN nielsen_l1 IS NULL THEN 1 END) AS unmapped_items
FROM gold.fact_transaction_items_ref;

-- =====================================================
-- PERFORMANCE & OPTIMIZATION CHECKS
-- =====================================================

PRINT '';
PRINT '=== PERFORMANCE VALIDATION ===';

-- Check for potential performance issues
SELECT
    'Performance Indicators' AS validation_type,
    (SELECT COUNT(*) FROM gold.fact_transactions_ref WHERE transaction_date >= DATEADD(day, -30, GETDATE())) AS recent_30d_transactions,
    (SELECT COUNT(*) FROM gold.fact_transactions_ref WHERE transaction_date >= DATEADD(day, -7, GETDATE())) AS recent_7d_transactions,
    (SELECT COUNT(*) FROM gold.fact_transactions_ref WHERE transaction_date >= DATEADD(day, -1, GETDATE())) AS recent_1d_transactions,
    (SELECT COUNT(DISTINCT store_id) FROM gold.fact_transactions_ref WHERE transaction_date >= DATEADD(day, -7, GETDATE())) AS active_stores_7d;

-- =====================================================
-- DATA LINEAGE VALIDATION
-- =====================================================

PRINT '';
PRINT '=== DATA LINEAGE VALIDATION ===';

-- Verify canonical_tx_id consistency across all layers
WITH tx_id_validation AS (
    SELECT
        b.canonical_tx_id,
        CASE WHEN s.canonical_tx_id IS NOT NULL THEN 1 ELSE 0 END AS in_silver,
        CASE WHEN g.canonical_tx_id IS NOT NULL THEN 1 ELSE 0 END AS in_gold
    FROM (SELECT DISTINCT canonical_tx_id FROM [<LAKEHOUSE_SQL_NAME>].dbo.bronze_sales_interactions_raw) b
    LEFT JOIN (SELECT DISTINCT canonical_tx_id FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions) s
        ON b.canonical_tx_id = s.canonical_tx_id
    LEFT JOIN (SELECT DISTINCT canonical_tx_id FROM gold.fact_transactions_ref) g
        ON b.canonical_tx_id = g.canonical_tx_id
)
SELECT
    'Data Lineage Validation' AS validation_type,
    COUNT(*) AS bronze_unique_tx_ids,
    SUM(in_silver) AS matched_in_silver,
    SUM(in_gold) AS matched_in_gold,
    COUNT(*) - SUM(in_silver) AS missing_from_silver,
    COUNT(*) - SUM(in_gold) AS missing_from_gold,
    CASE
        WHEN COUNT(*) = SUM(in_silver) AND COUNT(*) = SUM(in_gold) THEN 'PERFECT'
        WHEN SUM(in_silver) >= COUNT(*) * 0.95 AND SUM(in_gold) >= COUNT(*) * 0.95 THEN 'GOOD'
        ELSE 'NEEDS REVIEW'
    END AS lineage_status
FROM tx_id_validation;

-- =====================================================
-- BUSINESS RULES VALIDATION
-- =====================================================

PRINT '';
PRINT '=== BUSINESS RULES VALIDATION ===';

-- Validate business rules
SELECT
    'Business Rules Compliance' AS validation_type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN transaction_value BETWEEN 1 AND 50000 THEN 1 ELSE 0 END) AS valid_transaction_amounts,
    SUM(CASE WHEN basket_size BETWEEN 1 AND 50 THEN 1 ELSE 0 END) AS valid_basket_sizes,
    SUM(CASE WHEN customer_age BETWEEN 13 AND 120 OR customer_age IS NULL THEN 1 ELSE 0 END) AS valid_ages,
    SUM(CASE WHEN customer_gender IN ('Male', 'Female', 'Unknown') OR customer_gender IS NULL THEN 1 ELSE 0 END) AS valid_genders,
    CASE
        WHEN COUNT(*) = SUM(CASE WHEN transaction_value BETWEEN 1 AND 50000 THEN 1 ELSE 0 END) THEN 'PASS'
        ELSE 'REVIEW REQUIRED'
    END AS amount_validation_status
FROM gold.fact_transactions_ref;

-- =====================================================
-- FINAL VALIDATION SUMMARY
-- =====================================================

PRINT '';
PRINT '=== VALIDATION SUMMARY ===';

-- Overall system health check
WITH validation_summary AS (
    SELECT
        CASE
            WHEN (SELECT COUNT(*) FROM gold.fact_transactions_ref) > 0
                 AND (SELECT COUNT(*) FROM gold.fact_transaction_items_ref) > 0
                 AND (SELECT COUNT(*) FROM gold.dim_store_ref) > 0
            THEN 'HEALTHY'
            ELSE 'UNHEALTHY'
        END AS system_status,
        (SELECT COUNT(*) FROM gold.fact_transactions_ref) AS total_transactions,
        (SELECT COUNT(DISTINCT store_id) FROM gold.fact_transactions_ref) AS active_stores,
        (SELECT COUNT(DISTINCT facial_id) FROM gold.fact_transactions_ref WHERE facial_id IS NOT NULL) AS identified_customers,
        (SELECT MAX(transaction_date) FROM gold.fact_transactions_ref) AS latest_data_date,
        DATEDIFF(day, (SELECT MAX(transaction_date) FROM gold.fact_transactions_ref), GETDATE()) AS data_age_days
)
SELECT
    'System Health Summary' AS validation_type,
    system_status,
    total_transactions,
    active_stores,
    identified_customers,
    latest_data_date,
    data_age_days,
    CASE
        WHEN system_status = 'HEALTHY' AND data_age_days <= 1 THEN '🟢 EXCELLENT'
        WHEN system_status = 'HEALTHY' AND data_age_days <= 7 THEN '🟡 GOOD'
        WHEN system_status = 'HEALTHY' THEN '🟠 ACCEPTABLE'
        ELSE '🔴 CRITICAL'
    END AS overall_status
FROM validation_summary;

PRINT '';
PRINT '========================================';
PRINT 'Validation Complete';
PRINT 'Review results above for any issues';
PRINT '========================================';