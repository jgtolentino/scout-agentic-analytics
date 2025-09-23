-- ==========================================
-- Zero-Trust Location System Lockdown
-- Hard constraints and automated validation
-- ==========================================

-- This script implements hard-guard constraints to prevent regression
-- and provides automated validation for the zero-trust location system.

-- ==========================================
-- 1. HARD-GUARD CONSTRAINTS FOR DIM_STORES_NCR
-- ==========================================

-- Add NOT NULL constraints to critical fields
ALTER TABLE public.dim_stores_ncr
  ALTER COLUMN region SET NOT NULL,
  ALTER COLUMN municipality SET NOT NULL;

-- Add check constraint to ensure only NCR stores
ALTER TABLE public.dim_stores_ncr
ADD CONSTRAINT chk_stores_ncr_only CHECK (region = 'NCR');

-- Create trigger function to enforce geometry requirements
CREATE OR REPLACE FUNCTION dim_ncr_geom_guard()
RETURNS TRIGGER AS $$
BEGIN
  -- Must be NCR
  IF NEW.region <> 'NCR' THEN
    RAISE EXCEPTION 'Only NCR stores allowed in dim_stores_ncr, got: %', NEW.region;
  END IF;

  -- Municipality is required
  IF NEW.municipality IS NULL OR TRIM(NEW.municipality) = '' THEN
    RAISE EXCEPTION 'Municipality required for store_id: %', NEW.store_id;
  END IF;

  -- Must have either polygon OR lat/lon coordinates
  IF NEW.store_polygon IS NULL AND (NEW.geo_latitude IS NULL OR NEW.geo_longitude IS NULL) THEN
    RAISE EXCEPTION 'Store % needs polygon OR lat/lon coordinates', NEW.store_id;
  END IF;

  -- Validate coordinate ranges for NCR (rough bounds)
  IF NEW.geo_latitude IS NOT NULL AND (NEW.geo_latitude < 14.0 OR NEW.geo_latitude > 15.0) THEN
    RAISE EXCEPTION 'Latitude % outside NCR bounds for store %', NEW.geo_latitude, NEW.store_id;
  END IF;

  IF NEW.geo_longitude IS NOT NULL AND (NEW.geo_longitude < 120.5 OR NEW.geo_longitude > 121.5) THEN
    RAISE EXCEPTION 'Longitude % outside NCR bounds for store %', NEW.geo_longitude, NEW.store_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to enforce constraints
DROP TRIGGER IF EXISTS trg_dim_ncr_geom_guard ON public.dim_stores_ncr;
CREATE TRIGGER trg_dim_ncr_geom_guard
  BEFORE INSERT OR UPDATE ON public.dim_stores_ncr
  FOR EACH ROW EXECUTE FUNCTION dim_ncr_geom_guard();

-- ==========================================
-- 2. FACT TABLE VALIDATION VIEW
-- ==========================================

