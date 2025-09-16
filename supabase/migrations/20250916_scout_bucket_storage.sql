-- Scout Edge Bucket Storage Infrastructure Migration
-- Create Google Drive to Supabase bucket storage pipeline
-- Date: 2025-09-16
-- Purpose: Automated Scout Edge data sync from Google Drive to bucket storage

BEGIN;

-- Create scout-ingest bucket if it doesn't exist (declarative for reference)
-- Note: Bucket creation is typically done via Supabase dashboard or CLI
-- This migration focuses on policies and triggers

-- Ensure scout-ingest bucket exists and configure policies
-- Create bucket storage policies for Scout Edge data

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Clean up existing Scout bucket policies
DROP POLICY IF EXISTS "scout_bucket_public_read" ON storage.objects;
DROP POLICY IF EXISTS "scout_bucket_service_write" ON storage.objects;
DROP POLICY IF EXISTS "scout_bucket_authenticated_read" ON storage.objects;

-- Policy for service role to manage scout-ingest bucket
CREATE POLICY "scout_bucket_service_full_access"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'scout-ingest');

-- Policy for authenticated users to read scout-ingest files
CREATE POLICY "scout_bucket_authenticated_read"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'scout-ingest');

-- Create scout bucket file registry to track processing status
CREATE TABLE IF NOT EXISTS metadata.scout_bucket_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- File identification
    bucket_name TEXT NOT NULL DEFAULT 'scout-ingest',
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT,
    file_type TEXT,
    content_type TEXT,
    
    -- Source information
    source_type TEXT NOT NULL CHECK (source_type IN ('google_drive', 'scout_edge', 'manual_upload')),
    source_id TEXT, -- Google Drive file ID or device ID
    original_path TEXT,
    
    -- Processing status
    processing_status TEXT NOT NULL DEFAULT 'pending' 
        CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed', 'skipped')),
    processed_at TIMESTAMPTZ,
    processing_duration_ms INTEGER,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    -- Scout Edge specific metadata (from schema analysis)
    scout_metadata JSONB,
    transaction_count INTEGER,
    device_id TEXT,
    store_id TEXT,
    
    -- Quality metrics
    validation_status TEXT CHECK (validation_status IN ('valid', 'invalid', 'warning')),
    quality_score DECIMAL(3,2),
    quality_issues TEXT[],
    
    -- File versioning
    file_hash TEXT,
    is_duplicate BOOLEAN DEFAULT FALSE,
    duplicate_of UUID REFERENCES metadata.scout_bucket_files(id),
    
    -- Timestamps
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(bucket_name, file_path),
    CONSTRAINT valid_quality_score CHECK (quality_score >= 0.0 AND quality_score <= 1.0)
);

-- Create scout bucket sync jobs registry
CREATE TABLE IF NOT EXISTS metadata.scout_sync_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Job identification
    job_name TEXT NOT NULL,
    job_type TEXT NOT NULL CHECK (job_type IN ('drive_sync', 'bucket_process', 'full_pipeline')),
    
    -- Source configuration
    source_config JSONB NOT NULL,
    target_config JSONB,
    
    -- Execution details
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,
    
    -- Processing metrics
    files_discovered INTEGER DEFAULT 0,
    files_processed INTEGER DEFAULT 0,
    files_succeeded INTEGER DEFAULT 0,
    files_failed INTEGER DEFAULT 0,
    files_skipped INTEGER DEFAULT 0,
    total_size_bytes BIGINT DEFAULT 0,
    
    -- Error handling
    error_details JSONB,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Progress tracking
    progress_percentage DECIMAL(5,2) DEFAULT 0.0,
    current_phase TEXT,
    phase_details JSONB,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT valid_progress CHECK (progress_percentage >= 0.0 AND progress_percentage <= 100.0)
);

