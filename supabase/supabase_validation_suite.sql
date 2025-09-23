-- ==========================================
-- Supabase PostgreSQL Validation Suite
-- Comprehensive testing for Scout Edge fact_transactions_location
-- ==========================================

-- 0) FAST SMOKE TEST (Does it even run?)
-- ==========================================

\echo '🧪 FAST SMOKE TEST - Basic functionality validation'
\echo '=================================================='

-- Check if tables exist
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_name IN ('fact_transactions_location', 'fact_transaction_items', 'dim_ncr_stores')
    AND table_schema = 'public';

    IF table_count = 3 THEN
        RAISE NOTICE '✅ SMOKE TEST: All 3 tables exist';
    ELSE
        RAISE EXCEPTION '❌ SMOKE TEST FAILED: Missing tables (found %)', table_count;
    END IF;
END $$;

-- 1) CORE INVARIANTS VALIDATION
-- ==========================================

\echo ''
\echo '📊 CORE INVARIANTS - Data integrity and completeness'
\echo '=================================================='

-- 1.1 Row count validation
SELECT
    'Record Count Validation' as validation_type,
    COUNT(*) as actual_count,
    13149 as expected_count,
    CASE
        WHEN COUNT(*) = 13149 THEN '✅ PASS'
        WHEN COUNT(*) BETWEEN 10000 AND 15000 THEN '⚠️ ACCEPTABLE'
        ELSE '❌ FAIL - Count outside range'
    END as status
FROM fact_transactions_location;

-- 1.2 Store coverage validation
SELECT
    'Store Coverage' as validation_type,
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

-- 1.3 Location rule enforcement
SELECT
    'Location Rule Enforcement' as validation_type,
    SUM(CASE WHEN municipality_name IS NULL THEN 1 ELSE 0 END) as missing_municipality,
    SUM(CASE WHEN store_polygon IS NULL AND (geo_latitude IS NULL OR geo_longitude IS NULL) THEN 1 ELSE 0 END) as missing_geometry,
    CASE
        WHEN SUM(CASE WHEN municipality_name IS NULL THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN store_polygon IS NULL AND (geo_latitude IS NULL OR geo_longitude IS NULL) THEN 1 ELSE 0 END) = 0
        THEN '✅ PASS - All records have municipality AND (polygon OR coordinates)'
        ELSE '❌ FAIL - Location rule violations found'
    END as status
FROM fact_transactions_location;

-- 1.4 Region/province validation
SELECT
    'Region/Province Validation' as validation_type,
    region,
    province_name,
    COUNT(*) as count,
    CASE
        WHEN region = 'NCR' AND province_name = 'Metro Manila' THEN '✅ Correct'
        ELSE '❌ Invalid'
    END as status
FROM fact_transactions_location
GROUP BY region, province_name;

-- 1.5 Transaction ID uniqueness
WITH duplicate_check AS (
    SELECT transaction_id, COUNT(*) as dup_count
    FROM fact_transactions_location
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
)
SELECT
    'Transaction ID Uniqueness' as validation_type,
    COUNT(*) as duplicate_transactions,
    CASE
        WHEN COUNT(*) = 0 THEN '✅ PASS - No duplicates'
        ELSE '❌ FAIL - Duplicate transaction IDs found'
    END as status
FROM duplicate_check;

-- 1.6 NCR geographic bounds validation
SELECT
    'NCR Geographic Bounds' as validation_type,
    SUM(CASE WHEN geo_latitude NOT BETWEEN 14.20 AND 14.90 THEN 1 ELSE 0 END) as lat_out_of_bounds,
    SUM(CASE WHEN geo_longitude NOT BETWEEN 120.90 AND 121.20 THEN 1 ELSE 0 END) as lon_out_of_bounds,
    CASE
        WHEN SUM(CASE WHEN geo_latitude NOT BETWEEN 14.20 AND 14.90 THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN geo_longitude NOT BETWEEN 120.90 AND 121.20 THEN 1 ELSE 0 END) = 0
        THEN '✅ PASS - All coordinates within NCR bounds'
        ELSE '⚠️ WARNING - Some coordinates outside NCR bounds'
    END as status
