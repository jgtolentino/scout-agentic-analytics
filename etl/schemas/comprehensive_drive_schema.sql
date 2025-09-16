-- Comprehensive Google Drive ETL Schema
-- Production-grade schema for TBWA Scout Analytics Platform
-- Supports: Documents, Spreadsheets, Presentations, Creative Assets, Financial Reports, Research Data

-- Drop existing structures
DROP SCHEMA IF EXISTS drive_intelligence CASCADE;
CREATE SCHEMA drive_intelligence;

-- =====================================================
-- CORE DOCUMENT MANAGEMENT
-- =====================================================

-- Enhanced Drive folder registry with business classification
CREATE TABLE drive_intelligence.folder_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    folder_id TEXT NOT NULL UNIQUE,
    folder_name TEXT NOT NULL,
    folder_path TEXT,
    parent_folder_id TEXT,
    business_domain TEXT NOT NULL CHECK (business_domain IN (
        'creative_intelligence', 'financial_management', 'retail_analytics', 
        'market_research', 'client_assets', 'internal_operations',
        'strategic_planning', 'performance_reports', 'compliance_legal'
    )),
    data_classification TEXT NOT NULL DEFAULT 'internal' CHECK (data_classification IN (
        'public', 'internal', 'confidential', 'restricted'
    )),
    auto_processing BOOLEAN DEFAULT true,
    retention_days INTEGER DEFAULT 2555, -- 7 years
    pii_scanning_enabled BOOLEAN DEFAULT true,
    content_extraction_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_by TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes for performance
CREATE INDEX idx_folder_registry_business_domain ON drive_intelligence.folder_registry(business_domain);
CREATE INDEX idx_folder_registry_parent ON drive_intelligence.folder_registry(parent_folder_id);
CREATE INDEX idx_folder_registry_classification ON drive_intelligence.folder_registry(data_classification);

-- Enhanced Bronze layer for all file types
CREATE TABLE drive_intelligence.bronze_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id TEXT NOT NULL UNIQUE,
    file_name TEXT NOT NULL,
    folder_id TEXT NOT NULL,
    folder_path TEXT,
    
    -- File metadata
    mime_type TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    md5_checksum TEXT,
    created_time TIMESTAMPTZ,
    modified_time TIMESTAMPTZ,
    
    -- File categorization
    file_category TEXT NOT NULL CHECK (file_category IN (
        'document', 'spreadsheet', 'presentation', 'image', 'video', 
        'audio', 'archive', 'pdf', 'google_workspace', 'creative_asset', 
        'financial_report', 'research_data', 'other'
    )),
    document_type TEXT CHECK (document_type IN (
        'strategy_document', 'creative_brief', 'financial_report', 
        'market_research', 'campaign_analysis', 'client_presentation',
        'internal_memo', 'legal_document', 'compliance_report',
        'performance_dashboard', 'budget_planning', 'competitive_analysis'
    )),
    
    -- Content and processing
    file_content BYTEA,
    extracted_text TEXT,
    content_summary TEXT,
    key_entities JSONB DEFAULT '[]'::jsonb,
    
    -- Quality and compliance
    quality_score DECIMAL(3,2) DEFAULT 0.0 CHECK (quality_score >= 0 AND quality_score <= 1),
    contains_pii BOOLEAN DEFAULT false,
    pii_types JSONB DEFAULT '[]'::jsonb,
    compliance_flags JSONB DEFAULT '{}'::jsonb,
    
    -- Processing metadata
    processing_status TEXT DEFAULT 'pending' CHECK (processing_status IN (
        'pending', 'processing', 'completed', 'failed', 'skipped'
    )),
    error_details TEXT,
    synced_at TIMESTAMPTZ DEFAULT now(),
    processed_at TIMESTAMPTZ,
    job_run_id UUID,
    
    -- Business context
    business_value TEXT CHECK (business_value IN ('critical', 'high', 'medium', 'low')),
    confidentiality_level TEXT DEFAULT 'internal' CHECK (confidentiality_level IN (
        'public', 'internal', 'confidential', 'restricted'
    )),
    
    -- Audit fields
    version_number INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    ingested_at TIMESTAMPTZ DEFAULT now(),
    
    -- Relationships
    FOREIGN KEY (folder_id) REFERENCES drive_intelligence.folder_registry(folder_id)
);

