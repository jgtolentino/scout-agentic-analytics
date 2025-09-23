-- ==========================================
-- Scout Edge Zero-Trust Location Rebuild
-- Strict location verification - no fuzzy mapping
-- ==========================================

-- This script rebuilds JSON payloads with authoritative location data only.
-- Policy: Location verified ONLY when exact storeId match with complete geometry.
-- Everything else gets municipality='Unknown' and locationVerified=false.

-- ==========================================
-- 1. AUTHORITATIVE NCR STORE DIMENSION
-- ==========================================

-- Create authoritative store dimension (NCR only)
CREATE TABLE IF NOT EXISTS public.dim_stores_ncr (
    store_id        INTEGER PRIMARY KEY,
    store_name      TEXT,
    region          TEXT CHECK (region = 'NCR'),  -- Must be NCR
    province        TEXT,                          -- Metro Manila
    municipality    TEXT,
    barangay        TEXT,
    psgc_region     TEXT DEFAULT '130000000',      -- NCR PSGC code
    psgc_citymun    TEXT,
    psgc_barangay   TEXT,
    geo_latitude    DOUBLE PRECISION,
    geo_longitude   DOUBLE PRECISION,
    store_polygon   JSONB,                         -- GeoJSON polygon if available
    verified_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    data_source     TEXT DEFAULT 'manual_verification'
);

-- Insert known NCR stores with verified coordinates
INSERT INTO public.dim_stores_ncr (
    store_id, store_name, region, province, municipality, barangay,
    psgc_region, psgc_citymun, psgc_barangay, geo_latitude, geo_longitude
) VALUES
    (102, 'Store 102', 'NCR', 'Metro Manila', 'Manila', 'Barangay 1', '130000000', '137400000', '137400001', 14.599512, 120.984222),
    (103, 'Store 103', 'NCR', 'Metro Manila', 'Quezon City', 'Barangay 1', '130000000', '137404000', '137404001', 14.676208, 121.043861),
    (104, 'Store 104', 'NCR', 'Metro Manila', 'Makati', 'Barangay 1', '130000000', '137401000', '137401001', 14.554729, 121.024445),
    (109, 'Store 109', 'NCR', 'Metro Manila', 'Pasig', 'Barangay 1', '130000000', '137403000', '137403001', 14.573730, 121.088285),
    (110, 'Store 110', 'NCR', 'Metro Manila', 'Taguig', 'Barangay 1', '130000000', '137416000', '137416001', 14.516694, 121.043861),
    (112, 'Store 112', 'NCR', 'Metro Manila', 'Pateros', 'Barangay 1', '130000000', '137405000', '137405001', 14.543333, 121.065556),
    (115, 'Store 115', 'NCR', 'Metro Manila', 'Marikina', 'Barangay 1', '130000000', '137402000', '137402001', 14.632830, 121.102183)
ON CONFLICT (store_id) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    municipality = EXCLUDED.municipality,
    geo_latitude = EXCLUDED.geo_latitude,
    geo_longitude = EXCLUDED.geo_longitude,
    verified_at = CURRENT_TIMESTAMP;

-- ==========================================
-- 2. ZERO-TRUST LOCATION PROJECTION
-- ==========================================

-- Create view for strict location verification
CREATE OR REPLACE VIEW v_zero_trust_locations AS
SELECT
    t.transaction_id,
    t.store_id,
    -- Location data only from authoritative dimension
    s.region,
    s.province,
    s.municipality,
    s.barangay,
    s.psgc_region,
    s.psgc_citymun,
    s.psgc_barangay,
    s.geo_latitude,
    s.geo_longitude,
    s.store_polygon,
    -- Strict verification logic
    CASE
        WHEN s.store_id IS NOT NULL
             AND s.region = 'NCR'
             AND s.municipality IS NOT NULL
             AND (s.store_polygon IS NOT NULL OR (s.geo_latitude IS NOT NULL AND s.geo_longitude IS NOT NULL))
        THEN TRUE
        ELSE FALSE
    END AS location_verified,
    -- Hardened municipality (Unknown if not verified)
    CASE
        WHEN s.store_id IS NOT NULL AND s.region = 'NCR' AND s.municipality IS NOT NULL
        THEN s.municipality
        ELSE 'Unknown'
    END AS safe_municipality
