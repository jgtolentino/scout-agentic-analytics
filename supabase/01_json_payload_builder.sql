-- ==========================================
-- Scout Edge JSON Payload Builder - PostgreSQL/Supabase
-- Transforms raw staging data into deduplicated JSONB payloads
-- ==========================================

-- ==========================================
-- 1. CREATE FACT TABLE FOR JSONB PAYLOADS
-- ==========================================

-- Drop existing fact table if it exists
DROP TABLE IF EXISTS fact_transactions_location CASCADE;

-- Create fact table with JSONB payload column
CREATE TABLE fact_transactions_location (
    -- Primary identifiers
    canonical_tx_id     TEXT            PRIMARY KEY,
    transaction_id      TEXT            NOT NULL,
    store_id            INTEGER         NULL,
    device_id           TEXT            NULL,

    -- Summary metrics (for fast queries without JSON parsing)
    total_amount        DECIMAL(10,2)   NULL,
    item_count          INTEGER         DEFAULT 0,
    substitution_detected BOOLEAN       DEFAULT FALSE,

    -- Location summary (for geographic queries)
    municipality_name   TEXT            NULL,
    province_name       TEXT            NULL,
    region              TEXT            NULL,
    latitude            DECIMAL(10,8)   NULL,
    longitude           DECIMAL(11,8)   NULL,

    -- Quality metrics
    data_quality_score  DECIMAL(5,2)    NULL,

    -- JSONB payload (the complete nested structure)
    payload_json        JSONB           NULL,

    -- Audit fields
    source_file_count   INTEGER         DEFAULT 0,
    created_at          TIMESTAMPTZ     DEFAULT NOW(),

    -- Check constraints
    CONSTRAINT chk_fact_quality_score CHECK (data_quality_score BETWEEN 0 AND 100),
    CONSTRAINT chk_fact_amount_positive CHECK (total_amount >= 0)
);

-- Create indexes for performance
CREATE INDEX idx_fact_store_location ON fact_transactions_location (store_id, municipality_name);
CREATE INDEX idx_fact_substitution ON fact_transactions_location (substitution_detected, store_id) WHERE substitution_detected = TRUE;
CREATE INDEX idx_fact_quality_score ON fact_transactions_location (data_quality_score DESC);
CREATE INDEX idx_fact_created_at ON fact_transactions_location (created_at DESC);

-- JSONB indexes for efficient JSON querying
CREATE INDEX idx_fact_json_store_id ON fact_transactions_location USING gin ((payload_json -> 'storeId'));
CREATE INDEX idx_fact_json_municipality ON fact_transactions_location USING gin ((payload_json -> 'location' -> 'municipality'));
CREATE INDEX idx_fact_json_substitution ON fact_transactions_location USING gin ((payload_json -> 'qualityFlags' -> 'substitutionDetected'));

-- ==========================================
-- 2. GEOGRAPHIC REFERENCE DATA
-- ==========================================

-- Create NCR store mapping if it doesn't exist
DROP TABLE IF EXISTS dim_ncr_stores CASCADE;

CREATE TABLE dim_ncr_stores (
    store_id            INTEGER         PRIMARY KEY,
    store_name          TEXT            NOT NULL,
    device_id           TEXT            NULL,
    municipality_name   TEXT            NOT NULL,
    province_name       TEXT            NOT NULL DEFAULT 'Metro Manila',
    region              TEXT            NOT NULL DEFAULT 'NCR',
    barangay_name       TEXT            NULL,
    psgc_region         TEXT            DEFAULT '130000000',
    psgc_citymun        TEXT            NULL,
    psgc_barangay       TEXT            NULL,
    latitude            DECIMAL(10,8)   NOT NULL,
    longitude           DECIMAL(11,8)   NOT NULL
);

