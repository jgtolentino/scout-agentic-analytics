-- ==========================================
-- SCOUT EDGE • Production JSONB Payload Builder (PostgreSQL)
-- Function-based emitter with validation
-- ==========================================

-- Items normalize/dedup (expects payload_json::jsonb with items[])
CREATE OR REPLACE VIEW v_items_dedup AS
WITH raw AS (
  SELECT
    pt.transaction_id,
    (it->>'sku')                            AS sku,
    NULLIF(BTRIM(COALESCE(it->>'brand', it->>'brandName')),'') AS brand,
    NULLIF(it->>'quantity','')::int         AS qty,
    NULLIF(it->>'unitPrice','')::numeric    AS unit_price,
    NULLIF(it->>'totalPrice','')::numeric   AS total_price
  FROM payload_transactions pt
  CROSS JOIN LATERAL jsonb_array_elements((pt.payload_json->'items')::jsonb) AS it
)
, norm AS (
  SELECT
    transaction_id,
    COALESCE(sku, 'SKU-'||ROW_NUMBER() OVER (PARTITION BY transaction_id)) AS sku,
    brand,
    qty,
    unit_price,
    total_price
  FROM raw
)
SELECT
  transaction_id,
  sku,
  brand,
  SUM(COALESCE(qty,1))                        AS qty,
  COALESCE(MAX(unit_price), MAX(NULLIF(total_price,0))/NULLIF(MAX(NULLIF(qty,0)),0)) AS unit_price,
  SUM(COALESCE(total_price, COALESCE(unit_price,0)*COALESCE(qty,1))) AS total_price,
  ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY sku,brand)  AS line_id
FROM norm
GROUP BY transaction_id, sku, brand;

-- earliest ts per transaction
CREATE OR REPLACE VIEW v_txn_ts AS
SELECT transaction_id,
       MIN((COALESCE(created_on, interaction_start_time, event_time))::timestamptz) AS txn_ts
FROM sales_interaction_transcripts
GROUP BY transaction_id;

-- requested brand + reason
CREATE OR REPLACE VIEW v_requested_brand AS
WITH base AS (
  SELECT
    t.transaction_id,
    NULLIF(BTRIM(t.detectedbrand),'') AS requested_brand,
    LOWER(COALESCE(t.transcripttext,'')) AS txt,
    (COALESCE(t.created_on, t.interaction_start_time, t.event_time))::timestamptz AS ts
  FROM sales_interaction_transcripts t
)
, rb AS (
  SELECT DISTINCT ON (transaction_id)
         transaction_id, requested_brand
  FROM base
  WHERE requested_brand IS NOT NULL
  ORDER BY transaction_id, ts
)
, rs AS (
  SELECT DISTINCT ON (transaction_id)
         transaction_id,
         CASE
           WHEN txt LIKE '%out of stock%' OR txt LIKE '%no stock%' OR txt LIKE '%wala%' OR txt LIKE '%ubos%' THEN 'stockout'
           WHEN txt LIKE '%suggest%' OR txt LIKE '%ibang brand%' OR txt LIKE '%pwede na ito%' OR txt LIKE '%alternative%' THEN 'suggestion'
           ELSE 'unknown'
         END AS substitution_reason
  FROM base
  ORDER BY transaction_id, ts
)
SELECT rb.transaction_id, rb.requested_brand, COALESCE(rs.substitution_reason,'unknown') AS substitution_reason
FROM rb LEFT JOIN rs USING (transaction_id);

-- items + substitution
CREATE OR REPLACE VIEW v_items_with_substitution AS
SELECT
  i.transaction_id, i.line_id, i.sku, i.brand, i.qty, i.unit_price, i.total_price,
  (CASE
     WHEN r.requested_brand IS NULL OR i.brand IS NULL THEN FALSE
     WHEN UPPER(i.brand) = UPPER(r.requested_brand) THEN FALSE
     ELSE TRUE
   END) AS substitution_event,
  (CASE
     WHEN r.requested_brand IS NOT NULL AND i.brand IS NOT NULL AND UPPER(i.brand) <> UPPER(r.requested_brand)
     THEN r.requested_brand ELSE NULL END) AS substitution_from
FROM v_items_dedup i
LEFT JOIN v_requested_brand r USING (transaction_id);

