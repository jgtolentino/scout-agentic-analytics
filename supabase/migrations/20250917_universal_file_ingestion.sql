-- Universal File Ingestion Schema Migration
-- Support format-flexible Google Drive data processing
-- Date: 2025-09-17
-- Purpose: Enable CSV, JSON, Excel, TSV, XML, Parquet ingestion

BEGIN;

-- Create universal file ingestion table for format-flexible processing
CREATE TABLE IF NOT EXISTS staging.universal_file_ingestion (
    -- Primary identifiers
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id TEXT NOT NULL,
    file_name TEXT NOT NULL,

    -- Format detection results
    file_format TEXT NOT NULL CHECK (file_format IN ('json', 'csv', 'tsv', 'excel', 'xml', 'parquet', 'text')),
    detection_confidence DECIMAL(3,2) NOT NULL CHECK (detection_confidence >= 0.0 AND detection_confidence <= 1.0),

    -- Schema inference results
    schema_inference JSONB NOT NULL,
    column_mappings JSONB,

    -- Raw data storage (first 1000 records)
    raw_data JSONB NOT NULL,
    total_records INTEGER NOT NULL DEFAULT 0,

    -- Processing metadata
    processing_metadata JSONB NOT NULL,

    -- ETL metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Status tracking
    status TEXT DEFAULT 'ingested' CHECK (status IN ('ingested', 'processed', 'failed', 'archived')),
    error_message TEXT
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_universal_file_ingestion_file_id
    ON staging.universal_file_ingestion(file_id);

CREATE INDEX IF NOT EXISTS idx_universal_file_ingestion_format
    ON staging.universal_file_ingestion(file_format);

CREATE INDEX IF NOT EXISTS idx_universal_file_ingestion_created_at
    ON staging.universal_file_ingestion(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_universal_file_ingestion_status
    ON staging.universal_file_ingestion(status);

-- GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_universal_file_ingestion_schema_gin
    ON staging.universal_file_ingestion USING GIN(schema_inference);

CREATE INDEX IF NOT EXISTS idx_universal_file_ingestion_mappings_gin
    ON staging.universal_file_ingestion USING GIN(column_mappings);

CREATE INDEX IF NOT EXISTS idx_universal_file_ingestion_data_gin
    ON staging.universal_file_ingestion USING GIN(raw_data);

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION staging.update_universal_file_ingestion_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_universal_file_ingestion_updated_at
    BEFORE UPDATE ON staging.universal_file_ingestion
    FOR EACH ROW
    EXECUTE FUNCTION staging.update_universal_file_ingestion_updated_at();

-- Create view for monitoring ingestion pipeline
CREATE OR REPLACE VIEW staging.universal_file_ingestion_stats AS
SELECT
    file_format,
    status,
    COUNT(*) as file_count,
    AVG(detection_confidence) as avg_confidence,
    AVG(total_records) as avg_records,
    AVG(EXTRACT(EPOCH FROM (processing_metadata->>'processing_time_ms')::int) / 1000.0) as avg_processing_seconds,
    MIN(created_at) as first_ingestion,
    MAX(created_at) as last_ingestion
FROM staging.universal_file_ingestion
GROUP BY file_format, status
ORDER BY file_format, status;

-- Create function to get ingestion summary
CREATE OR REPLACE FUNCTION staging.get_ingestion_summary(
    p_hours_back INTEGER DEFAULT 24
) RETURNS TABLE (
    summary_type TEXT,
    metric_name TEXT,
    metric_value BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'file_formats'::TEXT,
        file_format,
        COUNT(*)::BIGINT
    FROM staging.universal_file_ingestion
    WHERE created_at > NOW() - INTERVAL '1 hour' * p_hours_back
    GROUP BY file_format

    UNION ALL

    SELECT
        'status_breakdown'::TEXT,
        status,
        COUNT(*)::BIGINT
    FROM staging.universal_file_ingestion
    WHERE created_at > NOW() - INTERVAL '1 hour' * p_hours_back
    GROUP BY status

    UNION ALL

    SELECT
        'totals'::TEXT,
        'total_files',
        COUNT(*)::BIGINT
    FROM staging.universal_file_ingestion
    WHERE created_at > NOW() - INTERVAL '1 hour' * p_hours_back

    UNION ALL

    SELECT
        'totals'::TEXT,
        'total_records',
        SUM(total_records)::BIGINT
    FROM staging.universal_file_ingestion
    WHERE created_at > NOW() - INTERVAL '1 hour' * p_hours_back;
END;
$$ LANGUAGE plpgsql;

-- Create RLS policies for security
ALTER TABLE staging.universal_file_ingestion ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can do everything
CREATE POLICY universal_file_ingestion_service_role
    ON staging.universal_file_ingestion
    FOR ALL
    TO service_role
    USING (true);

-- Policy: Authenticated users can read
CREATE POLICY universal_file_ingestion_read
    ON staging.universal_file_ingestion
    FOR SELECT
    TO authenticated
    USING (true);

-- Grant permissions
GRANT ALL PRIVILEGES ON staging.universal_file_ingestion TO postgres;
GRANT SELECT ON staging.universal_file_ingestion TO authenticated;
GRANT ALL ON staging.universal_file_ingestion TO service_role;

-- Grant permissions on the view and function
GRANT SELECT ON staging.universal_file_ingestion_stats TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION staging.get_ingestion_summary TO authenticated, service_role;

-- Add to ETL job registry for monitoring
INSERT INTO metadata.etl_job_registry (
    job_name,
    job_type,
    source_system,
    target_tables,
    schedule_cron,
    enabled,
    retry_config,
    processing_config
) VALUES (
    'universal_drive_file_processor',
    'file_format_detection',
    'google_drive',
    ARRAY['staging.universal_file_ingestion'],
    '0 */15 * * *',  -- Every 15 minutes
    true,
    '{"max_retries": 3, "retry_delay_seconds": 180, "exponential_backoff": true}'::jsonb,
    '{
        "supported_formats": ["json", "csv", "tsv", "excel", "xml", "parquet"],
        "max_file_size_mb": 100,
        "schema_inference_enabled": true,
        "ml_column_mapping_enabled": true,
        "confidence_threshold": 0.8,
        "cache_results": true,
        "batch_size": 50
    }'::jsonb
) ON CONFLICT (job_name) DO UPDATE SET
    processing_config = EXCLUDED.processing_config,
    updated_at = NOW();

COMMIT;

-- Success confirmation
SELECT
    'Universal File Ingestion Schema Created Successfully' as status,
    COUNT(*) as tables_created
FROM information_schema.tables
WHERE table_schema = 'staging'
    AND table_name = 'universal_file_ingestion';