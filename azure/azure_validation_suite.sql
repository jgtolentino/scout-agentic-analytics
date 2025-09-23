/* ==========================================
   Azure SQL Validation Suite
   Comprehensive testing for Scout Edge fact_transactions_location
   ========================================== */

PRINT N'🧪 AZURE SQL VALIDATION SUITE - Scout Edge Fact Table'
PRINT N'======================================================'

SET NOCOUNT ON;
GO

-- 0) FAST SMOKE TEST (Does it even run?)
-- ==========================================

PRINT N'🧪 FAST SMOKE TEST - Basic functionality validation'
PRINT N'=================================================='

DECLARE @table_count INT;
SELECT @table_count = COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN ('fact_transactions_location', 'fact_transaction_items', 'dim_ncr_stores')
AND TABLE_SCHEMA = 'dbo';

IF @table_count = 3
    PRINT N'✅ SMOKE TEST: All 3 tables exist'
ELSE
BEGIN
    PRINT N'❌ SMOKE TEST FAILED: Missing tables (found ' + CAST(@table_count AS NVARCHAR(10)) + ')'
    RAISERROR('Smoke test failed', 16, 1);
    RETURN;
END

-- Check if stored procedures exist
IF OBJECT_ID('dbo.sp_populate_fact_transactions_location', 'P') IS NOT NULL
    PRINT N'✅ SMOKE TEST: ETL stored procedure exists'
ELSE
    PRINT N'⚠️ SMOKE TEST: ETL stored procedure missing'

-- 1) CORE INVARIANTS VALIDATION
-- ==========================================

PRINT N''
PRINT N'📊 CORE INVARIANTS - Data integrity and completeness'
PRINT N'=================================================='

-- 1.1 Row count validation
DECLARE @row_count INT;
SELECT @row_count = COUNT(*) FROM dbo.fact_transactions_location;

PRINT N'1.1 Row count validation...'
PRINT N'Total rows loaded: ' + CAST(@row_count AS NVARCHAR(10))

IF @row_count BETWEEN 10000 AND 15000
    PRINT N'✅ Row count within expected range (10K-15K)'
ELSE IF @row_count > 0
    PRINT N'⚠️ Row count outside expected range: ' + CAST(@row_count AS NVARCHAR(10))
ELSE
BEGIN
    PRINT N'❌ No data loaded in fact table'
    RAISERROR('No data in fact table', 16, 1);
END

-- 1.2 Store coverage validation
PRINT N'1.2 Store coverage validation...'
SELECT
    'Store Coverage' as validation_type,
    store_id,
    municipality_name,
    COUNT(*) as transaction_count,
    CASE
        WHEN store_id IN (102, 103, 104, 108, 109, 110, 112) THEN '✅ Expected Store'
        ELSE '❌ Unexpected Store'
    END as status
FROM dbo.fact_transactions_location
GROUP BY store_id, municipality_name
ORDER BY store_id;

-- 1.3 Location rule enforcement
PRINT N'1.3 Location rule enforcement...'
DECLARE @missing_municipality INT, @missing_geometry INT;

SELECT
    @missing_municipality = SUM(CASE WHEN municipality_name IS NULL THEN 1 ELSE 0 END),
    @missing_geometry = SUM(CASE WHEN store_polygon IS NULL AND (geo_latitude IS NULL OR geo_longitude IS NULL) THEN 1 ELSE 0 END)
FROM dbo.fact_transactions_location;

IF @missing_municipality = 0 AND @missing_geometry = 0
    PRINT N'✅ Location rule enforced: All records have municipality AND (polygon OR coordinates)'
ELSE
BEGIN
    PRINT N'❌ Location rule violations: ' + CAST(@missing_municipality AS NVARCHAR(10)) + ' missing municipality, ' + CAST(@missing_geometry AS NVARCHAR(10)) + ' missing geometry'
    RAISERROR('Location rule violations found', 16, 1);
END

