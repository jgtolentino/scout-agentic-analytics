-- File: sql/03_json_diagnostics.sql
-- JSON Diagnostics for PayloadTransactions
-- Purpose: Identify malformed JSON and patterns in payload_json failures

-- Batch 1: JSON Health Check
IF SCHEMA_ID('dbo') IS NULL THROW 50000,'dbo schema missing',1;
GO

-- Check JSON validity across PayloadTransactions
SELECT
    'JSON Validity Summary' as check_type,
    COUNT(*) as total_records,
    SUM(CASE WHEN ISJSON(payload_json) = 1 THEN 1 ELSE 0 END) as valid_json_count,
    SUM(CASE WHEN ISJSON(payload_json) = 0 THEN 1 ELSE 0 END) as invalid_json_count,
    CAST(SUM(CASE WHEN ISJSON(payload_json) = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS decimal(5,2)) as valid_percentage
FROM dbo.PayloadTransactions;

-- Sample of invalid JSON records for pattern analysis
SELECT TOP 10
    'Invalid JSON Samples' as check_type,
    pt.id,
    pt.sessionId,
    pt.storeId,
    pt.deviceId,
    LEN(pt.payload_json) as payload_length,
    LEFT(pt.payload_json, 200) as payload_sample,
    pt.createdAt
FROM dbo.PayloadTransactions pt
WHERE ISJSON(pt.payload_json) = 0
ORDER BY pt.createdAt DESC;

-- Analyze payload_json patterns
SELECT
    'JSON Pattern Analysis' as check_type,
    CASE
        WHEN payload_json IS NULL THEN 'NULL'
        WHEN LEN(payload_json) = 0 THEN 'EMPTY'
        WHEN LEFT(LTRIM(payload_json), 1) != '{' THEN 'NOT_OBJECT'
        WHEN RIGHT(RTRIM(payload_json), 1) != '}' THEN 'INCOMPLETE_OBJECT'
        WHEN CHARINDEX('""', payload_json) > 0 THEN 'DOUBLE_QUOTES'
        WHEN CHARINDEX(CHAR(13), payload_json) > 0 OR CHARINDEX(CHAR(10), payload_json) > 0 THEN 'CONTAINS_NEWLINES'
        WHEN CHARINDEX('\', payload_json) > 0 THEN 'CONTAINS_BACKSLASH'
        ELSE 'OTHER_INVALID'
    END as pattern_type,
    COUNT(*) as occurrence_count
FROM dbo.PayloadTransactions pt
WHERE ISJSON(pt.payload_json) = 0
GROUP BY
    CASE
        WHEN payload_json IS NULL THEN 'NULL'
        WHEN LEN(payload_json) = 0 THEN 'EMPTY'
        WHEN LEFT(LTRIM(payload_json), 1) != '{' THEN 'NOT_OBJECT'
        WHEN RIGHT(RTRIM(payload_json), 1) != '}' THEN 'INCOMPLETE_OBJECT'
        WHEN CHARINDEX('""', payload_json) > 0 THEN 'DOUBLE_QUOTES'
        WHEN CHARINDEX(CHAR(13), payload_json) > 0 OR CHARINDEX(CHAR(10), payload_json) > 0 THEN 'CONTAINS_NEWLINES'
        WHEN CHARINDEX('\', payload_json) > 0 THEN 'CONTAINS_BACKSLASH'
        ELSE 'OTHER_INVALID'
    END
ORDER BY occurrence_count DESC;

-- Test specific JSON path extractions against valid records
SELECT
    'JSON Path Validation' as check_type,
    COUNT(*) as total_valid_records,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.transactionId') IS NOT NULL THEN 1 ELSE 0 END) as has_transaction_id,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.items[0].brandName') IS NOT NULL THEN 1 ELSE 0 END) as has_brand_name,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.items[0].productName') IS NOT NULL THEN 1 ELSE 0 END) as has_product_name,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.items[0].category') IS NOT NULL THEN 1 ELSE 0 END) as has_category,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.totals.totalAmount') IS NOT NULL THEN 1 ELSE 0 END) as has_total_amount,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.totals.totalItems') IS NOT NULL THEN 1 ELSE 0 END) as has_total_items,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.transactionContext.paymentMethod') IS NOT NULL THEN 1 ELSE 0 END) as has_payment_method,
    SUM(CASE WHEN JSON_VALUE(payload_json,'$.transactionContext.audioTranscript') IS NOT NULL THEN 1 ELSE 0 END) as has_audio_transcript
FROM dbo.PayloadTransactions pt
WHERE ISJSON(pt.payload_json) = 1;

-- Store and device breakdown for invalid JSON
SELECT
    'Invalid JSON by Store/Device' as check_type,
    pt.storeId,
    pt.deviceId,
    COUNT(*) as invalid_count,
    MIN(pt.createdAt) as first_occurrence,
    MAX(pt.createdAt) as last_occurrence
