-- ==========================================
-- Scout Edge Data Quality Validation Queries
-- Comprehensive testing for fact_transactions_location
-- ==========================================

-- 1. DATA COMPLETENESS VALIDATION
-- ==========================================

-- Check total record count matches expected 13,149 transactions
SELECT
    'Record Count Validation' as validation_type,
    COUNT(*) as actual_count,
    13149 as expected_count,
    CASE
        WHEN COUNT(*) = 13149 THEN '✅ PASS'
        ELSE '❌ FAIL - Missing records'
    END as status
FROM fact_transactions_location;

-- Verify all 7 stores have data
SELECT
    'Store Coverage Validation' as validation_type,
    COUNT(DISTINCT store_id) as actual_stores,
    7 as expected_stores,
    STRING_AGG(DISTINCT store_id::TEXT, ', ' ORDER BY store_id::TEXT) as stores_with_data,
    CASE
        WHEN COUNT(DISTINCT store_id) = 7 THEN '✅ PASS'
        ELSE '❌ FAIL - Missing stores'
    END as status
FROM fact_transactions_location;

-- Check expected stores are present
SELECT
    'Expected Stores Present' as validation_type,
    store_id,
    municipality_name,
    COUNT(*) as transaction_count,
    CASE
        WHEN store_id IN (102, 103, 104, 108, 109, 110, 112) THEN '✅ Expected Store'
        ELSE '❌ Unexpected Store'
    END as status
FROM fact_transactions_location
GROUP BY store_id, municipality_name
ORDER BY store_id;

-- 2. DATA INTEGRITY VALIDATION
-- ==========================================

-- Check for null critical fields
SELECT
    'Critical Field Completeness' as validation_type,
    COUNT(*) FILTER (WHERE canonical_tx_id IS NULL) as null_canonical_ids,
    COUNT(*) FILTER (WHERE transaction_id IS NULL) as null_transaction_ids,
    COUNT(*) FILTER (WHERE device_id IS NULL) as null_device_ids,
    COUNT(*) FILTER (WHERE store_id IS NULL) as null_store_ids,
    COUNT(*) FILTER (WHERE total_amount IS NULL) as null_amounts,
    CASE
        WHEN COUNT(*) FILTER (WHERE canonical_tx_id IS NULL OR transaction_id IS NULL OR device_id IS NULL OR store_id IS NULL OR total_amount IS NULL) = 0
        THEN '✅ PASS'
        ELSE '❌ FAIL - Null critical fields found'
    END as status
FROM fact_transactions_location;

-- Validate canonical transaction ID uniqueness
SELECT
    'Canonical ID Uniqueness' as validation_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT canonical_tx_id) as unique_canonical_ids,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT canonical_tx_id) THEN '✅ PASS'
        ELSE '❌ FAIL - Duplicate canonical IDs'
    END as status
FROM fact_transactions_location;

-- Check for valid monetary amounts
SELECT
    'Amount Validation' as validation_type,
    COUNT(*) FILTER (WHERE total_amount < 0) as negative_amounts,
    COUNT(*) FILTER (WHERE total_amount = 0) as zero_amounts,
    COUNT(*) FILTER (WHERE total_amount > 10000) as suspiciously_high_amounts,
    MIN(total_amount) as min_amount,
    MAX(total_amount) as max_amount,
    AVG(total_amount)::DECIMAL(10,2) as avg_amount,
    CASE
        WHEN COUNT(*) FILTER (WHERE total_amount < 0) = 0 THEN '✅ PASS'
        ELSE '❌ FAIL - Negative amounts found'
    END as status
FROM fact_transactions_location;

-- 3. NCR LOCATION VALIDATION
-- ==========================================

-- Verify all transactions have NCR location data
SELECT
    'NCR Location Coverage' as validation_type,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE region = 'NCR') as ncr_transactions,
    COUNT(*) FILTER (WHERE province_name = 'Metro Manila') as metro_manila_transactions,
    COUNT(*) FILTER (WHERE municipality_name IS NOT NULL) as transactions_with_municipality,
    ROUND(
        (COUNT(*) FILTER (WHERE municipality_name IS NOT NULL)::DECIMAL / COUNT(*)) * 100,
        2
    ) as municipality_coverage_pct,
    CASE
        WHEN COUNT(*) FILTER (WHERE region = 'NCR') = COUNT(*) THEN '✅ PASS'
        ELSE '❌ FAIL - Non-NCR transactions found'
    END as status
