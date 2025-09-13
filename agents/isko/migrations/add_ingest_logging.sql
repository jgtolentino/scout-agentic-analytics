-- Add comprehensive ingestion logging for Isko Agent
-- This tracks every SKU ingestion attempt with detailed metadata

CREATE TABLE IF NOT EXISTS sku_ingest_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku_id TEXT,
  sku_name TEXT,
  source_url TEXT,
  source_type TEXT DEFAULT 'edge_function', -- 'edge_function', 'scraper', 'api', 'manual'
  status TEXT NOT NULL, -- 'success', 'error', 'duplicate', 'validation_failed'
  error_message TEXT,
  error_code TEXT,
  request_payload JSONB,
  response_payload JSONB,
  processing_time_ms INTEGER,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT DEFAULT 'isko-agent'
);

-- Indexes for performance
CREATE INDEX idx_ingest_log_sku_id ON sku_ingest_log(sku_id);
CREATE INDEX idx_ingest_log_status ON sku_ingest_log(status);
CREATE INDEX idx_ingest_log_created_at ON sku_ingest_log(created_at DESC);
CREATE INDEX idx_ingest_log_source_url ON sku_ingest_log(source_url);

-- View for recent ingestion activity
CREATE OR REPLACE VIEW recent_ingestion_activity AS
SELECT 
    date_trunc('hour', created_at) as hour,
    source_type,
    status,
    COUNT(*) as count,
    AVG(processing_time_ms) as avg_processing_time_ms
FROM sku_ingest_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY date_trunc('hour', created_at), source_type, status
ORDER BY hour DESC;

-- Function to get ingestion stats
CREATE OR REPLACE FUNCTION get_ingestion_stats(
    p_days_back INTEGER DEFAULT 7,
    p_source_type TEXT DEFAULT NULL
)
RETURNS TABLE (
    total_attempts BIGINT,
    successful_ingestions BIGINT,
    failed_ingestions BIGINT,
    duplicate_skus BIGINT,
    validation_failures BIGINT,
    success_rate NUMERIC,
    avg_processing_time_ms NUMERIC,
    unique_skus BIGINT,
    unique_sources BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_attempts,
        COUNT(CASE WHEN status = 'success' THEN 1 END)::BIGINT as successful_ingestions,
        COUNT(CASE WHEN status = 'error' THEN 1 END)::BIGINT as failed_ingestions,
        COUNT(CASE WHEN status = 'duplicate' THEN 1 END)::BIGINT as duplicate_skus,
        COUNT(CASE WHEN status = 'validation_failed' THEN 1 END)::BIGINT as validation_failures,
        ROUND(
            COUNT(CASE WHEN status = 'success' THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(*), 0) * 100, 
            2
        ) as success_rate,
        ROUND(AVG(processing_time_ms)::NUMERIC, 2) as avg_processing_time_ms,
        COUNT(DISTINCT sku_id)::BIGINT as unique_skus,
        COUNT(DISTINCT source_url)::BIGINT as unique_sources
    FROM sku_ingest_log
    WHERE created_at > NOW() - INTERVAL '1 day' * p_days_back
    AND (p_source_type IS NULL OR source_type = p_source_type);
END;
$$ LANGUAGE plpgsql;

-- Row Level Security
ALTER TABLE sku_ingest_log ENABLE ROW LEVEL SECURITY;

-- Policy for read access
CREATE POLICY "Allow authenticated read access to ingest logs" 
    ON sku_ingest_log FOR SELECT 
    TO authenticated
    USING (true);

-- Policy for insert (only service role)
CREATE POLICY "Allow service role to insert logs" 
    ON sku_ingest_log FOR INSERT 
    TO service_role
    WITH CHECK (true);

-- Add comment
COMMENT ON TABLE sku_ingest_log IS 'Comprehensive logging for all SKU ingestion attempts by Isko agent';