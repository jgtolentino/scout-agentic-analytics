-- Quick Setup SQL for Scout Ingestion Pipeline
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/cxzllzyxwpyptfretryc/sql/new

-- 1. Create edge_uploader role if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'edge_uploader') THEN
    CREATE ROLE edge_uploader NOINHERIT;
  END IF;
END $$;

-- 2. Set up bucket policies for scout-ingest
-- Allow edge_uploader to write only to date-prefixed paths
CREATE POLICY "edge_uploader_write_only" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'scout-ingest' 
  AND auth.jwt() ->> 'role' = 'edge_uploader'
  AND (
    -- Must be in YYYY-MM-DD/device-id/ format
    name ~ '^\d{4}-\d{2}-\d{2}/[^/]+/.+$'
    -- Allow current date only
    AND split_part(name, '/', 1) = to_char(CURRENT_DATE, 'YYYY-MM-DD')
  )
);

-- Prevent reading
CREATE POLICY "edge_uploader_no_read" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'scout-ingest' 
  AND auth.jwt() ->> 'role' = 'edge_uploader'
  AND false
);

-- 3. Create Bronze schema and tables
CREATE SCHEMA IF NOT EXISTS scout_bronze;

CREATE TABLE IF NOT EXISTS scout_bronze.transactions_raw (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT,
  ts TIMESTAMPTZ,
  payload JSONB NOT NULL,
  src_path TEXT,
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bronze_device_ts ON scout_bronze.transactions_raw(device_id, ts DESC);
CREATE INDEX idx_bronze_inserted ON scout_bronze.transactions_raw(inserted_at DESC);

-- 4. Create Silver schema and tables
CREATE SCHEMA IF NOT EXISTS scout_silver;

CREATE TABLE IF NOT EXISTS scout_silver.transactions (
  transaction_id TEXT PRIMARY KEY,
  store_id TEXT,
  ts TIMESTAMPTZ NOT NULL,
  location JSONB,
  product_category TEXT,
  brand_name TEXT,
  sku TEXT,
  units_per_transaction INT,
  peso_value NUMERIC(12,2),
  basket_size INT,
  request_mode TEXT,
  request_type TEXT,
  suggestion_accepted BOOLEAN,
  gender TEXT,
  age_bracket TEXT,
  substitution_event JSONB,
  duration_seconds INT,
  campaign_influenced BOOLEAN,
  handshake_score NUMERIC,
  is_tbwa_client BOOLEAN,
  payment_method TEXT,
  customer_type TEXT,
  store_type TEXT,
  economic_class TEXT,
  _ingested_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_silver_ts ON scout_silver.transactions(ts DESC);
CREATE INDEX idx_silver_store ON scout_silver.transactions(store_id);

-- 5. Create Gold views
CREATE SCHEMA IF NOT EXISTS scout_gold;

CREATE OR REPLACE VIEW scout_gold.revenue_trend AS
SELECT 
  date_trunc('day', ts)::date as date,
  sum(peso_value) as revenue,
  count(*) as transactions,
  count(distinct store_id) as unique_stores
FROM scout_silver.transactions
GROUP BY 1
ORDER BY 1 DESC;

-- 6. Grant permissions
GRANT USAGE ON SCHEMA scout_bronze TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA scout_bronze TO service_role;
GRANT SELECT, INSERT ON scout_bronze.transactions_raw TO authenticated;

GRANT USAGE ON SCHEMA scout_silver TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA scout_silver TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA scout_silver TO anon, authenticated;

GRANT USAGE ON SCHEMA scout_gold TO anon, authenticated, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA scout_gold TO anon, authenticated;

-- 7. Create processing function for Bronze to Silver
CREATE OR REPLACE FUNCTION scout_bronze.process_to_silver(batch_size INT DEFAULT 1000)
RETURNS INT AS $$
DECLARE
  processed_count INT;
BEGIN
  WITH new_transactions AS (
    SELECT DISTINCT ON ((payload->>'transaction_id'))
      payload->>'transaction_id' as transaction_id,
      payload->>'store_id' as store_id,
      COALESCE((payload->>'ts')::timestamptz, ts) as ts,
      payload->'location' as location,
      payload->>'product_category' as product_category,
      payload->>'brand_name' as brand_name,
      payload->>'sku' as sku,
      (payload->>'units_per_transaction')::int as units_per_transaction,
      (payload->>'peso_value')::numeric(12,2) as peso_value,
      (payload->>'basket_size')::int as basket_size,
      payload->>'request_mode' as request_mode,
      payload->>'request_type' as request_type,
      (payload->>'suggestion_accepted')::boolean as suggestion_accepted,
      payload->>'gender' as gender,
      payload->>'age_bracket' as age_bracket,
      payload->'substitution_event' as substitution_event,
      (payload->>'duration_seconds')::int as duration_seconds,
      (payload->>'campaign_influenced')::boolean as campaign_influenced,
      (payload->>'handshake_score')::numeric as handshake_score,
      (payload->>'is_tbwa_client')::boolean as is_tbwa_client,
      payload->>'payment_method' as payment_method,
      payload->>'customer_type' as customer_type,
      payload->>'store_type' as store_type,
      payload->>'economic_class' as economic_class
    FROM scout_bronze.transactions_raw
    WHERE payload->>'transaction_id' IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM scout_silver.transactions s 
        WHERE s.transaction_id = payload->>'transaction_id'
      )
    ORDER BY payload->>'transaction_id', inserted_at DESC
    LIMIT batch_size
  )
  INSERT INTO scout_silver.transactions
  SELECT * FROM new_transactions
  ON CONFLICT (transaction_id) DO NOTHING;
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Test the setup
SELECT 'Setup complete! Next steps:' as message
UNION ALL
SELECT '1. Generate edge device token with: node scripts/generate-uploader-token.js'
UNION ALL
SELECT '2. Deploy Edge Functions'
UNION ALL
SELECT '3. Test upload to scout-ingest bucket';