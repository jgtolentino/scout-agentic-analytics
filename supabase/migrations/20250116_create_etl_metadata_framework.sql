-- ETL Metadata Framework for SuperClaude Automated Pipeline
-- Comprehensive audit, lineage, and quality control system
-- Phase 1: Foundation Layer

-- Create metadata schema for ETL framework
CREATE SCHEMA IF NOT EXISTS metadata;

-- ETL Job Runs - Track all pipeline executions
CREATE TABLE IF NOT EXISTS metadata.etl_job_runs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_name TEXT NOT NULL,
  job_type TEXT NOT NULL, -- 'ingestion', 'transformation', 'analytics', 'ml'
  layer TEXT NOT NULL CHECK (layer IN ('bronze', 'silver', 'gold', 'platinum')),
  source_system TEXT NOT NULL,
  target_table TEXT NOT NULL,
  agent_name TEXT NOT NULL, -- SuperClaude agent responsible
  agent_persona TEXT NOT NULL, -- Persona configuration used
  mcp_servers TEXT[], -- MCP servers utilized
  
  -- Execution details
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed', 'cancelled')),
  records_processed INTEGER DEFAULT 0,
  records_inserted INTEGER DEFAULT 0,
  records_updated INTEGER DEFAULT 0,
  records_failed INTEGER DEFAULT 0,
  
  -- Performance metrics
  duration_ms INTEGER,
  memory_usage_mb NUMERIC(10,2),
  cpu_usage_percent NUMERIC(5,2),
  
  -- Error handling
  error_message TEXT,
  error_code TEXT,
  retry_count INTEGER DEFAULT 0,
  
  -- Quality metrics
  quality_score NUMERIC(5,2),
  validation_results JSONB,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Data Lineage - Track data flow across the medallion architecture
CREATE TABLE IF NOT EXISTS metadata.data_lineage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_run_id UUID REFERENCES metadata.etl_job_runs(id),
  
  -- Source information
  source_schema TEXT NOT NULL,
  source_table TEXT NOT NULL,
  source_columns TEXT[],
  source_row_count INTEGER,
  source_min_timestamp TIMESTAMP,
  source_max_timestamp TIMESTAMP,
  
  -- Target information
  target_schema TEXT NOT NULL,
  target_table TEXT NOT NULL,
  target_columns TEXT[],
  target_row_count INTEGER,
  
  -- Transformation details
  transformation_type TEXT NOT NULL, -- 'extract', 'cleanse', 'aggregate', 'enrich', 'predict'
  transformation_logic TEXT,
  business_rules TEXT[],
  
  -- Data quality
  data_drift_score NUMERIC(5,2),
  schema_changes JSONB,
  anomalies_detected JSONB,
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- Quality Metrics - Track data quality across all layers
CREATE TABLE IF NOT EXISTS metadata.quality_metrics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_run_id UUID REFERENCES metadata.etl_job_runs(id),
  table_schema TEXT NOT NULL,
  table_name TEXT NOT NULL,
  
  -- Completeness metrics
  total_records INTEGER NOT NULL,
  null_count INTEGER DEFAULT 0,
  completeness_score NUMERIC(5,2),
  
  -- Uniqueness metrics
  duplicate_count INTEGER DEFAULT 0,
  uniqueness_score NUMERIC(5,2),
  
  -- Validity metrics
  invalid_records INTEGER DEFAULT 0,
  validity_score NUMERIC(5,2),
  
  -- Consistency metrics
  consistency_score NUMERIC(5,2),
  consistency_issues JSONB,
  
  -- Timeliness metrics
  freshness_hours NUMERIC(8,2),
  latency_minutes NUMERIC(8,2),
  
  -- Overall quality
  overall_quality_score NUMERIC(5,2),
  quality_grade TEXT CHECK (quality_grade IN ('A', 'B', 'C', 'D', 'F')),
  
  -- Quality rules applied
  rules_checked TEXT[],
  rules_passed INTEGER DEFAULT 0,
  rules_failed INTEGER DEFAULT 0,
  
  measured_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Error Log - Comprehensive error tracking and categorization