FROM fact_transactions_location;

-- Validate municipality names are standardized
SELECT
    'Municipality Standardization' as validation_type,
    municipality_name,
    COUNT(*) as transaction_count,
    CASE
        WHEN municipality_name IN ('Manila', 'Quezon City', 'Makati', 'Pasig', 'Mandaluyong', 'Parañaque', 'Taguig')
        THEN '✅ Valid Municipality'
        ELSE '❌ Invalid Municipality'
    END as status
FROM fact_transactions_location
WHERE municipality_name IS NOT NULL
GROUP BY municipality_name
ORDER BY transaction_count DESC;

-- 4. SUBSTITUTION EVENT VALIDATION
-- ==========================================

-- Check substitution detection statistics
SELECT
    'Substitution Detection Stats' as validation_type,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions_detected,
    ROUND(
        (COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as substitution_rate_pct,
    COUNT(*) FILTER (WHERE audio_transcript IS NOT NULL AND LENGTH(audio_transcript) > 0) as transactions_with_transcript,
    ROUND(
        (COUNT(*) FILTER (WHERE audio_transcript IS NOT NULL AND LENGTH(audio_transcript) > 0)::DECIMAL / COUNT(*)) * 100,
        2
    ) as transcript_coverage_pct,
    CASE
        WHEN COUNT(*) FILTER (WHERE substitution_detected = TRUE) BETWEEN 1000 AND 5000
        THEN '✅ PASS - Expected substitution range'
        ELSE '⚠️ WARNING - Substitution rate outside expected range'
    END as status
FROM fact_transactions_location;

-- Validate substitution logic consistency
SELECT
    'Substitution Logic Consistency' as validation_type,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE AND substitution_reason IS NULL) as missing_substitution_reasons,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE AND brand_switching_score IS NULL) as missing_switching_scores,
    COUNT(*) FILTER (WHERE substitution_detected = FALSE AND substitution_reason IS NOT NULL) as false_negatives,
    CASE
        WHEN COUNT(*) FILTER (WHERE substitution_detected = TRUE AND substitution_reason IS NULL) = 0
        THEN '✅ PASS'
        ELSE '❌ FAIL - Inconsistent substitution data'
    END as status
FROM fact_transactions_location;

-- 5. PRIVACY COMPLIANCE VALIDATION
-- ==========================================

