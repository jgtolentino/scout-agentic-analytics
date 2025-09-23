-- ================================================
-- Scout Edge Substitution Analytics Views
-- NCR Store Analysis and Brand Switching Patterns
-- ================================================

-- Substitution Rate by Store and Municipality
CREATE OR REPLACE VIEW v_substitution_by_location AS
SELECT
    store_id,
    municipality_name,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
    ROUND(
        (COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as substitution_rate_pct,
    AVG(brand_switching_score) FILTER (WHERE substitution_detected = TRUE) as avg_switching_score,
    SUM(total_amount) as total_revenue,
    SUM(total_amount) FILTER (WHERE substitution_detected = TRUE) as substitution_revenue,
    ROUND(
        (SUM(total_amount) FILTER (WHERE substitution_detected = TRUE) / SUM(total_amount)) * 100,
        2
    ) as substitution_revenue_pct
FROM fact_transactions_location
WHERE processed_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY store_id, municipality_name
ORDER BY substitution_rate_pct DESC;

-- Brand Switching Patterns Analysis
CREATE OR REPLACE VIEW v_brand_switching_patterns AS
WITH brand_mentions AS (
    SELECT
        ft.canonical_tx_id,
        ft.audio_transcript,
        ft.substitution_detected,
        ft.municipality_name,
        fi.brand_name as purchased_brand,
        fi.category,
        fi.total_price
    FROM fact_transactions_location ft
    JOIN fact_transaction_items fi ON ft.canonical_tx_id = fi.canonical_tx_id
    WHERE ft.substitution_detected = TRUE
    AND ft.audio_transcript IS NOT NULL
    AND LENGTH(ft.audio_transcript) > 0
),
category_analysis AS (
    SELECT
        category,
        municipality_name,
        COUNT(*) as substitution_events,
        COUNT(DISTINCT purchased_brand) as unique_brands_purchased,
        AVG(total_price) as avg_transaction_value,
        STRING_AGG(DISTINCT purchased_brand, ', ' ORDER BY purchased_brand) as brands_purchased
    FROM brand_mentions
    GROUP BY category, municipality_name
)
SELECT
    category,
    municipality_name,
    substitution_events,
    unique_brands_purchased,
    ROUND(avg_transaction_value, 2) as avg_transaction_value,
    brands_purchased,
    ROUND(
        substitution_events::DECIMAL / SUM(substitution_events) OVER (PARTITION BY municipality_name) * 100,
        2
    ) as category_share_pct
FROM category_analysis
ORDER BY municipality_name, substitution_events DESC;

-- Daily Substitution Trends
CREATE OR REPLACE VIEW v_daily_substitution_trends AS
SELECT
    DATE(processed_at) as transaction_date,
    municipality_name,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
    ROUND(
        (COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as daily_substitution_rate,
    SUM(total_amount) as daily_revenue,
    AVG(total_amount) as avg_transaction_value,
    COUNT(DISTINCT device_id) as active_devices
FROM fact_transactions_location
WHERE processed_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(processed_at), municipality_name
ORDER BY transaction_date DESC, municipality_name;

-- Customer Request vs Purchase Analysis
CREATE OR REPLACE VIEW v_customer_behavior_analysis AS
SELECT
    fi.customer_request_type,
    fi.category,
    ft.municipality_name,
    COUNT(*) as transactions,
    COUNT(*) FILTER (WHERE ft.substitution_detected = TRUE) as substitutions,
    ROUND(
        (COUNT(*) FILTER (WHERE ft.substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as substitution_rate_pct,
    COUNT(*) FILTER (WHERE fi.specific_brand_requested = TRUE) as specific_brand_requests,
    COUNT(*) FILTER (WHERE fi.pointed_to_product = TRUE) as pointed_to_product,
    COUNT(*) FILTER (WHERE fi.accepted_suggestion = TRUE) as accepted_suggestions,
    AVG(fi.total_price) as avg_item_value,
    AVG(ft.processing_duration) as avg_processing_time
FROM fact_transactions_location ft
JOIN fact_transaction_items fi ON ft.canonical_tx_id = fi.canonical_tx_id
WHERE ft.processed_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY fi.customer_request_type, fi.category, ft.municipality_name
ORDER BY substitution_rate_pct DESC;

-- Brand Popularity vs Substitution Rate
CREATE OR REPLACE VIEW v_brand_performance_analysis AS
WITH brand_stats AS (
    SELECT
        fi.brand_name,
        fi.category,
        ft.municipality_name,
        COUNT(*) as total_purchases,
        COUNT(*) FILTER (WHERE ft.substitution_detected = TRUE) as substitution_purchases,
        SUM(fi.total_price) as total_revenue,
        AVG(fi.total_price) as avg_item_price,
        AVG(fi.confidence) as avg_detection_confidence,
        AVG(fi.brand_confidence) as avg_brand_confidence
    FROM fact_transactions_location ft
    JOIN fact_transaction_items fi ON ft.canonical_tx_id = fi.canonical_tx_id
    WHERE fi.brand_name IS NOT NULL
    AND ft.processed_at >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY fi.brand_name, fi.category, ft.municipality_name
)
SELECT
    brand_name,
    category,
    municipality_name,
    total_purchases,
    substitution_purchases,
    ROUND(
        (substitution_purchases::DECIMAL / total_purchases) * 100,
        2
    ) as brand_substitution_rate,
    ROUND(total_revenue, 2) as total_revenue,
    ROUND(avg_item_price, 2) as avg_item_price,
    ROUND(avg_detection_confidence, 3) as avg_detection_confidence,
    ROUND(avg_brand_confidence, 3) as avg_brand_confidence,
    CASE
        WHEN total_purchases >= 100 THEN 'High Volume'
        WHEN total_purchases >= 20 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END as volume_category
FROM brand_stats
WHERE total_purchases >= 5  -- Filter for meaningful sample sizes
ORDER BY total_purchases DESC, brand_substitution_rate DESC;

-- NCR Geographic Distribution Analysis
CREATE OR REPLACE VIEW v_ncr_geographic_analysis AS
SELECT
    municipality_name,
    region,
    province_name,
    COUNT(DISTINCT store_id) as unique_stores,
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
    ROUND(
        (COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as substitution_rate_pct,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    COUNT(DISTINCT DATE(processed_at)) as active_days,
    MIN(processed_at) as first_transaction,
    MAX(processed_at) as last_transaction
FROM fact_transactions_location
WHERE processed_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY municipality_name, region, province_name
ORDER BY total_transactions DESC;

-- Audio Transcript Analysis
CREATE OR REPLACE VIEW v_transcript_analysis AS
WITH transcript_stats AS (
    SELECT
        canonical_tx_id,
        municipality_name,
        substitution_detected,
        audio_transcript,
        LENGTH(audio_transcript) as transcript_length,
        ARRAY_LENGTH(STRING_TO_ARRAY(audio_transcript, ' '), 1) as word_count,
        processing_duration,
        total_amount
    FROM fact_transactions_location
    WHERE audio_transcript IS NOT NULL
    AND LENGTH(TRIM(audio_transcript)) > 0
    AND processed_at >= CURRENT_DATE - INTERVAL '90 days'
)
SELECT
    municipality_name,
    substitution_detected,
    COUNT(*) as transactions,
    AVG(transcript_length) as avg_transcript_length,
    AVG(word_count) as avg_word_count,
    AVG(processing_duration) as avg_processing_time,
    AVG(total_amount) as avg_transaction_value,
    MIN(transcript_length) as min_transcript_length,
    MAX(transcript_length) as max_transcript_length,
    -- Common word analysis
    MODE() WITHIN GROUP (ORDER BY SPLIT_PART(audio_transcript, ' ', 1)) as most_common_first_word
FROM transcript_stats
GROUP BY municipality_name, substitution_detected
ORDER BY municipality_name, substitution_detected DESC;

-- Device Performance Analysis
CREATE OR REPLACE VIEW v_device_performance_analysis AS
SELECT
    device_id,
    store_id,
    municipality_name,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
    ROUND(
        (COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as device_substitution_rate,
    SUM(total_amount) as device_revenue,
    AVG(total_amount) as avg_transaction_value,
    AVG(processing_duration) as avg_processing_time,
    AVG(total_items) as avg_items_per_transaction,
    COUNT(DISTINCT DATE(processed_at)) as active_days,
    MIN(processed_at) as first_transaction,
    MAX(processed_at) as last_transaction,
    -- Edge version analysis
    edge_version,
    COUNT(*) FILTER (WHERE audio_stored = FALSE) as privacy_compliant_transactions
FROM fact_transactions_location
WHERE processed_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY device_id, store_id, municipality_name, edge_version
ORDER BY total_transactions DESC;

-- Substitution Event Summary Dashboard
CREATE OR REPLACE VIEW v_substitution_dashboard AS
SELECT
    'Overall' as metric_scope,
    NULL as scope_value,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as total_substitutions,
    ROUND(
        (COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100,
        2
    ) as substitution_rate_pct,
    SUM(total_amount) as total_revenue,
    SUM(total_amount) FILTER (WHERE substitution_detected = TRUE) as substitution_revenue,
    AVG(brand_switching_score) FILTER (WHERE substitution_detected = TRUE) as avg_switching_score,
    COUNT(DISTINCT municipality_name) as unique_municipalities,
    COUNT(DISTINCT store_id) as unique_stores,
    COUNT(DISTINCT device_id) as unique_devices
FROM fact_transactions_location
WHERE processed_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT
    'By Municipality',
    municipality_name,
    COUNT(*),
    COUNT(*) FILTER (WHERE substitution_detected = TRUE),
    ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100, 2),
    SUM(total_amount),
    SUM(total_amount) FILTER (WHERE substitution_detected = TRUE),
    AVG(brand_switching_score) FILTER (WHERE substitution_detected = TRUE),
    1,
    COUNT(DISTINCT store_id),
    COUNT(DISTINCT device_id)
FROM fact_transactions_location
WHERE processed_at >= CURRENT_DATE - INTERVAL '30 days'
AND municipality_name IS NOT NULL
GROUP BY municipality_name

ORDER BY metric_scope, substitution_rate_pct DESC;

-- Create materialized view for performance (refresh daily)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_daily_substitution_summary AS
SELECT
    DATE(processed_at) as summary_date,
    municipality_name,
    COUNT(*) as transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
    ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100, 2) as substitution_rate,
    SUM(total_amount) as revenue,
    AVG(total_amount) as avg_transaction,
    COUNT(DISTINCT device_id) as active_devices,
    COUNT(DISTINCT store_id) as active_stores
FROM fact_transactions_location
WHERE processed_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY DATE(processed_at), municipality_name;

-- Create index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_daily_substitution_summary
ON mv_daily_substitution_summary(summary_date, municipality_name);

-- Comments for documentation
COMMENT ON VIEW v_substitution_by_location IS 'Substitution rates and revenue impact by store location';
COMMENT ON VIEW v_brand_switching_patterns IS 'Analysis of brand switching behavior by category and location';
COMMENT ON VIEW v_daily_substitution_trends IS 'Daily trends in substitution events and transaction patterns';
COMMENT ON VIEW v_customer_behavior_analysis IS 'Customer request types vs actual purchase behavior';
COMMENT ON VIEW v_brand_performance_analysis IS 'Brand popularity and substitution rates with confidence metrics';
COMMENT ON VIEW v_ncr_geographic_analysis IS 'Geographic distribution of transactions across NCR municipalities';
COMMENT ON VIEW v_transcript_analysis IS 'Audio transcript characteristics and processing metrics';
COMMENT ON VIEW v_device_performance_analysis IS 'Device-level performance and substitution tracking';
COMMENT ON VIEW v_substitution_dashboard IS 'Executive dashboard summary of substitution metrics';
COMMENT ON MATERIALIZED VIEW mv_daily_substitution_summary IS 'Daily aggregated substitution metrics for fast reporting';