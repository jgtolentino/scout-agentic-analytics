-- ==========================================
-- Scout Analytics: Client-Ready Views
-- Business intelligence and reporting views
-- ==========================================

-- This script creates analytics views for client reporting, data quality validation,
-- and business intelligence dashboards. All views are optimized for performance
-- and provide clean, consistent data for external consumption.

-- ==========================================
-- 1. ANALYTICAL SCHEMA
-- ==========================================

-- Create dedicated schema for analytics views
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA analytics IS
'Analytics schema containing client-ready views for business intelligence and reporting';

-- ==========================================
-- 2. SARI-SARI STORE TRANSACTIONS VIEW
-- ==========================================

-- Primary analytics view for client consumption
CREATE OR REPLACE VIEW analytics.v_sari_sari_transactions AS
SELECT
    -- Transaction identifiers
    t.transaction_id,
    t.store_id,
    t.device_id,

    -- Location data (verified only)
    t.payload_json -> 'location' ->> 'region' as region,
    t.payload_json -> 'location' ->> 'municipality' as municipality,
    t.payload_json -> 'location' ->> 'barangay' as barangay,
    (t.payload_json -> 'location' -> 'geo' ->> 'lat')::DOUBLE PRECISION as latitude,
    (t.payload_json -> 'location' -> 'geo' ->> 'lon')::DOUBLE PRECISION as longitude,

    -- Store information
    s.store_name,
    s.municipality as store_municipality,
    s.geo_latitude as store_latitude,
    s.geo_longitude as store_longitude,

    -- Basket analysis
    (t.payload_json -> 'basket' ->> 'itemCount')::INTEGER as item_count,
    (t.payload_json -> 'basket' ->> 'totalAmount')::DECIMAL as total_amount,
    CASE WHEN (t.payload_json -> 'basket' ->> 'itemCount')::INTEGER > 1 THEN TRUE ELSE FALSE END as is_basket,

    -- Customer interaction
    t.payload_json -> 'interaction' ->> 'ageBracket' as age_bracket,
    t.payload_json -> 'interaction' ->> 'gender' as gender,
    t.payload_json -> 'interaction' ->> 'role' as customer_role,
    t.payload_json -> 'interaction' ->> 'weekdayOrWeekend' as weekday_weekend,
    t.payload_json -> 'interaction' ->> 'timeOfDay' as time_of_day,

    -- Quality flags
    (t.payload_json -> 'qualityFlags' ->> 'locationVerified')::BOOLEAN as location_verified,
    (t.payload_json -> 'qualityFlags' ->> 'brandMatched')::BOOLEAN as brand_matched,
    (t.payload_json -> 'qualityFlags' ->> 'substitutionDetected')::BOOLEAN as substitution_detected,

    -- Temporal data
    t.created_at as transaction_timestamp,
    DATE(t.created_at) as transaction_date,
    EXTRACT(YEAR FROM t.created_at) as transaction_year,
    EXTRACT(MONTH FROM t.created_at) as transaction_month,
    EXTRACT(DOW FROM t.created_at) as day_of_week,
    EXTRACT(HOUR FROM t.created_at) as hour_of_day,

    -- Data lineage
    t.payload_json -> 'source' ->> 'file' as source_file,
    t.updated_at as last_updated

FROM public.fact_transactions_location t
LEFT JOIN public.dim_stores_ncr s ON s.store_id = t.store_id
WHERE
    -- Only include verified transactions for client reporting
    (t.payload_json -> 'qualityFlags' ->> 'locationVerified')::BOOLEAN = TRUE
    AND t.payload_json -> 'location' ->> 'municipality' != 'Unknown';

COMMENT ON VIEW analytics.v_sari_sari_transactions IS
'Client-ready view of verified sari-sari store transactions with complete location and basket data';

-- ==========================================
-- 3. STORE PERFORMANCE METRICS VIEW
-- ==========================================