FROM fact_transactions_location
WHERE geo_latitude IS NOT NULL AND geo_longitude IS NOT NULL;

-- 2) SUBSTITUTION EVENT VALIDATION
-- ==========================================

\echo ''
\echo '🔄 SUBSTITUTION EVENT VALIDATION - Logic and consistency'
\echo '=================================================='

-- 2.1 Substitution logic consistency
SELECT
    'Substitution Logic Consistency' as validation_type,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE AND substitution_reason IS NULL) as missing_reasons,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE AND brand_switching_score IS NULL) as missing_scores,
    COUNT(*) FILTER (WHERE substitution_detected = FALSE AND substitution_reason IS NOT NULL) as false_negatives,
    CASE
        WHEN COUNT(*) FILTER (WHERE substitution_detected = TRUE AND substitution_reason IS NULL) = 0
        THEN '✅ PASS - Substitution logic consistent'
        ELSE '❌ FAIL - Substitution logic inconsistencies found'
    END as status
FROM fact_transactions_location;

-- 2.2 Substitution rate analysis
SELECT
    'Substitution Rate Analysis' as validation_type,
    substitution_detected,
    substitution_reason,
    COUNT(*) as count,
    ROUND((COUNT(*)::DECIMAL / SUM(COUNT(*)) OVER ()) * 100, 2) as percentage,
    CASE
        WHEN substitution_detected = TRUE AND COUNT(*) BETWEEN 1000 AND 5000
        THEN '✅ Expected Range'
        WHEN substitution_detected = TRUE
        THEN '⚠️ Outside Expected Range'
        ELSE '✅ Non-Substitution'
    END as status
FROM fact_transactions_location
GROUP BY substitution_detected, substitution_reason
ORDER BY substitution_detected DESC, count DESC;

-- 2.3 Substitution sample for manual QA
SELECT
    'Substitution Sample QA' as sample_type,
    transaction_id,
    store_id,
    municipality_name,
    LEFT(audio_transcript, 50) || '...' as transcript_sample,
    requested_brands,
    purchased_brands,
    substitution_reason,
    brand_switching_score
FROM fact_transactions_location
WHERE substitution_detected = TRUE
  AND audio_transcript IS NOT NULL
ORDER BY processed_at DESC
LIMIT 5;

-- 3) PRIVACY COMPLIANCE VALIDATION
-- ==========================================

\echo ''
\echo '🔒 PRIVACY COMPLIANCE VALIDATION - Data protection verification'
\echo '=================================================='

-- 3.1 Privacy compliance check
SELECT
    'Privacy Compliance Check' as validation_type,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE audio_stored = FALSE) as audio_not_stored,
    COUNT(*) FILTER (WHERE facial_recognition = FALSE) as no_facial_recognition,
    COUNT(*) FILTER (WHERE anonymization_level = 'high') as high_anonymization,
    ROUND((COUNT(*) FILTER (WHERE audio_stored = FALSE)::DECIMAL / COUNT(*)) * 100, 2) as audio_compliance_pct,
    CASE
        WHEN COUNT(*) FILTER (WHERE audio_stored = FALSE) = COUNT(*)
         AND COUNT(*) FILTER (WHERE facial_recognition = FALSE) = COUNT(*)
        THEN '✅ PASS - Full privacy compliance'
        ELSE '❌ FAIL - Privacy violations detected'
    END as status
FROM fact_transactions_location;

-- 3.2 Check for emotion columns (should not exist)
SELECT
    'Emotion Column Check' as validation_type,
    COUNT(*) as emotion_columns_found,
    CASE
        WHEN COUNT(*) = 0 THEN '✅ PASS - No emotion columns (privacy compliant)'
        ELSE '❌ FAIL - Emotion columns found'
    END as status
