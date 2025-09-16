-- Drive Intelligence Schema Deployment Migration
-- Deploy comprehensive Google Drive ETL and intelligence platform
-- Date: 2025-09-16
-- Purpose: Production deployment of TBWA Scout Drive Intelligence Platform

BEGIN;

-- Apply the comprehensive Drive Intelligence schema
\i /Users/tbwa/scout-v7/etl/schemas/comprehensive_drive_schema.sql

-- Create migration log entry
INSERT INTO metadata.migration_log (
    migration_id,
    migration_name,
    migration_type,
    description,
    status,
    executed_at
) VALUES (
    '20250916_drive_intelligence_deployment',
    'Drive Intelligence Platform Deployment',
    'schema_deployment',
    'Comprehensive Google Drive ETL and Intelligence Platform supporting Creative Intelligence, Financial Analysis, Research Intelligence, and Document Management for TBWA Scout Analytics',
    'applied',
    NOW()
);

-- Insert initial drive intelligence job configuration
INSERT INTO drive_intelligence.etl_job_registry (
    job_name,
    job_type,
    folder_target,
    schedule_cron,
    enabled,
    max_file_size_mb,
    supported_file_types,
    processing_config,
    retry_config,
    notification_config
) VALUES 
    (
        'TBWA_Scout_Daily_Drive_Sync',
        'folder_sync',
        '1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA',
        '0 1 * * *',  -- Daily at 1 AM
        true,
        100,
        ARRAY['pdf', 'docx', 'xlsx', 'pptx', 'jpg', 'png', 'mp4'],
        '{"incremental": true, "max_parallel": 10, "ai_analysis": true, "entity_extraction": true, "pii_detection": true}'::jsonb,
        '{"max_retries": 3, "retry_delay_seconds": 120, "exponential_backoff": true}'::jsonb,
        '{"email_on_failure": true, "slack_notifications": true, "dashboard_alerts": true}'::jsonb
    ),
    (
        'Weekly_Drive_Intelligence_Analysis',
        'intelligence_analysis',
        'all',
        '0 3 * * 1',  -- Weekly on Monday at 3 AM
        true,
        200,
        ARRAY['pdf', 'docx', 'xlsx', 'pptx'],
        '{"deep_analysis": true, "sentiment_analysis": true, "business_entity_extraction": true, "relationship_mapping": true}'::jsonb,
        '{"max_retries": 2, "retry_delay_seconds": 300}'::jsonb,
        '{"email_on_completion": true, "executive_summary": true}'::jsonb
    ),
    (
        'Monthly_Compliance_Scanner',
        'compliance_scan',
        'all',
        '0 2 1 * *',  -- Monthly on 1st at 2 AM
        true,
        500,
        ARRAY['pdf', 'docx', 'xlsx', 'pptx', 'txt'],
        '{"comprehensive_pii_scan": true, "classification_audit": true, "compliance_reporting": true, "risk_assessment": true}'::jsonb,
        '{"max_retries": 2, "retry_delay_seconds": 600}'::jsonb,
        '{"compliance_report": true, "executive_notification": true, "audit_trail": true}'::jsonb
    )
ON CONFLICT (job_name) DO UPDATE SET
    processing_config = EXCLUDED.processing_config,
    retry_config = EXCLUDED.retry_config,
    notification_config = EXCLUDED.notification_config,
    updated_at = NOW();

-- Create Bruno executor integration SQL function
CREATE OR REPLACE FUNCTION drive_intelligence.trigger_bruno_drive_etl(
    folder_id_param TEXT,
    folder_name_param TEXT DEFAULT 'TBWA_Scout_Analytics',
    incremental_param BOOLEAN DEFAULT true
) RETURNS JSONB AS $$
DECLARE
    execution_id UUID;
    result_json JSONB;
BEGIN
    -- Generate execution ID
    execution_id := gen_random_uuid();
    
    -- Log the trigger request
    INSERT INTO drive_intelligence.etl_execution_history (
        job_id,
        execution_id,
        started_at,
        status,
        performance_metrics
    ) 
    SELECT 
        id,
        execution_id,
        NOW(),
        'running',
        jsonb_build_object(
            'trigger_type', 'manual',
            'folder_id', folder_id_param,
            'folder_name', folder_name_param,
            'incremental', incremental_param
        )
    FROM drive_intelligence.etl_job_registry 
    WHERE job_name = 'TBWA_Scout_Daily_Drive_Sync';
    
    -- Return the Bruno CLI command to execute
    result_json := jsonb_build_object(
        'success', true,
        'execution_id', execution_id,
        'bruno_command', format(
            'python3 /Users/tbwa/scout-v7/etl/bruno_executor.py drive --folder-id %s --folder-name "%s" %s',
            folder_id_param,
            folder_name_param,
            CASE WHEN incremental_param THEN '--incremental' ELSE '--full' END
        ),
        'instructions', 'Execute the provided Bruno command to run the Google Drive ETL pipeline',
        'monitoring', 'Monitor execution at http://localhost:8088 (Temporal UI)',
        'logs', 'Check logs at /Users/tbwa/scout-v7/etl/logs/bruno_executor.log'
    );
    
    RETURN result_json;
END;
$$ LANGUAGE plpgsql;