CREATE OR REPLACE VIEW analytics.v_store_performance AS
WITH daily_metrics AS (
    SELECT
        s.store_id,
        s.store_name,
        s.municipality,
        s.geo_latitude,
        s.geo_longitude,
        DATE(t.created_at) as transaction_date,
        COUNT(*) as daily_transactions,
        COUNT(*) FILTER (WHERE (t.payload_json -> 'basket' ->> 'itemCount')::INTEGER > 1) as daily_basket_transactions,
        COUNT(DISTINCT t.device_id) as daily_unique_devices,
        AVG((t.payload_json -> 'basket' ->> 'itemCount')::INTEGER) as daily_avg_basket_size,
        SUM((t.payload_json -> 'basket' ->> 'totalAmount')::DECIMAL) as daily_total_amount
    FROM public.dim_stores_ncr s
    LEFT JOIN analytics.v_sari_sari_transactions t ON t.store_id = s.store_id
    WHERE t.location_verified = TRUE
    GROUP BY s.store_id, s.store_name, s.municipality, s.geo_latitude, s.geo_longitude, DATE(t.created_at)
)
SELECT
    store_id,
    store_name,
    municipality,
    geo_latitude,
    geo_longitude,

    -- Overall metrics
    COUNT(transaction_date) as active_days,
    SUM(daily_transactions) as total_transactions,
    SUM(daily_basket_transactions) as total_basket_transactions,
    SUM(daily_unique_devices) as total_unique_devices,
    SUM(daily_total_amount) as total_amount,

    -- Average daily performance
    ROUND(AVG(daily_transactions), 2) as avg_daily_transactions,
    ROUND(AVG(daily_basket_transactions), 2) as avg_daily_basket_transactions,
    ROUND(AVG(daily_unique_devices), 2) as avg_daily_unique_devices,
    ROUND(AVG(daily_avg_basket_size), 2) as avg_basket_size,
    ROUND(AVG(daily_total_amount), 2) as avg_daily_amount,

    -- Performance indicators
    ROUND((SUM(daily_basket_transactions) * 100.0 / NULLIF(SUM(daily_transactions), 0)), 2) as basket_rate_pct,
    ROUND((SUM(daily_transactions) * 1.0 / NULLIF(SUM(daily_unique_devices), 0)), 2) as transactions_per_device,
    MIN(transaction_date) as first_transaction_date,
    MAX(transaction_date) as last_transaction_date,

    -- Performance categories
    CASE
        WHEN AVG(daily_transactions) >= 50 THEN 'High Volume'
        WHEN AVG(daily_transactions) >= 20 THEN 'Medium Volume'
        WHEN AVG(daily_transactions) >= 5 THEN 'Low Volume'
        ELSE 'Minimal Activity'
    END as volume_category,

    CASE
        WHEN (SUM(daily_basket_transactions) * 100.0 / NULLIF(SUM(daily_transactions), 0)) >= 30 THEN 'High Basket Rate'
        WHEN (SUM(daily_basket_transactions) * 100.0 / NULLIF(SUM(daily_transactions), 0)) >= 15 THEN 'Medium Basket Rate'
        ELSE 'Low Basket Rate'
    END as basket_category

FROM daily_metrics
GROUP BY store_id, store_name, municipality, geo_latitude, geo_longitude
ORDER BY total_transactions DESC;

COMMENT ON VIEW analytics.v_store_performance IS
'Store performance metrics with volume and basket analysis for business intelligence';

-- ==========================================
-- 4. TEMPORAL ANALYSIS VIEW
-- ==========================================

CREATE OR REPLACE VIEW analytics.v_temporal_patterns AS
SELECT
    -- Time dimensions
    transaction_date,
    transaction_year,
    transaction_month,
    day_of_week,
    CASE day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_name,
    hour_of_day,
    weekday_weekend,

    -- Geographic grouping
    municipality,

    -- Transaction metrics
    COUNT(*) as transaction_count,
    COUNT(*) FILTER (WHERE is_basket = TRUE) as basket_transactions,
    COUNT(DISTINCT store_id) as unique_stores,
    COUNT(DISTINCT device_id) as unique_devices,

    -- Basket analysis
    SUM(item_count) as total_items,
    SUM(total_amount) as total_amount,
    ROUND(AVG(item_count), 2) as avg_items_per_transaction,
    ROUND(AVG(total_amount), 2) as avg_amount_per_transaction,

    -- Quality metrics
    COUNT(*) FILTER (WHERE location_verified = TRUE) as verified_transactions,
    COUNT(*) FILTER (WHERE brand_matched = TRUE) as brand_matched_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitution_transactions,

    -- Performance rates
    ROUND((COUNT(*) FILTER (WHERE is_basket = TRUE) * 100.0 / COUNT(*)), 2) as basket_rate_pct,
    ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE) * 100.0 / COUNT(*)), 2) as substitution_rate_pct

FROM analytics.v_sari_sari_transactions
GROUP BY
    transaction_date, transaction_year, transaction_month, day_of_week,
    hour_of_day, weekday_weekend, municipality
ORDER BY transaction_date DESC, hour_of_day;

COMMENT ON VIEW analytics.v_temporal_patterns IS
'Temporal analysis of transaction patterns by time, location, and performance metrics';

-- ==========================================
-- 5. GEOGRAPHIC DISTRIBUTION VIEW
-- ==========================================