FROM information_schema.columns
WHERE table_name = 'fact_transactions_location'
AND column_name ILIKE '%emotion%';

-- 4) ITEM-LEVEL VALIDATION
-- ==========================================

\echo ''
\echo '🛍️ ITEM-LEVEL VALIDATION - Normalized data integrity'
\echo '=================================================='

-- 4.1 Items relationship integrity
WITH item_stats AS (
    SELECT
        (SELECT COUNT(*) FROM fact_transactions_location) as total_transactions,
        (SELECT COUNT(DISTINCT canonical_tx_id) FROM fact_transaction_items) as transactions_with_items,
        (SELECT COUNT(*) FROM fact_transaction_items) as total_items
)
SELECT
    'Items Relationship Integrity' as validation_type,
    total_transactions,
    transactions_with_items,
    total_items,
    ROUND(total_items::DECIMAL / total_transactions, 2) as avg_items_per_transaction,
    CASE
        WHEN transactions_with_items = total_transactions THEN '✅ PASS - All transactions have items'
        WHEN transactions_with_items > total_transactions * 0.95 THEN '⚠️ ACCEPTABLE - Most transactions have items'
        ELSE '❌ FAIL - Many transactions missing items'
    END as status
FROM item_stats;

-- 4.2 Item brand data quality
WITH item_quality AS (
    SELECT
        COUNT(*) as total_items,
        COUNT(*) FILTER (WHERE brand_name IS NOT NULL) as items_with_brands,
        COUNT(*) FILTER (WHERE category IS NOT NULL) as items_with_categories,
        COUNT(*) FILTER (WHERE unit_price > 0) as items_with_valid_prices
    FROM fact_transaction_items
)
SELECT
    'Item Brand Data Quality' as validation_type,
    total_items,
    items_with_brands,
    ROUND((items_with_brands::DECIMAL / total_items) * 100, 1) as brand_coverage_pct,
    items_with_categories,
    ROUND((items_with_categories::DECIMAL / total_items) * 100, 1) as category_coverage_pct,
    CASE
        WHEN items_with_brands::DECIMAL / total_items >= 0.90 THEN '✅ PASS - High brand coverage'
        WHEN items_with_brands::DECIMAL / total_items >= 0.70 THEN '⚠️ ACCEPTABLE - Moderate brand coverage'
        ELSE '❌ FAIL - Low brand coverage'
    END as status
FROM item_quality;

-- 5) BUSINESS LOGIC VALIDATION
-- ==========================================

\echo ''
\echo '💰 BUSINESS LOGIC VALIDATION - Transaction totals and consistency'
\echo '=================================================='

-- 5.1 Transaction totals consistency
WITH transaction_totals AS (
    SELECT
        ft.canonical_tx_id,
        ft.total_amount as transaction_total,
        ft.total_items as transaction_item_count,
        COALESCE(SUM(fi.total_price), 0) as items_sum,
        COUNT(fi.*) as items_count
    FROM fact_transactions_location ft
    LEFT JOIN fact_transaction_items fi ON ft.canonical_tx_id = fi.canonical_tx_id
    GROUP BY ft.canonical_tx_id, ft.total_amount, ft.total_items
),
consistency_stats AS (
    SELECT
        COUNT(*) as total_transactions,
        COUNT(*) FILTER (WHERE ABS(transaction_total - items_sum) < 0.01) as matching_totals,
        COUNT(*) FILTER (WHERE transaction_item_count = items_count) as matching_item_counts
    FROM transaction_totals
)
SELECT
    'Transaction Totals Consistency' as validation_type,
    total_transactions,
    matching_totals,
    ROUND((matching_totals::DECIMAL / total_transactions) * 100, 1) as total_accuracy_pct,
    matching_item_counts,
    ROUND((matching_item_counts::DECIMAL / total_transactions) * 100, 1) as count_accuracy_pct,
    CASE
        WHEN matching_totals::DECIMAL / total_transactions >= 0.95 THEN '✅ PASS - High accuracy'
        WHEN matching_totals::DECIMAL / total_transactions >= 0.80 THEN '⚠️ ACCEPTABLE - Moderate accuracy'
        ELSE '❌ FAIL - Poor accuracy'
    END as status