-- 1.4 Region/province validation
PRINT N'1.4 Region/province validation...'
SELECT
    'Region/Province' as validation_type,
    region,
    province_name,
    COUNT(*) as count,
    CASE
        WHEN region = 'NCR' AND province_name = 'Metro Manila' THEN '✅ Correct'
        ELSE '❌ Invalid'
    END as status
FROM dbo.fact_transactions_location
GROUP BY region, province_name;

-- 1.5 Transaction ID uniqueness
PRINT N'1.5 Transaction ID uniqueness...'
DECLARE @duplicate_count INT;

SELECT @duplicate_count = COUNT(*)
FROM (
    SELECT transaction_id, COUNT(*) as dup_cnt
    FROM dbo.fact_transactions_location
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
) duplicates;

IF @duplicate_count = 0
    PRINT N'✅ No duplicate transaction IDs found'
ELSE
BEGIN
    PRINT N'❌ Found ' + CAST(@duplicate_count AS NVARCHAR(10)) + ' duplicate transaction IDs'
    RAISERROR('Duplicate transaction IDs found', 16, 1);
END

-- 1.6 NCR geographic bounds validation
PRINT N'1.6 NCR geographic bounds validation...'
DECLARE @lat_oob INT, @lon_oob INT;

SELECT
    @lat_oob = SUM(CASE WHEN geo_latitude NOT BETWEEN 14.20 AND 14.90 THEN 1 ELSE 0 END),
    @lon_oob = SUM(CASE WHEN geo_longitude NOT BETWEEN 120.90 AND 121.20 THEN 1 ELSE 0 END)
FROM dbo.fact_transactions_location
WHERE geo_latitude IS NOT NULL AND geo_longitude IS NOT NULL;

IF @lat_oob = 0 AND @lon_oob = 0
    PRINT N'✅ All coordinates within NCR bounds'
ELSE
    PRINT N'⚠️ Coordinates outside NCR bounds: ' + CAST(@lat_oob AS NVARCHAR(10)) + ' latitude, ' + CAST(@lon_oob AS NVARCHAR(10)) + ' longitude'

-- 2) SUBSTITUTION EVENT VALIDATION
-- ==========================================

PRINT N''
PRINT N'🔄 SUBSTITUTION EVENT VALIDATION - Logic and consistency'
PRINT N'=================================================='

-- 2.1 Substitution logic consistency
PRINT N'2.1 Substitution logic consistency...'
DECLARE @logic_violations INT;

SELECT @logic_violations = COUNT(*)
FROM dbo.fact_transactions_location
WHERE substitution_occurred = 1
  AND (substitution_from IS NULL
       OR substitution_to IS NULL
       OR UPPER(substitution_from) = UPPER(substitution_to));

IF @logic_violations = 0
    PRINT N'✅ Substitution logic is consistent'
ELSE
BEGIN
    PRINT N'❌ Found ' + CAST(@logic_violations AS NVARCHAR(10)) + ' substitution logic violations'
    RAISERROR('Substitution logic violations found', 16, 1);
END

-- 2.2 Substitution rate analysis
PRINT N'2.2 Substitution rate analysis...'
SELECT
    'Substitution Distribution' as analysis_type,
    substitution_occurred,
    substitution_reason,
    COUNT(*) as count,
    CAST(ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) AS NVARCHAR(10)) + '%' as percentage
FROM dbo.fact_transactions_location
GROUP BY substitution_occurred, substitution_reason
ORDER BY substitution_occurred DESC, COUNT(*) DESC;

-- 2.3 False negative detection
PRINT N'2.3 False negative detection...'
DECLARE @false_negatives INT;

SELECT @false_negatives = COUNT(*)
FROM dbo.fact_transactions_location
WHERE substitution_occurred = 0
  AND substitution_from IS NOT NULL
  AND substitution_to IS NOT NULL
  AND UPPER(substitution_from) != UPPER(substitution_to);

IF @false_negatives = 0
    PRINT N'✅ No false negatives detected'
ELSE
    PRINT N'⚠️ Found ' + CAST(@false_negatives AS NVARCHAR(10)) + ' potential false negatives'