-- Performance indexes
CREATE INDEX idx_bronze_files_folder ON drive_intelligence.bronze_files(folder_id);
CREATE INDEX idx_bronze_files_category ON drive_intelligence.bronze_files(file_category);
CREATE INDEX idx_bronze_files_type ON drive_intelligence.bronze_files(document_type);
CREATE INDEX idx_bronze_files_modified ON drive_intelligence.bronze_files(modified_time);
CREATE INDEX idx_bronze_files_status ON drive_intelligence.bronze_files(processing_status);
CREATE INDEX idx_bronze_files_pii ON drive_intelligence.bronze_files(contains_pii);
CREATE INDEX idx_bronze_files_business_value ON drive_intelligence.bronze_files(business_value);

-- =====================================================
-- CONTENT INTELLIGENCE LAYER
-- =====================================================

-- Silver layer: Processed and enriched documents
CREATE TABLE drive_intelligence.silver_document_intelligence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id TEXT NOT NULL REFERENCES drive_intelligence.bronze_files(file_id),
    
    -- Enhanced content analysis
    document_title TEXT,
    author_name TEXT,
    creation_date DATE,
    language_detected TEXT DEFAULT 'en',
    page_count INTEGER,
    word_count INTEGER,
    
    -- Semantic content analysis
    main_topics JSONB DEFAULT '[]'::jsonb,
    key_themes JSONB DEFAULT '[]'::jsonb,
    sentiment_score DECIMAL(3,2), -- -1 to 1
    urgency_level TEXT CHECK (urgency_level IN ('low', 'medium', 'high', 'critical')),
    
    -- Business entity extraction
    mentioned_brands JSONB DEFAULT '[]'::jsonb,
    mentioned_products JSONB DEFAULT '[]'::jsonb,
    mentioned_campaigns JSONB DEFAULT '[]'::jsonb,
    mentioned_competitors JSONB DEFAULT '[]'::jsonb,
    financial_figures JSONB DEFAULT '[]'::jsonb,
    dates_mentioned JSONB DEFAULT '[]'::jsonb,
    
    -- Document relationships
    related_documents JSONB DEFAULT '[]'::jsonb,
    document_hierarchy_level INTEGER DEFAULT 1,
    parent_document_id TEXT,
    
    -- Content quality metrics
    readability_score DECIMAL(5,2),
    completeness_score DECIMAL(3,2) DEFAULT 1.0,
    accuracy_confidence DECIMAL(3,2) DEFAULT 0.8,
    
    -- Business context enrichment
    relevant_business_units JSONB DEFAULT '[]'::jsonb,
    action_items_count INTEGER DEFAULT 0,
    decision_points_count INTEGER DEFAULT 0,
    risk_indicators JSONB DEFAULT '[]'::jsonb,
    
    -- Temporal dimensions
    reporting_period_start DATE,
    reporting_period_end DATE,
    document_freshness_days INTEGER,
    update_frequency TEXT CHECK (update_frequency IN ('daily', 'weekly', 'monthly', 'quarterly', 'annually', 'ad_hoc')),
    
    -- Processing metadata
    ai_processing_version TEXT DEFAULT 'v1.0',
    extraction_confidence DECIMAL(3,2) DEFAULT 0.7,
    processed_at TIMESTAMPTZ DEFAULT now(),
    last_analyzed TIMESTAMPTZ DEFAULT now(),
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_silver_docs_file ON drive_intelligence.silver_document_intelligence(file_id);
CREATE INDEX idx_silver_docs_topics ON drive_intelligence.silver_document_intelligence USING GIN(main_topics);
CREATE INDEX idx_silver_docs_brands ON drive_intelligence.silver_document_intelligence USING GIN(mentioned_brands);
CREATE INDEX idx_silver_docs_urgency ON drive_intelligence.silver_document_intelligence(urgency_level);
CREATE INDEX idx_silver_docs_freshness ON drive_intelligence.silver_document_intelligence(document_freshness_days);

-- =====================================================
-- CREATIVE INTELLIGENCE TABLES
-- =====================================================