FROM consistency_stats;

-- 5.2 Amount validation
WITH amount_stats AS (
    SELECT
        COUNT(*) as total_transactions,
        COUNT(*) FILTER (WHERE total_amount < 0) as negative_amounts,
        COUNT(*) FILTER (WHERE total_amount = 0) as zero_amounts,
        COUNT(*) FILTER (WHERE total_amount > 10000) as suspiciously_high_amounts,
        MIN(total_amount) as min_amount,
        MAX(total_amount) as max_amount,
        ROUND(AVG(total_amount), 2) as avg_amount
    FROM fact_transactions_location
)
SELECT
    'Amount Validation' as validation_type,
    total_transactions,
    negative_amounts,
    zero_amounts,
    suspiciously_high_amounts,
    min_amount,
    max_amount,
    avg_amount,
    CASE
        WHEN negative_amounts = 0 THEN '✅ PASS - No negative amounts'
        ELSE '❌ FAIL - Negative amounts found'
    END as status
FROM amount_stats;

-- 6) PERFORMANCE VALIDATION
-- ==========================================

\echo ''
\echo '⚡ PERFORMANCE VALIDATION - Index usage and query speed'
\echo '=================================================='

-- 6.1 Index usage test (explain plan)
EXPLAIN (ANALYZE, BUFFERS)
SELECT store_id, municipality_name, COUNT(*), AVG(total_amount)
FROM fact_transactions_location
WHERE substitution_detected = TRUE
  AND store_id IN (102, 103, 104)
GROUP BY store_id, municipality_name
ORDER BY store_id;

-- 7) OVERALL DATA QUALITY SCORE
-- ==========================================

\echo ''
\echo '🎯 OVERALL DATA QUALITY SCORE - Comprehensive assessment'
\echo '=================================================='

WITH validation_checks AS (
    -- Check 1: Row count
    SELECT 'row_count' as check_name,
           CASE WHEN COUNT(*) BETWEEN 10000 AND 15000 THEN 1 ELSE 0 END as passed
    FROM fact_transactions_location

    UNION ALL

    -- Check 2: Store coverage
    SELECT 'store_coverage',
           CASE WHEN COUNT(DISTINCT store_id) = 7 THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    -- Check 3: No null critical fields
    SELECT 'no_null_critical_fields',
           CASE WHEN COUNT(*) FILTER (WHERE canonical_tx_id IS NULL OR transaction_id IS NULL OR device_id IS NULL OR store_id IS NULL OR total_amount IS NULL) = 0 THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    -- Check 4: Unique canonical IDs
    SELECT 'unique_canonical_ids',
           CASE WHEN COUNT(*) = COUNT(DISTINCT canonical_tx_id) THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    -- Check 5: No negative amounts
    SELECT 'no_negative_amounts',
           CASE WHEN COUNT(*) FILTER (WHERE total_amount < 0) = 0 THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    -- Check 6: NCR region coverage
    SELECT 'ncr_region_coverage',
           CASE WHEN COUNT(*) FILTER (WHERE region = 'NCR') = COUNT(*) THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    -- Check 7: Privacy compliance
    SELECT 'privacy_compliance',
           CASE WHEN COUNT(*) FILTER (WHERE audio_stored = FALSE AND facial_recognition = FALSE) = COUNT(*) THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    -- Check 8: Location rule compliance
    SELECT 'location_rule_compliance',
           CASE WHEN COUNT(*) FILTER (WHERE municipality_name IS NULL OR (store_polygon IS NULL AND (geo_latitude IS NULL OR geo_longitude IS NULL))) = 0 THEN 1 ELSE 0 END
    FROM fact_transactions_location

    UNION ALL

    -- Check 9: No emotion columns
    SELECT 'no_emotion_columns',
           CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
    FROM information_schema.columns
    WHERE table_name = 'fact_transactions_location' AND column_name ILIKE '%emotion%'

    UNION ALL

    -- Check 10: Substitution logic consistency
    SELECT 'substitution_logic_consistency',
           CASE WHEN COUNT(*) FILTER (WHERE substitution_detected = TRUE AND substitution_reason IS NULL) = 0 THEN 1 ELSE 0 END
    FROM fact_transactions_location
),
quality_summary AS (
    SELECT
        SUM(passed) as checks_passed,
        COUNT(*) as total_checks,
        ROUND((SUM(passed)::DECIMAL / COUNT(*)) * 100, 1) as quality_score_pct
    FROM validation_checks
)
SELECT
    '🎯 OVERALL DATA QUALITY SCORE' as validation_summary,
    checks_passed,
    total_checks,
    quality_score_pct || '%' as quality_score,
    CASE
        WHEN checks_passed = total_checks THEN '🎉 EXCELLENT - All validations passed'
        WHEN quality_score_pct >= 90 THEN '✅ GOOD - Most validations passed'
        WHEN quality_score_pct >= 70 THEN '⚠️ ACCEPTABLE - Some issues found'
        ELSE '❌ POOR - Multiple validation failures'
    END as overall_status
