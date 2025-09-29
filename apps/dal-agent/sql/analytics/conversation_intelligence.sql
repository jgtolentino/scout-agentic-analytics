-- Conversation Intelligence Analytics
-- Comprehensive analysis of customer-store owner interactions with speaker separation
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: CONVERSATION METRICS OVERVIEW
-- =====================================================

WITH conversation_overview AS (
    SELECT
        -- Transaction context
        t.transaction_id,
        t.canonical_tx_id,
        t.store_id,
        s.store_name,
        s.region,
        t.transaction_date,
        t.transaction_datetime,
        t.category,
        t.brand,
        t.transaction_value,

        -- Customer demographics
        t.demographics_gender,
        t.demographics_age,

        -- Conversation intelligence from enhanced JSON
        TRY_CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.duration_seconds') AS INT) AS conversation_duration,
        TRY_CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.speaker_turns.customer') AS INT) AS customer_turns,
        TRY_CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.speaker_turns.store_owner') AS INT) AS owner_turns,
        TRY_CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.brands_discussed') AS INT) AS brands_discussed,
        TRY_CAST(JSON_VALUE(t.enhanced_payload, '$.conversation.suggestion_acceptance_rate') AS DECIMAL(5,3)) AS suggestion_acceptance,

        -- Intent classification
        JSON_VALUE(t.enhanced_payload, '$.conversation.primary_intent') AS primary_intent,
        JSON_VALUE(t.enhanced_payload, '$.conversation.conversation_flow') AS conversation_flow,

        -- Brand mentions
        JSON_VALUE(t.enhanced_payload, '$.conversation.brands_mentioned') AS brands_mentioned_json,
        JSON_VALUE(t.enhanced_payload, '$.conversation.products_mentioned') AS products_mentioned_json,

        -- Conversation effectiveness
        CASE
            WHEN JSON_VALUE(t.enhanced_payload, '$.conversation.purchase_completed') = 'true' THEN 1
            ELSE 0
        END AS purchase_completed,

        CASE
            WHEN JSON_VALUE(t.enhanced_payload, '$.conversation.substitution_occurred') = 'true' THEN 1
            ELSE 0
        END AS substitution_occurred

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dim.stores s ON t.store_id = s.store_id
    WHERE t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND t.enhanced_payload IS NOT NULL
        AND JSON_VALUE(t.enhanced_payload, '$.conversation') IS NOT NULL
),

-- =====================================================
-- SECTION 2: SPEAKER TURN ANALYSIS
-- =====================================================

