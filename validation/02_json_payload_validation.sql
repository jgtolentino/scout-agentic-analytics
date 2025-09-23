-- ==========================================
-- JSON Payload Validation Queries
-- Cross-platform validation for Scout Edge JSON payloads
-- ==========================================

-- This file contains validation queries that work on both:
-- - Azure SQL Server (using JSON_VALUE, JSON_QUERY functions)
-- - PostgreSQL/Supabase (using JSONB operators)

-- ==========================================
-- AZURE SQL SERVER VALIDATION QUERIES
-- ==========================================

/*
-- Execute these on Azure SQL Server after running json payload transformation

-- 1. Basic JSON Structure Validation
SELECT
    'JSON Structure Validation' as validation_category,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE ISJSON(payload_json) = 1) as valid_json_records,
    COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.transactionId') IS NOT NULL) as with_transaction_id,
    COUNT(*) FILTER (WHERE JSON_QUERY(payload_json, '$.basket.items') IS NOT NULL) as with_basket_items,
    COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.location.municipality') IS NOT NULL) as with_location_data,
    ROUND((COUNT(*) FILTER (WHERE ISJSON(payload_json) = 1) * 100.0 / COUNT(*)), 1) as json_validity_pct
FROM dbo.fact_transactions_location;

-- 2. Basket Items Analysis
WITH basket_analysis AS (
    SELECT
        canonical_tx_id,
        JSON_VALUE(payload_json, '$.transactionId') as transaction_id,
        JSON_VALUE(payload_json, '$.storeId') as store_id,
        (SELECT COUNT(*) FROM OPENJSON(JSON_QUERY(payload_json, '$.basket.items'))) as item_count,
        (SELECT SUM(CAST(value ->> 'totalPrice' AS DECIMAL(10,2)))
         FROM OPENJSON(JSON_QUERY(payload_json, '$.basket.items'))) as calculated_total,
        (SELECT COUNT(*) FROM OPENJSON(JSON_QUERY(payload_json, '$.basket.items'))
         WHERE JSON_VALUE(value, '$.substitutionEvent') = 'true') as substitution_items
    FROM dbo.fact_transactions_location
    WHERE payload_json IS NOT NULL
)
SELECT
    'Basket Analysis' as validation_category,
    AVG(item_count) as avg_items_per_transaction,
    AVG(calculated_total) as avg_transaction_value,
    SUM(substitution_items) as total_substitution_items,
    COUNT(*) FILTER (WHERE substitution_items > 0) as transactions_with_substitutions,
    ROUND((COUNT(*) FILTER (WHERE substitution_items > 0) * 100.0 / COUNT(*)), 1) as substitution_rate_pct
FROM basket_analysis;

-- 3. Geographic Data Validation
SELECT
    'Geographic Validation' as validation_category,
    JSON_VALUE(payload_json, '$.location.region') as region,
    JSON_VALUE(payload_json, '$.location.province') as province,
    JSON_VALUE(payload_json, '$.location.municipality') as municipality,
    COUNT(*) as transaction_count,
    AVG(CAST(JSON_VALUE(payload_json, '$.location.geo.lat') AS DECIMAL(10,8))) as avg_latitude,
    AVG(CAST(JSON_VALUE(payload_json, '$.location.geo.lon') AS DECIMAL(11,8))) as avg_longitude,
    COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.locationVerified') = 'true') as location_verified_count
FROM dbo.fact_transactions_location
WHERE payload_json IS NOT NULL
GROUP BY
    JSON_VALUE(payload_json, '$.location.region'),
    JSON_VALUE(payload_json, '$.location.province'),
    JSON_VALUE(payload_json, '$.location.municipality')
ORDER BY transaction_count DESC;

-- 4. Quality Flags Summary
SELECT
    'Quality Flags Summary' as validation_category,
    COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.brandMatched') = 'true') as brand_matched_count,
    COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.locationVerified') = 'true') as location_verified_count,
    COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected') = 'true') as substitution_detected_count,
    ROUND((COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.brandMatched') = 'true') * 100.0 / COUNT(*)), 1) as brand_match_pct,
    ROUND((COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.locationVerified') = 'true') * 100.0 / COUNT(*)), 1) as location_verified_pct,
    ROUND((COUNT(*) FILTER (WHERE JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected') = 'true') * 100.0 / COUNT(*)), 1) as substitution_detected_pct
FROM dbo.fact_transactions_location
WHERE payload_json IS NOT NULL;

-- 5. Data Quality Score Distribution
SELECT
    'Quality Score Distribution' as validation_category,
    CASE
        WHEN data_quality_score >= 90 THEN 'Excellent (90-100)'
        WHEN data_quality_score >= 70 THEN 'Good (70-89)'
        WHEN data_quality_score >= 50 THEN 'Fair (50-69)'
        ELSE 'Poor (<50)'
    END as quality_tier,
    COUNT(*) as transaction_count,
    AVG(data_quality_score) as avg_score_in_tier,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 1) as percentage_of_total
FROM dbo.fact_transactions_location
GROUP BY
    CASE
        WHEN data_quality_score >= 90 THEN 'Excellent (90-100)'
        WHEN data_quality_score >= 70 THEN 'Good (70-89)'
        WHEN data_quality_score >= 50 THEN 'Fair (50-69)'
        ELSE 'Poor (<50)'
    END
ORDER BY avg_score_in_tier DESC;

*/

