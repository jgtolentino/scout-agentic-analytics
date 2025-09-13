-- Iska Agent - Database Schema for Unified Agent Repository Integration
-- This schema extends the existing agent_repository schema with Iska-specific tables

-- Create Iska Agent integration tables for unified agent repository

-- Extend agent_repository schema with Iska-specific tables
CREATE TABLE IF NOT EXISTS agent_repository.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    source TEXT NOT NULL,
    source_type TEXT NOT NULL,
    document_type TEXT NOT NULL,
    file_path TEXT,
    url TEXT,
    checksum TEXT,
    file_size INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB,
    qa_status TEXT DEFAULT 'pending',
    qa_errors TEXT[],
    agent_id UUID REFERENCES agent_repository.agents(id)
);

CREATE TABLE IF NOT EXISTS agent_repository.assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_name TEXT NOT NULL,
    asset_type TEXT NOT NULL,
    asset_url TEXT NOT NULL,
    brand TEXT,
    category TEXT,
    tags TEXT[],
    file_size INTEGER,
    checksum TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB,
    agent_id UUID REFERENCES agent_repository.agents(id)
);

CREATE TABLE IF NOT EXISTS agent_repository.embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES agent_repository.documents(id),
    embedding VECTOR(1536),
    model TEXT DEFAULT 'text-embedding-3-small',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS agent_repository.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    source_type TEXT NOT NULL,
    source_url TEXT NOT NULL,
    document_type TEXT NOT NULL,
    action TEXT NOT NULL,
    agent_trigger TEXT NOT NULL,
    qa_status TEXT NOT NULL,
    error_message TEXT,
    processing_time REAL,
    file_size INTEGER,
    checksum TEXT,
    agent_id UUID REFERENCES agent_repository.agents(id)
);

CREATE TABLE IF NOT EXISTS agent_repository.ingestion_cycles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_documents INTEGER NOT NULL,
    passed_qa INTEGER NOT NULL,
    stored_documents INTEGER NOT NULL,
    processing_time REAL NOT NULL,
    sources JSONB,
    agent_id UUID REFERENCES agent_repository.agents(id)
);

