-- Contract Validation Functions and PII Masking
-- Production-grade data contract enforcement with JSON Schema validation

-- =====================================================================
-- JSON SCHEMA VALIDATION FUNCTION
-- =====================================================================
CREATE OR REPLACE FUNCTION contracts.validate_json_schema(
  data_json JSONB,
  schema_json JSONB
) RETURNS BOOLEAN AS $$
DECLARE
  validation_result BOOLEAN;
BEGIN
  -- This is a simplified JSON schema validator
  -- In production, use a proper JSON Schema validation library
  
  -- Check required fields
  IF schema_json ? 'required' THEN
    IF NOT (data_json ?& (SELECT array_agg(value::text) FROM jsonb_array_elements_text(schema_json->'required'))) THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- Check data types for each property
  IF schema_json ? 'properties' THEN
    -- This would be expanded for full JSON Schema validation
    -- For now, return true if basic structure is valid
    RETURN TRUE;
  END IF;
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- CONTRACT VALIDATION FOR BRONZE INGESTION
-- =====================================================================
CREATE OR REPLACE FUNCTION contracts.validate_bronze_batch(
  source_name_param TEXT,
  batch_data JSONB,
  partition_key_param TEXT DEFAULT NULL
) RETURNS TABLE (
  is_valid BOOLEAN,
  violations JSONB,
  valid_records INTEGER,
  invalid_records INTEGER
) AS $$
DECLARE
  contract_rec contracts.sources%ROWTYPE;
  record_json JSONB;
  violation_details JSONB := '[]'::JSONB;
  valid_count INTEGER := 0;
  invalid_count INTEGER := 0;
  temp_violations JSONB;
BEGIN
  -- Get contract for source
  SELECT * INTO contract_rec 
  FROM contracts.sources 
  WHERE source_name = source_name_param 
    AND (effective_to IS NULL OR effective_to > NOW());
    
  IF NOT FOUND THEN
    -- Log missing contract
    INSERT INTO metadata.contract_violations (
      source_name, partition_key, violations, violation_type, severity
    ) VALUES (
      source_name_param, partition_key_param,
      '{"error": "No active contract found for source"}'::JSONB,
      'schema', 'critical'
    );
    
    RETURN QUERY SELECT FALSE, '{"error": "No contract found"}'::JSONB, 0, 0;
    RETURN;
  END IF;
  
  -- Validate each record in batch
  FOR record_json IN SELECT value FROM jsonb_array_elements(batch_data)
  LOOP
    -- Validate against JSON schema
    IF contracts.validate_json_schema(record_json, contract_rec.json_schema) THEN
      valid_count := valid_count + 1;
    ELSE
      invalid_count := invalid_count + 1;
      
      -- Build violation details
      temp_violations := jsonb_build_object(
        'record', record_json,
        'violations', jsonb_build_array('Schema validation failed'),
        'timestamp', NOW()
      );
      
      violation_details := violation_details || jsonb_build_array(temp_violations);
    END IF;
  END LOOP;
  
  -- Check batch-level constraints
  IF jsonb_array_length(batch_data) < contract_rec.min_rows_per_partition THEN
    violation_details := violation_details || jsonb_build_array(
      jsonb_build_object(
        'violation', 'Insufficient rows in partition',
        'expected_min', contract_rec.min_rows_per_partition,
        'actual', jsonb_array_length(batch_data)
      )
    );
  END IF;
  
  -- Log violations if any
  IF jsonb_array_length(violation_details) > 0 THEN
    INSERT INTO metadata.contract_violations (
      source_name, partition_key, row_count, violations, violation_type, severity
    ) VALUES (
      source_name_param, partition_key_param, 
      jsonb_array_length(batch_data), violation_details,
      'data_quality', 
      CASE WHEN invalid_count::FLOAT / jsonb_array_length(batch_data) > 0.1 THEN 'critical' 
           WHEN invalid_count::FLOAT / jsonb_array_length(batch_data) > 0.05 THEN 'high'
           ELSE 'medium' END
    );
  END IF;
  
  RETURN QUERY SELECT 
    (jsonb_array_length(violation_details) = 0), 
    violation_details,
    valid_count,
    invalid_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- PII DETECTION AND MASKING FUNCTIONS
-- =====================================================================

