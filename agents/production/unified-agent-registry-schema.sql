-- Unified Agent Registry Schema for TBWA Enterprise Platform
-- Production-grade schema with redundancy, monitoring, and audit support
-- Version: 2.0.0
-- Date: 2025-07-18

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS agent_registry;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- =====================================================
-- CORE AGENT REGISTRY TABLES
-- =====================================================

-- Main agent registry table
CREATE TABLE IF NOT EXISTS agent_registry.agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_name TEXT NOT NULL UNIQUE,
    agent_type TEXT NOT NULL,
    version TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'inactive' CHECK (status IN ('active', 'inactive', 'maintenance', 'deprecated', 'failover')),
    capabilities JSONB NOT NULL DEFAULT '[]'::jsonb,
    configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
    dependencies JSONB DEFAULT '{}'::jsonb,
    
    -- Metadata
    description TEXT,
    author TEXT,
    owner TEXT,
    tags TEXT[] DEFAULT '{}',
    
    -- Redundancy support
    is_primary BOOLEAN DEFAULT true,
    failover_agent_id UUID REFERENCES agent_registry.agents(id),
    failover_priority INTEGER DEFAULT 0,
    
    -- Deployment info
    deployment_type TEXT CHECK (deployment_type IN ('docker', 'edge_function', 'kubernetes', 'lambda', 'standalone')),
    endpoint_url TEXT,
    health_check_url TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_heartbeat TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT unique_agent_version UNIQUE (agent_name, version)
);

-- Agent heartbeat and health monitoring
CREATE TABLE IF NOT EXISTS agent_registry.agent_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agent_registry.agents(id) ON DELETE CASCADE,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT NOT NULL CHECK (status IN ('healthy', 'unhealthy', 'degraded', 'unknown')),
    
    -- Health metrics
    cpu_usage NUMERIC(5,2),
    memory_usage NUMERIC(5,2),
    disk_usage NUMERIC(5,2),
    request_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    avg_response_time_ms NUMERIC(10,2),
    
    -- Additional health data
    health_check_data JSONB,
    error_messages TEXT[],
    
    -- Index for time-series queries
    CONSTRAINT agent_health_timestamp_idx UNIQUE (agent_id, timestamp)
);

-- Agent orchestration and communication
CREATE TABLE IF NOT EXISTS agent_registry.agent_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_agent_id UUID REFERENCES agent_registry.agents(id),
    to_agent_id UUID REFERENCES agent_registry.agents(id),
    message_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'timeout')),
    priority INTEGER DEFAULT 0,
    
    -- Timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Error handling
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    error_message TEXT,
    
    -- Message tracing
    correlation_id UUID,
    parent_message_id UUID REFERENCES agent_registry.agent_messages(id)
);

-- Audit log for all agent operations
CREATE TABLE IF NOT EXISTS agent_registry.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID REFERENCES agent_registry.agents(id),
    event_type TEXT NOT NULL,
    event_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    event_data JSONB,
    
    -- Actor information
    initiated_by TEXT,
    initiated_by_agent_id UUID REFERENCES agent_registry.agents(id),
    
    -- Context
    environment TEXT DEFAULT 'production',
    ip_address INET,
    user_agent TEXT,
    
    -- Result
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    duration_ms INTEGER
);

-- =====================================================
-- LYRA REDUNDANT AGENT SPECIFIC TABLES
-- =====================================================

-- Pull queue for Lyra agents
CREATE TABLE IF NOT EXISTS agent_registry.pull_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'retry')),
    
    -- Agent claiming mechanism
    agent_claimed UUID REFERENCES agent_registry.agents(id),
    claimed_at TIMESTAMP WITH TIME ZONE,
    
    -- Processing metadata
    process_after TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Prevent duplicate processing
    processing_key TEXT UNIQUE,
    
    -- Index for queue processing
    INDEX idx_pull_queue_status_process_after (status, process_after)
);