-- Creative asset analysis for marketing materials
CREATE TABLE drive_intelligence.creative_asset_analysis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id TEXT NOT NULL REFERENCES drive_intelligence.bronze_files(file_id),
    
    -- Creative classification
    creative_type TEXT CHECK (creative_type IN (
        'campaign_creative', 'brand_guideline', 'presentation_template',
        'social_media_asset', 'print_advertisement', 'digital_banner',
        'video_content', 'audio_content', 'interactive_content'
    )),
    campaign_name TEXT,
    brand_alignment_score DECIMAL(3,2),
    
    -- Visual analysis (for image/video files)
    dominant_colors JSONB DEFAULT '[]'::jsonb,
    text_overlay_detected BOOLEAN DEFAULT false,
    logo_detected BOOLEAN DEFAULT false,
    faces_detected INTEGER DEFAULT 0,
    
    -- Content effectiveness metrics
    engagement_prediction DECIMAL(3,2),
    brand_safety_score DECIMAL(3,2) DEFAULT 1.0,
    accessibility_score DECIMAL(3,2),
    
    -- Compliance and approval
    approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN (
        'pending', 'approved', 'rejected', 'requires_revision'
    )),
    legal_review_required BOOLEAN DEFAULT false,
    brand_review_required BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- FINANCIAL INTELLIGENCE TABLES
-- =====================================================

-- Financial document analysis
CREATE TABLE drive_intelligence.financial_document_analysis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id TEXT NOT NULL REFERENCES drive_intelligence.bronze_files(file_id),
    
    -- Financial document classification
    financial_type TEXT CHECK (financial_type IN (
        'budget_report', 'expense_report', 'invoice', 'financial_statement',
        'audit_report', 'cost_analysis', 'roi_analysis', 'forecast',
        'contract', 'purchase_order', 'payment_record'
    )),
    
    -- Financial data extraction
    total_amount DECIMAL(15,2),
    currency_code TEXT DEFAULT 'PHP',
    fiscal_period TEXT,
    cost_center TEXT,
    vendor_supplier TEXT,
    
    -- Budget and variance analysis
    budget_category TEXT,
    budget_variance_amount DECIMAL(15,2),
    variance_percentage DECIMAL(5,2),
    approval_required BOOLEAN DEFAULT false,
    
    -- Compliance tracking
    tax_implications BOOLEAN DEFAULT false,
    regulatory_filing_required BOOLEAN DEFAULT false,
    audit_trail_complete BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- RESEARCH INTELLIGENCE TABLES
-- =====================================================

-- Market research and competitive analysis
CREATE TABLE drive_intelligence.research_intelligence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id TEXT NOT NULL REFERENCES drive_intelligence.bronze_files(file_id),
    
    -- Research classification
    research_type TEXT CHECK (research_type IN (
        'market_research', 'competitive_analysis', 'consumer_insights',
        'trend_analysis', 'brand_perception', 'campaign_effectiveness',
        'consumer_survey', 'focus_group_results', 'industry_report'
    )),
    
    -- Research metadata
    research_methodology TEXT,
    sample_size INTEGER,
    confidence_level DECIMAL(3,2),
    margin_of_error DECIMAL(3,2),
    geographic_scope TEXT,
    demographic_focus JSONB DEFAULT '[]'::jsonb,
    
    -- Key findings
    primary_insights JSONB DEFAULT '[]'::jsonb,
    actionable_recommendations JSONB DEFAULT '[]'::jsonb,
    risk_factors JSONB DEFAULT '[]'::jsonb,
    market_opportunities JSONB DEFAULT '[]'::jsonb,
    
    -- Competitive intelligence
    competitors_analyzed JSONB DEFAULT '[]'::jsonb,
    market_share_data JSONB DEFAULT '{}'::jsonb,
    pricing_intelligence JSONB DEFAULT '{}'::jsonb,
    
    -- Business impact
    strategic_importance TEXT CHECK (strategic_importance IN ('critical', 'high', 'medium', 'low')),
    implementation_priority TEXT CHECK (implementation_priority IN ('immediate', 'short_term', 'medium_term', 'long_term')),
    estimated_business_impact DECIMAL(15,2),
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- GOLD LAYER: BUSINESS ANALYTICS
-- =====================================================