CREATE OR REPLACE VIEW analytics.v_geographic_distribution AS
SELECT
    region,
    municipality,
    barangay,

    -- Store coverage
    COUNT(DISTINCT store_id) as unique_stores,
    array_agg(DISTINCT store_id ORDER BY store_id) as store_ids,

    -- Transaction volume
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE is_basket = TRUE) as basket_transactions,
    COUNT(DISTINCT device_id) as unique_devices,

    -- Geographic center (average coordinates)
    ROUND(AVG(latitude), 6) as avg_latitude,
    ROUND(AVG(longitude), 6) as avg_longitude,

    -- Performance metrics
    SUM(item_count) as total_items,
    SUM(total_amount) as total_amount,
    ROUND(AVG(item_count), 2) as avg_basket_size,
    ROUND(AVG(total_amount), 2) as avg_transaction_amount,

    -- Quality indicators
    ROUND((COUNT(*) FILTER (WHERE is_basket = TRUE) * 100.0 / COUNT(*)), 2) as basket_rate_pct,
    ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE) * 100.0 / COUNT(*)), 2) as substitution_rate_pct,

    -- Activity periods
    MIN(transaction_date) as first_transaction,
    MAX(transaction_date) as last_transaction,
    COUNT(DISTINCT transaction_date) as active_days,

    -- Market classification
    CASE
        WHEN COUNT(*) >= 1000 THEN 'Major Market'
        WHEN COUNT(*) >= 500 THEN 'Significant Market'
        WHEN COUNT(*) >= 100 THEN 'Emerging Market'
        ELSE 'Limited Activity'
    END as market_classification

FROM analytics.v_sari_sari_transactions
GROUP BY region, municipality, barangay
ORDER BY total_transactions DESC, municipality, barangay;

COMMENT ON VIEW analytics.v_geographic_distribution IS
'Geographic distribution of transactions and market classification by location';

-- ==========================================
-- 6. DATA QUALITY DASHBOARD VIEW
-- ==========================================

CREATE OR REPLACE VIEW analytics.v_data_quality_dashboard AS
WITH quality_metrics AS (
    SELECT
        COUNT(*) as total_transactions,
        COUNT(*) FILTER (WHERE location_verified = TRUE) as verified_transactions,
        COUNT(*) FILTER (WHERE brand_matched = TRUE) as brand_matched_transactions,
        COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitution_transactions,
        COUNT(*) FILTER (WHERE municipality != 'Unknown') as known_location_transactions,
        COUNT(*) FILTER (WHERE is_basket = TRUE) as basket_transactions,
        COUNT(DISTINCT store_id) as unique_stores,
        COUNT(DISTINCT device_id) as unique_devices,
        MIN(transaction_date) as first_transaction,
        MAX(transaction_date) as last_transaction
    FROM analytics.v_sari_sari_transactions
),
store_coverage AS (
    SELECT COUNT(*) as stores_in_dimension
    FROM public.dim_stores_ncr
)
SELECT
    'Data Quality Dashboard' as report_title,
    CURRENT_TIMESTAMP as generated_at,

    -- Volume metrics
    qm.total_transactions,
    qm.unique_stores,
    qm.unique_devices,
    sc.stores_in_dimension,

    -- Quality rates
    ROUND((qm.verified_transactions * 100.0 / NULLIF(qm.total_transactions, 0)), 2) as verification_rate_pct,
    ROUND((qm.brand_matched_transactions * 100.0 / NULLIF(qm.total_transactions, 0)), 2) as brand_match_rate_pct,
    ROUND((qm.substitution_transactions * 100.0 / NULLIF(qm.total_transactions, 0)), 2) as substitution_rate_pct,
    ROUND((qm.known_location_transactions * 100.0 / NULLIF(qm.total_transactions, 0)), 2) as known_location_rate_pct,
    ROUND((qm.basket_transactions * 100.0 / NULLIF(qm.total_transactions, 0)), 2) as basket_rate_pct,

    -- Coverage metrics
    ROUND((qm.unique_stores * 100.0 / NULLIF(sc.stores_in_dimension, 0)), 2) as store_coverage_pct,
    ROUND((qm.total_transactions * 1.0 / NULLIF(qm.unique_devices, 0)), 2) as transactions_per_device,

    -- Data freshness
    qm.first_transaction,
    qm.last_transaction,
    EXTRACT(DAYS FROM (CURRENT_DATE - qm.last_transaction)) as days_since_last_transaction,

    -- Quality status
    CASE
        WHEN qm.verified_transactions * 100.0 / NULLIF(qm.total_transactions, 0) = 100 THEN 'EXCELLENT'
        WHEN qm.verified_transactions * 100.0 / NULLIF(qm.total_transactions, 0) >= 95 THEN 'GOOD'
        WHEN qm.verified_transactions * 100.0 / NULLIF(qm.total_transactions, 0) >= 80 THEN 'ACCEPTABLE'
        ELSE 'NEEDS_ATTENTION'
    END as overall_quality_status