speaker_analysis AS (
    SELECT
        store_id,
        store_name,
        region,
        category,
        demographics_gender,

        -- Conversation volume metrics
        COUNT(DISTINCT transaction_id) AS conversations,
        AVG(CAST(conversation_duration AS FLOAT)) AS avg_duration_seconds,
        AVG(CAST(customer_turns AS FLOAT)) AS avg_customer_turns,
        AVG(CAST(owner_turns AS FLOAT)) AS avg_owner_turns,

        -- Turn ratio analysis
        CAST(AVG(CAST(customer_turns AS FLOAT)) / NULLIF(AVG(CAST(owner_turns AS FLOAT)), 0) AS DECIMAL(5,2)) AS customer_owner_ratio,

        -- Conversation engagement
        AVG(CAST(brands_discussed AS FLOAT)) AS avg_brands_discussed,
        AVG(suggestion_acceptance) AS avg_suggestion_acceptance,

        -- Conversion effectiveness
        CAST(SUM(purchase_completed) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS purchase_completion_rate,
        CAST(SUM(substitution_occurred) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS substitution_rate,

        -- Duration bands
        COUNT(CASE WHEN conversation_duration < 30 THEN 1 END) AS quick_conversations,
        COUNT(CASE WHEN conversation_duration BETWEEN 30 AND 120 THEN 1 END) AS medium_conversations,
        COUNT(CASE WHEN conversation_duration > 120 THEN 1 END) AS long_conversations

    FROM conversation_overview
    WHERE conversation_duration IS NOT NULL
    GROUP BY store_id, store_name, region, category, demographics_gender
),

-- =====================================================
-- SECTION 3: INTENT CLASSIFICATION PATTERNS
-- =====================================================

intent_patterns AS (
    SELECT
        primary_intent,
        conversation_flow,
        category,
        demographics_gender,
        demographics_age,

        COUNT(DISTINCT transaction_id) AS occurrences,
        AVG(CAST(conversation_duration AS FLOAT)) AS avg_duration,
        AVG(CAST(brands_discussed AS FLOAT)) AS avg_brands_discussed,
        AVG(suggestion_acceptance) AS avg_suggestion_acceptance,

        -- Success metrics by intent
        CAST(SUM(purchase_completed) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS intent_success_rate,
        AVG(transaction_value) AS avg_transaction_value,

        -- Time patterns
        CASE
            WHEN DATEPART(HOUR, transaction_datetime) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, transaction_datetime) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, transaction_datetime) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS daypart

    FROM conversation_overview
    WHERE primary_intent IS NOT NULL
    GROUP BY primary_intent, conversation_flow, category, demographics_gender, demographics_age, daypart
),

-- =====================================================
-- SECTION 4: BRAND MENTION ANALYSIS
-- =====================================================

brand_mentions AS (
    SELECT
        t.brand AS final_brand,
        m.value AS mentioned_brand,
        t.category,
        t.demographics_gender,

        COUNT(DISTINCT t.transaction_id) AS mention_count,
        CAST(SUM(t.purchase_completed) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS mention_conversion_rate,
        AVG(t.transaction_value) AS avg_value_when_mentioned,

        -- Check if mentioned brand matches final purchase
        CAST(COUNT(CASE WHEN m.value = t.brand THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS brand_consistency_rate,

        -- Substitution analysis when brands differ
        COUNT(CASE WHEN m.value != t.brand AND t.substitution_occurred = 1 THEN 1 END) AS substitution_events

    FROM conversation_overview t
        CROSS APPLY OPENJSON(t.brands_mentioned_json) m
    WHERE t.brands_mentioned_json IS NOT NULL
        AND JSON_VALID(t.brands_mentioned_json) = 1
    GROUP BY t.brand, m.value, t.category, t.demographics_gender
),

-- =====================================================
-- SECTION 5: CONVERSATION FLOW EFFECTIVENESS
-- =====================================================

flow_effectiveness AS (
    SELECT
        conversation_flow,
        category,

        COUNT(DISTINCT transaction_id) AS flow_occurrences,
        AVG(CAST(conversation_duration AS FLOAT)) AS avg_flow_duration,

        -- Effectiveness metrics
        CAST(SUM(purchase_completed) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS flow_conversion_rate,
        AVG(suggestion_acceptance) AS avg_suggestion_acceptance,
        AVG(transaction_value) AS avg_transaction_value,

        -- Turn efficiency
        AVG(CAST(customer_turns AS FLOAT)) AS avg_customer_turns,
        AVG(CAST(owner_turns AS FLOAT)) AS avg_owner_turns,

        -- Flow complexity
        AVG(CAST(brands_discussed AS FLOAT)) AS avg_brands_in_flow,
        CAST(SUM(substitution_occurred) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS substitution_rate_in_flow

    FROM conversation_overview
    WHERE conversation_flow IS NOT NULL
    GROUP BY conversation_flow, category
)

-- =====================================================
-- SECTION 6: EXPORT QUERIES
-- =====================================================

-- Export 1: Conversation Overview
SELECT
    'Conversation Overview' AS export_type,
    store_name,
    region,
    category,
    demographics_gender,
    conversations,
    CAST(avg_duration_seconds AS DECIMAL(8,2)) AS avg_duration_seconds,
    CAST(avg_customer_turns AS DECIMAL(5,2)) AS avg_customer_turns,
    CAST(avg_owner_turns AS DECIMAL(5,2)) AS avg_owner_turns,
    customer_owner_ratio,
    CAST(avg_brands_discussed AS DECIMAL(5,2)) AS avg_brands_discussed,
    CAST(avg_suggestion_acceptance AS DECIMAL(5,3)) AS avg_suggestion_acceptance,
    purchase_completion_rate,
    substitution_rate,
    quick_conversations,
    medium_conversations,
    long_conversations
FROM speaker_analysis
ORDER BY conversations DESC, purchase_completion_rate DESC;

-- Export 2: Intent Classification Analysis
SELECT
    'Intent Classification' AS export_type,
    primary_intent,
    conversation_flow,
    category,
    demographics_gender,
    demographics_age,
    daypart,
    occurrences,
    CAST(avg_duration AS DECIMAL(8,2)) AS avg_duration_seconds,
    CAST(avg_brands_discussed AS DECIMAL(5,2)) AS avg_brands_discussed,
    CAST(avg_suggestion_acceptance AS DECIMAL(5,3)) AS avg_suggestion_acceptance,
    intent_success_rate,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,

    -- Intent effectiveness scoring
    CASE
        WHEN intent_success_rate >= 80 THEN 'Highly Effective'
        WHEN intent_success_rate >= 60 THEN 'Moderately Effective'
        WHEN intent_success_rate >= 40 THEN 'Somewhat Effective'
        ELSE 'Low Effectiveness'
    END AS effectiveness_tier

FROM intent_patterns
ORDER BY intent_success_rate DESC, occurrences DESC;

-- Export 3: Brand Mention Analysis
SELECT
    'Brand Mention Analysis' AS export_type,
    final_brand,
    mentioned_brand,
    category,
    demographics_gender,
    mention_count,
    mention_conversion_rate,
    CAST(avg_value_when_mentioned AS DECIMAL(10,2)) AS avg_value_when_mentioned,
    brand_consistency_rate,
    substitution_events,

    -- Brand mention patterns
    CASE
        WHEN mentioned_brand = final_brand THEN 'Direct Request'
        WHEN substitution_events > 0 THEN 'Substitution Pattern'
        ELSE 'Exploration Pattern'
    END AS mention_pattern,

    -- Brand loyalty indicators
    CASE
        WHEN brand_consistency_rate >= 90 THEN 'High Loyalty'
        WHEN brand_consistency_rate >= 70 THEN 'Moderate Loyalty'
        WHEN brand_consistency_rate >= 50 THEN 'Low Loyalty'
        ELSE 'Brand Switching'
    END AS loyalty_indicator

FROM brand_mentions
WHERE mention_count >= 3
ORDER BY mention_count DESC, mention_conversion_rate DESC;

-- Export 4: Conversation Flow Effectiveness
SELECT
    'Conversation Flow Effectiveness' AS export_type,
    conversation_flow,
    category,
    flow_occurrences,
    CAST(avg_flow_duration AS DECIMAL(8,2)) AS avg_duration_seconds,
    flow_conversion_rate,
    CAST(avg_suggestion_acceptance AS DECIMAL(5,3)) AS avg_suggestion_acceptance,
    CAST(avg_transaction_value AS DECIMAL(10,2)) AS avg_transaction_value,
    CAST(avg_customer_turns AS DECIMAL(5,2)) AS avg_customer_turns,
    CAST(avg_owner_turns AS DECIMAL(5,2)) AS avg_owner_turns,
    CAST(avg_brands_in_flow AS DECIMAL(5,2)) AS avg_brands_in_flow,
    substitution_rate_in_flow,

    -- Flow efficiency metrics
    CAST(avg_flow_duration / NULLIF(avg_customer_turns + avg_owner_turns, 0) AS DECIMAL(8,2)) AS seconds_per_turn,
    CAST(flow_conversion_rate / NULLIF(avg_flow_duration, 0) * 100 AS DECIMAL(8,4)) AS conversion_per_second,

    -- Flow quality assessment
    CASE
        WHEN flow_conversion_rate >= 80 AND avg_flow_duration <= 60 THEN 'Optimal Flow'
        WHEN flow_conversion_rate >= 70 THEN 'Good Flow'
        WHEN flow_conversion_rate >= 50 THEN 'Average Flow'
        ELSE 'Inefficient Flow'
    END AS flow_quality

FROM flow_effectiveness
ORDER BY flow_conversion_rate DESC, avg_flow_duration ASC;

-- Export 5: Conversation Intelligence Summary
SELECT
    'Conversation Summary' AS export_type,

    -- Overall metrics
    COUNT(DISTINCT transaction_id) AS total_conversations,
    CAST(AVG(CAST(conversation_duration AS FLOAT)) AS DECIMAL(8,2)) AS overall_avg_duration,
    CAST(SUM(purchase_completed) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS overall_conversion_rate,
    CAST(AVG(suggestion_acceptance) AS DECIMAL(5,3)) AS overall_suggestion_acceptance,

    -- Segmented analysis
    CAST(AVG(CASE WHEN demographics_gender = 'Male' THEN CAST(conversation_duration AS FLOAT) END) AS DECIMAL(8,2)) AS male_avg_duration,
    CAST(AVG(CASE WHEN demographics_gender = 'Female' THEN CAST(conversation_duration AS FLOAT) END) AS DECIMAL(8,2)) AS female_avg_duration,

    -- Category performance
    COUNT(CASE WHEN category = 'Tobacco Products' THEN 1 END) AS tobacco_conversations,
    COUNT(CASE WHEN category = 'Laundry' THEN 1 END) AS laundry_conversations,
    COUNT(CASE WHEN category = 'Beverages' THEN 1 END) AS beverage_conversations,

    -- Top performing metrics
    MAX(suggestion_acceptance) AS best_suggestion_acceptance,
    MIN(CASE WHEN conversation_duration > 0 THEN conversation_duration END) AS shortest_conversation,
    MAX(conversation_duration) AS longest_conversation,

    -- Conversation intelligence insights
    COUNT(CASE WHEN substitution_occurred = 1 THEN 1 END) AS total_substitutions,
    CAST(COUNT(CASE WHEN substitution_occurred = 1 THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS substitution_rate

FROM conversation_overview
WHERE conversation_duration IS NOT NULL;

PRINT 'Conversation intelligence analytics completed successfully';