-- Insert NCR store mappings
INSERT INTO dim_ncr_stores (store_id, store_name, device_id, municipality_name, province_name, region, barangay_name, psgc_region, psgc_citymun, psgc_barangay, latitude, longitude) VALUES
(102, 'Scout Store Manila', 'scoutpi-0102', 'Manila', 'Metro Manila', 'NCR', 'Ermita', '130000000', '137601000', '137601034', 14.5995, 120.9842),
(103, 'Scout Store Quezon City', 'scoutpi-0103', 'Quezon City', 'Metro Manila', 'NCR', 'Bagumbayan', '130000000', '137404000', '137404018', 14.6760, 121.0437),
(104, 'Scout Store Makati', 'scoutpi-0104', 'Makati', 'Metro Manila', 'NCR', 'Poblacion', '130000000', '137404000', '137404032', 14.5547, 121.0244),
(108, 'Scout Store Pasig', 'scoutpi-0108', 'Pasig', 'Metro Manila', 'NCR', 'Kapitolyo', '130000000', '137307000', '137307015', 14.5764, 121.0851),
(109, 'Scout Store Mandaluyong', 'scoutpi-0109', 'Mandaluyong', 'Metro Manila', 'NCR', 'Addition Hills', '130000000', '137501000', '137501001', 14.5833, 121.0333),
(110, 'Scout Store Parañaque', 'scoutpi-0110', 'Parañaque', 'Metro Manila', 'NCR', 'BF Homes', '130000000', '137307000', '137307004', 14.4793, 121.0195),
(112, 'Scout Store Taguig', 'scoutpi-0112', 'Taguig', 'Metro Manila', 'NCR', 'Bonifacio Global City', '130000000', '137601000', '137601008', 14.5176, 121.0509)
ON CONFLICT (store_id) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    device_id = EXCLUDED.device_id,
    municipality_name = EXCLUDED.municipality_name,
    barangay_name = EXCLUDED.barangay_name,
    psgc_citymun = EXCLUDED.psgc_citymun,
    psgc_barangay = EXCLUDED.psgc_barangay,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude;

-- ==========================================
-- 3. JSON PAYLOAD BUILDER FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION build_scout_json_payload(p_transaction_id TEXT)
RETURNS JSONB AS $$
DECLARE
    v_payload JSONB;
