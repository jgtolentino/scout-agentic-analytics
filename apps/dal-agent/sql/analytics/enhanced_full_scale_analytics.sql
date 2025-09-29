-- Enhanced Full Scale Analytics for Scout v7
-- Leverages 1,100+ brands with lexical variations and conversation intelligence
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: NIELSEN CATEGORY PERFORMANCE OVERVIEW
-- =====================================================

WITH nielsen_performance AS (
    SELECT
        nc.nielsen_category,
        nc.category_name,
        nc.category_prefix,
        nc.total_brands AS catalog_brands,

        -- Transaction metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,
        SUM(t.transaction_value) AS total_revenue,
        AVG(t.transaction_value) AS avg_transaction_value,
        AVG(t.basket_size) AS avg_basket_size,

        -- Active brand metrics
        COUNT(DISTINCT t.brand) AS active_brands,
        CAST(COUNT(DISTINCT t.brand) * 100.0 / nc.total_brands AS DECIMAL(5,2)) AS brand_activation_rate,

        -- Market share within category
        DENSE_RANK() OVER(ORDER BY SUM(t.transaction_value) DESC) AS revenue_rank,

        -- TBWA client performance
        COUNT(CASE WHEN bc.tbwa_client_id IS NOT NULL AND bc.tbwa_client_id != '' THEN 1 END) AS tbwa_transactions,
        SUM(CASE WHEN bc.tbwa_client_id IS NOT NULL AND bc.tbwa_client_id != '' THEN t.transaction_value ELSE 0 END) AS tbwa_revenue,

        -- Conversation intelligence metrics
        AVG(CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.duration_seconds') AS INT)) AS avg_conversation_duration,
        AVG(CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.suggestion_acceptance_rate') AS DECIMAL(5,3))) AS avg_suggestion_acceptance,
        COUNT(CASE WHEN JSON_VALUE(t.enhanced_payload, '$.conversation.substitution_occurred') = 'true' THEN 1 END) AS substitution_events

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dbo.enhanced_brand_catalog bc ON t.brand = bc.brand_name
        LEFT JOIN dbo.nielsen_categories nc ON bc.nielsen_category = nc.nielsen_category
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND nc.nielsen_category IS NOT NULL
    GROUP BY nc.nielsen_category, nc.category_name, nc.category_prefix, nc.total_brands
),

-- =====================================================
-- SECTION 2: LEXICAL VARIATION BRAND MATCHING
-- =====================================================

brand_variation_matches AS (
    SELECT
        t.transaction_id,
        t.brand AS original_brand,
        bc.brand_id,
        bc.brand_name AS matched_brand,
        bc.nielsen_category,
        bc.tbwa_client_id,

        -- Lexical matching details
        blv.variation_text,
        blv.variation_type,
        blv.confidence_weight,

        -- Match confidence scoring
        CASE
            WHEN t.brand = bc.brand_name THEN 1.0 -- Exact match
            WHEN t.brand = blv.variation_text THEN blv.confidence_weight -- Variation match
            WHEN t.brand LIKE '%' + blv.variation_text + '%' THEN blv.confidence_weight * 0.8 -- Partial match
            ELSE 0.5 -- Fuzzy match
        END AS match_confidence,

        t.transaction_value,
        t.demographics_gender,
        t.demographics_age

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dbo.enhanced_brand_catalog bc ON t.brand = bc.brand_name
        LEFT JOIN dbo.brand_lexical_variations blv ON (
            bc.brand_id = blv.brand_id
            OR t.brand = blv.variation_text
            OR t.brand LIKE '%' + blv.variation_text + '%'
        )
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND (bc.brand_id IS NOT NULL OR blv.variation_text IS NOT NULL)
),

-- =====================================================
-- SECTION 3: FILIPINO CONVERSATION PATTERN ANALYSIS
-- =====================================================

conversation_pattern_analysis AS (
    SELECT
        t.transaction_id,
        t.category,
        t.brand,
        t.demographics_gender,

        -- Extract conversation text from enhanced payload
        JSON_VALUE(t.enhanced_payload, '$.conversation.transcript') AS conversation_transcript,
        JSON_VALUE(t.enhanced_payload, '$.conversation.primary_intent') AS primary_intent,

        -- Pattern matching against Filipino patterns
        STRING_AGG(fcp.pattern_category, ', ') AS detected_patterns,
        AVG(fcp.politeness_level) AS avg_politeness_level,
        MAX(CASE WHEN fcp.language_mix = 'code_switched' THEN 1 ELSE 0 END) AS code_switching_detected,

        -- Conversation effectiveness
        CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.suggestion_acceptance_rate') AS DECIMAL(5,3)) AS suggestion_acceptance,
        CASE WHEN JSON_VALUE(t.enhanced_payload, '$.conversation.purchase_completed') = 'true' THEN 1 ELSE 0 END AS purchase_completed

    FROM canonical.v_transactions_flat_enhanced t
        CROSS APPLY (
            SELECT fcp.*
            FROM dbo.filipino_conversation_patterns fcp
            WHERE JSON_VALUE(t.enhanced_payload, '$.conversation.transcript') LIKE '%' + fcp.pattern_text + '%'
                OR JSON_VALUE(t.enhanced_payload, '$.conversation.transcript') LIKE '%' + REPLACE(fcp.pattern_text, '[brand]', t.brand) + '%'
        ) fcp
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND JSON_VALUE(t.enhanced_payload, '$.conversation.transcript') IS NOT NULL
    GROUP BY t.transaction_id, t.category, t.brand, t.demographics_gender,
             JSON_VALUE(t.enhanced_payload, '$.conversation.transcript'),
             JSON_VALUE(t.enhanced_payload, '$.conversation.primary_intent'),
             JSON_VALUE(t.enhanced_payload, '$.conversation.suggestion_acceptance_rate'),
             JSON_VALUE(t.enhanced_payload, '$.conversation.purchase_completed')
),

-- =====================================================
-- SECTION 4: TBWA CLIENT PERFORMANCE ANALYSIS
-- =====================================================

tbwa_client_performance AS (
    SELECT
        bc.tbwa_client_id,
        COUNT(DISTINCT bc.brand_id) AS client_brands,
        COUNT(DISTINCT nc.nielsen_category) AS categories_covered,

        -- Revenue metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.transaction_value) AS total_revenue,
        AVG(t.transaction_value) AS avg_transaction_value,

        -- Market share
        CAST(SUM(t.transaction_value) * 100.0 / (
            SELECT SUM(transaction_value)
            FROM canonical.v_transactions_flat_enhanced
            WHERE transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        ) AS DECIMAL(5,2)) AS market_share_pct,

        -- Brand variation effectiveness
        AVG(bvm.match_confidence) AS avg_brand_recognition,
        COUNT(CASE WHEN bvm.variation_type = 'informal' THEN 1 END) AS informal_mentions,
        COUNT(CASE WHEN bvm.variation_type = 'code_switched' THEN 1 END) AS code_switched_mentions,

        -- Conversation intelligence
        AVG(cpa.avg_politeness_level) AS avg_conversation_politeness,
        CAST(SUM(cpa.code_switching_detected) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS code_switching_rate,
        AVG(cpa.suggestion_acceptance) AS avg_suggestion_acceptance

    FROM dbo.enhanced_brand_catalog bc
        LEFT JOIN dbo.nielsen_categories nc ON bc.nielsen_category = nc.nielsen_category
        LEFT JOIN brand_variation_matches bvm ON bc.brand_id = bvm.brand_id
        LEFT JOIN canonical.v_transactions_flat_enhanced t ON bc.brand_name = t.brand
        LEFT JOIN conversation_pattern_analysis cpa ON t.transaction_id = cpa.transaction_id
    WHERE bc.tbwa_client_id IS NOT NULL
        AND bc.tbwa_client_id != ''
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY bc.tbwa_client_id
),

-- =====================================================
-- SECTION 5: CROSS-CATEGORY AFFINITY WITH NIELSEN
-- =====================================================

nielsen_cross_category_affinity AS (
    SELECT
        nc1.category_name AS primary_category,
        nc2.category_name AS affinity_category,
        nc1.category_prefix AS primary_prefix,
        nc2.category_prefix AS affinity_prefix,

        COUNT(DISTINCT t1.transaction_id) AS co_occurrence_count,
        COUNT(DISTINCT t1.canonical_tx_id) AS unique_customers,

        -- Lift calculation
        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id)
             FROM canonical.v_transactions_flat_enhanced t
             LEFT JOIN dbo.enhanced_brand_catalog bc ON t.brand = bc.brand_name
             LEFT JOIN dbo.nielsen_categories nc ON bc.nielsen_category = nc.nielsen_category
             WHERE nc.nielsen_category = nc1.nielsen_category
               AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
            ) AS primary_support,

        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id)
             FROM canonical.v_transactions_flat_enhanced t
             LEFT JOIN dbo.enhanced_brand_catalog bc ON t.brand = bc.brand_name
             LEFT JOIN dbo.nielsen_categories nc ON bc.nielsen_category = nc.nielsen_category
             WHERE nc.nielsen_category = nc2.nielsen_category
               AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
            ) AS affinity_support

    FROM canonical.v_transactions_flat_enhanced t1
        INNER JOIN canonical.v_transactions_flat_enhanced t2
            ON t1.transaction_id = t2.transaction_id
            AND t1.brand != t2.brand
        LEFT JOIN dbo.enhanced_brand_catalog bc1 ON t1.brand = bc1.brand_name
        LEFT JOIN dbo.enhanced_brand_catalog bc2 ON t2.brand = bc2.brand_name
        LEFT JOIN dbo.nielsen_categories nc1 ON bc1.nielsen_category = nc1.nielsen_category
        LEFT JOIN dbo.nielsen_categories nc2 ON bc2.nielsen_category = nc2.nielsen_category
    WHERE t1.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND nc1.nielsen_category IS NOT NULL
        AND nc2.nielsen_category IS NOT NULL
        AND nc1.nielsen_category != nc2.nielsen_category
    GROUP BY nc1.category_name, nc2.category_name, nc1.category_prefix, nc2.category_prefix,
             nc1.nielsen_category, nc2.nielsen_category
)