-- Check privacy settings compliance
SELECT
    'Privacy Compliance' as validation_type,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE audio_stored = FALSE) as audio_not_stored,
    COUNT(*) FILTER (WHERE facial_recognition = FALSE) as no_facial_recognition,
    COUNT(*) FILTER (WHERE anonymization_level = 'high') as high_anonymization,
    ROUND(
        (COUNT(*) FILTER (WHERE audio_stored = FALSE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as audio_privacy_compliance_pct,
    CASE
        WHEN COUNT(*) FILTER (WHERE audio_stored = FALSE) = COUNT(*)
        AND COUNT(*) FILTER (WHERE facial_recognition = FALSE) = COUNT(*)
        THEN '✅ PASS - Full privacy compliance'
        ELSE '❌ FAIL - Privacy violations detected'
    END as status
FROM fact_transactions_location;

-- 6. TECHNICAL METADATA VALIDATION
-- ==========================================

-- Verify Edge version consistency
SELECT
    'Edge Version Consistency' as validation_type,
    edge_version,
    COUNT(*) as transaction_count,
    ROUND((COUNT(*)::DECIMAL / SUM(COUNT(*)) OVER ()) * 100, 2) as percentage,
    CASE
        WHEN edge_version LIKE 'v2.0.0%' THEN '✅ Expected Version'
        ELSE '⚠️ Unexpected Version'
    END as status
FROM fact_transactions_location
WHERE edge_version IS NOT NULL
GROUP BY edge_version
ORDER BY transaction_count DESC;

-- Check processing methods presence
SELECT
    'Processing Methods Coverage' as validation_type,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE processing_methods IS NOT NULL) as with_processing_methods,
    COUNT(*) FILTER (WHERE 'stt_transcription' = ANY(processing_methods)) as with_stt_transcription,
    COUNT(*) FILTER (WHERE 'brand_detection' = ANY(processing_methods)) as with_brand_detection,
    ROUND(
        (COUNT(*) FILTER (WHERE processing_methods IS NOT NULL)::DECIMAL / COUNT(*)) * 100,
        2
    ) as processing_methods_coverage_pct,
    CASE
        WHEN COUNT(*) FILTER (WHERE processing_methods IS NOT NULL) > COUNT(*) * 0.95
        THEN '✅ PASS'
        ELSE '⚠️ WARNING - Low processing methods coverage'
    END as status
FROM fact_transactions_location;

-- 7. ITEM-LEVEL VALIDATION
-- ==========================================

-- Check items table relationship integrity
SELECT
    'Items Relationship Integrity' as validation_type,
    (SELECT COUNT(*) FROM fact_transactions_location) as total_transactions,
    (SELECT COUNT(DISTINCT canonical_tx_id) FROM fact_transaction_items) as transactions_with_items,
    (SELECT COUNT(*) FROM fact_transaction_items) as total_items,
    ROUND(
        (SELECT COUNT(*) FROM fact_transaction_items)::DECIMAL /
        (SELECT COUNT(*) FROM fact_transactions_location),
        2
    ) as avg_items_per_transaction,
    CASE
        WHEN (SELECT COUNT(DISTINCT canonical_tx_id) FROM fact_transaction_items) =
             (SELECT COUNT(*) FROM fact_transactions_location)
        THEN '✅ PASS - All transactions have items'
        ELSE '❌ FAIL - Missing item records'
    END as status;

-- Validate item-level brand data
SELECT
    'Item Brand Data Quality' as validation_type,
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE brand_name IS NOT NULL) as items_with_brands,
    COUNT(*) FILTER (WHERE category IS NOT NULL) as items_with_categories,
    COUNT(*) FILTER (WHERE unit_price > 0) as items_with_valid_prices,
    ROUND(
        (COUNT(*) FILTER (WHERE brand_name IS NOT NULL)::DECIMAL / COUNT(*)) * 100,
        2
    ) as brand_coverage_pct,
    CASE
        WHEN COUNT(*) FILTER (WHERE brand_name IS NOT NULL) > COUNT(*) * 0.90
        THEN '✅ PASS'
        ELSE '⚠️ WARNING - Low brand detection rate'
    END as status
FROM fact_transaction_items;

-- 8. BUSINESS LOGIC VALIDATION
-- ==========================================

-- Verify transaction totals match item sums
WITH transaction_totals AS (
    SELECT
        canonical_tx_id,
        total_amount as transaction_total,
        total_items as transaction_item_count,
        (SELECT SUM(total_price) FROM fact_transaction_items WHERE canonical_tx_id = ft.canonical_tx_id) as items_sum,
        (SELECT COUNT(*) FROM fact_transaction_items WHERE canonical_tx_id = ft.canonical_tx_id) as items_count
    FROM fact_transactions_location ft
)
SELECT
    'Transaction Totals Consistency' as validation_type,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE ABS(transaction_total - items_sum) < 0.01) as matching_totals,
    COUNT(*) FILTER (WHERE transaction_item_count = items_count) as matching_item_counts,
    ROUND(
        (COUNT(*) FILTER (WHERE ABS(transaction_total - items_sum) < 0.01)::DECIMAL / COUNT(*)) * 100,
        2
    ) as total_accuracy_pct,
    CASE
        WHEN COUNT(*) FILTER (WHERE ABS(transaction_total - items_sum) < 0.01) > COUNT(*) * 0.95
        THEN '✅ PASS'
        ELSE '❌ FAIL - Transaction total mismatches'
    END as status
FROM transaction_totals
WHERE items_sum IS NOT NULL;

-- 9. SUMMARY VALIDATION REPORT
-- ==========================================