-- Lyra-specific audit table
CREATE TABLE IF NOT EXISTS agent_registry.lyra_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID REFERENCES agent_registry.agents(id),
    event_type TEXT NOT NULL,
    event_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Lyra-specific fields
    schema_changes JSONB,
    data_processed INTEGER DEFAULT 0,
    processing_time_ms INTEGER,
    
    -- Failover tracking
    is_failover_event BOOLEAN DEFAULT false,
    previous_agent_id UUID REFERENCES agent_registry.agents(id),
    failover_reason TEXT,
    
    payload JSONB,
    notes TEXT
);

-- =====================================================
-- MASTER TOGGLE AGENT SPECIFIC TABLES
-- =====================================================

-- Master data registry
CREATE TABLE IF NOT EXISTS agent_registry.master_data_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dimension_type TEXT NOT NULL,
    dimension_key TEXT NOT NULL,
    dimension_value TEXT NOT NULL,
    
    -- Metadata
    source_table TEXT,
    source_column TEXT,
    first_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    occurrence_count INTEGER DEFAULT 1,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_stale BOOLEAN DEFAULT false,
    
    -- Configuration
    display_order INTEGER DEFAULT 0,
    display_label TEXT,
    metadata JSONB,
    
    -- Unique constraint
    CONSTRAINT unique_dimension_value UNIQUE (dimension_type, dimension_key)
);

-- Toggle/filter configuration
CREATE TABLE IF NOT EXISTS agent_registry.toggle_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    toggle_name TEXT NOT NULL UNIQUE,
    dimension_type TEXT NOT NULL,
    
    -- UI Configuration
    ui_component_type TEXT DEFAULT 'dropdown',
    ui_label TEXT,
    ui_placeholder TEXT,
    ui_order INTEGER DEFAULT 0,
    
    -- Behavior
    is_multi_select BOOLEAN DEFAULT false,
    is_searchable BOOLEAN DEFAULT true,
    is_clearable BOOLEAN DEFAULT true,
    default_values JSONB,
    
    -- Access control
    required_roles TEXT[] DEFAULT '{}',
    is_enabled BOOLEAN DEFAULT true,
    
    -- Metadata
    created_by TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    configuration JSONB
);

-- =====================================================
-- AGENT CAPABILITIES AND PERMISSIONS
-- =====================================================

-- Agent capabilities mapping
CREATE TABLE IF NOT EXISTS agent_registry.agent_capabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agent_registry.agents(id) ON DELETE CASCADE,
    capability_name TEXT NOT NULL,
    capability_version TEXT DEFAULT '1.0.0',
    
    -- Configuration
    is_enabled BOOLEAN DEFAULT true,
    configuration JSONB,
    
    -- Permissions
    required_permissions TEXT[],
    granted_permissions TEXT[],
    
    -- Constraints
    CONSTRAINT unique_agent_capability UNIQUE (agent_id, capability_name)
);

-- Agent API endpoints
CREATE TABLE IF NOT EXISTS agent_registry.agent_endpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agent_registry.agents(id) ON DELETE CASCADE,
    
    -- Endpoint details
    method TEXT NOT NULL CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH')),
    path TEXT NOT NULL,
    description TEXT,
    
    -- Request/Response schema
    request_schema JSONB,
    response_schema JSONB,
    
    -- Security
    auth_required BOOLEAN DEFAULT true,
    rate_limit INTEGER DEFAULT 100,
    
    -- Status
    is_enabled BOOLEAN DEFAULT true,
    is_deprecated BOOLEAN DEFAULT false,
    
    -- Versioning
    version TEXT DEFAULT 'v1',
    
    -- Constraints
    CONSTRAINT unique_agent_endpoint UNIQUE (agent_id, method, path, version)
);

-- =====================================================
-- PERFORMANCE AND MONITORING VIEWS
-- =====================================================