-- Comprehensive document performance analytics
CREATE TABLE drive_intelligence.gold_document_performance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Time dimensions
    analysis_date DATE NOT NULL DEFAULT CURRENT_DATE,
    reporting_period TEXT NOT NULL, -- 'daily', 'weekly', 'monthly', 'quarterly'
    
    -- Document volume metrics
    total_documents_processed INTEGER DEFAULT 0,
    new_documents_added INTEGER DEFAULT 0,
    documents_updated INTEGER DEFAULT 0,
    documents_archived INTEGER DEFAULT 0,
    
    -- Quality metrics
    avg_quality_score DECIMAL(3,2),
    pii_documents_count INTEGER DEFAULT 0,
    high_risk_documents_count INTEGER DEFAULT 0,
    compliance_violations_count INTEGER DEFAULT 0,
    
    -- Business value metrics by domain
    creative_assets_processed INTEGER DEFAULT 0,
    financial_documents_processed INTEGER DEFAULT 0,
    research_reports_processed INTEGER DEFAULT 0,
    strategic_documents_processed INTEGER DEFAULT 0,
    
    -- Content intelligence metrics
    total_extracted_insights INTEGER DEFAULT 0,
    actionable_recommendations_count INTEGER DEFAULT 0,
    critical_alerts_generated INTEGER DEFAULT 0,
    
    -- Performance indicators
    processing_efficiency_score DECIMAL(3,2),
    storage_optimization_percentage DECIMAL(5,2),
    content_freshness_score DECIMAL(3,2),
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create partitioning for performance
CREATE INDEX idx_gold_doc_perf_date ON drive_intelligence.gold_document_performance(analysis_date);
CREATE INDEX idx_gold_doc_perf_period ON drive_intelligence.gold_document_performance(reporting_period);

-- =====================================================
-- COMPREHENSIVE ETL WORKFLOW TABLES
-- =====================================================

-- ETL job registry for Drive workflows
CREATE TABLE drive_intelligence.etl_job_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_name TEXT NOT NULL UNIQUE,
    job_type TEXT NOT NULL CHECK (job_type IN (
        'folder_sync', 'content_extraction', 'intelligence_analysis',
        'quality_assessment', 'compliance_scan', 'business_categorization'
    )),
    folder_target TEXT, -- Can be specific folder or 'all'
    schedule_cron TEXT,
    enabled BOOLEAN DEFAULT true,
    max_file_size_mb INTEGER DEFAULT 100,
    supported_file_types TEXT[] DEFAULT ARRAY['pdf', 'docx', 'xlsx', 'pptx', 'jpg', 'png'],
    processing_config JSONB DEFAULT '{}'::jsonb,
    retry_config JSONB DEFAULT '{"max_retries": 3, "retry_delay_seconds": 60}'::jsonb,
    notification_config JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ETL execution history
CREATE TABLE drive_intelligence.etl_execution_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES drive_intelligence.etl_job_registry(id),
    execution_id UUID NOT NULL DEFAULT gen_random_uuid(),
    started_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'running' CHECK (status IN (
        'running', 'completed', 'failed', 'cancelled'
    )),
    files_processed INTEGER DEFAULT 0,
    files_succeeded INTEGER DEFAULT 0,
    files_failed INTEGER DEFAULT 0,
    total_bytes_processed BIGINT DEFAULT 0,
    processing_duration_seconds INTEGER,
    error_summary TEXT,
    performance_metrics JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- BUSINESS RULES AND CONFIGURATION
-- =====================================================

-- Document classification rules
CREATE TABLE drive_intelligence.classification_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_name TEXT NOT NULL UNIQUE,
    rule_type TEXT NOT NULL CHECK (rule_type IN ('filename_pattern', 'content_keyword', 'folder_location', 'file_metadata')),
    pattern_regex TEXT,
    keywords JSONB DEFAULT '[]'::jsonb,
    target_classification TEXT NOT NULL,
    confidence_score DECIMAL(3,2) DEFAULT 0.8,
    priority INTEGER DEFAULT 100,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- PII detection patterns
CREATE TABLE drive_intelligence.pii_detection_patterns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pattern_name TEXT NOT NULL UNIQUE,
    pattern_regex TEXT NOT NULL,
    pii_type TEXT NOT NULL CHECK (pii_type IN (
        'email', 'phone', 'ssn', 'credit_card', 'bank_account', 
        'passport', 'drivers_license', 'tax_id', 'custom'
    )),
    severity TEXT DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    enabled BOOLEAN DEFAULT true,
    false_positive_rate DECIMAL(3,2) DEFAULT 0.05,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- TRIGGERS AND AUTOMATION
-- =====================================================

-- Trigger to update updated_at timestamps
CREATE OR REPLACE FUNCTION drive_intelligence.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to all main tables
CREATE TRIGGER update_folder_registry_updated_at BEFORE UPDATE
    ON drive_intelligence.folder_registry FOR EACH ROW EXECUTE FUNCTION 
    drive_intelligence.update_updated_at_column();