-- Generate overall data quality score
WITH validation_results AS (
    SELECT 'Record Count' as check_name,
           CASE WHEN COUNT(*) = 13149 THEN 1 ELSE 0 END as passed
    FROM fact_transactions_location

    UNION ALL

    SELECT 'Store Coverage',
           CASE WHEN COUNT(DISTINCT store_id) = 7 THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    SELECT 'No Null Critical Fields',
           CASE WHEN COUNT(*) FILTER (WHERE canonical_tx_id IS NULL OR transaction_id IS NULL OR device_id IS NULL OR store_id IS NULL OR total_amount IS NULL) = 0 THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    SELECT 'Unique Canonical IDs',
           CASE WHEN COUNT(*) = COUNT(DISTINCT canonical_tx_id) THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    SELECT 'No Negative Amounts',
           CASE WHEN COUNT(*) FILTER (WHERE total_amount < 0) = 0 THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    SELECT 'NCR Region Coverage',
           CASE WHEN COUNT(*) FILTER (WHERE region = 'NCR') = COUNT(*) THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    SELECT 'Privacy Compliance',
           CASE WHEN COUNT(*) FILTER (WHERE audio_stored = FALSE AND facial_recognition = FALSE) = COUNT(*) THEN 1 ELSE 0 END
    FROM fact_transactions_location
)
SELECT
    'OVERALL DATA QUALITY SCORE' as validation_summary,
    SUM(passed) as checks_passed,
    COUNT(*) as total_checks,
    ROUND((SUM(passed)::DECIMAL / COUNT(*)) * 100, 1) as quality_score_pct,
    CASE
        WHEN SUM(passed) = COUNT(*) THEN '🎉 EXCELLENT - All validations passed'
        WHEN SUM(passed)::DECIMAL / COUNT(*) >= 0.9 THEN '✅ GOOD - Most validations passed'
        WHEN SUM(passed)::DECIMAL / COUNT(*) >= 0.7 THEN '⚠️ ACCEPTABLE - Some issues found'
        ELSE '❌ POOR - Multiple validation failures'
    END as overall_status
FROM validation_results;

-- 10. PERFORMANCE VALIDATION
-- ==========================================

-- Check query performance on key indexes
EXPLAIN (ANALYZE, BUFFERS)
SELECT store_id, municipality_name, COUNT(*), AVG(total_amount)
FROM fact_transactions_location
WHERE substitution_detected = TRUE
GROUP BY store_id, municipality_name;

-- Comments for documentation
COMMENT ON SCHEMA public IS 'Data quality validation queries for Scout Edge fact_transactions_location table';

-- Create validation summary function for regular monitoring
CREATE OR REPLACE FUNCTION validate_scout_data_quality()
RETURNS TABLE (
    check_category TEXT,
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'Completeness'::TEXT,
        'Record Count'::TEXT,
        CASE WHEN COUNT(*) = 13149 THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Expected: 13149, Actual: ' || COUNT(*)::TEXT
    FROM fact_transactions_location

    UNION ALL

    SELECT
        'Integrity'::TEXT,
        'Substitution Rate'::TEXT,
        CASE WHEN COUNT(*) FILTER (WHERE substitution_detected = TRUE) BETWEEN 1000 AND 5000
             THEN '✅ PASS' ELSE '⚠️ WARNING' END,
        'Substitutions: ' || COUNT(*) FILTER (WHERE substitution_detected = TRUE)::TEXT ||
        ' (' || ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100, 1)::TEXT || '%)'
    FROM fact_transactions_location

    UNION ALL

    SELECT
        'Privacy'::TEXT,
        'Compliance'::TEXT,
        CASE WHEN COUNT(*) FILTER (WHERE audio_stored = FALSE AND facial_recognition = FALSE) = COUNT(*)
             THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Audio stored: ' || COUNT(*) FILTER (WHERE audio_stored = TRUE)::TEXT ||
        ', Facial recognition: ' || COUNT(*) FILTER (WHERE facial_recognition = TRUE)::TEXT
    FROM fact_transactions_location;
END;
$$ LANGUAGE plpgsql;