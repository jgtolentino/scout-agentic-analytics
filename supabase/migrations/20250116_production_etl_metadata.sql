-- Production-Grade ETL Metadata Framework
-- OpenLineage standard compliance with data contracts and quality gates
-- Bruno-executed, deterministic ETL operations

-- Create schemas
CREATE SCHEMA IF NOT EXISTS metadata;
CREATE SCHEMA IF NOT EXISTS contracts;
CREATE SCHEMA IF NOT EXISTS quality;

-- =====================================================================
-- JOB RUNS - Track all pipeline executions
-- =====================================================================
CREATE TABLE IF NOT EXISTS metadata.job_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name TEXT NOT NULL,
  run_id UUID NOT NULL, -- Temporal workflow run ID
  run_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  run_ended_at TIMESTAMPTZ,
  status TEXT CHECK (status IN ('running', 'success', 'failed', 'cancelled')) NOT NULL DEFAULT 'running',
  
  -- Partition and execution context
  input_partition TEXT,
  output_partition TEXT,
  executor TEXT NOT NULL DEFAULT 'bruno', -- bruno, temporal, dbt
  
  -- Performance metrics
  duration_ms INTEGER,
  records_processed INTEGER DEFAULT 0,
  records_inserted INTEGER DEFAULT 0,
  records_updated INTEGER DEFAULT 0,
  records_failed INTEGER DEFAULT 0,
  
  -- Error handling
  error_json JSONB,
  retry_count INTEGER DEFAULT 0,
  
  -- Lineage tracking
  parent_run_id UUID REFERENCES metadata.job_runs(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- DATA CONTRACTS - JSON Schema validation
-- =====================================================================
CREATE TABLE IF NOT EXISTS contracts.sources (
  source_name TEXT PRIMARY KEY,
  json_schema JSONB NOT NULL,
  owner TEXT NOT NULL,
  sla_minutes INTEGER NOT NULL DEFAULT 60,
  pii BOOLEAN NOT NULL DEFAULT false,
  
  -- Contract versioning
  version TEXT NOT NULL DEFAULT '1.0.0',
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ,
  
  -- Quality requirements
  min_rows_per_partition INTEGER DEFAULT 0,
  max_null_percentage NUMERIC(5,2) DEFAULT 100.0,
  required_columns TEXT[] NOT NULL DEFAULT '{}',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Contract violations tracking
CREATE TABLE IF NOT EXISTS metadata.contract_violations (
  id BIGSERIAL PRIMARY KEY,
  source_name TEXT REFERENCES contracts.sources(source_name),
  observed_at TIMESTAMPTZ DEFAULT NOW(),
  partition_key TEXT,
  row_count INTEGER,
  violations JSONB NOT NULL, -- Great Expectations or custom validation report
  
  -- Violation details
  violation_type TEXT NOT NULL, -- 'schema', 'data_quality', 'business_rule', 'sla'
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) NOT NULL DEFAULT 'medium',
  
  -- Resolution tracking
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- QUALITY METRICS - Comprehensive data quality tracking
-- =====================================================================
CREATE TABLE IF NOT EXISTS metadata.quality_metrics (
  id BIGSERIAL PRIMARY KEY,
  job_run_id UUID REFERENCES metadata.job_runs(id),
  
  -- Dataset identification
  dataset TEXT NOT NULL,
  layer TEXT CHECK (layer IN ('bronze', 'silver', 'gold', 'platinum')) NOT NULL,
  partition_key TEXT,
  
  -- Metric details
  metric_name TEXT NOT NULL,
  metric_value NUMERIC NOT NULL,
  metric_unit TEXT, -- 'percentage', 'count', 'seconds', 'bytes'
  
  -- Quality dimensions
  dimension TEXT CHECK (dimension IN ('completeness', 'uniqueness', 'validity', 'consistency', 'accuracy', 'timeliness')) NOT NULL,
  
  -- Measurement context
  measured_at TIMESTAMPTZ DEFAULT NOW(),
  measurement_sql TEXT, -- SQL used to calculate metric
  
  -- Thresholds and SLA
  threshold_value NUMERIC,
  threshold_operator TEXT CHECK (threshold_operator IN ('>', '>=', '<', '<=', '=', '!=')),
  sla_met BOOLEAN,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- OPENLINEAGE EVENTS - Standardized lineage tracking
-- =====================================================================
CREATE TABLE IF NOT EXISTS metadata.openlineage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- OpenLineage core fields
  event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  event_type TEXT CHECK (event_type IN ('START', 'COMPLETE', 'FAIL', 'ABORT')) NOT NULL,
  
  -- Run context
  run_id UUID NOT NULL,
  job_name TEXT NOT NULL,
  job_namespace TEXT NOT NULL DEFAULT 'scout_analytics',
  
  -- Producer information
  producer TEXT NOT NULL DEFAULT 'bruno-executor',
  schema_url TEXT DEFAULT 'https://openlineage.io/spec/1-0-5/OpenLineage.json',
  
  -- Inputs and outputs
  inputs JSONB, -- Array of input datasets with schemas
  outputs JSONB, -- Array of output datasets with schemas
  
  -- Facets (metadata)
  facets JSONB, -- Additional metadata (ownership, documentation, etc.)
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- SLA MONITORING - Track performance against defined SLAs
-- =====================================================================
CREATE TABLE IF NOT EXISTS metadata.sla_monitoring (
  id BIGSERIAL PRIMARY KEY,
  job_run_id UUID REFERENCES metadata.job_runs(id),
  
  -- SLA definition
  sla_name TEXT NOT NULL,
  sla_type TEXT CHECK (sla_type IN ('latency', 'throughput', 'quality', 'availability', 'freshness')) NOT NULL,
  
  -- Target and actual values
  target_value NUMERIC NOT NULL,
  target_unit TEXT NOT NULL, -- 'minutes', 'hours', 'records_per_hour', 'percentage'
  actual_value NUMERIC NOT NULL,
  actual_unit TEXT NOT NULL,
  
  -- SLA status
  sla_met BOOLEAN NOT NULL,
  variance_percent NUMERIC(8,2),
  
  -- Breach handling
  breach_severity TEXT CHECK (breach_severity IN ('minor', 'major', 'critical')),
  notification_sent BOOLEAN DEFAULT FALSE,
  escalation_level INTEGER DEFAULT 0,
  
  -- Error budget tracking
  error_budget_consumed NUMERIC(5,2), -- Percentage of monthly error budget consumed
  
  measured_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- WATERMARKS - Track incremental processing state
-- =====================================================================
CREATE TABLE IF NOT EXISTS metadata.watermarks (
  source_name TEXT NOT NULL,
  table_name TEXT NOT NULL,
  watermark_column TEXT NOT NULL,
  watermark_value TEXT NOT NULL, -- Store as text to handle various data types
  watermark_timestamp TIMESTAMPTZ NOT NULL,
  
  -- Partition information
  partition_key TEXT,
  
  -- Processing metadata
  job_run_id UUID REFERENCES metadata.job_runs(id),
  rows_processed INTEGER DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  PRIMARY KEY (source_name, table_name, watermark_column)
);

-- =====================================================================
-- MEDALLION HEALTH - Overall pipeline health monitoring
-- =====================================================================
CREATE TABLE IF NOT EXISTS metadata.medallion_health (
  id BIGSERIAL PRIMARY KEY,
  
  -- Health check scope
  layer TEXT CHECK (layer IN ('bronze', 'silver', 'gold', 'platinum')) NOT NULL,
  check_timestamp TIMESTAMPTZ DEFAULT NOW(),
  
  -- Table counts
  total_tables INTEGER NOT NULL,
  healthy_tables INTEGER NOT NULL,
  unhealthy_tables INTEGER NOT NULL,
  
  -- Quality metrics
  avg_quality_score NUMERIC(5,2),
  min_quality_score NUMERIC(5,2),
  max_quality_score NUMERIC(5,2),
  
  -- Performance metrics
  avg_latency_minutes NUMERIC(8,2),
  max_latency_minutes NUMERIC(8,2),
  p95_latency_minutes NUMERIC(8,2),
  
  -- Error tracking
  error_count INTEGER DEFAULT 0,
  critical_errors INTEGER DEFAULT 0,
  sla_breaches INTEGER DEFAULT 0,
  
  -- Overall health assessment
  health_status TEXT CHECK (health_status IN ('healthy', 'warning', 'critical', 'down')) NOT NULL,
  health_score NUMERIC(5,2), -- 0-100 overall health score
  
  -- Recommendations and actions
  recommendations TEXT[],
  action_required BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- PII DETECTION & MASKING - Security and compliance
-- =====================================================================
CREATE TABLE IF NOT EXISTS quality.pii_detection_rules (
  id BIGSERIAL PRIMARY KEY,
  rule_name TEXT UNIQUE NOT NULL,
  pii_type TEXT NOT NULL, -- 'email', 'phone', 'ssn', 'credit_card', 'name', 'address'
  detection_regex TEXT NOT NULL,
  confidence_threshold NUMERIC(3,2) DEFAULT 0.8,
  
  -- Masking configuration
  masking_function TEXT NOT NULL, -- SQL function name for masking
  masking_strategy TEXT CHECK (masking_strategy IN ('hash', 'redact', 'partial', 'tokenize')) NOT NULL,
  
  enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert common PII detection rules
INSERT INTO quality.pii_detection_rules (rule_name, pii_type, detection_regex, masking_function, masking_strategy) VALUES
  ('email_detection', 'email', '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', 'mask_email', 'partial'),
  ('phone_detection', 'phone', '^\+?1?[-.\s]?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})$', 'mask_phone', 'partial'),
  ('ssn_detection', 'ssn', '^\d{3}-?\d{2}-?\d{4}$', 'mask_ssn', 'redact'),
  ('credit_card_detection', 'credit_card', '^\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}$', 'mask_credit_card', 'partial')
ON CONFLICT (rule_name) DO NOTHING;

-- =====================================================================
-- INDEXES for performance
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_job_runs_status ON metadata.job_runs(status);
CREATE INDEX IF NOT EXISTS idx_job_runs_job_name ON metadata.job_runs(job_name);
CREATE INDEX IF NOT EXISTS idx_job_runs_started_at ON metadata.job_runs(run_started_at);
CREATE INDEX IF NOT EXISTS idx_job_runs_run_id ON metadata.job_runs(run_id);

CREATE INDEX IF NOT EXISTS idx_contract_violations_source ON metadata.contract_violations(source_name);
CREATE INDEX IF NOT EXISTS idx_contract_violations_severity ON metadata.contract_violations(severity);
CREATE INDEX IF NOT EXISTS idx_contract_violations_unresolved ON metadata.contract_violations(resolved) WHERE NOT resolved;

CREATE INDEX IF NOT EXISTS idx_quality_metrics_dataset ON metadata.quality_metrics(dataset, layer);
CREATE INDEX IF NOT EXISTS idx_quality_metrics_measured_at ON metadata.quality_metrics(measured_at);
CREATE INDEX IF NOT EXISTS idx_quality_metrics_sla_breaches ON metadata.quality_metrics(sla_met) WHERE NOT sla_met;

CREATE INDEX IF NOT EXISTS idx_openlineage_events_run_id ON metadata.openlineage_events(run_id);
CREATE INDEX IF NOT EXISTS idx_openlineage_events_job_name ON metadata.openlineage_events(job_name);
CREATE INDEX IF NOT EXISTS idx_openlineage_events_event_time ON metadata.openlineage_events(event_time);

CREATE INDEX IF NOT EXISTS idx_watermarks_source_table ON metadata.watermarks(source_name, table_name);
CREATE INDEX IF NOT EXISTS idx_watermarks_updated_at ON metadata.watermarks(updated_at);

-- =====================================================================
-- VIEWS for monitoring and reporting
-- =====================================================================

-- Pipeline health dashboard
CREATE OR REPLACE VIEW metadata.v_pipeline_health AS
SELECT 
  layer,
  COUNT(*) as total_jobs_24h,
  COUNT(*) FILTER (WHERE status = 'success') as successful_jobs,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_jobs,
  COUNT(*) FILTER (WHERE status = 'running') as running_jobs,
  ROUND(AVG(duration_ms::numeric / 1000), 2) as avg_duration_seconds,
  ROUND(AVG(EXTRACT(EPOCH FROM (run_ended_at - run_started_at))), 2) as avg_total_time_seconds,
  MAX(run_started_at) as last_run_time,
  
  -- SLA metrics
  COUNT(*) FILTER (WHERE run_ended_at IS NOT NULL AND run_ended_at <= run_started_at + INTERVAL '1 hour') as on_time_jobs,
  ROUND(
    COUNT(*) FILTER (WHERE run_ended_at IS NOT NULL AND run_ended_at <= run_started_at + INTERVAL '1 hour')::numeric 
    / NULLIF(COUNT(*) FILTER (WHERE run_ended_at IS NOT NULL), 0) * 100, 
    2
  ) as sla_percentage
FROM metadata.job_runs
WHERE run_started_at >= NOW() - INTERVAL '24 hours'
GROUP BY layer
ORDER BY 
  CASE layer
    WHEN 'bronze' THEN 1
    WHEN 'silver' THEN 2
    WHEN 'gold' THEN 3
    WHEN 'platinum' THEN 4
  END;

-- Data quality dashboard
CREATE OR REPLACE VIEW metadata.v_data_quality_dashboard AS
WITH latest_metrics AS (
  SELECT DISTINCT ON (dataset, layer, metric_name)
    dataset,
    layer,
    metric_name,
    metric_value,
    dimension,
    sla_met,
    measured_at
  FROM metadata.quality_metrics
  WHERE measured_at >= NOW() - INTERVAL '24 hours'
  ORDER BY dataset, layer, metric_name, measured_at DESC
)
SELECT 
  dataset,
  layer,
  COUNT(*) as total_metrics,
  COUNT(*) FILTER (WHERE sla_met = true) as passing_metrics,
  COUNT(*) FILTER (WHERE sla_met = false) as failing_metrics,
  ROUND(AVG(metric_value), 2) as avg_quality_score,
  MIN(metric_value) as min_quality_score,
  MAX(metric_value) as max_quality_score,
  MAX(measured_at) as last_measured
FROM latest_metrics
GROUP BY dataset, layer
ORDER BY failing_metrics DESC, avg_quality_score ASC;

-- Error summary view
CREATE OR REPLACE VIEW metadata.v_error_summary AS
SELECT 
  violation_type,
  severity,
  COUNT(*) as violation_count,
  COUNT(DISTINCT source_name) as affected_sources,
  SUM(row_count) as total_affected_records,
  MAX(observed_at) as latest_violation,
  COUNT(*) FILTER (WHERE NOT resolved) as unresolved_count
FROM metadata.contract_violations
WHERE observed_at >= NOW() - INTERVAL '24 hours'
GROUP BY violation_type, severity
ORDER BY 
  CASE severity 
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
  END,
  violation_count DESC;

-- Freshness monitoring
CREATE OR REPLACE VIEW metadata.v_data_freshness AS
SELECT 
  w.source_name,
  w.table_name,
  w.watermark_timestamp,
  EXTRACT(EPOCH FROM (NOW() - w.watermark_timestamp)) / 60 as staleness_minutes,
  cs.sla_minutes,
  CASE 
    WHEN EXTRACT(EPOCH FROM (NOW() - w.watermark_timestamp)) / 60 <= cs.sla_minutes THEN 'fresh'
    WHEN EXTRACT(EPOCH FROM (NOW() - w.watermark_timestamp)) / 60 <= cs.sla_minutes * 2 THEN 'warning'
    ELSE 'stale'
  END as freshness_status,
  w.rows_processed,
  w.updated_at
FROM metadata.watermarks w
LEFT JOIN contracts.sources cs ON w.source_name = cs.source_name
ORDER BY staleness_minutes DESC;

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
ALTER TABLE metadata.job_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracts.sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.contract_violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.quality_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.openlineage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.sla_monitoring ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.watermarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.medallion_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE quality.pii_detection_rules ENABLE ROW LEVEL SECURITY;

-- Policies for service role (ETL processes)
CREATE POLICY "Service role full access" ON metadata.job_runs FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON contracts.sources FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.contract_violations FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.quality_metrics FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.openlineage_events FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.sla_monitoring FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.watermarks FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.medallion_health FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON quality.pii_detection_rules FOR ALL TO service_role USING (true);

-- Policies for authenticated users (read-only)
CREATE POLICY "Authenticated read access" ON metadata.job_runs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON contracts.sources FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.contract_violations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.quality_metrics FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.openlineage_events FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.sla_monitoring FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.watermarks FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.medallion_health FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON quality.pii_detection_rules FOR SELECT TO authenticated USING (true);

-- =====================================================================
-- INITIALIZE with Azure interactions contract
-- =====================================================================
INSERT INTO contracts.sources (
  source_name,
  json_schema,
  owner,
  sla_minutes,
  pii,
  version,
  required_columns
) VALUES (
  'azure.interactions',
  '{
    "type": "object",
    "required": ["InteractionID", "StoreID", "TransactionDate"],
    "properties": {
      "InteractionID": {"type": "string"},
      "StoreID": {"type": "integer", "minimum": 1},
      "StoreName": {"type": "string"},
      "StoreLocation": {"type": "string"},
      "ProductID": {"type": "integer", "minimum": 1},
      "TransactionDate": {"type": "string", "format": "date-time"},
      "DeviceID": {"type": "string"},
      "FacialID": {"type": "string"},
      "Sex": {"type": "string", "enum": ["M", "F", "Male", "Female"]},
      "Age": {"type": "integer", "minimum": 0, "maximum": 120},
      "EmotionalState": {"type": "string"},
      "TranscriptionText": {"type": "string"},
      "Gender": {"type": "string", "enum": ["Male", "Female", "Unknown"]},
      "BarangayID": {"type": "integer"},
      "BarangayName": {"type": "string"},
      "MunicipalityName": {"type": "string"},
      "ProvinceName": {"type": "string"},
      "RegionName": {"type": "string"}
    }
  }'::jsonb,
  'data@insightpulse.ai',
  15, -- 15 minute SLA for Azure data
  true, -- Contains PII (FacialID, Age, Gender, etc.)
  '1.0.0',
  ARRAY['InteractionID', 'StoreID', 'TransactionDate']
) ON CONFLICT (source_name) DO UPDATE SET 
  json_schema = EXCLUDED.json_schema,
  updated_at = NOW();

-- Initialize medallion health baseline
INSERT INTO metadata.medallion_health (
  layer,
  total_tables,
  healthy_tables,
  unhealthy_tables,
  avg_quality_score,
  health_status,
  health_score
) VALUES 
  ('bronze', 6, 6, 0, 95.0, 'healthy', 95.0),
  ('silver', 5, 5, 0, 92.0, 'healthy', 92.0),
  ('gold', 71, 71, 0, 88.0, 'healthy', 88.0),
  ('platinum', 14, 14, 0, 85.0, 'healthy', 85.0)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- COMMENTS for documentation
-- =====================================================================
COMMENT ON SCHEMA metadata IS 'Production-grade ETL metadata with OpenLineage compliance for Bruno-executed workflows';
COMMENT ON SCHEMA contracts IS 'Data contracts with JSON Schema validation and SLA definitions';
COMMENT ON SCHEMA quality IS 'Data quality rules, PII detection, and compliance frameworks';

COMMENT ON TABLE metadata.job_runs IS 'Track all ETL job executions with Temporal workflow integration';
COMMENT ON TABLE contracts.sources IS 'Data contracts with JSON Schema validation and quality requirements';
COMMENT ON TABLE metadata.contract_violations IS 'Log contract violations with severity and resolution tracking';
COMMENT ON TABLE metadata.quality_metrics IS 'Comprehensive data quality metrics with SLA monitoring';
COMMENT ON TABLE metadata.openlineage_events IS 'OpenLineage standard events for data lineage tracking';
COMMENT ON TABLE metadata.sla_monitoring IS 'SLA performance tracking with error budget management';
COMMENT ON TABLE metadata.watermarks IS 'Incremental processing state for CDC and batch operations';
COMMENT ON TABLE quality.pii_detection_rules IS 'PII detection rules with masking strategies for compliance';