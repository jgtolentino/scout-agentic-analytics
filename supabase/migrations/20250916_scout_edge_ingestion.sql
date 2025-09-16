-- Scout Edge Data Ingestion Schema Migration
-- Ingest 13,289 local Scout Edge JSON transaction files
-- Date: 2025-09-16
-- Purpose: Create unified Scout Edge + Azure + Drive analytics platform

BEGIN;

-- Create Scout Edge transactions table based on JSON structure analysis
CREATE TABLE IF NOT EXISTS bronze.scout_edge_transactions (
    -- Primary identifiers
    transaction_id UUID PRIMARY KEY,
    store_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    transaction_timestamp TIMESTAMPTZ,
    
    -- Brand detection intelligence (enhanced from JSON structure)
    detected_brands JSONB,
    explicit_mentions JSONB,
    implicit_signals JSONB,
    detection_methods TEXT[],
    category_brand_mapping JSONB,
    
    -- Transaction items (normalized from items array)
    items JSONB NOT NULL,
    
    -- Totals and metrics
    total_amount DECIMAL(10,2),
    total_items INTEGER,
    branded_amount DECIMAL(10,2),
    unbranded_amount DECIMAL(10,2),
    branded_count INTEGER,
    unbranded_count INTEGER,
    unique_brands_count INTEGER,
    
    -- Transaction context and metadata
    transaction_context JSONB,
    duration_seconds DECIMAL(5,2),
    payment_method TEXT,
    time_of_day TEXT,
    day_type TEXT,
    audio_transcript TEXT,
    processing_methods TEXT[],
    
    -- Privacy and compliance (from privacy JSON object)
    privacy_settings JSONB,
    audio_stored BOOLEAN DEFAULT FALSE,
    brand_analysis_only BOOLEAN DEFAULT TRUE,
    no_facial_recognition BOOLEAN DEFAULT TRUE,
    no_image_processing BOOLEAN DEFAULT TRUE,
    data_retention_days INTEGER DEFAULT 30,
    anonymization_level TEXT DEFAULT 'high',
    consent_timestamp TIMESTAMPTZ,
    
    -- Processing metadata
    processing_time_seconds DECIMAL(6,3),
    edge_version TEXT DEFAULT 'v2.0.0-stt-only',
    source_file TEXT,
    
    -- ETL metadata
    ingested_at TIMESTAMPTZ DEFAULT NOW(),
    ingested_by TEXT DEFAULT 'scout_edge_etl',
    processing_version TEXT DEFAULT 'v1.0.0',
    quality_score DECIMAL(3,2),
    
    -- Indexes and constraints
    CONSTRAINT valid_amounts CHECK (total_amount >= 0 AND branded_amount >= 0 AND unbranded_amount >= 0),
    CONSTRAINT valid_counts CHECK (total_items >= 0 AND branded_count >= 0 AND unbranded_count >= 0),
    CONSTRAINT valid_quality_score CHECK (quality_score >= 0.0 AND quality_score <= 1.0)
);

-- Create device registry for Scout Edge devices
CREATE TABLE IF NOT EXISTS metadata.scout_edge_device_registry (
    device_id TEXT PRIMARY KEY,
    device_name TEXT,
    store_id TEXT,
    location_description TEXT,
    device_type TEXT DEFAULT 'scoutpi',
    firmware_version TEXT,
    capabilities JSONB,
    installation_date DATE,
    last_seen TIMESTAMPTZ,
    status TEXT CHECK (status IN ('active', 'inactive', 'maintenance', 'decommissioned')),
    
    -- Performance metrics
    total_transactions INTEGER DEFAULT 0,
    avg_processing_time DECIMAL(6,3),
    success_rate DECIMAL(5,4),
    
    -- ETL metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create Scout Edge ETL job configuration
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
    'scout_edge_local_ingestion',
    'file_batch_ingestion',
    'local_filesystem',
    ARRAY['bronze.scout_edge_transactions'],
    '0 */6 * * *',  -- Every 6 hours
    true,
    '{
        "max_retries": 3,
        "retry_delay_seconds": 300,
        "exponential_backoff": true,
        "dead_letter_queue": true
    }'::jsonb,
    '{
        "source_path": "/Users/tbwa/Downloads/Project-Scout-2",
        "batch_size": 500,
        "parallel_devices": true,
        "max_parallel_workers": 7,
        "file_pattern": "*.json",
        "incremental": false,
        "validation_enabled": true,
        "deduplication_enabled": true
    }'::jsonb
) ON CONFLICT (job_name) DO UPDATE SET
    processing_config = EXCLUDED.processing_config,
    updated_at = NOW();