-- 2.4 Substitution sample for manual QA
PRINT N'2.4 Substitution sample for manual QA...'
SELECT TOP 5
    'Manual QA Sample' as sample_type,
    transaction_id,
    store_id,
    municipality_name,
    LEFT(ISNULL(audio_transcript, ''), 50) + '...' as transcript_sample,
    substitution_from,
    substitution_to,
    substitution_reason,
    brand_switching_score
FROM dbo.fact_transactions_location
WHERE substitution_occurred = 1
  AND audio_transcript IS NOT NULL
ORDER BY processed_at DESC;

-- 3) PRIVACY COMPLIANCE VALIDATION
-- ==========================================

PRINT N''
PRINT N'🔒 PRIVACY COMPLIANCE VALIDATION - Data protection verification'
PRINT N'=================================================='

-- 3.1 Audio storage compliance
PRINT N'3.1 Audio storage compliance...'
DECLARE @audio_violations INT, @total_records INT;

SELECT
    @audio_violations = COUNT(*) - COUNT(CASE WHEN audio_stored = 0 THEN 1 END),
    @total_records = COUNT(*)
FROM dbo.fact_transactions_location;

IF @audio_violations = 0
    PRINT N'✅ Full audio privacy compliance: 0/' + CAST(@total_records AS NVARCHAR(10)) + ' records store audio'
ELSE
BEGIN
    PRINT N'❌ Audio privacy violations: ' + CAST(@audio_violations AS NVARCHAR(10)) + '/' + CAST(@total_records AS NVARCHAR(10)) + ' records store audio'
    RAISERROR('Audio privacy violations found', 16, 1);
END

-- 3.2 Facial recognition compliance
PRINT N'3.2 Facial recognition compliance...'
DECLARE @facial_violations INT;

SELECT @facial_violations = COUNT(*) - COUNT(CASE WHEN facial_recognition = 0 THEN 1 END)
FROM dbo.fact_transactions_location;

IF @facial_violations = 0
    PRINT N'✅ Full facial recognition compliance: 0/' + CAST(@total_records AS NVARCHAR(10)) + ' records use facial recognition'
ELSE
BEGIN
    PRINT N'❌ Facial recognition violations: ' + CAST(@facial_violations AS NVARCHAR(10)) + '/' + CAST(@total_records AS NVARCHAR(10)) + ' records use facial recognition'
    RAISERROR('Facial recognition violations found', 16, 1);
END

-- 3.3 Check for emotion columns (should not exist)
PRINT N'3.3 Emotion column check...'
DECLARE @emotion_columns INT;

SELECT @emotion_columns = COUNT(*)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_transactions_location'
AND COLUMN_NAME LIKE '%emotion%';

IF @emotion_columns = 0
    PRINT N'✅ No emotion columns found (privacy compliant)'
ELSE
BEGIN
    PRINT N'❌ Found ' + CAST(@emotion_columns AS NVARCHAR(10)) + ' emotion-related columns'
    RAISERROR('Emotion columns found - privacy violation', 16, 1);
END

-- 4) ITEM-LEVEL VALIDATION
-- ==========================================

PRINT N''
PRINT N'🛍️ ITEM-LEVEL VALIDATION - Normalized data integrity'
PRINT N'=================================================='

-- 4.1 Items relationship integrity
PRINT N'4.1 Items relationship integrity...'
DECLARE @total_transactions INT, @transactions_with_items INT, @total_items INT;

SELECT @total_transactions = COUNT(*) FROM dbo.fact_transactions_location;
SELECT @transactions_with_items = COUNT(DISTINCT canonical_tx_id) FROM dbo.fact_transaction_items;
SELECT @total_items = COUNT(*) FROM dbo.fact_transaction_items;

PRINT N'Items integrity: ' + CAST(@transactions_with_items AS NVARCHAR(10)) + '/' + CAST(@total_transactions AS NVARCHAR(10)) + ' transactions have items (avg ' + CAST(CAST(@total_items AS FLOAT) / @total_transactions AS NVARCHAR(10)) + ' items/tx)'