-- Create Google Drive file mapping table
CREATE TABLE IF NOT EXISTS metadata.google_drive_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Google Drive identifiers
    drive_file_id TEXT NOT NULL UNIQUE,
    drive_folder_id TEXT NOT NULL,
    drive_name TEXT NOT NULL,
    drive_path TEXT,
    
    -- File metadata
    mime_type TEXT,
    file_size BIGINT,
    file_hash TEXT,
    
    -- Google Drive metadata
    created_time TIMESTAMPTZ,
    modified_time TIMESTAMPTZ,
    version TEXT,
    drive_owners JSONB,
    drive_permissions JSONB,
    
    -- Sync status
    sync_status TEXT DEFAULT 'pending' 
        CHECK (sync_status IN ('pending', 'synced', 'failed', 'excluded')),
    last_synced_at TIMESTAMPTZ,
    bucket_file_path TEXT,
    bucket_file_id UUID REFERENCES metadata.scout_bucket_files(id),
    
    -- Processing flags
    is_scout_edge_file BOOLEAN DEFAULT FALSE,
    scout_device_detected TEXT,
    file_classification TEXT,
    
    -- Timestamps
    discovered_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create function to validate Scout Edge file structure
CREATE OR REPLACE FUNCTION metadata.validate_scout_edge_file(file_content JSONB)
RETURNS JSONB AS $$
DECLARE
    validation_result JSONB := '{}'::jsonb;
    required_fields TEXT[] := ARRAY['transactionId', 'storeId', 'deviceId', 'items', 'totals'];
    field_name TEXT;
    issues TEXT[] := ARRAY[]::TEXT[];
    quality_score DECIMAL(3,2) := 1.0;
BEGIN
    -- Check required fields
    FOREACH field_name IN ARRAY required_fields
    LOOP
        IF NOT (file_content ? field_name) THEN
            issues := array_append(issues, format('Missing required field: %s', field_name));
            quality_score := quality_score - 0.2;
        END IF;
    END LOOP;
    
    -- Validate items array
    IF file_content ? 'items' THEN
        IF jsonb_typeof(file_content->'items') != 'array' THEN
            issues := array_append(issues, 'Items field must be an array');
            quality_score := quality_score - 0.1;
        ELSIF jsonb_array_length(file_content->'items') = 0 THEN
            issues := array_append(issues, 'Items array is empty');
            quality_score := quality_score - 0.1;
        END IF;
    END IF;
    
    -- Validate totals structure
    IF file_content ? 'totals' THEN
        IF NOT (file_content->'totals' ? 'totalAmount') THEN
            issues := array_append(issues, 'Missing totalAmount in totals');
            quality_score := quality_score - 0.1;
        END IF;
    END IF;
    
    -- Validate device ID format
    IF file_content ? 'deviceId' THEN
        IF NOT (file_content->>'deviceId' ~ '^SCOUTPI-\d+$') THEN
            issues := array_append(issues, 'Invalid deviceId format');
            quality_score := quality_score - 0.1;
        END IF;
    END IF;
    
    -- Build validation result
    validation_result := jsonb_build_object(
        'is_valid', array_length(issues, 1) IS NULL OR array_length(issues, 1) = 0,
        'quality_score', GREATEST(quality_score, 0.0),
        'issues', to_jsonb(COALESCE(issues, ARRAY[]::TEXT[])),
        'required_fields_present', array_length(required_fields, 1) - array_length(issues, 1),
        'total_required_fields', array_length(required_fields, 1),
        'validated_at', NOW()
    );
    
    RETURN validation_result;
END;
$$ LANGUAGE plpgsql;

-- Create function to extract Scout metadata from file content
CREATE OR REPLACE FUNCTION metadata.extract_scout_metadata(file_content JSONB)
RETURNS JSONB AS $$
DECLARE
    metadata_result JSONB;
    items_count INTEGER := 0;
    brands_count INTEGER := 0;
    total_amount DECIMAL;