-- final jsonb per transaction
CREATE OR REPLACE VIEW v_transaction_payload_json AS
SELECT
  pt.transaction_id,
  jsonb_build_object(
    'transactionId', pt.transaction_id,
    'storeId',       pt.store_id,
    'deviceId',      pt.device_id,
    'timestamp',     to_char(t.txn_ts AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'basket', jsonb_build_object(
      'items', (
         SELECT jsonb_agg(jsonb_build_object(
             'lineId', iw.line_id,
             'brand',  iw.brand,
             'sku',    iw.sku,
             'qty',    iw.qty,
             'unitPrice', iw.unit_price,
             'totalPrice', iw.total_price,
             'substitutionEvent', iw.substitution_event,
             'substitutionFrom',  iw.substitution_from
         ) ORDER BY iw.line_id)
         FROM v_items_with_substitution iw
         WHERE iw.transaction_id = pt.transaction_id
      )
    ),
    'interaction', jsonb_build_object(
      'ageBracket', f.age_bracket,
      'gender',     f.gender,
      'role',       f.role,
      'weekdayOrWeekend', f.weekday_or_weekend,
      'timeOfDay',        f.time_of_day
    ),
    'location', jsonb_build_object(
      'region',        s.region,
      'province',      s.provincename,
      'municipality',  s.municipalityname,
      'barangay',      s.barangayname,
      'psgc_region',   s.psgc_region,
      'psgc_citymun',  s.psgc_citymun,
      'psgc_barangay', s.psgc_barangay,
      'geo', jsonb_build_object('lat', s.geolatitude, 'lon', s.geolongitude)
    ),
    'qualityFlags', jsonb_build_object(
      'brandMatched',        EXISTS (SELECT 1 FROM v_items_with_substitution x WHERE x.transaction_id=pt.transaction_id AND x.brand IS NOT NULL),
      'locationVerified',    (s.municipalityname IS NOT NULL AND (s.storepolygon IS NOT NULL OR (s.geolatitude IS NOT NULL AND s.geolongitude IS NOT NULL))),
      'substitutionDetected', EXISTS (SELECT 1 FROM v_items_with_substitution x WHERE x.transaction_id=pt.transaction_id AND x.substitution_event)
    ),
    'source', jsonb_build_object(
      'file',      f.source_path,
      'rowCount', (SELECT COUNT(*) FROM v_items_dedup d WHERE d.transaction_id = pt.transaction_id)
    )
  ) AS payload_json
FROM payload_transactions pt
LEFT JOIN v_txn_ts t ON t.transaction_id = pt.transaction_id
LEFT JOIN fact_transactions_location f ON f.transaction_id = pt.transaction_id
LEFT JOIN stores s ON s.store_id = pt.store_id;

-- Production function: materialize jsonb into fact table
CREATE OR REPLACE FUNCTION public.emit_fact_payload_json()
RETURNS TABLE (
  report_type text,
  metric_name text,
  metric_value bigint,
  percentage numeric
)
LANGUAGE plpgsql AS $$
DECLARE
  _updated_rows bigint;
  _total_rows bigint;
  _json_rows bigint;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Scout Edge JSONB Payload Generation';
  RAISE NOTICE '========================================';

  -- 1) Materialize JSONB into fact table
  RAISE NOTICE 'Materializing JSONB payloads...';

  WITH updated AS (
    UPDATE fact_transactions_location f
    SET payload_json = v.payload_json,
        updated_at = CURRENT_TIMESTAMP
    FROM v_transaction_payload_json v
    WHERE v.transaction_id = f.transaction_id
    RETURNING f.transaction_id
  )
  SELECT COUNT(*) INTO _updated_rows FROM updated;

  RAISE NOTICE 'Updated % rows with JSONB payloads', _updated_rows;

  -- 2) Get summary metrics
  SELECT
    COUNT(*),
    COUNT(payload_json)
  INTO _total_rows, _json_rows
  FROM fact_transactions_location;

  -- 3) Return comprehensive validation summary
  RAISE NOTICE 'Generating validation summary...';

  -- Summary metrics
  RETURN QUERY
  SELECT
    'SUMMARY'::text,
    'total_transactions'::text,
    _total_rows,
    100.0::numeric
  UNION ALL
  SELECT
    'SUMMARY'::text,
    'json_payload_rows'::text,
    _json_rows,
    ROUND((_json_rows * 100.0 / NULLIF(_total_rows, 0)), 2)
  UNION ALL
  SELECT
    'SUMMARY'::text,
    'null_payload_rows'::text,
    _total_rows - _json_rows,
    ROUND(((_total_rows - _json_rows) * 100.0 / NULLIF(_total_rows, 0)), 2)
  UNION ALL
  SELECT
    'SUMMARY'::text,
    'substitution_transactions'::text,
    COUNT(*),
    ROUND((COUNT(*) * 100.0 / NULLIF(_json_rows, 0)), 2)
  FROM fact_transactions_location
  WHERE (payload_json -> 'qualityFlags' ->> 'substitutionDetected')::boolean = TRUE
  UNION ALL
  SELECT
    'SUMMARY'::text,
    'brand_matched_transactions'::text,
    COUNT(*),
    ROUND((COUNT(*) * 100.0 / NULLIF(_json_rows, 0)), 2)
  FROM fact_transactions_location
  WHERE (payload_json -> 'qualityFlags' ->> 'brandMatched')::boolean = TRUE
  UNION ALL
  SELECT
    'SUMMARY'::text,
    'location_verified_transactions'::text,
    COUNT(*),
    ROUND((COUNT(*) * 100.0 / NULLIF(_json_rows, 0)), 2)
  FROM fact_transactions_location
  WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE;

  -- Quality checks
  RETURN QUERY
  SELECT
    'QUALITY_CHECKS'::text,
    'invalid_json_structure'::text,
    COUNT(*),
    ROUND((COUNT(*) * 100.0 / NULLIF(_json_rows, 0)), 2)
  FROM fact_transactions_location
  WHERE payload_json IS NOT NULL AND NOT jsonb_typeof(payload_json) = 'object'
  UNION ALL
  SELECT
    'QUALITY_CHECKS'::text,
    'missing_transaction_id'::text,
    COUNT(*),
    ROUND((COUNT(*) * 100.0 / NULLIF(_json_rows, 0)), 2)
  FROM fact_transactions_location
  WHERE payload_json IS NOT NULL AND payload_json ->> 'transactionId' IS NULL
  UNION ALL
  SELECT
    'QUALITY_CHECKS'::text,
    'empty_basket_items'::text,
    COUNT(*),
    ROUND((COUNT(*) * 100.0 / NULLIF(_json_rows, 0)), 2)
  FROM fact_transactions_location
  WHERE payload_json IS NOT NULL AND jsonb_array_length(payload_json -> 'basket' -> 'items') = 0;

  -- Payload size analysis
  RETURN QUERY
  SELECT
    'PAYLOAD_SIZE'::text,
    'avg_payload_size_kb'::text,
    ROUND(AVG(octet_length(payload_json::text)) / 1024.0)::bigint,
    NULL::numeric
  FROM fact_transactions_location
  WHERE payload_json IS NOT NULL
  UNION ALL
  SELECT
    'PAYLOAD_SIZE'::text,
    'max_payload_size_kb'::text,
    ROUND(MAX(octet_length(payload_json::text)) / 1024.0)::bigint,
    NULL::numeric
  FROM fact_transactions_location
  WHERE payload_json IS NOT NULL
  UNION ALL
  SELECT
    'PAYLOAD_SIZE'::text,
    'min_payload_size_kb'::text,
    ROUND(MIN(octet_length(payload_json::text)) / 1024.0)::bigint,
    NULL::numeric
  FROM fact_transactions_location
  WHERE payload_json IS NOT NULL;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'JSONB Payload Generation Complete';
  RAISE NOTICE 'Total Updated: % transactions', _updated_rows;
  RAISE NOTICE '========================================';

