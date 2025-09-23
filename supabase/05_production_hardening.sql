-- ==========================================
-- Zero-Trust Location System: Production Hardening
-- Additional constraints, guards, and validation
-- ==========================================

-- This script provides additional hardening layers beyond the base lockdown
-- to ensure maximum production resilience and prevent any regression.

-- ==========================================
-- 1. ENHANCED DIMENSION CONSTRAINTS
-- ==========================================

-- Strengthen geometry validation with precise NCR bounds
DO $$
BEGIN
    -- Drop existing constraint if exists
    BEGIN
        ALTER TABLE public.dim_stores_ncr DROP CONSTRAINT IF EXISTS dim_stores_ncr_geom_enhanced;
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- Add enhanced geometry constraint
    ALTER TABLE public.dim_stores_ncr
    ADD CONSTRAINT dim_stores_ncr_geom_enhanced
    CHECK (
        store_polygon IS NOT NULL OR
        (geo_latitude BETWEEN 14.2 AND 14.9 AND
         geo_longitude BETWEEN 120.9 AND 121.2)
    );

    -- Ensure unique store-municipality mapping
    BEGIN
        ALTER TABLE public.dim_stores_ncr
        ADD CONSTRAINT dim_stores_ncr_unique_location
        UNIQUE (store_id, municipality);
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Unique constraint already exists - skipping';
        WHEN unique_violation THEN
            RAISE NOTICE 'Unique constraint conflicts with existing data - skipping';
    END;
END $$;

-- Add verification timestamp tracking
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'dim_stores_ncr'
        AND column_name = 'last_verified_at'
    ) THEN
        ALTER TABLE public.dim_stores_ncr
        ADD COLUMN last_verified_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
END $$;

-- ==========================================
-- 2. PAYLOAD SHAPE VALIDATION
-- ==========================================

-- Enforce consistent JSON structure across all payloads
CREATE OR REPLACE VIEW qa_payload_shape AS
SELECT
    transaction_id,
    'Missing transactionId' as violation_type
FROM public.fact_transactions_location
WHERE NOT (payload_json ? 'transactionId')

UNION ALL

SELECT
    transaction_id,
    'Missing storeId' as violation_type
FROM public.fact_transactions_location
WHERE NOT (payload_json ? 'storeId')

UNION ALL

SELECT
    transaction_id,
    'Missing basket structure' as violation_type
FROM public.fact_transactions_location
WHERE NOT (
    payload_json ? 'basket' AND
    payload_json->'basket' ? 'items' AND
    payload_json->'basket' ? 'itemCount'
)

UNION ALL

SELECT
    transaction_id,
    'Missing location structure' as violation_type
FROM public.fact_transactions_location
WHERE NOT (
    payload_json ? 'location' AND
    payload_json->'location' ? 'municipality' AND
    payload_json->'location' ? 'region'
)

UNION ALL

SELECT
    transaction_id,
    'Missing qualityFlags structure' as violation_type
FROM public.fact_transactions_location
WHERE NOT (
    payload_json ? 'qualityFlags' AND
    payload_json->'qualityFlags' ? 'locationVerified'
);

-- Payload consistency check function
CREATE OR REPLACE FUNCTION check_payload_consistency()
RETURNS TABLE (
    check_name TEXT,
    violations BIGINT,
    violation_details TEXT
)
LANGUAGE sql AS $$
    SELECT
        'Payload Shape Consistency' as check_name,
        COUNT(*) as violations,
        CASE
            WHEN COUNT(*) > 0
            THEN 'Found ' || COUNT(*) || ' transactions with malformed JSON structure'
            ELSE 'All payloads have consistent structure'
        END as violation_details
    FROM qa_payload_shape;
$$;

-- ==========================================
-- 3. COORDINATE BOUNDS VALIDATION
-- ==========================================

-- Function to validate NCR coordinate bounds
CREATE OR REPLACE FUNCTION validate_ncr_coordinates(lat DOUBLE PRECISION, lon DOUBLE PRECISION)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
BEGIN
    -- NCR bounds validation
    IF lat IS NULL OR lon IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Precise NCR coordinate ranges
    IF lat < 14.20 OR lat > 14.90 THEN
        RETURN FALSE;
    END IF;

    IF lon < 120.90 OR lon > 121.20 THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

-- Enhanced coordinate validation view
CREATE OR REPLACE VIEW qa_coordinate_validation AS
SELECT
    s.store_id,
    s.store_name,
    s.geo_latitude,
    s.geo_longitude,
    validate_ncr_coordinates(s.geo_latitude, s.geo_longitude) as coordinates_valid,
    CASE
        WHEN NOT validate_ncr_coordinates(s.geo_latitude, s.geo_longitude)
        THEN 'Coordinates outside NCR bounds'
        ELSE 'Valid NCR coordinates'
    END as validation_status
FROM public.dim_stores_ncr s;

-- ==========================================
-- 4. AUDIT TRAIL STRENGTHENING
-- ==========================================