-- Active agents view
CREATE OR REPLACE VIEW agent_registry.active_agents AS
SELECT 
    a.*,
    h.status as health_status,
    h.timestamp as last_health_check,
    h.cpu_usage,
    h.memory_usage,
    h.error_count
FROM agent_registry.agents a
LEFT JOIN LATERAL (
    SELECT * FROM agent_registry.agent_health
    WHERE agent_id = a.id
    ORDER BY timestamp DESC
    LIMIT 1
) h ON true
WHERE a.status = 'active';

-- Agent performance metrics
CREATE OR REPLACE VIEW agent_registry.agent_performance AS
SELECT 
    a.agent_name,
    a.agent_type,
    COUNT(DISTINCT m.id) as total_messages,
    COUNT(DISTINCT m.id) FILTER (WHERE m.status = 'completed') as completed_messages,
    COUNT(DISTINCT m.id) FILTER (WHERE m.status = 'failed') as failed_messages,
    AVG(EXTRACT(EPOCH FROM (m.completed_at - m.created_at))) as avg_processing_time_sec,
    MAX(m.created_at) as last_activity
FROM agent_registry.agents a
LEFT JOIN agent_registry.agent_messages m ON (a.id = m.from_agent_id OR a.id = m.to_agent_id)
WHERE m.created_at > NOW() - INTERVAL '24 hours'
GROUP BY a.id, a.agent_name, a.agent_type;

-- Master data freshness view
CREATE OR REPLACE VIEW agent_registry.master_data_freshness AS
SELECT 
    dimension_type,
    COUNT(*) as total_values,
    COUNT(*) FILTER (WHERE is_active) as active_values,
    COUNT(*) FILTER (WHERE is_stale) as stale_values,
    MAX(last_seen) as most_recent_update,
    MIN(first_seen) as oldest_entry
FROM agent_registry.master_data_registry
GROUP BY dimension_type;

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION agent_registry.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update trigger to all tables with updated_at
CREATE TRIGGER update_agents_updated_at BEFORE UPDATE ON agent_registry.agents
    FOR EACH ROW EXECUTE FUNCTION agent_registry.update_updated_at_column();

CREATE TRIGGER update_pull_queue_updated_at BEFORE UPDATE ON agent_registry.pull_queue
    FOR EACH ROW EXECUTE FUNCTION agent_registry.update_updated_at_column();

CREATE TRIGGER update_toggle_config_updated_at BEFORE UPDATE ON agent_registry.toggle_config
    FOR EACH ROW EXECUTE FUNCTION agent_registry.update_updated_at_column();

-- Agent failover function
CREATE OR REPLACE FUNCTION agent_registry.trigger_agent_failover(
    primary_agent_id UUID,
    reason TEXT DEFAULT 'Health check failure'
) RETURNS UUID AS $$
DECLARE
    failover_id UUID;
BEGIN
    -- Find the failover agent
    SELECT failover_agent_id INTO failover_id
    FROM agent_registry.agents
    WHERE id = primary_agent_id AND status = 'active';
    
    IF failover_id IS NOT NULL THEN
        -- Update primary agent status
        UPDATE agent_registry.agents
        SET status = 'failover', last_heartbeat = NOW()
        WHERE id = primary_agent_id;
        
        -- Activate failover agent
        UPDATE agent_registry.agents
        SET status = 'active', is_primary = true
        WHERE id = failover_id;
        
        -- Log the failover event
        INSERT INTO agent_registry.lyra_audit (
            agent_id, event_type, is_failover_event, 
            previous_agent_id, failover_reason
        ) VALUES (
            failover_id, 'failover_activated', true,
            primary_agent_id, reason
        );
        
        -- Audit log
        INSERT INTO agent_registry.audit_log (
            agent_id, event_type, event_data, success
        ) VALUES (
            primary_agent_id, 'failover_triggered',
            jsonb_build_object(
                'reason', reason,
                'failover_agent_id', failover_id
            ),
            true
        );
    END IF;
    
    RETURN failover_id;