BEGIN
    -- Build complete JSONB payload
    WITH transaction_base AS (
        SELECT
            s.canonical_tx_id,
            s.store_id,
            s.device_id,
            MIN(s.transaction_timestamp) as earliest_timestamp,
            COUNT(*) as interaction_count,
            SUM(COALESCE(s.total_amount, 0)) as total_amount,
            -- Demographics (prefer latest non-null values)
            COALESCE(
                MAX(CASE WHEN s.audio_transcript IS NOT NULL AND LENGTH(s.audio_transcript) > 0
                    THEN s.audio_transcript END),
                'No audio'
            ) as audio_transcript,
            -- Quality flags
            BOOL_OR(s.substitution_detected) as has_substitution,
            CASE WHEN s.store_id IS NOT NULL THEN TRUE ELSE FALSE END as location_verified,
            COUNT(*) FILTER (WHERE s.audio_transcript IS NOT NULL AND LENGTH(s.audio_transcript) > 0) > 0 as has_audio
        FROM scout_gold_transactions_flat s
        WHERE s.canonical_tx_id = p_transaction_id
        GROUP BY s.canonical_tx_id, s.store_id, s.device_id
    ),
    basket_items AS (
        SELECT
            s.canonical_tx_id,
            -- Build basket items array
            jsonb_agg(
                jsonb_build_object(
                    'lineId', ROW_NUMBER() OVER (ORDER BY s.ts_ph),
                    'brand', COALESCE(s.brand, 'Unknown'),
                    'sku', 'SKU-' || s.deviceid,
                    'qty', 1,
                    'unitPrice', COALESCE(s.total_price, 0),
                    'totalPrice', COALESCE(s.total_price, 0),
                    'substitutionEvent', COALESCE(s.substitution_detected, FALSE),
                    'substitutionFrom', CASE WHEN s.substitution_detected THEN s.brand END
                )
            ) as basket_items_json
        FROM scout_gold_transactions_flat s
        WHERE s.canonical_tx_id = p_transaction_id
    )
    SELECT jsonb_build_object(
        'transactionId', tb.canonical_tx_id,
        'storeId', tb.store_id,
        'deviceId', tb.device_id,
        'timestamp', TO_CHAR(tb.earliest_timestamp AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'basket', jsonb_build_object(
            'items', bi.basket_items_json
        ),
        'interaction', jsonb_build_object(
            'ageBracket', COALESCE(
                (SELECT age::TEXT FROM scout_gold_transactions_flat s2
                 WHERE s2.canonical_tx_id = tb.canonical_tx_id AND s2.age IS NOT NULL
                 ORDER BY s2.ts_ph DESC LIMIT 1),
                'Unknown'
            ),
            'gender', COALESCE(
                (SELECT gender FROM scout_gold_transactions_flat s2
                 WHERE s2.canonical_tx_id = tb.canonical_tx_id AND s2.gender IS NOT NULL
                 ORDER BY s2.ts_ph DESC LIMIT 1),
                'Unknown'
            ),
            'role', 'Customer',
            'weekdayOrWeekend', CASE WHEN EXTRACT(DOW FROM tb.earliest_timestamp) IN (0, 6) THEN 'Weekend' ELSE 'Weekday' END,
            'timeOfDay', TO_CHAR(tb.earliest_timestamp, 'HH12AM')
        ),
        'location', jsonb_build_object(
            'region', COALESCE(ds.region, 'NCR'),
            'province', COALESCE(ds.province_name, 'Metro Manila'),
            'municipality', ds.municipality_name,
            'barangay', ds.barangay_name,
            'psgc_region', COALESCE(ds.psgc_region, '130000000'),
            'psgc_citymun', ds.psgc_citymun,
            'psgc_barangay', ds.psgc_barangay,
            'geo', jsonb_build_object(
                'lat', ds.latitude,
                'lon', ds.longitude
            )
        ),
        'qualityFlags', jsonb_build_object(
            'brandMatched', CASE WHEN ds.store_id IS NOT NULL THEN TRUE ELSE FALSE END,
            'locationVerified', CASE WHEN ds.municipality_name IS NOT NULL AND ds.latitude IS NOT NULL THEN TRUE ELSE FALSE END,
            'substitutionDetected', tb.has_substitution
        ),
        'source', jsonb_build_object(
            'file', 'scout_gold_transactions_flat',
            'rowCount', tb.interaction_count
        )
    ) INTO v_payload
    FROM transaction_base tb
    LEFT JOIN basket_items bi ON tb.canonical_tx_id = bi.canonical_tx_id
    LEFT JOIN dim_ncr_stores ds ON tb.store_id = ds.store_id;

    RETURN v_payload;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 4. DEDUPLICATION AND TRANSFORMATION PROCEDURE
-- ==========================================

CREATE OR REPLACE FUNCTION transform_to_json_payloads(
    clean_fact_table BOOLEAN DEFAULT TRUE,
    batch_size INTEGER DEFAULT 1000
)
RETURNS TABLE (
    processed_count INTEGER,
    error_count INTEGER,
    duration_seconds INTEGER
) AS $$
DECLARE
    v_start_time TIMESTAMPTZ := NOW();
    v_processed_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_total_transactions INTEGER;
    v_batch_start INTEGER := 1;
    v_batch_end INTEGER;
    v_current_tx_id TEXT;
    v_error_message TEXT;
BEGIN
    RAISE NOTICE 'Scout Edge JSON Payload Transformation Started';
    RAISE NOTICE 'Start Time: %', v_start_time;

    -- Clean fact table if requested
    IF clean_fact_table THEN
        TRUNCATE TABLE fact_transactions_location;
        RAISE NOTICE 'Fact table cleaned.';
    END IF;

    -- Get count of distinct transaction IDs to process
    SELECT COUNT(DISTINCT canonical_tx_id) INTO v_total_transactions
    FROM scout_gold_transactions_flat
    WHERE canonical_tx_id IS NOT NULL;

    RAISE NOTICE 'Total unique transactions to process: %', v_total_transactions;

    -- Process transactions using a cursor for memory efficiency
    FOR v_current_tx_id IN
        SELECT DISTINCT canonical_tx_id
        FROM scout_gold_transactions_flat
        WHERE canonical_tx_id IS NOT NULL
        ORDER BY canonical_tx_id
    LOOP
        BEGIN
            -- Insert transformed transaction
            INSERT INTO fact_transactions_location (
                canonical_tx_id,
                transaction_id,
                store_id,
                device_id,
                total_amount,
                item_count,
                substitution_detected,
                municipality_name,
                province_name,
                region,
                latitude,
                longitude,
                data_quality_score,
                source_file_count,
                payload_json
            )
            WITH transaction_summary AS (
                SELECT
                    s.canonical_tx_id,
                    s.canonical_tx_id as transaction_id,
                    COALESCE(s.storeid::INTEGER, NULL) as store_id,
                    s.deviceid as device_id,
                    SUM(COALESCE(s.total_price, 0)) as total_amount,
                    COUNT(*) as item_count,
                    BOOL_OR(COALESCE(s.substitution_detected, FALSE)) as substitution_detected,
                    ds.municipality_name,
                    ds.province_name,
                    ds.region,
                    ds.latitude,
                    ds.longitude,
                    -- Calculate quality score (0-100)
                    (CASE WHEN s.canonical_tx_id IS NOT NULL THEN 20 ELSE 0 END +
                     CASE WHEN s.storeid IS NOT NULL AND s.storeid != '' THEN 20 ELSE 0 END +
                     CASE WHEN s.deviceid IS NOT NULL THEN 10 ELSE 0 END +
                     CASE WHEN ds.municipality_name IS NOT NULL THEN 20 ELSE 0 END +
                     CASE WHEN COUNT(*) FILTER (WHERE s.audio_transcript IS NOT NULL AND LENGTH(s.audio_transcript) > 0) > 0 THEN 20 ELSE 0 END +
                     CASE WHEN BOOL_OR(COALESCE(s.substitution_detected, FALSE)) THEN 10 ELSE 0 END)::DECIMAL(5,2) as data_quality_score,
                    1 as source_file_count,
                    build_scout_json_payload(s.canonical_tx_id) as payload_json
                FROM scout_gold_transactions_flat s
                LEFT JOIN dim_ncr_stores ds ON s.storeid::INTEGER = ds.store_id
                WHERE s.canonical_tx_id = v_current_tx_id
                GROUP BY s.canonical_tx_id, s.storeid, s.deviceid, ds.municipality_name, ds.province_name, ds.region, ds.latitude, ds.longitude
            )
            SELECT * FROM transaction_summary;

            v_processed_count := v_processed_count + 1;

        EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            RAISE NOTICE 'Error processing transaction %: %', v_current_tx_id, v_error_message;
        END;

        -- Progress update every 1000 transactions
        IF v_processed_count % 1000 = 0 THEN
            RAISE NOTICE 'Progress: % / % transactions processed', v_processed_count, v_total_transactions;
        END IF;
    END LOOP;

    -- Final statistics
    DECLARE
        v_end_time TIMESTAMPTZ := NOW();
        v_duration_seconds INTEGER := EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER;
    BEGIN
        RAISE NOTICE 'Transformation Complete';
        RAISE NOTICE 'Transactions processed: %', v_processed_count;
        RAISE NOTICE 'Errors encountered: %', v_error_count;
        RAISE NOTICE 'Duration: % seconds', v_duration_seconds;
        RAISE NOTICE 'End Time: %', v_end_time;

        -- Return summary
        RETURN QUERY SELECT v_processed_count, v_error_count, v_duration_seconds;
    END;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 5. VALIDATION FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION validate_json_payloads()
RETURNS TABLE (
    check_category TEXT,
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
DECLARE
    v_total_rows INTEGER;
    v_avg_quality DECIMAL(5,2);
    v_json_null_count INTEGER;
BEGIN
    -- Get basic statistics
    SELECT
        COUNT(*),
        AVG(data_quality_score),
        COUNT(*) FILTER (WHERE payload_json IS NULL)
    INTO v_total_rows, v_avg_quality, v_json_null_count
    FROM fact_transactions_location;

    -- Basic completeness checks
    RETURN QUERY
    SELECT
        'Completeness'::TEXT,
        'Total Rows'::TEXT,
        CASE WHEN v_total_rows BETWEEN 10000 AND 200000 THEN '✅ PASS' ELSE '⚠️ REVIEW' END,
        'Found: ' || v_total_rows::TEXT || ' (expected 10K-200K)'

    UNION ALL

    SELECT
        'Quality'::TEXT,
        'Average Score'::TEXT,
        CASE WHEN v_avg_quality >= 70 THEN '✅ PASS' ELSE '⚠️ REVIEW' END,
        'Score: ' || ROUND(v_avg_quality, 1)::TEXT || '% (target: ≥70%)'

    UNION ALL

    SELECT
        'JSON'::TEXT,
        'Valid Payloads'::TEXT,
        CASE WHEN v_json_null_count = 0 THEN '✅ PASS' ELSE '⚠️ REVIEW' END,
        'NULL payloads: ' || v_json_null_count::TEXT

    UNION ALL

    SELECT
        'Structure'::TEXT,
        'Basket Items'::TEXT,
        CASE WHEN COUNT(*) FILTER (WHERE payload_json -> 'basket' -> 'items' IS NOT NULL) = COUNT(*)
             THEN '✅ PASS' ELSE '⚠️ REVIEW' END,
        'With basket: ' || COUNT(*) FILTER (WHERE payload_json -> 'basket' -> 'items' IS NOT NULL)::TEXT ||
        ' / ' || COUNT(*)::TEXT
    FROM fact_transactions_location
    WHERE payload_json IS NOT NULL

    UNION ALL

    SELECT
        'Geography'::TEXT,
        'Location Data'::TEXT,
        CASE WHEN COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' IS NOT NULL) > COUNT(*) * 0.7
             THEN '✅ PASS' ELSE '⚠️ REVIEW' END,
        'With location: ' || COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' IS NOT NULL)::TEXT ||
        ' (' || ROUND((COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' IS NOT NULL) * 100.0 / COUNT(*)), 1)::TEXT || '%)'
    FROM fact_transactions_location
    WHERE payload_json IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 6. ADDITIONAL UTILITY FUNCTIONS
-- ==========================================

-- Function to get store distribution
CREATE OR REPLACE FUNCTION get_store_distribution()
RETURNS TABLE (
    store_id INTEGER,
    municipality_name TEXT,
    transactions BIGINT,
    avg_quality DECIMAL(5,2),
    total_items BIGINT,
    substitutions BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.store_id,
        f.municipality_name,
        COUNT(*) as transactions,
        AVG(f.data_quality_score) as avg_quality,
        SUM(f.item_count) as total_items,
        COUNT(*) FILTER (WHERE f.substitution_detected = TRUE) as substitutions
    FROM fact_transactions_location f
    WHERE f.store_id IS NOT NULL
    GROUP BY f.store_id, f.municipality_name
    ORDER BY f.store_id;
END;
$$ LANGUAGE plpgsql;

-- Function to query JSON payloads by criteria
CREATE OR REPLACE FUNCTION query_transactions_by_location(p_municipality TEXT)
RETURNS TABLE (
    canonical_tx_id TEXT,
    store_id INTEGER,
    payload_json JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.canonical_tx_id,
        f.store_id,
        f.payload_json
    FROM fact_transactions_location f
    WHERE f.payload_json -> 'location' ->> 'municipality' = p_municipality;
END;
$$ LANGUAGE plpgsql;

-- Function to extract basket items
CREATE OR REPLACE FUNCTION get_basket_items(p_transaction_id TEXT)
RETURNS TABLE (
    line_id INTEGER,
    brand TEXT,
    sku TEXT,
    qty INTEGER,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2),
    substitution_event BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (item ->> 'lineId')::INTEGER,
        item ->> 'brand',
        item ->> 'sku',
        (item ->> 'qty')::INTEGER,
        (item ->> 'unitPrice')::DECIMAL(10,2),
        (item ->> 'totalPrice')::DECIMAL(10,2),
        (item ->> 'substitutionEvent')::BOOLEAN
    FROM fact_transactions_location f,
         jsonb_array_elements(f.payload_json -> 'basket' -> 'items') as item
    WHERE f.canonical_tx_id = p_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 7. EXECUTION EXAMPLES
-- ==========================================

-- Create a procedure wrapper for easier execution
CREATE OR REPLACE FUNCTION execute_scout_transformation()
RETURNS TEXT AS $$
DECLARE
    v_result RECORD;
    v_validation RECORD;
    v_report TEXT := '';
BEGIN
    -- Execute transformation
    RAISE NOTICE 'Starting Scout Edge JSON transformation...';

    SELECT * INTO v_result FROM transform_to_json_payloads(TRUE, 1000);

    v_report := v_report || 'Transformation Results:' || E'\n';
    v_report := v_report || '- Processed: ' || v_result.processed_count || ' transactions' || E'\n';
    v_report := v_report || '- Errors: ' || v_result.error_count || E'\n';
    v_report := v_report || '- Duration: ' || v_result.duration_seconds || ' seconds' || E'\n\n';

    -- Run validation
    RAISE NOTICE 'Running validation...';

    v_report := v_report || 'Validation Results:' || E'\n';
    FOR v_validation IN SELECT * FROM validate_json_payloads() LOOP
        v_report := v_report || v_validation.check_category || ' - ' || v_validation.check_name || ': ' ||
                   v_validation.status || ' (' || v_validation.details || ')' || E'\n';
    END LOOP;

    RETURN v_report;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 8. READY TO EXECUTE
-- ==========================================

-- Display setup completion message
DO $$
BEGIN
    RAISE NOTICE 'Scout Edge PostgreSQL JSON Payload Builder Complete';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Ready to execute:';
    RAISE NOTICE '1. SELECT execute_scout_transformation();';
    RAISE NOTICE '2. SELECT * FROM validate_json_payloads();';
    RAISE NOTICE '3. SELECT * FROM get_store_distribution();';
    RAISE NOTICE '';
    RAISE NOTICE 'Transform Scout Edge data into JSONB payloads! 🚀';
END $$;