IF @transactions_with_items = @total_transactions
    PRINT N'✅ All transactions have item records'
ELSE
    PRINT N'⚠️ ' + CAST((@total_transactions - @transactions_with_items) AS NVARCHAR(10)) + '/' + CAST(@total_transactions AS NVARCHAR(10)) + ' transactions missing item records'

-- 4.2 Item brand data quality
PRINT N'4.2 Item brand data quality...'
SELECT
    'Item Data Quality' as quality_type,
    COUNT(*) as total_items,
    SUM(CASE WHEN brand_name IS NOT NULL THEN 1 ELSE 0 END) as items_with_brands,
    CAST(ROUND((SUM(CASE WHEN brand_name IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 1) AS NVARCHAR(10)) + '%' as brand_coverage,
    SUM(CASE WHEN category IS NOT NULL THEN 1 ELSE 0 END) as items_with_categories,
    CAST(ROUND((SUM(CASE WHEN category IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 1) AS NVARCHAR(10)) + '%' as category_coverage
FROM dbo.fact_transaction_items;

-- 5) BUSINESS LOGIC VALIDATION
-- ==========================================

PRINT N''
PRINT N'💰 BUSINESS LOGIC VALIDATION - Transaction totals and consistency'
PRINT N'=================================================='

-- 5.1 Transaction totals consistency
PRINT N'5.1 Transaction totals consistency...'
WITH transaction_totals AS (
    SELECT
        ft.canonical_tx_id,
        ft.total_amount as transaction_total,
        ft.total_items as transaction_item_count,
        ISNULL(SUM(fi.total_price), 0) as items_sum,
        COUNT(fi.item_id) as items_count
    FROM dbo.fact_transactions_location ft
    LEFT JOIN dbo.fact_transaction_items fi ON ft.canonical_tx_id = fi.canonical_tx_id
    GROUP BY ft.canonical_tx_id, ft.total_amount, ft.total_items
)
SELECT
    'Transaction Consistency' as validation_type,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN ABS(transaction_total - items_sum) < 0.01 THEN 1 ELSE 0 END) as matching_totals,
    CAST(ROUND((SUM(CASE WHEN ABS(transaction_total - items_sum) < 0.01 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 1) AS NVARCHAR(10)) + '%' as total_accuracy,
    SUM(CASE WHEN transaction_item_count = items_count THEN 1 ELSE 0 END) as matching_item_counts,
    CAST(ROUND((SUM(CASE WHEN transaction_item_count = items_count THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 1) AS NVARCHAR(10)) + '%' as count_accuracy,
    CASE
        WHEN SUM(CASE WHEN ABS(transaction_total - items_sum) < 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.95 THEN '✅ High Accuracy'
        WHEN SUM(CASE WHEN ABS(transaction_total - items_sum) < 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.80 THEN '⚠️ Acceptable'
        ELSE '❌ Poor Accuracy'
    END as status
FROM transaction_totals;

-- 5.2 Amount validation
PRINT N'5.2 Amount validation...'
SELECT
    'Amount Validation' as validation_type,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN total_amount < 0 THEN 1 ELSE 0 END) as negative_amounts,
    SUM(CASE WHEN total_amount = 0 THEN 1 ELSE 0 END) as zero_amounts,
    SUM(CASE WHEN total_amount > 10000 THEN 1 ELSE 0 END) as high_amounts,
    MIN(total_amount) as min_amount,
    MAX(total_amount) as max_amount,
    CAST(ROUND(AVG(total_amount), 2) AS DECIMAL(10,2)) as avg_amount,
    CASE
        WHEN SUM(CASE WHEN total_amount < 0 THEN 1 ELSE 0 END) = 0 THEN '✅ No Negative Amounts'
        ELSE '❌ Found Negative Amounts'
    END as status
FROM dbo.fact_transactions_location;

-- 6) PERFORMANCE VALIDATION
-- ==========================================

PRINT N''
PRINT N'⚡ PERFORMANCE VALIDATION - Index usage and query speed'
PRINT N'=================================================='

-- 6.1 Index usage verification
PRINT N'6.1 Index usage verification...'
PRINT N'Testing query performance with indexes...'

DECLARE @start_time DATETIME2 = SYSDATETIME();

SELECT store_id, municipality_name, COUNT(*) as count, AVG(total_amount) as avg_amount
FROM dbo.fact_transactions_location
WHERE substitution_occurred = 1
  AND store_id IN (102, 103, 104)
GROUP BY store_id, municipality_name
ORDER BY store_id;

DECLARE @end_time DATETIME2 = SYSDATETIME();
DECLARE @duration_ms INT = DATEDIFF(MILLISECOND, @start_time, @end_time);

PRINT N'Query completed in ' + CAST(@duration_ms AS NVARCHAR(10)) + ' milliseconds'

IF @duration_ms < 1000
    PRINT N'✅ Query performance acceptable (<1 second)'
ELSE
    PRINT N'⚠️ Query performance may need optimization (>' + CAST(@duration_ms/1000.0 AS NVARCHAR(10)) + ' seconds)'

-- 7) OVERALL DATA QUALITY SCORE
-- ==========================================

PRINT N''
PRINT N'🎯 OVERALL DATA QUALITY SCORE - Comprehensive assessment'
PRINT N'=================================================='

DECLARE @checks_passed INT = 0;
DECLARE @total_checks INT = 10;
DECLARE @quality_score DECIMAL(4,1);
DECLARE @overall_status NVARCHAR(100);

-- Perform all quality checks and count passes
DECLARE @check_results TABLE (
    check_name NVARCHAR(50),
    passed BIT
);

-- Check 1: Row count
INSERT INTO @check_results
SELECT 'row_count',
       CASE WHEN COUNT(*) BETWEEN 10000 AND 15000 THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location;

-- Check 2: No null critical fields
INSERT INTO @check_results
SELECT 'no_null_critical_fields',
       CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location
WHERE canonical_tx_id IS NULL OR transaction_id IS NULL OR device_id IS NULL OR store_id IS NULL OR total_amount IS NULL;

-- Check 3: Unique canonical IDs
INSERT INTO @check_results
SELECT 'unique_canonical_ids',
       CASE WHEN COUNT(*) = COUNT(DISTINCT canonical_tx_id) THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location;

-- Check 4: No negative amounts
INSERT INTO @check_results
SELECT 'no_negative_amounts',
       CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location
WHERE total_amount < 0;

-- Check 5: NCR region coverage
INSERT INTO @check_results
SELECT 'ncr_region_coverage',
       CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM dbo.fact_transactions_location WHERE region = 'NCR') THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location;

-- Check 6: Privacy compliance (audio)
INSERT INTO @check_results
SELECT 'audio_privacy_compliance',
       CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location
WHERE audio_stored = 1;

-- Check 7: Privacy compliance (facial)
INSERT INTO @check_results
SELECT 'facial_privacy_compliance',
       CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location
WHERE facial_recognition = 1;

-- Check 8: No emotion columns
INSERT INTO @check_results
SELECT 'no_emotion_columns',
       CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_transactions_location' AND COLUMN_NAME LIKE '%emotion%';

-- Check 9: Location rule compliance
INSERT INTO @check_results
SELECT 'location_rule_compliance',
       CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location
WHERE municipality_name IS NULL OR (store_polygon IS NULL AND (geo_latitude IS NULL OR geo_longitude IS NULL));

-- Check 10: Store coverage
INSERT INTO @check_results
SELECT 'store_coverage',
       CASE WHEN COUNT(DISTINCT store_id) = 7 THEN 1 ELSE 0 END
FROM dbo.fact_transactions_location;

-- Calculate final score
SELECT @checks_passed = SUM(CAST(passed AS INT)) FROM @check_results;
SET @quality_score = (@checks_passed * 100.0) / @total_checks;

-- Determine overall status
SET @overall_status = CASE
    WHEN @checks_passed = @total_checks THEN '🎉 EXCELLENT - All validations passed'
    WHEN @quality_score >= 90 THEN '✅ GOOD - Most validations passed'
    WHEN @quality_score >= 70 THEN '⚠️ ACCEPTABLE - Some issues found'
    ELSE '❌ POOR - Multiple validation failures'
END;

PRINT N''
PRINT N'=== FINAL DATA QUALITY ASSESSMENT ==='
PRINT N'Checks Passed: ' + CAST(@checks_passed AS NVARCHAR(10)) + '/' + CAST(@total_checks AS NVARCHAR(10))
PRINT N'Quality Score: ' + CAST(@quality_score AS NVARCHAR(10)) + '%'
PRINT N'Overall Status: ' + @overall_status
PRINT N''

-- Display individual check results
PRINT N'Individual Check Results:'
SELECT
    check_name,
    CASE WHEN passed = 1 THEN '✅ PASS' ELSE '❌ FAIL' END as result
FROM @check_results
ORDER BY check_name;

PRINT N'======================================'

-- 8) CREATE MONITORING FUNCTION
-- ==========================================

IF OBJECT_ID('dbo.fn_quick_data_quality_check', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_quick_data_quality_check;
GO

CREATE FUNCTION dbo.fn_quick_data_quality_check()
RETURNS @results TABLE (
    check_category NVARCHAR(50),
    check_name NVARCHAR(50),
    status NVARCHAR(20),
    details NVARCHAR(200)
)
AS
BEGIN
    -- Row count check
    INSERT INTO @results
    SELECT
        'Completeness',
        'Record Count',
        CASE WHEN COUNT(*) BETWEEN 10000 AND 15000 THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Records: ' + CAST(COUNT(*) AS NVARCHAR(10))
    FROM dbo.fact_transactions_location;

    -- Substitution rate check
    INSERT INTO @results
    SELECT
        'Business Logic',
        'Substitution Rate',
        CASE WHEN SUM(CASE WHEN substitution_occurred = 1 THEN 1 ELSE 0 END) BETWEEN 1000 AND 5000
             THEN '✅ PASS' ELSE '⚠️ WARNING' END,
        'Substitutions: ' + CAST(SUM(CASE WHEN substitution_occurred = 1 THEN 1 ELSE 0 END) AS NVARCHAR(10)) +
        ' (' + CAST(ROUND((SUM(CASE WHEN substitution_occurred = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 1) AS NVARCHAR(10)) + '%)'
    FROM dbo.fact_transactions_location;

    -- Privacy compliance check
    INSERT INTO @results
    SELECT
        'Privacy',
        'Audio/Facial Compliance',
        CASE WHEN SUM(CASE WHEN audio_stored = 1 OR facial_recognition = 1 THEN 1 ELSE 0 END) = 0
             THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Violations: Audio=' + CAST(SUM(CASE WHEN audio_stored = 1 THEN 1 ELSE 0 END) AS NVARCHAR(10)) +
        ', Facial=' + CAST(SUM(CASE WHEN facial_recognition = 1 THEN 1 ELSE 0 END) AS NVARCHAR(10))
    FROM dbo.fact_transactions_location;

    -- Location coverage check
    INSERT INTO @results
    SELECT
        'Data Quality',
        'Location Coverage',
        CASE WHEN SUM(CASE WHEN municipality_name IS NULL THEN 1 ELSE 0 END) = 0
             THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Missing municipalities: ' + CAST(SUM(CASE WHEN municipality_name IS NULL THEN 1 ELSE 0 END) AS NVARCHAR(10))
    FROM dbo.fact_transactions_location;

    RETURN;
END;
GO

PRINT N''
PRINT N'🚀 AZURE SQL VALIDATION SUITE COMPLETE'
PRINT N'Use: SELECT * FROM dbo.fn_quick_data_quality_check(); for ongoing monitoring'
PRINT N''
GO