END;
$$ LANGUAGE plpgsql;

-- Claim pull queue item (for Lyra agents)
CREATE OR REPLACE FUNCTION agent_registry.claim_pull_queue_item(
    claiming_agent_id UUID
) RETURNS UUID AS $$
DECLARE
    queue_item_id UUID;
BEGIN
    -- Atomically claim the next available item
    UPDATE agent_registry.pull_queue
    SET 
        status = 'processing',
        agent_claimed = claiming_agent_id,
        claimed_at = NOW()
    WHERE id = (
        SELECT id FROM agent_registry.pull_queue
        WHERE status = 'pending'
        AND process_after <= NOW()
        ORDER BY created_at
        LIMIT 1
        FOR UPDATE SKIP LOCKED
    )
    RETURNING id INTO queue_item_id;
    
    RETURN queue_item_id;
END;
$$ LANGUAGE plpgsql;

-- Master data upsert function
CREATE OR REPLACE FUNCTION agent_registry.upsert_master_data(
    p_dimension_type TEXT,
    p_dimension_key TEXT,
    p_dimension_value TEXT,
    p_source_table TEXT DEFAULT NULL,
    p_source_column TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO agent_registry.master_data_registry (
        dimension_type, dimension_key, dimension_value,
        source_table, source_column, last_seen, occurrence_count
    ) VALUES (
        p_dimension_type, p_dimension_key, p_dimension_value,
        p_source_table, p_source_column, NOW(), 1
    )
    ON CONFLICT (dimension_type, dimension_key) 
    DO UPDATE SET
        last_seen = NOW(),
        occurrence_count = master_data_registry.occurrence_count + 1,
        is_active = true,
        is_stale = false;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE agent_registry.agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_registry.agent_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_registry.agent_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_registry.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_registry.pull_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_registry.master_data_registry ENABLE ROW LEVEL SECURITY;

-- Service role has full access
CREATE POLICY "Service role full access on agents" ON agent_registry.agents
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on health" ON agent_registry.agent_health
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on messages" ON agent_registry.agent_messages
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on audit" ON agent_registry.audit_log
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on queue" ON agent_registry.pull_queue
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on master data" ON agent_registry.master_data_registry
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Authenticated users can read agents and health
CREATE POLICY "Authenticated read agents" ON agent_registry.agents
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated read health" ON agent_registry.agent_health
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated read master data" ON agent_registry.master_data_registry
    FOR SELECT USING (auth.role() = 'authenticated');

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Agent lookups
CREATE INDEX idx_agents_status ON agent_registry.agents(status);
CREATE INDEX idx_agents_type ON agent_registry.agents(agent_type);
CREATE INDEX idx_agents_heartbeat ON agent_registry.agents(last_heartbeat);

-- Health monitoring
CREATE INDEX idx_agent_health_agent_timestamp ON agent_registry.agent_health(agent_id, timestamp DESC);
CREATE INDEX idx_agent_health_status ON agent_registry.agent_health(status);

-- Message processing
CREATE INDEX idx_messages_status ON agent_registry.agent_messages(status);
CREATE INDEX idx_messages_to_agent ON agent_registry.agent_messages(to_agent_id);
CREATE INDEX idx_messages_created ON agent_registry.agent_messages(created_at);

-- Audit trail
CREATE INDEX idx_audit_agent_time ON agent_registry.audit_log(agent_id, event_time DESC);
CREATE INDEX idx_audit_event_type ON agent_registry.audit_log(event_type);

-- Pull queue
CREATE INDEX idx_pull_queue_processing ON agent_registry.pull_queue(status, process_after);
CREATE INDEX idx_pull_queue_agent ON agent_registry.pull_queue(agent_claimed);

-- Master data
CREATE INDEX idx_master_data_type ON agent_registry.master_data_registry(dimension_type);
CREATE INDEX idx_master_data_active ON agent_registry.master_data_registry(is_active);
CREATE INDEX idx_master_data_last_seen ON agent_registry.master_data_registry(last_seen);

-- =====================================================
-- INITIAL DATA SETUP
-- =====================================================

-- Insert core agent types
INSERT INTO agent_registry.agents (
    agent_name, agent_type, version, status, capabilities, configuration, description, owner
) VALUES 
-- Core system agents
('Orchestrator', 'coordinator', '2.0.0', 'active', 
 '["agent_orchestration", "workflow_management", "health_monitoring"]'::jsonb,
 '{"max_concurrent_workflows": 10, "heartbeat_interval": 5}'::jsonb,
 'Master orchestration agent for coordinating all other agents',
 'System'),

-- Lyra redundant agents
('Lyra-Primary', 'schema_inference', '1.0.0', 'active',
 '["schema_discovery", "json_to_sql", "data_ingestion", "master_data_update"]'::jsonb,
 '{"pull_interval": 1, "batch_size": 1000, "is_primary": true}'::jsonb,
 'Primary Lyra agent for schema inference and data ingestion',
 'Data Platform Lead'),

('Lyra-Secondary', 'schema_inference', '1.0.0', 'inactive',
 '["schema_discovery", "json_to_sql", "data_ingestion", "master_data_update"]'::jsonb,
 '{"pull_interval": 1, "batch_size": 1000, "is_primary": false}'::jsonb,
 'Secondary Lyra agent for high-availability failover',
 'Data Platform Lead'),

-- Master Toggle Agent
('Master-Toggle', 'filter_management', '1.0.0', 'active',
 '["filter_sync", "dimension_detection", "stale_pruning", "toggle_api", "event_streaming"]'::jsonb,
 '{"sync_interval": 60, "prune_interval": 300, "websocket_enabled": true}'::jsonb,
 'Manages all dashboard filters and toggles with real-time updates',
 'Data Platform Lead'),

-- Iska agent
('Iska', 'documentation_intelligence', '2.0.0', 'active',
 '["web_scraping", "document_ingestion", "asset_parsing", "qa_validation", "audit_logging", "knowledge_base_updates", "agent_orchestration", "semantic_search"]'::jsonb,
 '{"ingestion_interval": 21600, "qa_threshold": 0.85, "embedding_model": "text-embedding-3-small"}'::jsonb,
 'Enterprise documentation and asset intelligence agent',
 'InsightPulseAI')

ON CONFLICT (agent_name) DO UPDATE SET
    version = EXCLUDED.version,
    capabilities = EXCLUDED.capabilities,
    configuration = EXCLUDED.configuration,
    updated_at = NOW();

-- Set up agent redundancy relationships
UPDATE agent_registry.agents 
SET failover_agent_id = (SELECT id FROM agent_registry.agents WHERE agent_name = 'Lyra-Secondary')
WHERE agent_name = 'Lyra-Primary';

UPDATE agent_registry.agents 
SET failover_agent_id = (SELECT id FROM agent_registry.agents WHERE agent_name = 'Lyra-Primary')
WHERE agent_name = 'Lyra-Secondary';

-- Grant permissions
GRANT ALL ON ALL TABLES IN SCHEMA agent_registry TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA agent_registry TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA agent_registry TO service_role;

GRANT SELECT ON ALL TABLES IN SCHEMA agent_registry TO authenticated;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA agent_registry TO authenticated;

-- Create notification for schema completion
DO $$
BEGIN
    RAISE NOTICE 'Unified Agent Registry Schema created successfully!';
    RAISE NOTICE 'Total tables created: %', (
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'agent_registry'
    );
    RAISE NOTICE 'Initial agents loaded: %', (
        SELECT COUNT(*) FROM agent_registry.agents
    );
END $$;