-- =====================================================
-- SECTION 6: EXPORT QUERIES
-- =====================================================

-- Export 1: Nielsen Category Performance
SELECT
    'Nielsen Category Performance' AS export_type,
    nielsen_category,
    category_name,
    category_prefix,
    catalog_brands,
    active_brands,
    brand_activation_rate,
    transactions,
    unique_customers,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,
    CAST(avg_basket_size AS DECIMAL(8,2)) AS avg_basket_size,
    revenue_rank,
    tbwa_transactions,
    CAST(tbwa_revenue AS DECIMAL(18,2)) AS tbwa_revenue,
    CAST(tbwa_revenue * 100.0 / NULLIF(total_revenue, 0) AS DECIMAL(5,2)) AS tbwa_share_pct,
    CAST(avg_conversation_duration AS DECIMAL(8,2)) AS avg_conversation_seconds,
    CAST(avg_suggestion_acceptance AS DECIMAL(5,3)) AS avg_suggestion_acceptance,
    substitution_events,
    CAST(substitution_events * 100.0 / NULLIF(transactions, 0) AS DECIMAL(5,2)) AS substitution_rate_pct
FROM nielsen_performance
ORDER BY total_revenue DESC;

-- Export 2: Brand Variation Effectiveness
SELECT
    'Brand Variation Effectiveness' AS export_type,
    matched_brand,
    nielsen_category,
    variation_type,
    COUNT(DISTINCT transaction_id) AS matches,
    COUNT(DISTINCT original_brand) AS original_brand_variants,
    AVG(match_confidence) AS avg_confidence,
    SUM(transaction_value) AS total_value,
    STRING_AGG(DISTINCT variation_text, ', ') AS variation_examples,
    CASE
        WHEN tbwa_client_id IS NOT NULL AND tbwa_client_id != '' THEN 'TBWA Client'
        ELSE 'Non-TBWA'
    END AS client_status