-- Critical assertion view: verified JSON must have backing dim row
CREATE OR REPLACE VIEW qa_zero_trust_assert AS
SELECT
  t.transaction_id,
  t.store_id,
  (t.payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean AS json_verified,
  t.payload_json -> 'location' ->> 'municipality' AS json_municipality,
  s.store_id IS NOT NULL AS in_dim,
  s.region = 'NCR' AS dim_is_ncr,
  s.municipality AS dim_municipality,
  (s.store_polygon IS NOT NULL OR (s.geo_latitude IS NOT NULL AND s.geo_longitude IS NOT NULL)) AS dim_has_geom,
  -- Violation flag: claims verified but no valid dim backing
  CASE
    WHEN (t.payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE
         AND NOT (s.store_id IS NOT NULL
                  AND s.region = 'NCR'
                  AND s.municipality IS NOT NULL
                  AND (s.store_polygon IS NOT NULL OR (s.geo_latitude IS NOT NULL AND s.geo_longitude IS NOT NULL)))
    THEN TRUE
    ELSE FALSE
  END AS is_violation
FROM public.fact_transactions_location t
LEFT JOIN public.dim_stores_ncr s ON s.store_id = t.store_id;

-- ==========================================
-- 3. AUTOMATED VALIDATION FUNCTIONS
-- ==========================================

-- Zero-trust integrity check (should always return 0 violations)
CREATE OR REPLACE FUNCTION check_zero_trust_integrity()
RETURNS TABLE (
  check_name TEXT,
  violations BIGINT,
  total_applicable BIGINT,
  violation_details TEXT
)
LANGUAGE sql AS $$
  -- Check 1: No false verified claims
  SELECT
    'No False Verified Claims' as check_name,
    COUNT(*) FILTER (WHERE is_violation) as violations,
    COUNT(*) as total_applicable,
    CASE
      WHEN COUNT(*) FILTER (WHERE is_violation) > 0
      THEN 'Store IDs with violations: ' || string_agg(DISTINCT store_id::text, ', ')
      ELSE 'All verified locations have valid dim backing'
    END as violation_details
  FROM qa_zero_trust_assert

  UNION ALL

  -- Check 2: No Unknown municipalities for verified locations
  SELECT
    'No Unknown in Verified',
    COUNT(*) FILTER (WHERE json_verified = TRUE AND json_municipality = 'Unknown'),
    COUNT(*) FILTER (WHERE json_verified = TRUE),
    CASE
      WHEN COUNT(*) FILTER (WHERE json_verified = TRUE AND json_municipality = 'Unknown') > 0
      THEN 'Verified transactions showing Unknown municipality'
      ELSE 'All verified locations have proper municipality'
    END
  FROM qa_zero_trust_assert

  UNION ALL

  -- Check 3: Municipality consistency between JSON and dim
  SELECT
    'Municipality Consistency',
    COUNT(*) FILTER (WHERE json_verified = TRUE AND json_municipality != dim_municipality),
    COUNT(*) FILTER (WHERE json_verified = TRUE),
    CASE
      WHEN COUNT(*) FILTER (WHERE json_verified = TRUE AND json_municipality != dim_municipality) > 0
      THEN 'JSON municipality differs from dim municipality'
      ELSE 'JSON and dim municipalities consistent'
    END
  FROM qa_zero_trust_assert;
$$;

-- ==========================================
-- 4. STORE ADDITION PLAYBOOK FUNCTION
-- ==========================================

-- Safe function to add new store and rebuild affected transactions
CREATE OR REPLACE FUNCTION add_store_with_rebuild(
  p_store_id INTEGER,
  p_store_name TEXT,
  p_municipality TEXT,
  p_barangay TEXT DEFAULT 'Unknown',
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_polygon JSONB DEFAULT NULL
)
RETURNS TABLE (
  operation TEXT,
  affected_transactions BIGINT,
  verification_change TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
  _before_verified BIGINT;
  _after_verified BIGINT;
  _affected_count BIGINT;
BEGIN
  -- Get before count
  SELECT COUNT(*) INTO _before_verified
  FROM public.fact_transactions_location
  WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

  -- Add/update store in dimension
  INSERT INTO public.dim_stores_ncr (
    store_id, store_name, region, province, municipality, barangay,
    psgc_region, psgc_citymun, psgc_barangay, geo_latitude, geo_longitude, store_polygon
  ) VALUES (
    p_store_id, p_store_name, 'NCR', 'Metro Manila', p_municipality, p_barangay,
    '130000000', '137404000', '137404001', p_latitude, p_longitude, p_polygon
  )
  ON CONFLICT (store_id) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    municipality = EXCLUDED.municipality,
    barangay = EXCLUDED.barangay,
    geo_latitude = EXCLUDED.geo_latitude,
    geo_longitude = EXCLUDED.geo_longitude,
    store_polygon = COALESCE(EXCLUDED.store_polygon, dim_stores_ncr.store_polygon),
    verified_at = CURRENT_TIMESTAMP;

  -- Rebuild JSON for affected transactions
  WITH updated AS (
    UPDATE public.fact_transactions_location f
    SET
      payload_json = jsonb_build_object(
        'transactionId', f.transaction_id,
        'storeId', f.store_id,
        'deviceId', f.device_id,
        'timestamp', to_char(f.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'basket', f.payload_json -> 'basket',
        'interaction', f.payload_json -> 'interaction',
        'location', jsonb_build_object(
          'region', 'NCR',
          'province', 'Metro Manila',
          'municipality', p_municipality,
          'barangay', p_barangay,
          'psgc_region', '130000000',
          'psgc_citymun', '137404000',
          'psgc_barangay', '137404001',
          'geo', jsonb_build_object('lat', p_latitude, 'lon', p_longitude)
        ),
        'qualityFlags', jsonb_build_object(
          'brandMatched', (f.payload_json -> 'qualityFlags' ->> 'brandMatched')::boolean,
          'locationVerified', TRUE,
          'substitutionDetected', (f.payload_json -> 'qualityFlags' ->> 'substitutionDetected')::boolean
        ),
        'source', f.payload_json -> 'source'
      ),
      updated_at = CURRENT_TIMESTAMP
    WHERE f.store_id = p_store_id
    RETURNING f.transaction_id
  )
  SELECT COUNT(*) INTO _affected_count FROM updated;

  -- Get after count
  SELECT COUNT(*) INTO _after_verified
  FROM public.fact_transactions_location
  WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

  -- Return results
  RETURN QUERY VALUES
    ('Store Added/Updated', _affected_count, format('%s → %s verified (+%s)', _before_verified, _after_verified, _after_verified - _before_verified));
END;
$$;

-- ==========================================
-- 5. NIGHTLY MONITORING FUNCTIONS
-- ==========================================

-- Store verification coverage report
CREATE OR REPLACE FUNCTION store_verification_report()
RETURNS TABLE (
  store_id INTEGER,
  store_name TEXT,
  municipality TEXT,
  transactions BIGINT,
  verified_transactions BIGINT,
  verification_rate_pct NUMERIC(5,2),
  in_dimension BOOLEAN
)
LANGUAGE sql AS $$
  WITH store_stats AS (
    SELECT
      (t.payload_json ->> 'storeId')::INTEGER as store_id,
      COUNT(*) as total_tx,
      COUNT(*) FILTER (WHERE (t.payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) as verified_tx,
      t.payload_json -> 'location' ->> 'municipality' as municipality
    FROM public.fact_transactions_location t
    GROUP BY (t.payload_json ->> 'storeId')::INTEGER, t.payload_json -> 'location' ->> 'municipality'
  )
  SELECT
    s.store_id,
    COALESCE(d.store_name, 'Unknown Store') as store_name,
    s.municipality,
    s.total_tx,
    s.verified_tx,
    ROUND((s.verified_tx * 100.0 / NULLIF(s.total_tx, 0)), 2) as verification_rate_pct,
    d.store_id IS NOT NULL as in_dimension
  FROM store_stats s
  LEFT JOIN public.dim_stores_ncr d ON d.store_id = s.store_id
  ORDER BY s.store_id;
$$;

-- System health summary
CREATE OR REPLACE FUNCTION zero_trust_health_summary()
RETURNS TABLE (
  metric TEXT,
  value BIGINT,
  percentage NUMERIC(5,2),
  status TEXT
)
LANGUAGE sql AS $$
  WITH metrics AS (
    SELECT
      COUNT(*) as total_transactions,
      COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) as verified_transactions,
      COUNT(*) FILTER (WHERE payload_json -> 'location' ->> 'municipality' = 'Unknown') as unknown_transactions,
      COUNT(DISTINCT (payload_json ->> 'storeId')::INTEGER) as unique_stores,
      (SELECT COUNT(*) FROM public.dim_stores_ncr) as stores_in_dim
    FROM public.fact_transactions_location
  )
  SELECT 'Total Transactions', total_transactions, 100.00, 'INFO' FROM metrics
  UNION ALL
  SELECT 'Verified Transactions', verified_transactions,
         ROUND((verified_transactions * 100.0 / NULLIF(total_transactions, 0)), 2),
         CASE WHEN verified_transactions = total_transactions THEN 'EXCELLENT'
              WHEN verified_transactions > (total_transactions * 0.9) THEN 'GOOD'
              ELSE 'NEEDS_ATTENTION' END
  FROM metrics
  UNION ALL
  SELECT 'Unknown Municipalities', unknown_transactions,
         ROUND((unknown_transactions * 100.0 / NULLIF(total_transactions, 0)), 2),
         CASE WHEN unknown_transactions = 0 THEN 'EXCELLENT'
              WHEN unknown_transactions < (total_transactions * 0.1) THEN 'ACCEPTABLE'
              ELSE 'NEEDS_ATTENTION' END
  FROM metrics
  UNION ALL
  SELECT 'Stores in Dimension', stores_in_dim,
         ROUND((stores_in_dim * 100.0 / NULLIF(unique_stores, 0)), 2),
         CASE WHEN stores_in_dim = unique_stores THEN 'EXCELLENT'
              WHEN stores_in_dim > (unique_stores * 0.8) THEN 'GOOD'
              ELSE 'NEEDS_ATTENTION' END
  FROM metrics;
$$;

-- ==========================================
-- 6. EXECUTION EXAMPLES
-- ==========================================

/*
-- Check system integrity (should show 0 violations)
SELECT * FROM check_zero_trust_integrity();

-- Add new store and rebuild affected transactions
SELECT * FROM add_store_with_rebuild(
  p_store_id := 115,
  p_store_name := 'New Store',
  p_municipality := 'Marikina',
  p_barangay := 'Barangay Central',
  p_latitude := 14.632830,
  p_longitude := 121.102183
);

-- Generate store verification report
SELECT * FROM store_verification_report();

-- Check overall system health
SELECT * FROM zero_trust_health_summary();

-- Monitor for regressions (should be 0)
SELECT COUNT(*) as unknown_municipality_violations
FROM public.fact_transactions_location
WHERE payload_json -> 'location' ->> 'municipality' = 'Unknown';

-- Validate constraints are working
-- This should fail:
-- INSERT INTO public.dim_stores_ncr (store_id, store_name, region, municipality)
-- VALUES (999, 'Bad Store', 'INVALID', 'Test');
*/