-- Register Scout Edge devices from analysis
INSERT INTO metadata.scout_edge_device_registry 
(device_id, device_name, store_id, total_transactions, status, last_seen) 
VALUES 
    ('SCOUTPI-0002', 'Scout Pi Device 0002', '102', 1488, 'active', NOW()),
    ('SCOUTPI-0003', 'Scout Pi Device 0003', '103', 1484, 'active', NOW()),
    ('SCOUTPI-0004', 'Scout Pi Device 0004', '104', 207, 'active', NOW()),
    ('SCOUTPI-0006', 'Scout Pi Device 0006', '106', 5919, 'active', NOW()),
    ('SCOUTPI-0009', 'Scout Pi Device 0009', '109', 2645, 'active', NOW()),
    ('SCOUTPI-0010', 'Scout Pi Device 0010', '110', 1312, 'active', NOW'),
    ('SCOUTPI-0012', 'Scout Pi Device 0012', '112', 234, 'active', NOW())
ON CONFLICT (device_id) DO UPDATE SET
    total_transactions = EXCLUDED.total_transactions,
    last_seen = EXCLUDED.last_seen,
    updated_at = NOW();

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_scout_edge_transactions_store_device 
    ON bronze.scout_edge_transactions(store_id, device_id);
    
CREATE INDEX IF NOT EXISTS idx_scout_edge_transactions_timestamp 
    ON bronze.scout_edge_transactions(transaction_timestamp DESC);
    
CREATE INDEX IF NOT EXISTS idx_scout_edge_transactions_brands 
    ON bronze.scout_edge_transactions USING GIN(detected_brands);
    
CREATE INDEX IF NOT EXISTS idx_scout_edge_transactions_items 
    ON bronze.scout_edge_transactions USING GIN(items);
    
CREATE INDEX IF NOT EXISTS idx_scout_edge_transactions_processing 
    ON bronze.scout_edge_transactions(processing_version, ingested_at);

-- Create function to extract brands from Scout Edge JSON
CREATE OR REPLACE FUNCTION bronze.extract_scout_edge_brands(detected_brands_json JSONB)
RETURNS TEXT[] AS $$
BEGIN
    -- Extract brand names from the detected_brands object
    RETURN ARRAY(
        SELECT jsonb_object_keys(detected_brands_json)
        WHERE detected_brands_json IS NOT NULL
    );
EXCEPTION WHEN OTHERS THEN
    RETURN ARRAY[]::TEXT[];
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create function to calculate transaction quality score
CREATE OR REPLACE FUNCTION bronze.calculate_scout_edge_quality_score(
    items_json JSONB,
    detected_brands JSONB,
    processing_methods TEXT[],
    audio_transcript TEXT
) RETURNS DECIMAL(3,2) AS $$
DECLARE
    quality_score DECIMAL(3,2) := 0.0;
    item_count INTEGER;
    brands_count INTEGER;
    methods_count INTEGER;
BEGIN
    -- Base score from items completeness
    item_count := jsonb_array_length(COALESCE(items_json, '[]'::jsonb));
    IF item_count > 0 THEN
        quality_score := quality_score + 0.3;
    END IF;
    
    -- Brand detection quality
    brands_count := jsonb_object_keys_count(COALESCE(detected_brands, '{}'::jsonb));
    IF brands_count > 0 THEN
        quality_score := quality_score + 0.3;
    END IF;
    
    -- Processing methods completeness
    methods_count := array_length(COALESCE(processing_methods, ARRAY[]::TEXT[]), 1);
    IF methods_count >= 3 THEN
        quality_score := quality_score + 0.2;
    ELSIF methods_count > 0 THEN
        quality_score := quality_score + 0.1;
    END IF;
    
    -- Audio transcript quality
    IF audio_transcript IS NOT NULL AND length(audio_transcript) > 5 THEN
        quality_score := quality_score + 0.2;
    END IF;
    
    RETURN LEAST(quality_score, 1.0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create Scout Edge data validation function
CREATE OR REPLACE FUNCTION bronze.validate_scout_edge_transaction(
    transaction_data JSONB
) RETURNS JSONB AS $$
DECLARE
    validation_result JSONB := '{}'::jsonb;
    error_count INTEGER := 0;
    warnings TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate required fields
    IF NOT (transaction_data ? 'transactionId') THEN
        error_count := error_count + 1;
        warnings := array_append(warnings, 'Missing transactionId');
    END IF;
    
    IF NOT (transaction_data ? 'storeId') THEN
        error_count := error_count + 1;
        warnings := array_append(warnings, 'Missing storeId');
    END IF;
    
    IF NOT (transaction_data ? 'deviceId') THEN
        error_count := error_count + 1;
        warnings := array_append(warnings, 'Missing deviceId');
    END IF;
    
    -- Validate items array
    IF NOT (transaction_data ? 'items') OR jsonb_array_length(transaction_data->'items') = 0 THEN
        warnings := array_append(warnings, 'Empty or missing items array');
    END IF;
    
    -- Validate totals consistency
    IF (transaction_data->'totals'->>'totalAmount')::DECIMAL != 
       (transaction_data->'totals'->>'brandedAmount')::DECIMAL + 
       (transaction_data->'totals'->>'unbrandedAmount')::DECIMAL THEN
        warnings := array_append(warnings, 'Total amount mismatch');
    END IF;
    
    -- Build validation result
    validation_result := jsonb_build_object(
        'is_valid', error_count = 0,
        'error_count', error_count,
        'warnings', to_jsonb(warnings),
        'validated_at', NOW()
    );
    
    RETURN validation_result;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-calculate quality score
CREATE OR REPLACE FUNCTION bronze.set_scout_edge_quality_score()
RETURNS TRIGGER AS $$
BEGIN
    NEW.quality_score := bronze.calculate_scout_edge_quality_score(
        NEW.items,
        NEW.detected_brands,
        NEW.processing_methods,
        NEW.audio_transcript
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER scout_edge_quality_score_trigger
    BEFORE INSERT OR UPDATE ON bronze.scout_edge_transactions
    FOR EACH ROW
    EXECUTE FUNCTION bronze.set_scout_edge_quality_score();

-- Grant permissions
GRANT ALL PRIVILEGES ON bronze.scout_edge_transactions TO postgres;
GRANT ALL PRIVILEGES ON metadata.scout_edge_device_registry TO postgres;
GRANT EXECUTE ON FUNCTION bronze.extract_scout_edge_brands TO postgres;
GRANT EXECUTE ON FUNCTION bronze.calculate_scout_edge_quality_score TO postgres;
GRANT EXECUTE ON FUNCTION bronze.validate_scout_edge_transaction TO postgres;

-- Create migration log entry
INSERT INTO metadata.migration_log (
    migration_id,
    migration_name,
    migration_type,
    description,
    status,
    executed_at
) VALUES (
    '20250916_scout_edge_ingestion',
    'Scout Edge Local Data Ingestion Infrastructure',
    'schema_extension',
    'Create comprehensive Scout Edge data ingestion platform for 13,289 local JSON transaction files across 7 devices with brand detection intelligence and unified analytics integration',
    'applied',
    NOW()
);

COMMIT;

-- Display deployment summary
\echo ''
\echo '======================================================'
\echo 'Scout Edge Data Ingestion Infrastructure Deployed'
\echo '======================================================'
\echo ''
\echo 'Tables Created:'
\echo '• bronze.scout_edge_transactions - Main transaction data'
\echo '• metadata.scout_edge_device_registry - Device management'
\echo ''
\echo 'Functions Created:'
\echo '• bronze.extract_scout_edge_brands - Brand extraction'
\echo '• bronze.calculate_scout_edge_quality_score - Quality scoring'
\echo '• bronze.validate_scout_edge_transaction - Data validation'
\echo ''
\echo 'Devices Registered:'
\echo '• SCOUTPI-0002 (1,488 transactions)'
\echo '• SCOUTPI-0003 (1,484 transactions)'
\echo '• SCOUTPI-0004 (207 transactions)'
\echo '• SCOUTPI-0006 (5,919 transactions)'
\echo '• SCOUTPI-0009 (2,645 transactions)'
\echo '• SCOUTPI-0010 (1,312 transactions)'
\echo '• SCOUTPI-0012 (234 transactions)'
\echo ''
\echo 'Total Files Ready for Ingestion: 13,289'
\echo 'Source Path: /Users/tbwa/Downloads/Project-Scout-2'
\echo ''
\echo 'Next Steps:'
\echo '1. Implement Temporal workflow: scout_edge_ingestion_workflow.py'
\echo '2. Add Bruno executor command: scout-edge'
\echo '3. Execute ingestion: python3 bruno_executor.py scout-edge'
\echo '======================================================'