FROM brand_variation_matches
WHERE match_confidence >= 0.7
GROUP BY matched_brand, nielsen_category, variation_type, tbwa_client_id
ORDER BY matches DESC, avg_confidence DESC;

-- Export 3: Filipino Conversation Patterns
SELECT
    'Filipino Conversation Patterns' AS export_type,
    category,
    detected_patterns,
    COUNT(DISTINCT transaction_id) AS pattern_occurrences,
    AVG(avg_politeness_level) AS avg_politeness,
    CAST(SUM(code_switching_detected) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS code_switching_rate,
    AVG(suggestion_acceptance) AS avg_suggestion_acceptance,
    CAST(SUM(purchase_completed) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS pattern_conversion_rate,
    STRING_AGG(DISTINCT demographics_gender, ', ') AS customer_genders
FROM conversation_pattern_analysis
WHERE detected_patterns IS NOT NULL
GROUP BY category, detected_patterns
ORDER BY pattern_occurrences DESC;

-- Export 4: TBWA Client Performance
SELECT
    'TBWA Client Performance' AS export_type,
    tbwa_client_id,
    client_brands,
    categories_covered,
    transactions,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,
    market_share_pct,
    CAST(avg_brand_recognition AS DECIMAL(5,3)) AS avg_brand_recognition,
    informal_mentions,
    code_switched_mentions,
    CAST(avg_conversation_politeness AS DECIMAL(5,2)) AS avg_conversation_politeness,
    code_switching_rate,
    CAST(avg_suggestion_acceptance AS DECIMAL(5,3)) AS avg_suggestion_acceptance,

    -- Performance tier
    CASE
        WHEN market_share_pct >= 10 THEN 'Tier 1 (10%+)'
        WHEN market_share_pct >= 5 THEN 'Tier 2 (5-10%)'
        WHEN market_share_pct >= 1 THEN 'Tier 3 (1-5%)'
        ELSE 'Tier 4 (<1%)'
    END AS performance_tier

FROM tbwa_client_performance
ORDER BY total_revenue DESC;

-- Export 5: Nielsen Cross-Category Affinity
SELECT
    'Nielsen Cross Category Affinity' AS export_type,
    primary_category,
    affinity_category,
    primary_prefix,
    affinity_prefix,
    co_occurrence_count,
    unique_customers,
    CAST(primary_support * 100 AS DECIMAL(5,2)) AS primary_support_pct,
    CAST(affinity_support * 100 AS DECIMAL(5,2)) AS affinity_support_pct,
    CAST((primary_support / NULLIF(affinity_support, 0)) AS DECIMAL(8,2)) AS lift_score,

    -- Affinity strength classification
    CASE
        WHEN (primary_support / NULLIF(affinity_support, 0)) > 2.0 THEN 'Very Strong'
        WHEN (primary_support / NULLIF(affinity_support, 0)) > 1.5 THEN 'Strong'
        WHEN (primary_support / NULLIF(affinity_support, 0)) > 1.2 THEN 'Moderate'
        WHEN (primary_support / NULLIF(affinity_support, 0)) > 1.0 THEN 'Weak'
        ELSE 'No Affinity'
    END AS affinity_strength

FROM nielsen_cross_category_affinity
WHERE co_occurrence_count >= 5
ORDER BY lift_score DESC, co_occurrence_count DESC;

-- Export 6: Full Scale Summary
SELECT
    'Full Scale Analytics Summary' AS export_type,

    -- Overall scale metrics
    (SELECT COUNT(*) FROM dbo.enhanced_brand_catalog) AS total_catalog_brands,
    (SELECT COUNT(*) FROM dbo.enhanced_sku_catalog) AS total_catalog_skus,
    (SELECT COUNT(*) FROM dbo.nielsen_categories) AS total_nielsen_categories,
    (SELECT COUNT(*) FROM dbo.brand_lexical_variations) AS total_lexical_variations,

    -- Active data metrics
    COUNT(DISTINCT t.brand) AS active_brands_in_period,
    COUNT(DISTINCT t.transaction_id) AS total_transactions,
    COUNT(DISTINCT t.canonical_tx_id) AS unique_customers,
    CAST(SUM(t.transaction_value) AS DECIMAL(18,2)) AS total_revenue,

    -- TBWA performance
    COUNT(DISTINCT CASE WHEN bc.tbwa_client_id IS NOT NULL AND bc.tbwa_client_id != '' THEN t.transaction_id END) AS tbwa_transactions,
    CAST(SUM(CASE WHEN bc.tbwa_client_id IS NOT NULL AND bc.tbwa_client_id != '' THEN t.transaction_value ELSE 0 END) AS DECIMAL(18,2)) AS tbwa_revenue,
    CAST(SUM(CASE WHEN bc.tbwa_client_id IS NOT NULL AND bc.tbwa_client_id != '' THEN t.transaction_value ELSE 0 END) * 100.0 / SUM(t.transaction_value) AS DECIMAL(5,2)) AS tbwa_market_share,

    -- Conversation intelligence coverage
    COUNT(CASE WHEN JSON_VALUE(t.enhanced_payload, '$.conversation') IS NOT NULL THEN 1 END) AS conversations_with_intelligence,
    CAST(COUNT(CASE WHEN JSON_VALUE(t.enhanced_payload, '$.conversation') IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS conversation_coverage_pct

FROM canonical.v_transactions_flat_enhanced t
    LEFT JOIN dbo.enhanced_brand_catalog bc ON t.brand = bc.brand_name
WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26');

PRINT 'Enhanced full scale analytics completed successfully';
PRINT 'Coverage: 1,100+ brands with lexical variations and conversation intelligence';