CREATE TABLE IF NOT EXISTS metadata.error_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_run_id UUID REFERENCES metadata.etl_job_runs(id),
  
  -- Error classification
  error_type TEXT NOT NULL, -- 'schema', 'data', 'connection', 'business_rule', 'system'
  severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  error_code TEXT,
  error_message TEXT NOT NULL,
  
  -- Context information
  source_system TEXT,
  table_name TEXT,
  column_name TEXT,
  record_id TEXT,
  affected_records INTEGER DEFAULT 1,
  
  -- Error details
  stack_trace TEXT,
  sql_query TEXT,
  input_data JSONB,
  
  -- Resolution tracking
  resolution_status TEXT DEFAULT 'open' CHECK (resolution_status IN ('open', 'investigating', 'resolved', 'ignored')),
  resolution_notes TEXT,
  resolved_by TEXT,
  resolved_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- SLA Monitoring - Track pipeline performance against SLAs
CREATE TABLE IF NOT EXISTS metadata.sla_monitoring (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_run_id UUID REFERENCES metadata.etl_job_runs(id),
  
  -- SLA definition
  sla_name TEXT NOT NULL,
  sla_type TEXT NOT NULL, -- 'latency', 'throughput', 'quality', 'availability'
  target_value NUMERIC(10,2) NOT NULL,
  target_unit TEXT NOT NULL, -- 'minutes', 'hours', 'records_per_hour', 'percentage'
  
  -- Actual performance
  actual_value NUMERIC(10,2) NOT NULL,
  actual_unit TEXT NOT NULL,
  
  -- SLA status
  sla_met BOOLEAN NOT NULL,
  variance_percent NUMERIC(8,2),
  
  -- Breach handling
  breach_severity TEXT CHECK (breach_severity IN ('minor', 'major', 'critical')),
  notification_sent BOOLEAN DEFAULT FALSE,
  escalation_level INTEGER DEFAULT 0,
  
  measured_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Agent Orchestration - Track SuperClaude agent coordination
CREATE TABLE IF NOT EXISTS metadata.agent_orchestration (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  parent_job_run_id UUID REFERENCES metadata.etl_job_runs(id),
  
  -- Agent hierarchy
  parent_agent TEXT,
  child_agent TEXT NOT NULL,
  agent_type TEXT NOT NULL, -- 'orchestrator', 'ingestion', 'transformation', 'analytics', 'ml', 'quality', 'audit'
  
  -- Execution context
  persona_config TEXT NOT NULL,
  mcp_servers TEXT[],
  flags_used TEXT[],
  tools_used TEXT[],
  
  -- Coordination details
  spawn_reason TEXT,
  delegation_strategy TEXT, -- 'parallel_dirs', 'parallel_focus', 'sequential', 'adaptive'
  dependencies TEXT[],
  
  -- Performance
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  duration_ms INTEGER,
  
  -- Results
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed', 'cancelled')),
  output_summary TEXT,
  tokens_used INTEGER,
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- Data Contracts - Define expected data structures and quality standards
CREATE TABLE IF NOT EXISTS metadata.data_contracts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Contract identification
  contract_name TEXT NOT NULL UNIQUE,
  version TEXT NOT NULL,
  table_schema TEXT NOT NULL,
  table_name TEXT NOT NULL,
  
  -- Schema definition
  expected_columns JSONB NOT NULL, -- {"column_name": {"type": "text", "nullable": false, "constraints": []}}
  primary_keys TEXT[] NOT NULL,
  foreign_keys JSONB, -- {"column": "referenced_table.column"}
  
  -- Data quality requirements
  min_row_count INTEGER DEFAULT 0,
  max_null_percentage NUMERIC(5,2) DEFAULT 100,
  uniqueness_constraints TEXT[],
  value_constraints JSONB, -- {"column": {"min": 0, "max": 100, "allowed_values": []}}
  
  -- Business rules
  business_rules TEXT[],
  validation_queries TEXT[],
  
  -- SLA requirements
  max_latency_hours INTEGER DEFAULT 24,
  min_quality_score NUMERIC(5,2) DEFAULT 80,
  
  -- Lifecycle
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft', 'active', 'deprecated')),
  created_by TEXT NOT NULL,
  approved_by TEXT,
  approved_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Medallion Health - Monitor overall pipeline health
CREATE TABLE IF NOT EXISTS metadata.medallion_health (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Health check details
  layer TEXT NOT NULL CHECK (layer IN ('bronze', 'silver', 'gold', 'platinum')),
  table_count INTEGER NOT NULL,
  healthy_tables INTEGER NOT NULL,
  unhealthy_tables INTEGER NOT NULL,
  
  -- Quality metrics
  avg_quality_score NUMERIC(5,2),
  min_quality_score NUMERIC(5,2),
  max_quality_score NUMERIC(5,2),
  
  -- Performance metrics
  avg_latency_minutes NUMERIC(8,2),
  max_latency_minutes NUMERIC(8,2),
  
  -- Error metrics
  error_count INTEGER DEFAULT 0,
  critical_errors INTEGER DEFAULT 0,
  
  -- Overall health
  health_status TEXT NOT NULL CHECK (health_status IN ('healthy', 'warning', 'critical', 'down')),
  health_score NUMERIC(5,2),
  
  -- Recommendations
  recommendations TEXT[],
  action_required BOOLEAN DEFAULT FALSE,
  
  checked_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_etl_job_runs_status ON metadata.etl_job_runs(status);
CREATE INDEX IF NOT EXISTS idx_etl_job_runs_layer ON metadata.etl_job_runs(layer);
CREATE INDEX IF NOT EXISTS idx_etl_job_runs_started_at ON metadata.etl_job_runs(started_at);
CREATE INDEX IF NOT EXISTS idx_data_lineage_job_run_id ON metadata.data_lineage(job_run_id);
CREATE INDEX IF NOT EXISTS idx_quality_metrics_job_run_id ON metadata.quality_metrics(job_run_id);
CREATE INDEX IF NOT EXISTS idx_quality_metrics_table ON metadata.quality_metrics(table_schema, table_name);
CREATE INDEX IF NOT EXISTS idx_error_log_severity ON metadata.error_log(severity);
CREATE INDEX IF NOT EXISTS idx_error_log_type ON metadata.error_log(error_type);
CREATE INDEX IF NOT EXISTS idx_sla_monitoring_sla_met ON metadata.sla_monitoring(sla_met);
CREATE INDEX IF NOT EXISTS idx_agent_orchestration_parent ON metadata.agent_orchestration(parent_job_run_id);

-- Views for monitoring and reporting
CREATE OR REPLACE VIEW metadata.v_pipeline_health AS
SELECT 
  layer,
  COUNT(*) as total_jobs,
  COUNT(*) FILTER (WHERE status = 'completed') as completed_jobs,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_jobs,
  COUNT(*) FILTER (WHERE status = 'running') as running_jobs,
  AVG(duration_ms) as avg_duration_ms,
  AVG(quality_score) as avg_quality_score,
  MAX(started_at) as last_run_time
FROM metadata.etl_job_runs
WHERE started_at >= NOW() - INTERVAL '24 hours'
GROUP BY layer
ORDER BY 
  CASE layer
    WHEN 'bronze' THEN 1
    WHEN 'silver' THEN 2
    WHEN 'gold' THEN 3
    WHEN 'platinum' THEN 4
  END;

CREATE OR REPLACE VIEW metadata.v_data_quality_dashboard AS
SELECT 
  qm.table_schema,
  qm.table_name,
  qm.overall_quality_score,
  qm.quality_grade,
  qm.completeness_score,
  qm.uniqueness_score,
  qm.validity_score,
  qm.consistency_score,
  qm.freshness_hours,
  qm.total_records,
  ejr.layer,
  qm.measured_at
FROM metadata.quality_metrics qm
JOIN metadata.etl_job_runs ejr ON qm.job_run_id = ejr.id
WHERE qm.measured_at >= NOW() - INTERVAL '24 hours'
ORDER BY qm.overall_quality_score ASC, qm.measured_at DESC;

CREATE OR REPLACE VIEW metadata.v_error_summary AS
SELECT 
  error_type,
  severity,
  COUNT(*) as error_count,
  COUNT(DISTINCT job_run_id) as affected_jobs,
  SUM(affected_records) as total_affected_records,
  MAX(created_at) as latest_error
FROM metadata.error_log
WHERE created_at >= NOW() - INTERVAL '24 hours'
  AND resolution_status = 'open'
GROUP BY error_type, severity
ORDER BY 
  CASE severity 
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
  END,
  error_count DESC;

-- Row Level Security
ALTER TABLE metadata.etl_job_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.data_lineage ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.quality_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.error_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.sla_monitoring ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.agent_orchestration ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.data_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE metadata.medallion_health ENABLE ROW LEVEL SECURITY;

-- Policies for service role (ETL processes)
CREATE POLICY "Service role full access" ON metadata.etl_job_runs FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.data_lineage FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.quality_metrics FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.error_log FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.sla_monitoring FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.agent_orchestration FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.data_contracts FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access" ON metadata.medallion_health FOR ALL TO service_role USING (true);

-- Policies for authenticated users (read-only)
CREATE POLICY "Authenticated read access" ON metadata.etl_job_runs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.data_lineage FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.quality_metrics FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.error_log FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.sla_monitoring FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.agent_orchestration FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.data_contracts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read access" ON metadata.medallion_health FOR SELECT TO authenticated USING (true);

-- Initialize data contracts for Azure interactions table
INSERT INTO metadata.data_contracts (
  contract_name,
  version,
  table_schema,
  table_name,
  expected_columns,
  primary_keys,
  min_row_count,
  max_null_percentage,
  max_latency_hours,
  min_quality_score,
  status,
  created_by
) VALUES (
  'azure_interactions_v1',
  '1.0.0',
  'azure_data',
  'interactions',
  '{
    "InteractionID": {"type": "text", "nullable": true},
    "StoreID": {"type": "integer", "nullable": true},
    "StoreName": {"type": "text", "nullable": true},
    "StoreLocation": {"type": "text", "nullable": true},
    "ProductID": {"type": "integer", "nullable": true},
    "TransactionDate": {"type": "timestamp", "nullable": true},
    "DeviceID": {"type": "text", "nullable": true},
    "FacialID": {"type": "text", "nullable": true},
    "Sex": {"type": "text", "nullable": true},
    "Age": {"type": "integer", "nullable": true},
    "EmotionalState": {"type": "text", "nullable": true},
    "TranscriptionText": {"type": "text", "nullable": true},
    "Gender": {"type": "text", "nullable": true},
    "BarangayID": {"type": "integer", "nullable": true},
    "BarangayName": {"type": "text", "nullable": true},
    "MunicipalityName": {"type": "text", "nullable": true},
    "ProvinceName": {"type": "text", "nullable": true},
    "RegionName": {"type": "text", "nullable": true}
  }'::jsonb,
  ARRAY['InteractionID'],
  160000,
  20.0,
  1,
  90.0,
  'active',
  'SuperClaude ETL Framework'
);

-- Add initial medallion health check
INSERT INTO metadata.medallion_health (
  layer,
  table_count,
  healthy_tables,
  unhealthy_tables,
  avg_quality_score,
  health_status,
  health_score
) VALUES 
  ('bronze', 6, 6, 0, 95.0, 'healthy', 95.0),
  ('silver', 5, 5, 0, 92.0, 'healthy', 92.0),
  ('gold', 71, 71, 0, 88.0, 'healthy', 88.0),
  ('platinum', 14, 14, 0, 85.0, 'healthy', 85.0);

-- Add comment documentation
COMMENT ON SCHEMA metadata IS 'ETL metadata framework for SuperClaude automated pipeline with comprehensive audit, lineage, and quality control';
COMMENT ON TABLE metadata.etl_job_runs IS 'Track all ETL pipeline executions with performance metrics and agent details';
COMMENT ON TABLE metadata.data_lineage IS 'Track data flow and transformations across the medallion architecture';
COMMENT ON TABLE metadata.quality_metrics IS 'Comprehensive data quality metrics for all layers';
COMMENT ON TABLE metadata.error_log IS 'Centralized error tracking with categorization and resolution management';
COMMENT ON TABLE metadata.sla_monitoring IS 'Monitor pipeline performance against defined SLAs';
COMMENT ON TABLE metadata.agent_orchestration IS 'Track SuperClaude agent coordination and delegation';
COMMENT ON TABLE metadata.data_contracts IS 'Define expected data structures and quality standards';
COMMENT ON TABLE metadata.medallion_health IS 'Monitor overall pipeline health across all layers';