BEGIN
    -- Extract basic metrics
    IF file_content ? 'items' THEN
        items_count := jsonb_array_length(file_content->'items');
    END IF;
    
    IF file_content ? 'brandDetection' AND file_content->'brandDetection' ? 'detectedBrands' THEN
        brands_count := jsonb_object_keys_count(file_content->'brandDetection'->'detectedBrands');
    END IF;
    
    IF file_content ? 'totals' AND file_content->'totals' ? 'totalAmount' THEN
        total_amount := (file_content->'totals'->>'totalAmount')::DECIMAL;
    END IF;
    
    metadata_result := jsonb_build_object(
        'transaction_id', file_content->>'transactionId',
        'store_id', file_content->>'storeId',
        'device_id', file_content->>'deviceId',
        'items_count', items_count,
        'brands_count', brands_count,
        'total_amount', total_amount,
        'has_brand_detection', file_content ? 'brandDetection',
        'has_audio_transcript', 
            file_content ? 'transactionContext' AND 
            file_content->'transactionContext' ? 'audioTranscript',
        'processing_methods', file_content->'transactionContext'->'processingMethods',
        'edge_version', file_content->>'edgeVersion',
        'privacy_compliant', 
            file_content ? 'privacy' AND 
            COALESCE((file_content->'privacy'->>'audioStored')::BOOLEAN, FALSE) = FALSE,
        'extracted_at', NOW()
    );
    
    RETURN metadata_result;
END;
$$ LANGUAGE plpgsql;

-- Create trigger function to update timestamps
CREATE OR REPLACE FUNCTION metadata.update_scout_bucket_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for timestamp updates
CREATE TRIGGER scout_bucket_files_update_timestamp
    BEFORE UPDATE ON metadata.scout_bucket_files
    FOR EACH ROW
    EXECUTE FUNCTION metadata.update_scout_bucket_timestamp();

CREATE TRIGGER scout_sync_jobs_update_timestamp
    BEFORE UPDATE ON metadata.scout_sync_jobs
    FOR EACH ROW
    EXECUTE FUNCTION metadata.update_scout_bucket_timestamp();

CREATE TRIGGER google_drive_files_update_timestamp
    BEFORE UPDATE ON metadata.google_drive_files
    FOR EACH ROW
    EXECUTE FUNCTION metadata.update_scout_bucket_timestamp();

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_scout_bucket_files_status_created 
    ON metadata.scout_bucket_files(processing_status, created_at);
    
CREATE INDEX IF NOT EXISTS idx_scout_bucket_files_source_type 
    ON metadata.scout_bucket_files(source_type, file_type);
    
CREATE INDEX IF NOT EXISTS idx_scout_bucket_files_device_store 
    ON metadata.scout_bucket_files(device_id, store_id) 
    WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_scout_sync_jobs_status_created 
    ON metadata.scout_sync_jobs(status, created_at);
    
CREATE INDEX IF NOT EXISTS idx_scout_sync_jobs_type_status 
    ON metadata.scout_sync_jobs(job_type, status);

CREATE INDEX IF NOT EXISTS idx_google_drive_files_sync_status 
    ON metadata.google_drive_files(sync_status, last_synced_at);
    
CREATE INDEX IF NOT EXISTS idx_google_drive_files_drive_id 
    ON metadata.google_drive_files(drive_file_id);
    
CREATE INDEX IF NOT EXISTS idx_google_drive_files_scout_classification 
    ON metadata.google_drive_files(is_scout_edge_file, file_classification);

-- Create view for monitoring bucket processing
CREATE OR REPLACE VIEW metadata.scout_bucket_monitoring AS
SELECT 
    -- File processing status
    processing_status,
    COUNT(*) as file_count,
    SUM(file_size) as total_size_bytes,
    AVG(quality_score) as avg_quality_score,
    AVG(processing_duration_ms) as avg_processing_time_ms,
    
    -- Source breakdown
    COUNT(*) FILTER (WHERE source_type = 'google_drive') as drive_files,
    COUNT(*) FILTER (WHERE source_type = 'scout_edge') as scout_edge_files,
    COUNT(*) FILTER (WHERE source_type = 'manual_upload') as manual_files,
    
    -- Device breakdown
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(DISTINCT store_id) as unique_stores,
    
    -- Time ranges
    MIN(created_at) as earliest_file,
    MAX(created_at) as latest_file,
    
    -- Quality metrics
    COUNT(*) FILTER (WHERE validation_status = 'valid') as valid_files,
    COUNT(*) FILTER (WHERE validation_status = 'invalid') as invalid_files,
    COUNT(*) FILTER (WHERE is_duplicate = true) as duplicate_files
    