END $$;

-- Sample data inspection function
CREATE OR REPLACE FUNCTION public.inspect_payload_samples(sample_size int DEFAULT 5)
RETURNS TABLE (
  transaction_id text,
  store_id int,
  item_count int,
  municipality text,
  has_substitution boolean,
  payload_size_kb numeric,
  preview text
)
LANGUAGE sql AS $$
  SELECT
    f.transaction_id,
    (f.payload_json ->> 'storeId')::int,
    jsonb_array_length(f.payload_json -> 'basket' -> 'items'),
    f.payload_json -> 'location' ->> 'municipality',
    (f.payload_json -> 'qualityFlags' ->> 'substitutionDetected')::boolean,
    ROUND(octet_length(f.payload_json::text) / 1024.0, 2),
    LEFT(f.payload_json::text, 200) || '...'
  FROM fact_transactions_location f
  WHERE f.payload_json IS NOT NULL
  ORDER BY f.transaction_id
  LIMIT sample_size;
$$;

-- ==========================================
-- EXECUTION INSTRUCTIONS
-- ==========================================

/*
-- Execute the full transformation
SELECT * FROM public.emit_fact_payload_json();

-- Quick validation query
SELECT
    COUNT(*) as total_transactions,
    COUNT(payload_json) as with_jsonb_payload,
    ROUND(AVG(octet_length(payload_json::text)) / 1024.0, 2) as avg_payload_kb,
    COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'substitutionDetected')::boolean = TRUE) as substitution_events
FROM fact_transactions_location;

-- Sample JSONB structure
SELECT
    transaction_id,
    payload_json -> 'basket' -> 'items' -> 0 as first_item,
    payload_json -> 'location' as location_data,
    payload_json -> 'qualityFlags' as quality_flags
FROM fact_transactions_location
WHERE payload_json IS NOT NULL
LIMIT 1;

-- Inspect sample data
SELECT * FROM public.inspect_payload_samples(3);

-- Performance test on JSONB queries
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    payload_json -> 'location' ->> 'municipality' as municipality,
    COUNT(*) as transaction_count,
    AVG((payload_json -> 'basket' ->> 'itemCount')::int) as avg_items
FROM fact_transactions_location
WHERE payload_json -> 'location' ->> 'region' = 'NCR'
  AND (payload_json -> 'qualityFlags' ->> 'brandMatched')::boolean = TRUE
GROUP BY payload_json -> 'location' ->> 'municipality'
ORDER BY transaction_count DESC;
*/