CREATE TABLE IF NOT EXISTS agent_repository.agent_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent TEXT NOT NULL,
    trigger TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    documents JSONB,
    count INTEGER NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    from_agent_id UUID REFERENCES agent_repository.agents(id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_documents_source_type ON agent_repository.documents(source_type);
CREATE INDEX IF NOT EXISTS idx_documents_document_type ON agent_repository.documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_qa_status ON agent_repository.documents(qa_status);
CREATE INDEX IF NOT EXISTS idx_documents_checksum ON agent_repository.documents(checksum);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON agent_repository.documents(created_at);

CREATE INDEX IF NOT EXISTS idx_assets_asset_type ON agent_repository.assets(asset_type);
CREATE INDEX IF NOT EXISTS idx_assets_category ON agent_repository.assets(category);
CREATE INDEX IF NOT EXISTS idx_assets_brand ON agent_repository.assets(brand);

CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON agent_repository.audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_log_source_type ON agent_repository.audit_log(source_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON agent_repository.audit_log(action);

CREATE INDEX IF NOT EXISTS idx_embeddings_document_id ON agent_repository.embeddings(document_id);

-- Create RLS policies for security
ALTER TABLE agent_repository.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_repository.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_repository.embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_repository.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_repository.ingestion_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_repository.agent_notifications ENABLE ROW LEVEL SECURITY;

-- Service role can access all data
CREATE POLICY "Service role can access all documents" ON agent_repository.documents
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role can access all assets" ON agent_repository.assets
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role can access all embeddings" ON agent_repository.embeddings
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role can access all audit logs" ON agent_repository.audit_log
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role can access all ingestion cycles" ON agent_repository.ingestion_cycles
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role can access all agent notifications" ON agent_repository.agent_notifications
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Register Iska agent in the repository
INSERT INTO agent_repository.agents (
    agent_name,
    agent_type,
    version,
    capabilities,
    configuration,
    status,
    created_at
) VALUES (
    'Iska',
    'documentation_intelligence',
    '2.0.0',
    '["web_scraping", "document_ingestion", "asset_parsing", "qa_validation", "audit_logging", "knowledge_base_updates", "agent_orchestration", "semantic_search", "change_detection", "sop_management", "regulatory_compliance"]'::jsonb,
    '{
        "ingestion_sources": {
            "web_scraping": true,
            "document_sources": true,
            "api_sources": true
        },
        "qa_workflow": {
            "enabled": true,
            "caca_integration": true
        },
        "verification": {
            "mandatory_checks": {
                "console_errors": false,
                "screenshot_proof": true,
                "automated_testing": true,
                "evidence_based_reporting": true
            }
        },
        "performance_targets": {
            "documents_per_hour": 1000,
            "qa_validation_time": 5,
            "processing_accuracy": 95
        }
    }'::jsonb,
    'active',
    NOW()
) ON CONFLICT (agent_name) DO UPDATE SET
    version = EXCLUDED.version,
    capabilities = EXCLUDED.capabilities,
    configuration = EXCLUDED.configuration,
    updated_at = NOW();

-- Create useful functions for Iska operations
CREATE OR REPLACE FUNCTION agent_repository.get_iska_metrics(days_back INTEGER DEFAULT 7)
RETURNS TABLE (
    total_documents INTEGER,
    passed_qa INTEGER,
    failed_qa INTEGER,
    processing_time_avg REAL,
    sources_breakdown JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_documents,
        COUNT(*) FILTER (WHERE qa_status = 'passed')::INTEGER as passed_qa,
        COUNT(*) FILTER (WHERE qa_status = 'failed')::INTEGER as failed_qa,
        AVG(EXTRACT(EPOCH FROM (updated_at - created_at)))::REAL as processing_time_avg,
        jsonb_object_agg(source_type, COUNT(*)) as sources_breakdown
    FROM agent_repository.documents
    WHERE created_at >= NOW() - INTERVAL '1 day' * days_back
    GROUP BY ();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION agent_repository.get_recent_ingestion_cycles(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    cycle_id UUID,
    timestamp TIMESTAMP WITH TIME ZONE,
    total_documents INTEGER,
    passed_qa INTEGER,
    processing_time REAL,
    sources JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        id,
        ic.timestamp,
        ic.total_documents,
        ic.passed_qa,
        ic.processing_time,
        ic.sources
    FROM agent_repository.ingestion_cycles ic
    ORDER BY ic.timestamp DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for document updates
CREATE OR REPLACE FUNCTION agent_repository.update_document_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_documents_timestamp
    BEFORE UPDATE ON agent_repository.documents
    FOR EACH ROW
    EXECUTE FUNCTION agent_repository.update_document_timestamp();

-- Grant permissions
GRANT ALL ON agent_repository.documents TO service_role;
GRANT ALL ON agent_repository.assets TO service_role;
GRANT ALL ON agent_repository.embeddings TO service_role;
GRANT ALL ON agent_repository.audit_log TO service_role;
GRANT ALL ON agent_repository.ingestion_cycles TO service_role;
GRANT ALL ON agent_repository.agent_notifications TO service_role;

-- Comment tables for documentation
COMMENT ON TABLE agent_repository.documents IS 'Stores all documents ingested by Iska agent';
COMMENT ON TABLE agent_repository.assets IS 'Stores all assets (images, files, etc.) discovered by Iska';
COMMENT ON TABLE agent_repository.embeddings IS 'Stores vector embeddings for semantic search';
COMMENT ON TABLE agent_repository.audit_log IS 'Audit trail for all Iska operations';
COMMENT ON TABLE agent_repository.ingestion_cycles IS 'Summary of each ingestion cycle';
COMMENT ON TABLE agent_repository.agent_notifications IS 'Notifications sent to downstream agents';

-- Create sample data for testing
INSERT INTO agent_repository.documents (
    title,
    content,
    source,
    source_type,
    document_type,
    qa_status,
    metadata
) VALUES 
(
    'Sample SOP Document',
    'This is a sample Standard Operating Procedure document for testing Iska agent functionality.',
    '/Users/tbwa/SOP/sample_sop.md',
    'local_file',
    'SOP',
    'passed',
    '{"file_extension": ".md", "sample": true}'::jsonb
),
(
    'Brand Guidelines Document',
    'This document contains the brand guidelines for TBWA creative assets and campaigns.',
    '/Users/tbwa/brand-guidelines/tbwa_brand_guide.pdf',
    'local_file',
    'Brand Guidelines',
    'passed',
    '{"file_extension": ".pdf", "sample": true}'::jsonb
);

-- Create sample audit log entries
INSERT INTO agent_repository.audit_log (
    source_type,
    source_url,
    document_type,
    action,
    agent_trigger,
    qa_status,
    processing_time
) VALUES 
(
    'local_file',
    '/Users/tbwa/SOP/sample_sop.md',
    'SOP',
    'file_processed',
    'scheduled',
    'passed',
    2.5
),
(
    'web_scraping',
    'https://brand-portal.tbwa.com/assets',
    'Brand Assets',
    'scrape_success',
    'scheduled',
    'passed',
    15.2
);

-- Create sample ingestion cycle
INSERT INTO agent_repository.ingestion_cycles (
    total_documents,
    passed_qa,
    stored_documents,
    processing_time,
    sources
) VALUES (
    25,
    23,
    23,
    180.5,
    '{"web_scraping": 10, "local_files": 15}'::jsonb
);

-- Final verification query
SELECT 
    'Iska Agent database integration completed successfully' as result,
    COUNT(*) as total_tables_created
FROM information_schema.tables 
WHERE table_schema = 'agent_repository' 
AND table_name IN ('documents', 'assets', 'embeddings', 'audit_log', 'ingestion_cycles', 'agent_notifications');