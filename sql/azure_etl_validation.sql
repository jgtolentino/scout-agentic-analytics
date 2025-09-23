-- =====================================================
-- Azure SQL Scout ETL Validation Queries
-- Comprehensive validation for Scout Analytics ETL
-- =====================================================

-- =====================================================
-- 1. BLOB STORAGE CONNECTION VALIDATION
-- =====================================================

-- Test external data source connectivity
SELECT
    name as data_source_name,
    location,
    type_desc
FROM sys.external_data_sources
WHERE name = 'eds_scout_blob_storage';

-- Test database scoped credential
SELECT
    name as credential_name,
    credential_identity
FROM sys.database_scoped_credentials
WHERE name = 'cr_scout_blob_storage';

-- =====================================================
-- 2. STAGING DATA VALIDATION
-- =====================================================

-- Staging transactions overview
SELECT
    'staging.transactions' as table_name,
    COUNT(*) as record_count,
    MIN(created_at) as earliest_record,
    MAX(created_at) as latest_record,
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(DISTINCT store_id) as unique_stores
FROM staging.transactions;

-- Staging stores overview
SELECT
    'staging.stores' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT store_id) as unique_stores,
    COUNT(DISTINCT region_name) as unique_regions,
    COUNT(DISTINCT city_name) as unique_cities
FROM staging.stores;

-- Staging data quality checks
SELECT
    'JSON Parsing Issues' as check_type,
    COUNT(*) as issues_found
FROM staging.transactions
WHERE TRY_PARSE(raw_json as JSON) IS NULL;

SELECT
    'Missing Transaction IDs' as check_type,
    COUNT(*) as issues_found
FROM staging.transactions
WHERE canonical_tx_id IS NULL OR canonical_tx_id = '';

SELECT
    'Missing Store IDs' as check_type,
    COUNT(*) as issues_found
FROM staging.transactions
WHERE store_id IS NULL;

-- =====================================================
-- 3. GOLD LAYER DATA VALIDATION
-- =====================================================

-- Gold layer transaction counts
SELECT
    'v_transactions_flat' as view_name,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT canonical_tx_id) as unique_transactions,
    ROUND(AVG(CAST(total_price as float)), 2) as avg_transaction_value,
    MIN(transaction_timestamp) as earliest_transaction,
    MAX(transaction_timestamp) as latest_transaction
FROM gold.v_transactions_flat;

-- Brand distribution validation
SELECT
    brand,
    COUNT(*) as transaction_count,
    ROUND(AVG(CAST(total_price as float)), 2) as avg_value,
    COUNT(DISTINCT canonical_tx_id) as unique_transactions
FROM gold.v_transactions_flat
GROUP BY brand
ORDER BY transaction_count DESC;

-- Store distribution validation
SELECT
    store_name,
    store_id,
    COUNT(*) as transaction_count,
    COUNT(DISTINCT canonical_tx_id) as unique_transactions,
    ROUND(SUM(CAST(total_price as float)), 2) as total_value
FROM gold.v_transactions_flat
GROUP BY store_name, store_id
ORDER BY transaction_count DESC;

-- Time distribution validation
SELECT
    DATEPART(hour, transaction_timestamp) as hour_of_day,
    COUNT(*) as transaction_count,
    ROUND(AVG(CAST(total_price as float)), 2) as avg_value
FROM gold.v_transactions_flat
GROUP BY DATEPART(hour, transaction_timestamp)
ORDER BY hour_of_day;

-- =====================================================
-- 4. REAL FILIPINO BRANDS VALIDATION
-- =====================================================

-- Detect real vs test brands
WITH real_filipino_brands AS (
    SELECT brand_name FROM (VALUES
        ('Safeguard'),
        ('Jack ''n Jill'),
        ('Piattos'),
        ('Combi'),
        ('Pantene'),
        ('Head & Shoulders'),
        ('Close Up'),
        ('Cream Silk'),
        ('Gatorade'),
        ('C2'),
        ('Coca-Cola'),
        ('Jollibee'),
        ('McDonald''s'),
        ('KFC'),
        ('Chowking'),
        ('Mang Inasal'),
        ('Greenwich'),
        ('Shakey''s'),
        ('Pizza Hut'),
        ('Domino''s'),
        ('SM'),
        ('Robinsons'),
        ('Ayala Malls'),
        ('Puregold'),
        ('Mercury Drug'),
        ('Watsons'),
        ('BPI'),
        ('BDO'),
        ('Metrobank'),
        ('Globe'),
        ('Smart'),
        ('PLDT'),
        ('Meralco'),
        ('Maynilad'),
        ('Manila Water'),
        ('Petron'),
        ('Shell'),
        ('Caltex'),
        ('Phoenix'),
        ('Unilever'),
        ('Procter & Gamble'),
        ('Nestle'),
        ('Mondelez'),
        ('URC')
    ) as brands(brand_name)
)
SELECT
    'Real Filipino Brands' as brand_type,
    COUNT(DISTINCT t.brand) as brand_count,
    COUNT(*) as transaction_count,
    ROUND(SUM(CAST(t.total_price as float)), 2) as total_value