-- Email masking function
CREATE OR REPLACE FUNCTION quality.mask_email(email_value TEXT) 
RETURNS TEXT AS $$
BEGIN
  IF email_value IS NULL OR email_value = '' THEN
    RETURN email_value;
  END IF;
  
  -- Return first character + **** + @domain
  RETURN LEFT(email_value, 1) || '****@' || SPLIT_PART(email_value, '@', 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Phone masking function
CREATE OR REPLACE FUNCTION quality.mask_phone(phone_value TEXT) 
RETURNS TEXT AS $$
BEGIN
  IF phone_value IS NULL OR phone_value = '' THEN
    RETURN phone_value;
  END IF;
  
  -- Return last 4 digits with XXX-XXX-
  RETURN 'XXX-XXX-' || RIGHT(REGEXP_REPLACE(phone_value, '[^0-9]', '', 'g'), 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- SSN masking function
CREATE OR REPLACE FUNCTION quality.mask_ssn(ssn_value TEXT) 
RETURNS TEXT AS $$
BEGIN
  RETURN 'XXX-XX-XXXX';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Credit card masking function
CREATE OR REPLACE FUNCTION quality.mask_credit_card(cc_value TEXT) 
RETURNS TEXT AS $$
BEGIN
  IF cc_value IS NULL OR cc_value = '' THEN
    RETURN cc_value;
  END IF;
  
  -- Return last 4 digits with XXXX-XXXX-XXXX-
  RETURN 'XXXX-XXXX-XXXX-' || RIGHT(REGEXP_REPLACE(cc_value, '[^0-9]', '', 'g'), 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Generic PII detection function
CREATE OR REPLACE FUNCTION quality.detect_pii_in_text(
  text_value TEXT,
  OUT pii_types TEXT[],
  OUT confidence_scores NUMERIC[]
) AS $$
DECLARE
  rule_rec quality.pii_detection_rules%ROWTYPE;
BEGIN
  pii_types := ARRAY[]::TEXT[];
  confidence_scores := ARRAY[]::NUMERIC[];
  
  -- Skip if text is null or empty
  IF text_value IS NULL OR text_value = '' THEN
    RETURN;
  END IF;
  
  -- Check each PII detection rule
  FOR rule_rec IN SELECT * FROM quality.pii_detection_rules WHERE enabled = TRUE
  LOOP
    IF text_value ~* rule_rec.detection_regex THEN
      pii_types := array_append(pii_types, rule_rec.pii_type);
      confidence_scores := array_append(confidence_scores, rule_rec.confidence_threshold);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Apply masking based on PII type
CREATE OR REPLACE FUNCTION quality.apply_pii_masking(
  text_value TEXT,
  pii_type TEXT
) RETURNS TEXT AS $$
BEGIN
  CASE pii_type
    WHEN 'email' THEN RETURN quality.mask_email(text_value);
    WHEN 'phone' THEN RETURN quality.mask_phone(text_value);
    WHEN 'ssn' THEN RETURN quality.mask_ssn(text_value);
    WHEN 'credit_card' THEN RETURN quality.mask_credit_card(text_value);
    ELSE RETURN '***REDACTED***';
  END CASE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- WATERMARK MANAGEMENT FUNCTIONS
-- =====================================================================

-- Get current watermark for incremental processing
CREATE OR REPLACE FUNCTION metadata.get_watermark(
  source_name_param TEXT,
  table_name_param TEXT,
  watermark_column_param TEXT
) RETURNS TEXT AS $$
DECLARE
  current_watermark TEXT;
BEGIN
  SELECT watermark_value INTO current_watermark
  FROM metadata.watermarks
  WHERE source_name = source_name_param
    AND table_name = table_name_param
    AND watermark_column = watermark_column_param;
    
  RETURN COALESCE(current_watermark, '1970-01-01 00:00:00');
END;
$$ LANGUAGE plpgsql;

-- Update watermark after successful processing
CREATE OR REPLACE FUNCTION metadata.update_watermark(
  source_name_param TEXT,
  table_name_param TEXT,
  watermark_column_param TEXT,
  new_watermark_value TEXT,
  partition_key_param TEXT DEFAULT NULL,
  job_run_id_param UUID DEFAULT NULL,
  rows_processed_param INTEGER DEFAULT 0
) RETURNS VOID AS $$
BEGIN
  INSERT INTO metadata.watermarks (
    source_name, table_name, watermark_column, 
    watermark_value, watermark_timestamp, partition_key,
    job_run_id, rows_processed
  ) VALUES (
    source_name_param, table_name_param, watermark_column_param,
    new_watermark_value, NOW(), partition_key_param,
    job_run_id_param, rows_processed_param
  )
  ON CONFLICT (source_name, table_name, watermark_column)
  DO UPDATE SET
    watermark_value = EXCLUDED.watermark_value,
    watermark_timestamp = EXCLUDED.watermark_timestamp,
    partition_key = EXCLUDED.partition_key,
    job_run_id = EXCLUDED.job_run_id,
    rows_processed = EXCLUDED.rows_processed,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- SLA MONITORING FUNCTIONS
-- =====================================================================

-- Check SLA compliance for a job run
CREATE OR REPLACE FUNCTION metadata.check_sla_compliance(
  job_run_id_param UUID
) RETURNS TABLE (
  sla_name TEXT,
  sla_met BOOLEAN,
  variance_percent NUMERIC,
  breach_severity TEXT
) AS $$
DECLARE
  job_rec metadata.job_runs%ROWTYPE;
  duration_minutes NUMERIC;
  expected_sla_minutes NUMERIC := 60; -- Default 1 hour SLA
BEGIN
  -- Get job details
  SELECT * INTO job_rec FROM metadata.job_runs WHERE id = job_run_id_param;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  -- Calculate actual duration
  IF job_rec.run_ended_at IS NOT NULL THEN
    duration_minutes := EXTRACT(EPOCH FROM (job_rec.run_ended_at - job_rec.run_started_at)) / 60;
  ELSE
    duration_minutes := EXTRACT(EPOCH FROM (NOW() - job_rec.run_started_at)) / 60;
  END IF;
  
  -- Check latency SLA
  RETURN QUERY SELECT 
    'job_completion_time'::TEXT,
    (duration_minutes <= expected_sla_minutes),
    ROUND(((duration_minutes - expected_sla_minutes) / expected_sla_minutes * 100), 2),
    CASE 
      WHEN duration_minutes <= expected_sla_minutes THEN NULL
      WHEN duration_minutes <= expected_sla_minutes * 1.5 THEN 'minor'::TEXT
      WHEN duration_minutes <= expected_sla_minutes * 2 THEN 'major'::TEXT
      ELSE 'critical'::TEXT
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- OPENLINEAGE EVENT HELPERS
-- =====================================================================

-- Emit OpenLineage START event
CREATE OR REPLACE FUNCTION metadata.emit_lineage_start(
  job_name_param TEXT,
  run_id_param UUID,
  inputs_param JSONB DEFAULT NULL,
  producer_param TEXT DEFAULT 'bruno-executor'
) RETURNS UUID AS $$
DECLARE
  event_id UUID;
BEGIN
  INSERT INTO metadata.openlineage_events (
    event_type, run_id, job_name, producer, inputs
  ) VALUES (
    'START', run_id_param, job_name_param, producer_param, inputs_param
  ) RETURNING id INTO event_id;
  
  RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- Emit OpenLineage COMPLETE event
CREATE OR REPLACE FUNCTION metadata.emit_lineage_complete(
  job_name_param TEXT,
  run_id_param UUID,
  inputs_param JSONB DEFAULT NULL,
  outputs_param JSONB DEFAULT NULL,
  facets_param JSONB DEFAULT NULL,
  producer_param TEXT DEFAULT 'bruno-executor'
) RETURNS UUID AS $$
DECLARE
  event_id UUID;
BEGIN
  INSERT INTO metadata.openlineage_events (
    event_type, run_id, job_name, producer, inputs, outputs, facets
  ) VALUES (
    'COMPLETE', run_id_param, job_name_param, producer_param, 
    inputs_param, outputs_param, facets_param
  ) RETURNING id INTO event_id;
  
  RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- Emit OpenLineage FAIL event
CREATE OR REPLACE FUNCTION metadata.emit_lineage_fail(
  job_name_param TEXT,
  run_id_param UUID,
  error_message_param TEXT,
  producer_param TEXT DEFAULT 'bruno-executor'
) RETURNS UUID AS $$
DECLARE
  event_id UUID;
  error_facets JSONB;
BEGIN
  error_facets := jsonb_build_object(
    'errorMessage', jsonb_build_object(
      '_producer', producer_param,
      '_schemaURL', 'https://openlineage.io/spec/facets/1-0-0/ErrorMessageRunFacet.json',
      'message', error_message_param,
      'programmingLanguage', 'SQL'
    )
  );
  
  INSERT INTO metadata.openlineage_events (
    event_type, run_id, job_name, producer, facets
  ) VALUES (
    'FAIL', run_id_param, job_name_param, producer_param, error_facets
  ) RETURNING id INTO event_id;
  
  RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- GRANT PERMISSIONS
-- =====================================================================

-- Grant execute permissions to service role
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA contracts TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA quality TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA metadata TO service_role;

-- Grant select permissions for authenticated users on views
GRANT SELECT ON ALL TABLES IN SCHEMA metadata TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA contracts TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA quality TO authenticated;

-- =====================================================================
-- EXAMPLE USAGE
-- =====================================================================

-- Example: Validate a batch of Azure interactions
/*
SELECT * FROM contracts.validate_bronze_batch(
  'azure.interactions',
  '[
    {
      "InteractionID": "INT001",
      "StoreID": 1,
      "TransactionDate": "2025-01-16T10:30:00Z",
      "Gender": "Male",
      "Age": 25
    },
    {
      "InteractionID": "INT002",
      "StoreID": 2,
      "TransactionDate": "2025-01-16T11:00:00Z",
      "Gender": "Female"
    }
  ]'::JSONB,
  '2025-01-16'
);
*/

-- Example: Detect PII in text
/*
SELECT * FROM quality.detect_pii_in_text('Contact John Doe at john.doe@example.com or 555-123-4567');
*/

-- Example: Update watermark after processing
/*
SELECT metadata.update_watermark(
  'azure.interactions',
  'interactions',
  'TransactionDate',
  '2025-01-16 12:00:00',
  '2025-01-16',
  gen_random_uuid(),
  1500
);
*/