FROM dbo.PayloadTransactions pt
WHERE ISJSON(pt.payload_json) = 0
GROUP BY pt.storeId, pt.deviceId
ORDER BY invalid_count DESC;

-- Time-based analysis of JSON validity
SELECT
    'JSON Validity by Date' as check_type,
    CAST(pt.createdAt AS date) as date_created,
    COUNT(*) as total_records,
    SUM(CASE WHEN ISJSON(pt.payload_json) = 1 THEN 1 ELSE 0 END) as valid_json_count,
    SUM(CASE WHEN ISJSON(pt.payload_json) = 0 THEN 1 ELSE 0 END) as invalid_json_count,
    CAST(SUM(CASE WHEN ISJSON(pt.payload_json) = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS decimal(5,2)) as valid_percentage
FROM dbo.PayloadTransactions pt
WHERE pt.createdAt >= DATEADD(day, -30, GETDATE()) -- Last 30 days
GROUP BY CAST(pt.createdAt AS date)
ORDER BY date_created DESC;

GO

-- Batch 2: Production View Impact Analysis
-- Test the updated views to ensure they handle malformed JSON gracefully

SELECT
    'Production View Test' as check_type,
    'Testing v_transactions_flat_production with malformed JSON handling' as description;

-- Count records that would be processed vs skipped
SELECT
    'View Processing Summary' as check_type,
    COUNT(*) as total_payloadtransactions,
    SUM(CASE WHEN ISJSON(pt.payload_json) = 1 THEN 1 ELSE 0 END) as processable_records,
    SUM(CASE WHEN ISJSON(pt.payload_json) = 0 THEN 1 ELSE 0 END) as skipped_records,
    CAST(SUM(CASE WHEN ISJSON(pt.payload_json) = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS decimal(5,2)) as processing_success_rate
FROM dbo.PayloadTransactions pt;

-- Test the updated view with a small sample
SELECT TOP 10
    'Updated View Sample' as check_type,
    v.canonical_tx_id,
    v.brand,
    v.product_name,
    v.category,
    v.total_amount,
    v.total_items,
    v.payment_method,
    v.txn_ts
FROM dbo.v_transactions_flat_production v
ORDER BY v.txn_ts DESC;

GO

-- Batch 3: Upstream Data Quality Recommendations
SELECT
    'Data Quality Recommendations' as check_type,
    'Based on diagnostic results, consider the following upstream fixes:' as description;

-- Common malformed JSON patterns for upstream fixing
WITH malformed_patterns AS (
    SELECT
        pt.storeId,
        pt.deviceId,
        CASE
            WHEN payload_json IS NULL THEN 'Null payload - check data collection'
            WHEN LEN(payload_json) = 0 THEN 'Empty payload - verify transaction completion'
            WHEN LEFT(LTRIM(payload_json), 1) != '{' THEN 'Invalid JSON start - check serialization'
            WHEN RIGHT(RTRIM(payload_json), 1) != '}' THEN 'Truncated JSON - check transmission'
            WHEN CHARINDEX('""', payload_json) > 0 THEN 'Double quote escape issue'
            WHEN CHARINDEX(CHAR(13), payload_json) > 0 OR CHARINDEX(CHAR(10), payload_json) > 0 THEN 'Newline character issue'
            ELSE 'Other JSON parsing error'
        END as issue_type,
        COUNT(*) as frequency
    FROM dbo.PayloadTransactions pt
    WHERE ISJSON(pt.payload_json) = 0
    GROUP BY
        pt.storeId,
        pt.deviceId,
        CASE
            WHEN payload_json IS NULL THEN 'Null payload - check data collection'
            WHEN LEN(payload_json) = 0 THEN 'Empty payload - verify transaction completion'
            WHEN LEFT(LTRIM(payload_json), 1) != '{' THEN 'Invalid JSON start - check serialization'
            WHEN RIGHT(RTRIM(payload_json), 1) != '}' THEN 'Truncated JSON - check transmission'
            WHEN CHARINDEX('""', payload_json) > 0 THEN 'Double quote escape issue'
            WHEN CHARINDEX(CHAR(13), payload_json) > 0 OR CHARINDEX(CHAR(10), payload_json) > 0 THEN 'Newline character issue'
            ELSE 'Other JSON parsing error'
        END
)
SELECT
    'Issue Priority Analysis' as check_type,
    issue_type,
    SUM(frequency) as total_occurrences,
    COUNT(DISTINCT storeId) as affected_stores,
    COUNT(DISTINCT deviceId) as affected_devices,
    CAST(SUM(frequency) * 100.0 / (SELECT COUNT(*) FROM dbo.PayloadTransactions WHERE ISJSON(payload_json) = 0) AS decimal(5,2)) as percentage_of_invalid
FROM malformed_patterns
GROUP BY issue_type
ORDER BY total_occurrences DESC;

GO