-- Create comprehensive data dictionary view
CREATE OR REPLACE VIEW drive_intelligence.data_dictionary AS
SELECT 
    'drive_intelligence' as schema_name,
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE table_name
        WHEN 'folder_registry' THEN 
            CASE column_name
                WHEN 'business_domain' THEN 'Business classification: creative_intelligence, financial_management, retail_analytics, market_research, client_assets, internal_operations, strategic_planning, performance_reports, compliance_legal'
                WHEN 'data_classification' THEN 'Data sensitivity: public, internal, confidential, restricted'
                WHEN 'auto_processing' THEN 'Enable automatic ETL processing for this folder'
                ELSE 'Core folder registry for Drive ETL integration'
            END
        WHEN 'bronze_files' THEN
            CASE column_name
                WHEN 'file_category' THEN 'File type: document, spreadsheet, presentation, image, video, audio, archive, pdf, google_workspace, creative_asset, financial_report, research_data, other'
                WHEN 'document_type' THEN 'Business document type: strategy_document, creative_brief, financial_report, market_research, campaign_analysis, client_presentation, internal_memo, legal_document, compliance_report, performance_dashboard, budget_planning, competitive_analysis'
                WHEN 'contains_pii' THEN 'PII detection flag for data privacy compliance'
                WHEN 'quality_score' THEN 'Document quality score (0.0-1.0) based on completeness, integrity, and business value'
                ELSE 'Bronze layer raw files with metadata and content extraction'
            END
        WHEN 'silver_document_intelligence' THEN 'Silver layer enriched documents with AI analysis, entity extraction, and business intelligence'
        WHEN 'creative_asset_analysis' THEN 'Creative intelligence analysis for marketing materials and brand assets'
        WHEN 'financial_document_analysis' THEN 'Financial document analysis for budget, expense, and financial reporting'
        WHEN 'research_intelligence' THEN 'Market research and competitive intelligence analysis'
        WHEN 'gold_document_performance' THEN 'Gold layer executive analytics for document performance and business insights'
        WHEN 'etl_job_registry' THEN 'ETL job configuration and scheduling registry'
        WHEN 'etl_execution_history' THEN 'ETL execution history and performance metrics'
        WHEN 'classification_rules' THEN 'Document classification rules and patterns'
        WHEN 'pii_detection_patterns' THEN 'PII detection patterns for data privacy compliance'
        ELSE 'Drive Intelligence Platform table'
    END as description
FROM information_schema.columns
WHERE table_schema = 'drive_intelligence'
ORDER BY table_name, ordinal_position;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON SCHEMA drive_intelligence TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA drive_intelligence TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA drive_intelligence TO postgres;
GRANT EXECUTE ON FUNCTION drive_intelligence.trigger_bruno_drive_etl TO postgres;

-- Create indexes for performance optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bronze_files_business_domain_created 
ON drive_intelligence.bronze_files(business_domain, file_created_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bronze_files_processing_status_priority 
ON drive_intelligence.bronze_files(processing_status, business_priority);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_silver_docs_business_relevance 
ON drive_intelligence.silver_document_intelligence(business_relevance_score DESC, document_freshness_days ASC);

-- Update statistics for query optimization
ANALYZE drive_intelligence.folder_registry;
ANALYZE drive_intelligence.bronze_files;
ANALYZE drive_intelligence.etl_job_registry;

-- Log successful deployment
INSERT INTO metadata.openlineage_events (
    event_id,
    job_name,
    run_id,
    event_type,
    event_data,
    created_at
) VALUES (
    gen_random_uuid(),
    'drive_intelligence_deployment',
    gen_random_uuid(),
    'COMPLETE',
    jsonb_build_object(
        'eventType', 'COMPLETE',
        'eventTime', NOW(),
        'producer', 'scout-etl-deployment',
        'job', jsonb_build_object(
            'namespace', 'scout.deployment',
            'name', 'drive_intelligence_platform'
        ),
        'outputs', jsonb_build_array(
            jsonb_build_object(
                'namespace', 'drive_intelligence',
                'name', 'comprehensive_platform',
                'facets', jsonb_build_object(
                    'schema', jsonb_build_object(
                        'tables', 12,
                        'views', 1,
                        'functions', 1,
                        'indexes', 15,
                        'capabilities', jsonb_build_array(
                            'creative_intelligence',
                            'financial_analysis',
                            'research_intelligence',
                            'document_management',
                            'pii_detection',
                            'compliance_scanning',
                            'business_analytics'
                        )
                    )
                )
            )
        )
    ),
    NOW()
);

COMMIT;

-- Display deployment summary
\echo ''
\echo '=========================================='
\echo 'TBWA Scout Drive Intelligence Platform'
\echo 'Production Deployment Completed Successfully'
\echo '=========================================='
\echo ''
\echo 'Schema: drive_intelligence'
\echo 'Tables Created: 12'
\echo 'Views Created: 1'
\echo 'Functions Created: 1'
\echo 'ETL Jobs Configured: 3'
\echo ''
\echo 'Capabilities Deployed:'
\echo '• Creative Intelligence Analysis'
\echo '• Financial Document Processing'
\echo '• Market Research Intelligence'
\echo '• Comprehensive Document Management'
\echo '• PII Detection & Compliance'
\echo '• Business Analytics & Reporting'
\echo ''
\echo 'Next Steps:'
\echo '1. Configure Google Drive API credentials'
\echo '2. Test ETL execution:'
\echo '   SELECT drive_intelligence.trigger_bruno_drive_etl('
\echo '     ''1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA'','
\echo '     ''TBWA_Scout_Analytics'','
\echo '     true'
\echo '   );'
\echo '3. Monitor execution via Temporal UI: http://localhost:8088'
\echo '4. Review analytics via Gold layer queries'
\echo ''
\echo 'Documentation: /Users/tbwa/scout-v7/etl/schemas/comprehensive_drive_schema.sql'
\echo '=========================================='