FROM metadata.scout_bucket_files
GROUP BY processing_status;

-- Grant permissions
GRANT ALL PRIVILEGES ON metadata.scout_bucket_files TO postgres;
GRANT ALL PRIVILEGES ON metadata.scout_sync_jobs TO postgres;
GRANT ALL PRIVILEGES ON metadata.google_drive_files TO postgres;
GRANT SELECT ON metadata.scout_bucket_monitoring TO postgres, authenticated;
GRANT EXECUTE ON FUNCTION metadata.validate_scout_edge_file TO postgres;
GRANT EXECUTE ON FUNCTION metadata.extract_scout_metadata TO postgres;

-- Insert initial Google Drive sync job configuration
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
    'google_drive_to_bucket_sync',
    'drive_to_bucket_sync',
    'google_drive_api',
    ARRAY['metadata.scout_bucket_files', 'metadata.google_drive_files'],
    '0 */6 * * *',  -- Every 6 hours
    true,
    '{
        "max_retries": 3,
        "retry_delay_seconds": 300,
        "exponential_backoff": true,
        "dead_letter_queue": true
    }'::jsonb,
    '{
        "drive_folder_id": "1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA",
        "bucket_name": "scout-ingest",
        "bucket_path": "edge-transactions/",
        "file_patterns": ["*.json"],
        "incremental_sync": true,
        "validation_enabled": true,
        "duplicate_detection": true,
        "max_file_size_mb": 50,
        "concurrent_downloads": 5
    }'::jsonb
) ON CONFLICT (job_name) DO UPDATE SET
    processing_config = EXCLUDED.processing_config,
    updated_at = NOW();

-- Create migration log entry
INSERT INTO metadata.migration_log (
    migration_id,
    migration_name,
    migration_type,
    description,
    status,
    executed_at
) VALUES (
    '20250916_scout_bucket_storage',
    'Scout Edge Bucket Storage Infrastructure',
    'infrastructure_setup',
    'Create comprehensive bucket storage infrastructure for Google Drive to Supabase Scout Edge data pipeline with file tracking, validation, and processing capabilities',
    'applied',
    NOW()
);

COMMIT;

-- Display deployment summary
\echo ''
\echo '======================================================='
\echo 'Scout Edge Bucket Storage Infrastructure Deployed'
\echo '======================================================='
\echo ''
\echo 'Infrastructure Created:'
\echo '• scout-ingest bucket policies and RLS'
\echo '• File tracking: metadata.scout_bucket_files'
\echo '• Sync jobs: metadata.scout_sync_jobs'
\echo '• Google Drive mapping: metadata.google_drive_files'
\echo '• Processing monitoring view'
\echo ''
\echo 'Functions Created:'
\echo '• validate_scout_edge_file - File structure validation'
\echo '• extract_scout_metadata - Scout metadata extraction'
\echo '• Automatic timestamp triggers'
\echo ''
\echo 'Google Drive Source:'
\echo '• Folder ID: 1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA'
\echo '• Target Bucket: scout-ingest/edge-transactions/'
\echo '• Sync Schedule: Every 6 hours'
\echo ''
\echo 'Next Steps:'
\echo '1. Create bucket if needed: supabase storage create scout-ingest'
\echo '2. Implement Drive sync workflow'
\echo '3. Create bucket processor workflow'
\echo '4. Deploy Edge Functions'
\echo '======================================================='