FROM gold.v_transactions_flat t
INNER JOIN real_filipino_brands rfb ON t.brand = rfb.brand_name

UNION ALL

SELECT
    'Test/Placeholder Brands' as brand_type,
    COUNT(DISTINCT t.brand) as brand_count,
    COUNT(*) as transaction_count,
    ROUND(SUM(CAST(t.total_price as float)), 2) as total_value
FROM gold.v_transactions_flat t
WHERE t.brand NOT IN (
    SELECT brand_name FROM real_filipino_brands
)
AND (
    t.brand LIKE 'Brand %'
    OR t.brand LIKE 'Test%'
    OR t.brand LIKE 'Sample%'
    OR t.brand LIKE 'Demo%'
    OR t.brand = 'Unknown'
);

-- List all unique brands for manual inspection
SELECT
    brand,
    COUNT(*) as transaction_count,
    CASE
        WHEN brand IN (
            'Safeguard', 'Jack ''n Jill', 'Piattos', 'Combi', 'Pantene',
            'Head & Shoulders', 'Close Up', 'Cream Silk', 'Gatorade', 'C2', 'Coca-Cola'
        ) THEN 'Real Filipino Brand'
        WHEN brand LIKE 'Brand %' OR brand LIKE 'Test%' OR brand LIKE 'Sample%' THEN 'Test/Placeholder'
        ELSE 'Unknown/Other'
    END as brand_classification
FROM gold.v_transactions_flat
GROUP BY brand
ORDER BY transaction_count DESC;

-- =====================================================
-- 5. DATA QUALITY SCORE CALCULATION
-- =====================================================

WITH quality_metrics AS (
    SELECT
        COUNT(*) as total_records,
        COUNT(CASE WHEN canonical_tx_id IS NOT NULL AND canonical_tx_id != '' THEN 1 END) as valid_tx_ids,
        COUNT(CASE WHEN total_price IS NOT NULL AND CAST(total_price as float) > 0 THEN 1 END) as valid_prices,
        COUNT(CASE WHEN brand IS NOT NULL AND brand != '' THEN 1 END) as valid_brands,
        COUNT(CASE WHEN store_name IS NOT NULL AND store_name != '' THEN 1 END) as valid_stores,
        COUNT(CASE WHEN transaction_timestamp IS NOT NULL THEN 1 END) as valid_timestamps
    FROM gold.v_transactions_flat
)
SELECT
    'Data Quality Score' as metric,
    ROUND(
        (
            (CAST(valid_tx_ids as float) / total_records * 100) +
            (CAST(valid_prices as float) / total_records * 100) +
            (CAST(valid_brands as float) / total_records * 100) +
            (CAST(valid_stores as float) / total_records * 100) +
            (CAST(valid_timestamps as float) / total_records * 100)
        ) / 5, 2
    ) as quality_percentage,
    total_records,
    valid_tx_ids,
    valid_prices,
    valid_brands,
    valid_stores,
    valid_timestamps
FROM quality_metrics;

-- =====================================================
-- 6. CROSS-TABULATION VALIDATION
-- =====================================================

-- Test crosstab view functionality
SELECT TOP 10
    store_name,
    transaction_date,
    Morning_Transactions,
    Midday_Transactions,
    Afternoon_Transactions,
    Evening_Transactions,
    Daily_Total_Value
FROM gold.v_transactions_crosstab
ORDER BY transaction_date DESC;

-- Validate crosstab totals match flat view
SELECT
    'Crosstab vs Flat Comparison' as validation_type,
    crosstab_sum.total_crosstab_value,
    flat_sum.total_flat_value,
    CASE
        WHEN ABS(crosstab_sum.total_crosstab_value - flat_sum.total_flat_value) < 0.01
        THEN 'PASS'
        ELSE 'FAIL'
    END as validation_result