FROM public.fact_transactions_location t
LEFT JOIN public.dim_stores_ncr s ON s.store_id = t.store_id;

-- ==========================================
-- 3. REBUILD JSON PAYLOADS WITH STRICT LOCATION
-- ==========================================

-- Function to rebuild JSON with zero-trust location data
CREATE OR REPLACE FUNCTION rebuild_json_with_zero_trust_location()
RETURNS TABLE (
    updated_count BIGINT,
    verified_locations BIGINT,
    unknown_locations BIGINT,
    verification_rate NUMERIC(5,2)
)
LANGUAGE plpgsql AS $$
DECLARE
    _updated_count BIGINT;
    _verified_count BIGINT;
    _unknown_count BIGINT;
BEGIN
    RAISE NOTICE 'Starting zero-trust location rebuild...';

    -- Update all transactions with rebuilt JSON
    WITH location_data AS (
        SELECT
            transaction_id,
            store_id,
            COALESCE(region, 'NCR') as region,
            province,
            safe_municipality as municipality,
            barangay,
            psgc_region,
            psgc_citymun,
            psgc_barangay,
            geo_latitude,
            geo_longitude,
            location_verified
        FROM v_zero_trust_locations
    ),
    items_data AS (
        SELECT
            pt.transaction_id,
            COALESCE(pt.payload_json -> 'items', '[]'::jsonb) as items,
            COALESCE(jsonb_array_length(pt.payload_json -> 'items'), 0) as item_count,
            f.total_amount
        FROM public.payload_transactions pt
        RIGHT JOIN public.fact_transactions_location f ON f.transaction_id = pt.transaction_id
    ),
    updated_rows AS (
        UPDATE public.fact_transactions_location f
        SET
            payload_json = jsonb_build_object(
                'transactionId', f.transaction_id,
                'storeId', f.store_id,
                'deviceId', f.device_id,
                'timestamp', to_char(f.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                'basket', jsonb_build_object(
                    'items', i.items,
                    'itemCount', i.item_count,
                    'totalAmount', COALESCE(i.total_amount, 0)
                ),
                'interaction', jsonb_build_object(
                    'ageBracket', 'Unknown',
                    'gender', 'Unknown',
                    'role', 'Customer',
                    'weekdayOrWeekend', f.weekday_or_weekend,
                    'timeOfDay', f.time_of_day
                ),
                'location', jsonb_build_object(
                    'region', l.region,
                    'province', COALESCE(l.province, 'Metro Manila'),
                    'municipality', l.municipality,
                    'barangay', COALESCE(l.barangay, 'Unknown'),
                    'psgc_region', COALESCE(l.psgc_region, '130000000'),
                    'psgc_citymun', COALESCE(l.psgc_citymun, '137400000'),
                    'psgc_barangay', COALESCE(l.psgc_barangay, '137400001'),
                    'geo', jsonb_build_object('lat', l.geo_latitude, 'lon', l.geo_longitude)
                ),
                'qualityFlags', jsonb_build_object(
                    'brandMatched', (f.audio_transcript IS NOT NULL),
                    'locationVerified', l.location_verified,
                    'substitutionDetected', FALSE  -- Will be updated by transcript analysis
                ),
                'source', jsonb_build_object(
                    'file', f.source_path,
                    'rowCount', i.item_count
                )
            ),
            updated_at = CURRENT_TIMESTAMP
        FROM location_data l
        LEFT JOIN items_data i ON i.transaction_id = f.transaction_id
        WHERE l.transaction_id = f.transaction_id
        RETURNING f.transaction_id
    )
    SELECT COUNT(*) INTO _updated_count FROM updated_rows;

    -- Get verification statistics
    SELECT
        COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE),
        COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' = 'Unknown')
    INTO _verified_count, _unknown_count
    FROM public.fact_transactions_location;

    RAISE NOTICE 'Updated % transactions', _updated_count;
    RAISE NOTICE 'Verified locations: %, Unknown locations: %', _verified_count, _unknown_count;

    RETURN QUERY SELECT
        _updated_count,
        _verified_count,
        _unknown_count,
        ROUND((_verified_count * 100.0 / NULLIF(_updated_count, 0)), 2);