CREATE TRIGGER update_bronze_files_updated_at BEFORE UPDATE
    ON drive_intelligence.bronze_files FOR EACH ROW EXECUTE FUNCTION 
    drive_intelligence.update_updated_at_column();

CREATE TRIGGER update_silver_document_intelligence_updated_at BEFORE UPDATE
    ON drive_intelligence.silver_document_intelligence FOR EACH ROW EXECUTE FUNCTION 
    drive_intelligence.update_updated_at_column();

-- =====================================================
-- INITIAL CONFIGURATION DATA
-- =====================================================

-- Insert default folder registry for the shared Drive folder
INSERT INTO drive_intelligence.folder_registry (
    folder_id, 
    folder_name, 
    business_domain, 
    data_classification,
    auto_processing,
    pii_scanning_enabled,
    content_extraction_enabled,
    metadata
) VALUES (
    '1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA',
    'TBWA Scout Analytics - ETL Integration Source',
    'strategic_planning',
    'internal',
    true,
    true,
    true,
    '{"description": "Primary folder for comprehensive Google Drive ETL integration", "priority": "high", "auto_categorization": true}'::jsonb
) ON CONFLICT (folder_id) DO UPDATE SET
    folder_name = EXCLUDED.folder_name,
    business_domain = EXCLUDED.business_domain,
    updated_at = now();

-- Insert default classification rules
INSERT INTO drive_intelligence.classification_rules (rule_name, rule_type, pattern_regex, target_classification, confidence_score) VALUES
    ('Creative Brief Pattern', 'filename_pattern', '(?i).*(brief|creative|campaign).*\.(pdf|docx)$', 'creative_brief', 0.9),
    ('Financial Report Pattern', 'filename_pattern', '(?i).*(budget|financial|expense|cost|invoice).*\.(xlsx|pdf)$', 'financial_report', 0.85),
    ('Research Document Pattern', 'filename_pattern', '(?i).*(research|analysis|survey|insights|market).*\.(pdf|docx)$', 'market_research', 0.8),
    ('Strategy Document Pattern', 'filename_pattern', '(?i).*(strategy|strategic|plan|planning).*\.(pdf|docx|pptx)$', 'strategy_document', 0.85)
ON CONFLICT (rule_name) DO NOTHING;

-- Insert PII detection patterns
INSERT INTO drive_intelligence.pii_detection_patterns (pattern_name, pattern_regex, pii_type, severity) VALUES
    ('Email Address', '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', 'email', 'medium'),
    ('Philippine Mobile', '\b(09|639)\d{9}\b', 'phone', 'medium'),
    ('Credit Card', '\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b', 'credit_card', 'high'),
    ('SSS Number', '\b\d{2}-\d{7}-\d{1}\b', 'ssn', 'high'),
    ('TIN Number', '\b\d{3}-\d{3}-\d{3}-\d{3}\b', 'tax_id', 'high')
ON CONFLICT (pattern_name) DO NOTHING;

-- Insert default ETL jobs
INSERT INTO drive_intelligence.etl_job_registry (
    job_name, 
    job_type, 
    folder_target, 
    schedule_cron, 
    processing_config
) VALUES
    ('Daily Document Sync', 'folder_sync', '1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA', '0 2 * * *', '{"incremental": true, "max_parallel": 5}'::jsonb),
    ('Content Intelligence Analysis', 'intelligence_analysis', 'all', '0 4 * * *', '{"ai_analysis": true, "entity_extraction": true}'::jsonb),
    ('Compliance Scanner', 'compliance_scan', 'all', '0 6 * * 1', '{"pii_detection": true, "classification_update": true}'::jsonb)
ON CONFLICT (job_name) DO NOTHING;

-- =====================================================
-- PERMISSIONS AND SECURITY
-- =====================================================

-- Grant permissions to postgres user (adjust as needed for production)
GRANT ALL PRIVILEGES ON SCHEMA drive_intelligence TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA drive_intelligence TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA drive_intelligence TO postgres;

-- Create RLS policies (Row Level Security) for multi-tenant scenarios
-- ALTER TABLE drive_intelligence.bronze_files ENABLE ROW LEVEL SECURITY;

COMMENT ON SCHEMA drive_intelligence IS 'Comprehensive Google Drive ETL and Intelligence Platform for TBWA Scout Analytics - Production Grade Schema supporting Creative Intelligence, Financial Analysis, Research Intelligence, and Document Management';