FROM
    (SELECT SUM(Daily_Total_Value) as total_crosstab_value FROM gold.v_transactions_crosstab) crosstab_sum,
    (SELECT SUM(CAST(total_price as float)) as total_flat_value FROM gold.v_transactions_flat) flat_sum;

-- =====================================================
-- 7. AUDIT TRAIL VALIDATION
-- =====================================================

-- Check audit table exists and has records
SELECT
    COUNT(*) as audit_record_count,
    MIN(export_timestamp) as earliest_export,
    MAX(export_timestamp) as latest_export,
    COUNT(DISTINCT operation_type) as operation_types
FROM audit.export_log;

-- Recent audit entries
SELECT TOP 10
    export_timestamp,
    operation_type,
    record_count,
    file_hash,
    validation_status
FROM audit.export_log
ORDER BY export_timestamp DESC;

-- =====================================================
-- 8. PERFORMANCE VALIDATION
-- =====================================================

-- Table sizes and row counts
SELECT
    SCHEMA_NAME(t.schema_id) as schema_name,
    t.name as table_name,
    p.rows as row_count,
    CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) as size_mb
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.schema_id IN (SCHEMA_ID('staging'), SCHEMA_ID('gold'), SCHEMA_ID('audit'))
GROUP BY t.schema_id, t.name, p.rows
ORDER BY schema_name, size_mb DESC;

-- Index usage statistics
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) as schema_name,
    OBJECT_NAME(i.object_id) as table_name,
    i.name as index_name,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
    ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE OBJECT_SCHEMA_NAME(i.object_id) IN ('staging', 'gold', 'audit')
    AND i.index_id > 0
ORDER BY schema_name, table_name, index_name;

-- =====================================================
-- 9. ETL EXECUTION VALIDATION
-- =====================================================

-- Last ETL run status
SELECT
    'Last ETL Execution' as status_type,
    MAX(created_at) as last_staging_update,
    COUNT(*) as staging_records
FROM staging.transactions

UNION ALL

SELECT
    'Gold Layer Status' as status_type,
    MAX(transaction_timestamp) as last_transaction,
    COUNT(*) as gold_records
FROM gold.v_transactions_flat;

-- Data freshness check
SELECT
    CASE
        WHEN DATEDIFF(hour, MAX(created_at), GETDATE()) <= 24 THEN 'FRESH'
        WHEN DATEDIFF(hour, MAX(created_at), GETDATE()) <= 72 THEN 'MODERATE'
        ELSE 'STALE'
    END as data_freshness,
    MAX(created_at) as last_update,
    DATEDIFF(hour, MAX(created_at), GETDATE()) as hours_since_update
FROM staging.transactions;

-- =====================================================
-- 10. SUMMARY VALIDATION REPORT
-- =====================================================

-- Executive summary of ETL health
WITH summary_stats AS (
    SELECT
        (SELECT COUNT(*) FROM staging.transactions) as staging_transactions,
        (SELECT COUNT(*) FROM staging.stores) as staging_stores,
        (SELECT COUNT(*) FROM gold.v_transactions_flat) as gold_transactions,
        (SELECT COUNT(DISTINCT brand) FROM gold.v_transactions_flat) as unique_brands,
        (SELECT COUNT(DISTINCT store_name) FROM gold.v_transactions_flat) as unique_stores,
        (SELECT MAX(transaction_timestamp) FROM gold.v_transactions_flat) as latest_transaction,
        (SELECT COUNT(*) FROM audit.export_log) as audit_records
)
SELECT
    'Scout Analytics ETL Status' as report_section,
    CASE
        WHEN staging_transactions > 0 AND gold_transactions > 0 AND audit_records > 0
        THEN 'HEALTHY'
        ELSE 'NEEDS_ATTENTION'
    END as overall_status,
    staging_transactions,
    staging_stores,
    gold_transactions,
    unique_brands,
    unique_stores,
    latest_transaction,
    audit_records
FROM summary_stats;

-- Quality gate recommendations
SELECT
    'Quality Gates' as recommendation_type,
    CASE
        WHEN (SELECT COUNT(*) FROM gold.v_transactions_flat WHERE brand LIKE 'Brand %') > 0
        THEN 'WARNING: Test brands detected in production data'
        WHEN (SELECT COUNT(*) FROM gold.v_transactions_flat) = 0
        THEN 'ERROR: No transactions in gold layer'
        WHEN (SELECT DATEDIFF(hour, MAX(created_at), GETDATE()) FROM staging.transactions) > 48
        THEN 'WARNING: Data is more than 48 hours old'
        ELSE 'PASS: All quality gates satisfied'
    END as recommendation;