-- ==========================================
-- POSTGRESQL/SUPABASE VALIDATION QUERIES
-- ==========================================

/*
-- Execute these on PostgreSQL/Supabase after running JSONB payload transformation

-- 1. Basic JSONB Structure Validation
SELECT
    'JSONB Structure Validation' as validation_category,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE payload_json IS NOT NULL) as valid_json_records,
    COUNT(*) FILTER (WHERE payload_json ->> 'transactionId' IS NOT NULL) as with_transaction_id,
    COUNT(*) FILTER (WHERE payload_json -> 'basket' -> 'items' IS NOT NULL) as with_basket_items,
    COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' IS NOT NULL) as with_location_data,
    ROUND((COUNT(*) FILTER (WHERE payload_json IS NOT NULL) * 100.0 / COUNT(*)), 1) as json_validity_pct
FROM fact_transactions_location;

-- 2. Basket Items Analysis
WITH basket_analysis AS (
    SELECT
        canonical_tx_id,
        payload_json ->> 'transactionId' as transaction_id,
        (payload_json ->> 'storeId')::INTEGER as store_id,
        jsonb_array_length(payload_json -> 'basket' -> 'items') as item_count,
        (SELECT SUM((item ->> 'totalPrice')::DECIMAL(10,2))
         FROM jsonb_array_elements(payload_json -> 'basket' -> 'items') as item) as calculated_total,
        (SELECT COUNT(*)
         FROM jsonb_array_elements(payload_json -> 'basket' -> 'items') as item
         WHERE (item ->> 'substitutionEvent')::BOOLEAN = TRUE) as substitution_items
    FROM fact_transactions_location
    WHERE payload_json IS NOT NULL
)
SELECT
    'Basket Analysis' as validation_category,
    AVG(item_count) as avg_items_per_transaction,
    AVG(calculated_total) as avg_transaction_value,
    SUM(substitution_items) as total_substitution_items,
    COUNT(*) FILTER (WHERE substitution_items > 0) as transactions_with_substitutions,
    ROUND((COUNT(*) FILTER (WHERE substitution_items > 0) * 100.0 / COUNT(*)), 1) as substitution_rate_pct
FROM basket_analysis;

-- 3. Geographic Data Validation
SELECT
    'Geographic Validation' as validation_category,
    payload_json -> 'location' ->> 'region' as region,
    payload_json -> 'location' ->> 'province' as province,
    payload_json -> 'location' ->> 'municipality' as municipality,
    COUNT(*) as transaction_count,
    AVG((payload_json -> 'location' -> 'geo' ->> 'lat')::DECIMAL(10,8)) as avg_latitude,
    AVG((payload_json -> 'location' -> 'geo' ->> 'lon')::DECIMAL(11,8)) as avg_longitude,
    COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::BOOLEAN = TRUE) as location_verified_count
FROM fact_transactions_location
WHERE payload_json IS NOT NULL
GROUP BY
    payload_json -> 'location' ->> 'region',
    payload_json -> 'location' ->> 'province',
    payload_json -> 'location' ->> 'municipality'
ORDER BY transaction_count DESC;

-- 4. Quality Flags Summary
SELECT
    'Quality Flags Summary' as validation_category,
    COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'brandMatched')::BOOLEAN = TRUE) as brand_matched_count,
    COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::BOOLEAN = TRUE) as location_verified_count,
    COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'substitutionDetected')::BOOLEAN = TRUE) as substitution_detected_count,
    ROUND((COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'brandMatched')::BOOLEAN = TRUE) * 100.0 / COUNT(*)), 1) as brand_match_pct,
    ROUND((COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::BOOLEAN = TRUE) * 100.0 / COUNT(*)), 1) as location_verified_pct,
    ROUND((COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'substitutionDetected')::BOOLEAN = TRUE) * 100.0 / COUNT(*)), 1) as substitution_detected_pct
FROM fact_transactions_location
WHERE payload_json IS NOT NULL;

-- 5. Data Quality Score Distribution
SELECT
    'Quality Score Distribution' as validation_category,
    CASE
        WHEN data_quality_score >= 90 THEN 'Excellent (90-100)'
        WHEN data_quality_score >= 70 THEN 'Good (70-89)'
        WHEN data_quality_score >= 50 THEN 'Fair (50-69)'
        ELSE 'Poor (<50)'
    END as quality_tier,
    COUNT(*) as transaction_count,
    AVG(data_quality_score) as avg_score_in_tier,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 1) as percentage_of_total
FROM fact_transactions_location
GROUP BY
    CASE
        WHEN data_quality_score >= 90 THEN 'Excellent (90-100)'
        WHEN data_quality_score >= 70 THEN 'Good (70-89)'
        WHEN data_quality_score >= 50 THEN 'Fair (50-69)'
        ELSE 'Poor (<50)'
    END
ORDER BY avg_score_in_tier DESC;

*/