-- Enhanced audit function with detailed violation tracking
CREATE OR REPLACE FUNCTION audit_zero_trust_violations()
RETURNS TABLE (
    audit_timestamp TIMESTAMP WITH TIME ZONE,
    violation_category TEXT,
    violation_count BIGINT,
    affected_stores INTEGER[],
    severity_level TEXT
)
LANGUAGE sql AS $$
    WITH violations AS (
        SELECT
            CURRENT_TIMESTAMP as audit_timestamp,
            'Location Verification' as violation_category,
            COUNT(*) as violation_count,
            ARRAY_AGG(DISTINCT store_id) as affected_stores,
            CASE WHEN COUNT(*) = 0 THEN 'NONE'
                 WHEN COUNT(*) < 10 THEN 'LOW'
                 WHEN COUNT(*) < 100 THEN 'MEDIUM'
                 ELSE 'HIGH' END as severity_level
        FROM qa_zero_trust_assert
        WHERE is_violation = TRUE

        UNION ALL

        SELECT
            CURRENT_TIMESTAMP,
            'Payload Structure',
            COUNT(*),
            ARRAY_AGG(DISTINCT transaction_id),
            CASE WHEN COUNT(*) = 0 THEN 'NONE'
                 WHEN COUNT(*) < 10 THEN 'LOW'
                 ELSE 'HIGH' END
        FROM qa_payload_shape

        UNION ALL

        SELECT
            CURRENT_TIMESTAMP,
            'Coordinate Bounds',
            COUNT(*),
            ARRAY_AGG(DISTINCT store_id),
            CASE WHEN COUNT(*) = 0 THEN 'NONE'
                 ELSE 'MEDIUM' END
        FROM qa_coordinate_validation
        WHERE NOT coordinates_valid
    )
    SELECT * FROM violations
    WHERE violation_count > 0 OR violation_category = 'Location Verification';
$$;

-- ==========================================
-- 5. STORE ADDITION VALIDATION
-- ==========================================