FROM quality_metrics qm, store_coverage sc;

COMMENT ON VIEW analytics.v_data_quality_dashboard IS
'Real-time data quality dashboard with key metrics and status indicators';

-- ==========================================
-- 7. BUSINESS INTELLIGENCE SUMMARY VIEW
-- ==========================================

CREATE OR REPLACE VIEW analytics.v_business_intelligence_summary AS
SELECT
    -- Report metadata
    'Scout Edge Business Intelligence' as report_title,
    CURRENT_DATE as report_date,
    COUNT(*) as total_verified_transactions,

    -- Market overview
    COUNT(DISTINCT municipality) as total_municipalities,
    COUNT(DISTINCT store_id) as active_stores,
    COUNT(DISTINCT device_id) as unique_devices,

    -- Transaction patterns
    SUM(item_count) as total_items_sold,
    SUM(total_amount) as total_transaction_value,
    ROUND(AVG(item_count), 2) as avg_items_per_transaction,
    ROUND(AVG(total_amount), 2) as avg_transaction_value,

    -- Basket analysis
    COUNT(*) FILTER (WHERE is_basket = TRUE) as multi_item_transactions,
    ROUND((COUNT(*) FILTER (WHERE is_basket = TRUE) * 100.0 / COUNT(*)), 2) as basket_rate_pct,

    -- Quality indicators
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitution_transactions,
    ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE) * 100.0 / COUNT(*)), 2) as substitution_rate_pct,

    -- Top performing municipality
    (
        SELECT municipality
        FROM analytics.v_sari_sari_transactions
        GROUP BY municipality
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) as top_municipality_by_volume,

    -- Most active store
    (
        SELECT store_name
        FROM analytics.v_sari_sari_transactions
        GROUP BY store_id, store_name
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) as most_active_store,

    -- Temporal insights
    (
        SELECT weekday_weekend
        FROM analytics.v_sari_sari_transactions
        GROUP BY weekday_weekend
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) as peak_activity_period,

    -- Data coverage period
    MIN(transaction_date) as data_start_date,
    MAX(transaction_date) as data_end_date,
    COUNT(DISTINCT transaction_date) as total_active_days

FROM analytics.v_sari_sari_transactions;

COMMENT ON VIEW analytics.v_business_intelligence_summary IS
'Executive summary view with key business intelligence metrics and insights';

-- ==========================================
-- 8. PERFORMANCE OPTIMIZATION
-- ==========================================

-- Create indexes for analytics performance
CREATE INDEX IF NOT EXISTS idx_fact_location_store_date
    ON public.fact_transactions_location (store_id, created_at)
    WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

CREATE INDEX IF NOT EXISTS idx_fact_location_municipality_date
    ON public.fact_transactions_location ((payload_json -> 'location' ->> 'municipality'), created_at)
    WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

CREATE INDEX IF NOT EXISTS idx_fact_location_basket_flag
    ON public.fact_transactions_location (((payload_json -> 'basket' ->> 'itemCount')::integer > 1))
    WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

-- ==========================================
-- 9. ACCESS CONTROL AND SECURITY
-- ==========================================

-- Create read-only role for analytics users
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analytics_reader') THEN
        CREATE ROLE analytics_reader;
    END IF;
END $$;

-- Grant read access to analytics schema
GRANT USAGE ON SCHEMA analytics TO analytics_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO analytics_reader;
GRANT SELECT ON ALL VIEWS IN SCHEMA analytics TO analytics_reader;

-- Ensure future objects are accessible
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT SELECT ON TABLES TO analytics_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT SELECT ON VIEWS TO analytics_reader;

-- ==========================================
-- 10. VALIDATION AND TESTING
-- ==========================================

-- Validate all views are working correctly
DO $$
DECLARE
    view_record RECORD;
    row_count INTEGER;
BEGIN
    RAISE NOTICE 'Analytics Views Validation Report:';
    RAISE NOTICE '=====================================';

    FOR view_record IN
        SELECT table_name
        FROM information_schema.views
        WHERE table_schema = 'analytics'
        ORDER BY table_name
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM analytics.%I', view_record.table_name) INTO row_count;
        RAISE NOTICE 'View: %, Rows: %', view_record.table_name, row_count;
    END LOOP;

    RAISE NOTICE '=====================================';
    RAISE NOTICE 'All analytics views created successfully!';
END $$;