-- ==========================================
-- CROSS-PLATFORM COMPARISON QUERIES
-- ==========================================

/*
-- These queries help compare results between Azure SQL and PostgreSQL implementations

-- Expected Results Comparison Template:
--
-- Metric                     | Azure SQL    | PostgreSQL   | Variance
-- ---------------------------|-------------|-------------|----------
-- Total Transactions        | 13,149      | 13,149      | 0%
-- Avg Items per Transaction  | 2.1         | 2.1         | 0%
-- Substitution Rate          | 18.2%       | 18.2%       | 0%
-- Location Coverage          | 73.1%       | 73.1%       | 0%
-- Avg Quality Score          | 78.5        | 78.5        | 0%

-- Success Criteria:
-- ✅ <1% variance in numeric metrics
-- ✅ 100% JSON structure validity
-- ✅ >70% location coverage
-- ✅ >70% average quality score
-- ✅ ~18% substitution detection rate
*/

-- ==========================================
-- SAMPLE JSON PAYLOAD EXAMPLES
-- ==========================================

/*
-- Azure SQL - Sample JSON extraction
SELECT TOP 3
    canonical_tx_id,
    JSON_VALUE(payload_json, '$.transactionId') as transaction_id,
    JSON_VALUE(payload_json, '$.storeId') as store_id,
    JSON_VALUE(payload_json, '$.location.municipality') as municipality,
    JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected') as has_substitution,
    LEFT(payload_json, 200) + '...' as sample_payload
FROM dbo.fact_transactions_location
WHERE payload_json IS NOT NULL
ORDER BY data_quality_score DESC;

-- PostgreSQL - Sample JSONB extraction
SELECT
    canonical_tx_id,
    payload_json ->> 'transactionId' as transaction_id,
    (payload_json ->> 'storeId')::INTEGER as store_id,
    payload_json -> 'location' ->> 'municipality' as municipality,
    (payload_json -> 'qualityFlags' ->> 'substitutionDetected')::BOOLEAN as has_substitution,
    LEFT(payload_json::TEXT, 200) || '...' as sample_payload
FROM fact_transactions_location
WHERE payload_json IS NOT NULL
ORDER BY data_quality_score DESC
LIMIT 3;
*/

-- ==========================================
-- VALIDATION CHECKLIST
-- ==========================================

/*
JSON Payload Validation Checklist:

□ Data Structure
  □ All records have valid JSON/JSONB
  □ Required fields present (transactionId, storeId, basket.items)
  □ Proper nesting structure maintained

□ Data Completeness
  □ Transaction count matches expected (13,149 or range)
  □ Basket items properly aggregated
  □ Location data mapped for >70% of records

□ Data Quality
  □ Quality scores calculated correctly
  □ Geographic coordinates within NCR bounds
  □ Substitution detection matches audio analysis

□ Performance
  □ JSON queries execute in <500ms
  □ Indexes utilized effectively
  □ Memory usage acceptable

□ Cross-Platform Consistency
  □ Azure SQL and PostgreSQL results match
  □ <1% variance in calculated metrics
  □ JSON structure identical

Success Criteria:
- ✅ JSON validity: 100%
- ✅ Location coverage: >70%
- ✅ Average quality score: >70
- ✅ Substitution rate: ~18%
- ✅ Query performance: <500ms
*/