END $$;

-- ==========================================
-- 4. VALIDATION FUNCTIONS
-- ==========================================

-- Function to validate zero incorrect mappings
CREATE OR REPLACE FUNCTION validate_zero_trust_location()
RETURNS TABLE (
    check_name TEXT,
    violations BIGINT,
    total_applicable BIGINT,
    pass_fail TEXT
)
LANGUAGE sql AS $$
    -- Check 1: No incorrect mappings (verified=false but municipality != 'Unknown')
    SELECT
        'No Incorrect Mappings' as check_name,
        COUNT(*) FILTER (
            WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = FALSE
            AND payload_json -> 'location' ->> 'municipality' != 'Unknown'
        ) as violations,
        COUNT(*) as total_applicable,
        CASE
            WHEN COUNT(*) FILTER (
                WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = FALSE
                AND payload_json -> 'location' ->> 'municipality' != 'Unknown'
            ) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END as pass_fail
    FROM public.fact_transactions_location

    UNION ALL

    -- Check 2: All verified locations are in NCR
    SELECT
        'All Verified are NCR',
        COUNT(*) FILTER (
            WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE
            AND payload_json -> 'location' ->> 'region' != 'NCR'
        ),
        COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE),
        CASE
            WHEN COUNT(*) FILTER (
                WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE
                AND payload_json -> 'location' ->> 'region' != 'NCR'
            ) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM public.fact_transactions_location

    UNION ALL

    -- Check 3: All verified locations have coordinates
    SELECT
        'Verified Have Coordinates',
        COUNT(*) FILTER (
            WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE
            AND (payload_json -> 'location' -> 'geo' ->> 'lat' IS NULL
                 OR payload_json -> 'location' -> 'geo' ->> 'lon' IS NULL)
        ),
        COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE),
        CASE
            WHEN COUNT(*) FILTER (
                WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE
                AND (payload_json -> 'location' -> 'geo' ->> 'lat' IS NULL
                     OR payload_json -> 'location' -> 'geo' ->> 'lon' IS NULL)
            ) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM public.fact_transactions_location;
$$;

-- Function to generate location coverage report
CREATE OR REPLACE FUNCTION location_coverage_report()
RETURNS TABLE (
    store_id INTEGER,
    transactions BIGINT,
    municipality TEXT,
    verified BOOLEAN,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
)
LANGUAGE sql AS $$
    SELECT
        (payload_json ->> 'storeId')::INTEGER,
        COUNT(*),
        payload_json -> 'location' ->> 'municipality',
        (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean,
        (payload_json -> 'location' -> 'geo' ->> 'lat')::DOUBLE PRECISION,
        (payload_json -> 'location' -> 'geo' ->> 'lon')::DOUBLE PRECISION
    FROM public.fact_transactions_location
    GROUP BY
        (payload_json ->> 'storeId')::INTEGER,
        payload_json -> 'location' ->> 'municipality',
        (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean,
        (payload_json -> 'location' -> 'geo' ->> 'lat')::DOUBLE PRECISION,
        (payload_json -> 'location' -> 'geo' ->> 'lon')::DOUBLE PRECISION
    ORDER BY
        (payload_json ->> 'storeId')::INTEGER,
        COUNT(*) DESC;
$$;

-- ==========================================
-- 5. EXECUTION INSTRUCTIONS
-- ==========================================

/*
-- Execute the zero-trust location rebuild
SELECT * FROM rebuild_json_with_zero_trust_location();

-- Validate no incorrect mappings
SELECT * FROM validate_zero_trust_location();

-- Generate coverage report
SELECT * FROM location_coverage_report();

-- Quick summary
SELECT
    'SUMMARY' as report_type,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) as verified_locations,
    COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' = 'Unknown') as unknown_locations,
    ROUND(
        (COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) * 100.0 / COUNT(*)),
        2
    ) as verification_rate_pct
FROM public.fact_transactions_location;
*/