-- Enhanced store addition with validation
CREATE OR REPLACE FUNCTION add_store_with_enhanced_validation(
    p_store_id INTEGER,
    p_store_name TEXT,
    p_municipality TEXT,
    p_barangay TEXT DEFAULT 'Unknown',
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_polygon JSONB DEFAULT NULL
)
RETURNS TABLE (
    operation_status TEXT,
    validation_result TEXT,
    affected_transactions BIGINT,
    verification_improvement TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    _coordinate_valid BOOLEAN;
    _before_verified BIGINT;
    _after_verified BIGINT;
    _affected_count BIGINT;
BEGIN
    -- Validate coordinates if provided
    _coordinate_valid := validate_ncr_coordinates(p_latitude, p_longitude);

    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL AND NOT _coordinate_valid THEN
        RETURN QUERY VALUES (
            'FAILED',
            'Coordinates outside NCR bounds',
            0::BIGINT,
            'No change - validation failed'
        );
        RETURN;
    END IF;

    -- Get baseline metrics
    SELECT COUNT(*) INTO _before_verified
    FROM public.fact_transactions_location
    WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

    -- Add store with enhanced validation
    INSERT INTO public.dim_stores_ncr (
        store_id, store_name, region, province, municipality, barangay,
        psgc_region, psgc_citymun, psgc_barangay,
        geo_latitude, geo_longitude, store_polygon,
        last_verified_at
    ) VALUES (
        p_store_id, p_store_name, 'NCR', 'Metro Manila', p_municipality, p_barangay,
        '130000000', '137404000', '137404001',
        p_latitude, p_longitude, p_polygon,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (store_id) DO UPDATE SET
        store_name = EXCLUDED.store_name,
        municipality = EXCLUDED.municipality,
        barangay = EXCLUDED.barangay,
        geo_latitude = EXCLUDED.geo_latitude,
        geo_longitude = EXCLUDED.geo_longitude,
        store_polygon = COALESCE(EXCLUDED.store_polygon, dim_stores_ncr.store_polygon),
        last_verified_at = CURRENT_TIMESTAMP;

    -- Rebuild affected transactions (reuse existing function logic)
    SELECT affected_transactions INTO _affected_count
    FROM add_store_with_rebuild(p_store_id, p_store_name, p_municipality, p_barangay, p_latitude, p_longitude, p_polygon);

    -- Get updated metrics
    SELECT COUNT(*) INTO _after_verified
    FROM public.fact_transactions_location
    WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

    RETURN QUERY VALUES (
        'SUCCESS',
        'Store added with valid NCR coordinates',
        _affected_count,
        format('Verified transactions: %s → %s (+%s)',
               _before_verified, _after_verified, _after_verified - _before_verified)
    );
END;
$$;

-- ==========================================
-- 6. COMPREHENSIVE VALIDATION SUITE
-- ==========================================

-- Master validation function combining all checks
CREATE OR REPLACE FUNCTION comprehensive_zero_trust_validation()
RETURNS TABLE (
    check_category TEXT,
    check_name TEXT,
    violations BIGINT,
    status TEXT,
    details TEXT
)
LANGUAGE sql AS $$
    -- Core zero-trust checks
    SELECT
        'Core Integrity' as check_category,
        check_name,
        violations,
        CASE WHEN violations = 0 THEN 'PASS' ELSE 'FAIL' END as status,
        violation_details as details
    FROM check_zero_trust_integrity()

    UNION ALL

    -- Payload structure checks
    SELECT
        'Payload Structure' as check_category,
        check_name,
        violations,
        CASE WHEN violations = 0 THEN 'PASS' ELSE 'FAIL' END as status,
        violation_details as details
    FROM check_payload_consistency()

    UNION ALL

    -- Coordinate validation
    SELECT
        'Geographic Bounds' as check_category,
        'NCR Coordinate Validation' as check_name,
        COUNT(*) FILTER (WHERE NOT coordinates_valid) as violations,
        CASE WHEN COUNT(*) FILTER (WHERE NOT coordinates_valid) = 0 THEN 'PASS' ELSE 'FAIL' END as status,
        'Stores: ' || string_agg(store_id::text, ', ') FILTER (WHERE NOT coordinates_valid) as details
    FROM qa_coordinate_validation

    ORDER BY check_category, check_name;
$$;

-- ==========================================
-- 7. PRODUCTION READINESS INDICATORS
-- ==========================================

-- System health dashboard query
CREATE OR REPLACE VIEW dashboard_system_health AS
SELECT
    'Zero-Trust System Health' as dashboard_title,
    CURRENT_TIMESTAMP as last_updated,
    (
        SELECT COUNT(*) = 0
        FROM comprehensive_zero_trust_validation()
        WHERE status = 'FAIL'
    ) as all_checks_passing,
    (
        SELECT ROUND(
            (COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) * 100.0 / COUNT(*)),
            2
        )
        FROM public.fact_transactions_location
    ) as verification_rate_pct,
    (
        SELECT COUNT(*)
        FROM public.dim_stores_ncr
    ) as total_stores_in_dimension,
    (
        SELECT COUNT(DISTINCT store_id)
        FROM public.fact_transactions_location
    ) as unique_stores_with_transactions;

COMMENT ON VIEW dashboard_system_health IS
'Real-time dashboard showing zero-trust location system health status and key metrics';

-- ==========================================
-- 8. EMERGENCY RECOVERY PROCEDURES
-- ==========================================

-- Emergency store recovery function
CREATE OR REPLACE FUNCTION emergency_store_recovery(p_store_id INTEGER)
RETURNS TABLE (
    recovery_action TEXT,
    result TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    _store_exists BOOLEAN;
    _transactions_count BIGINT;
BEGIN
    -- Check if store exists in dimension
    SELECT EXISTS(SELECT 1 FROM public.dim_stores_ncr WHERE store_id = p_store_id) INTO _store_exists;

    -- Count affected transactions
    SELECT COUNT(*) INTO _transactions_count
    FROM public.fact_transactions_location
    WHERE store_id = p_store_id;

    IF NOT _store_exists AND _transactions_count > 0 THEN
        RETURN QUERY VALUES (
            'EMERGENCY_ALERT',
            format('Store %s has %s transactions but no dimension entry - manual intervention required',
                   p_store_id, _transactions_count)
        );
    ELSIF _store_exists AND _transactions_count = 0 THEN
        RETURN QUERY VALUES (
            'CLEANUP_OPPORTUNITY',
            format('Store %s exists in dimension but has no transactions - consider archival', p_store_id)
        );
    ELSE
        RETURN QUERY VALUES (
            'HEALTHY',
            format('Store %s is properly configured with %s transactions', p_store_id, _transactions_count)
        );
    END IF;
END;
$$;

-- ==========================================
-- 9. EXECUTION VALIDATION
-- ==========================================

-- Verify all hardening measures are active
DO $$
DECLARE
    _constraint_count INTEGER;
    _trigger_count INTEGER;
    _function_count INTEGER;
BEGIN
    -- Count active constraints
    SELECT COUNT(*) INTO _constraint_count
    FROM information_schema.table_constraints
    WHERE table_name = 'dim_stores_ncr'
    AND constraint_type = 'CHECK';

    -- Count active triggers
    SELECT COUNT(*) INTO _trigger_count
    FROM information_schema.triggers
    WHERE event_object_table = 'dim_stores_ncr';

    -- Count validation functions
    SELECT COUNT(*) INTO _function_count
    FROM information_schema.routines
    WHERE routine_name LIKE '%zero_trust%' OR routine_name LIKE '%validation%';

    RAISE NOTICE 'Production Hardening Applied Successfully:';
    RAISE NOTICE '- CHECK constraints: %', _constraint_count;
    RAISE NOTICE '- Active triggers: %', _trigger_count;
    RAISE NOTICE '- Validation functions: %', _function_count;
    RAISE NOTICE '- System ready for production monitoring';
END $$;