FROM quality_summary;

-- 8) QUICK VALIDATION FUNCTION FOR MONITORING
-- ==========================================

CREATE OR REPLACE FUNCTION quick_data_quality_check()
RETURNS TABLE (
    check_category TEXT,
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Row count check
    SELECT
        'Completeness'::TEXT,
        'Record Count'::TEXT,
        CASE WHEN COUNT(*) BETWEEN 10000 AND 15000 THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Records: ' || COUNT(*)::TEXT
    FROM fact_transactions_location

    UNION ALL

    -- Substitution rate check
    SELECT
        'Business Logic'::TEXT,
        'Substitution Rate'::TEXT,
        CASE WHEN COUNT(*) FILTER (WHERE substitution_detected = TRUE) BETWEEN 1000 AND 5000
             THEN '✅ PASS' ELSE '⚠️ WARNING' END,
        'Substitutions: ' || COUNT(*) FILTER (WHERE substitution_detected = TRUE)::TEXT ||
        ' (' || ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100, 1)::TEXT || '%)'
    FROM fact_transactions_location

    UNION ALL

    -- Privacy compliance check
    SELECT
        'Privacy'::TEXT,
        'Audio/Facial Compliance'::TEXT,
        CASE WHEN COUNT(*) FILTER (WHERE audio_stored = TRUE OR facial_recognition = TRUE) = 0
             THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Violations: Audio=' || COUNT(*) FILTER (WHERE audio_stored = TRUE)::TEXT ||
        ', Facial=' || COUNT(*) FILTER (WHERE facial_recognition = TRUE)::TEXT
    FROM fact_transactions_location

    UNION ALL

    -- Location coverage check
    SELECT
        'Data Quality'::TEXT,
        'Location Coverage'::TEXT,
        CASE WHEN COUNT(*) FILTER (WHERE municipality_name IS NULL) = 0
             THEN '✅ PASS' ELSE '❌ FAIL' END,
        'Missing municipalities: ' || COUNT(*) FILTER (WHERE municipality_name IS NULL)::TEXT
    FROM fact_transactions_location;
END;
$$ LANGUAGE plpgsql;

\echo ''
\echo '🚀 SUPABASE VALIDATION SUITE COMPLETE'
\echo 'Use: SELECT * FROM quick_data_quality_check(); for ongoing monitoring'
\echo ''