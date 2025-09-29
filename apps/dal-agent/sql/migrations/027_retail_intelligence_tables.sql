-- =============================================================================
-- 027_retail_intelligence_tables.sql
-- Isko DeepResearch Agent - Retail Market Intelligence Schema
-- =============================================================================
-- Creates tables for storing automated market intelligence data
-- Integrates with Scout Analytics to provide external market context
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

PRINT 'Creating Isko DeepResearch Agent tables for retail intelligence...';

-- Drop existing tables if they exist (development only)
IF OBJECT_ID('dbo.retail_intel_overlays', 'U') IS NOT NULL DROP TABLE dbo.retail_intel_overlays;
IF OBJECT_ID('dbo.retail_intel_claims', 'U') IS NOT NULL DROP TABLE dbo.retail_intel_claims;
IF OBJECT_ID('dbo.retail_intel_events', 'U') IS NOT NULL DROP TABLE dbo.retail_intel_events;
IF OBJECT_ID('dbo.retail_intel_sources', 'U') IS NOT NULL DROP TABLE dbo.retail_intel_sources;
GO

-- =============================================================================
-- Table: retail_intel_sources
-- Purpose: Track information sources and their reliability scores
-- =============================================================================
CREATE TABLE dbo.retail_intel_sources (
    source_id           UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    source_name         NVARCHAR(255) NOT NULL,
    source_type         NVARCHAR(50) NOT NULL,  -- 'api', 'web', 'news', 'social', 'research'
    source_url          NVARCHAR(1000) NULL,
    reliability_score   DECIMAL(3,2) NOT NULL DEFAULT 0.5,  -- 0.0 to 1.0
    api_endpoint        NVARCHAR(500) NULL,
    rate_limit_rpm      INT NULL,  -- Requests per minute limit
    auth_required       BIT DEFAULT 0,
    last_accessed       DATETIME2 NULL,
    status              NVARCHAR(20) DEFAULT 'active',  -- 'active', 'inactive', 'blocked'
    created_date        DATETIME2 DEFAULT GETUTCDATE(),
    updated_date        DATETIME2 DEFAULT GETUTCDATE(),

    INDEX IX_retail_intel_sources_type (source_type),
    INDEX IX_retail_intel_sources_status (status),
    INDEX IX_retail_intel_sources_reliability (reliability_score DESC)
);

-- =============================================================================
-- Table: retail_intel_events
-- Purpose: Store market intelligence events with metadata
-- =============================================================================
CREATE TABLE dbo.retail_intel_events (
    event_id            UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    source_id           UNIQUEIDENTIFIER NOT NULL,
    event_type          NVARCHAR(50) NOT NULL,  -- 'product_launch', 'price_change', 'promotion', 'market_trend'
    brand_name          NVARCHAR(128) NULL,
    category_name       NVARCHAR(128) NULL,
    nielsen_category    NVARCHAR(128) NULL,
    event_title         NVARCHAR(500) NOT NULL,
    event_description   NVARCHAR(MAX) NULL,
    event_date          DATETIME2 NOT NULL,
    collection_date     DATETIME2 DEFAULT GETUTCDATE(),
    confidence_score    DECIMAL(3,2) NOT NULL DEFAULT 0.5,  -- 0.0 to 1.0
    relevance_score     DECIMAL(3,2) NOT NULL DEFAULT 0.5,  -- 0.0 to 1.0
    impact_level        NVARCHAR(20) DEFAULT 'medium',  -- 'low', 'medium', 'high', 'critical'
    geographic_scope    NVARCHAR(100) DEFAULT 'philippines',
    source_url          NVARCHAR(1000) NULL,
    raw_data            NVARCHAR(MAX) NULL,  -- JSON format
    processed_entities  NVARCHAR(MAX) NULL,  -- JSON format
    tags                NVARCHAR(500) NULL,  -- Comma-separated
    status              NVARCHAR(20) DEFAULT 'active',

    FOREIGN KEY (source_id) REFERENCES dbo.retail_intel_sources(source_id),
    INDEX IX_retail_intel_events_brand (brand_name),
    INDEX IX_retail_intel_events_category (category_name),
    INDEX IX_retail_intel_events_date (event_date DESC),
    INDEX IX_retail_intel_events_relevance (relevance_score DESC),
    INDEX IX_retail_intel_events_impact (impact_level),
    INDEX IX_retail_intel_events_type (event_type)
);

-- =============================================================================
-- Table: retail_intel_claims
-- Purpose: Specific market claims with citations and validation
-- =============================================================================
CREATE TABLE dbo.retail_intel_claims (
    claim_id            UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    event_id            UNIQUEIDENTIFIER NOT NULL,
    claim_type          NVARCHAR(50) NOT NULL,  -- 'market_share', 'price_point', 'consumer_sentiment', 'sales_trend'
    claim_statement     NVARCHAR(1000) NOT NULL,
    claim_value         NVARCHAR(100) NULL,  -- Numeric value if applicable
    claim_unit          NVARCHAR(50) NULL,   -- Unit of measurement
    brand_name          NVARCHAR(128) NULL,
    category_name       NVARCHAR(128) NULL,
    time_period         NVARCHAR(100) NULL,  -- 'Q3 2025', 'September 2025', etc.
    citation_text       NVARCHAR(2000) NULL,
    citation_url        NVARCHAR(1000) NULL,
    confidence_score    DECIMAL(3,2) NOT NULL DEFAULT 0.5,
    validation_status   NVARCHAR(20) DEFAULT 'pending',  -- 'pending', 'verified', 'disputed', 'false'
    supporting_evidence NVARCHAR(MAX) NULL,  -- JSON format
    contradicting_evidence NVARCHAR(MAX) NULL,  -- JSON format
    created_date        DATETIME2 DEFAULT GETUTCDATE(),
    validated_date      DATETIME2 NULL,

    FOREIGN KEY (event_id) REFERENCES dbo.retail_intel_events(event_id),
    INDEX IX_retail_intel_claims_type (claim_type),
    INDEX IX_retail_intel_claims_brand (brand_name),
    INDEX IX_retail_intel_claims_confidence (confidence_score DESC),
    INDEX IX_retail_intel_claims_validation (validation_status),
    INDEX IX_retail_intel_claims_date (created_date DESC)
);

-- =============================================================================
-- Table: retail_intel_overlays
-- Purpose: Dashboard overlays connecting intelligence with Scout metrics
-- =============================================================================
CREATE TABLE dbo.retail_intel_overlays (
    overlay_id          UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    event_id            UNIQUEIDENTIFIER NOT NULL,
    dashboard_card      NVARCHAR(100) NOT NULL,  -- 'brand_performance', 'category_trends', etc.
    overlay_type        NVARCHAR(50) NOT NULL,   -- 'context', 'alert', 'trend', 'validation'
    overlay_message     NVARCHAR(500) NOT NULL,
    overlay_data        NVARCHAR(MAX) NULL,      -- JSON format for additional data
    display_priority    INT DEFAULT 5,           -- 1 (highest) to 10 (lowest)
    start_date          DATETIME2 DEFAULT GETUTCDATE(),
    end_date            DATETIME2 NULL,          -- NULL for permanent overlays
    target_brands       NVARCHAR(500) NULL,     -- Comma-separated brand filter
    target_categories   NVARCHAR(500) NULL,     -- Comma-separated category filter
    visibility_rules    NVARCHAR(MAX) NULL,     -- JSON format for display conditions
    click_action        NVARCHAR(200) NULL,     -- URL or action for user interaction
    status              NVARCHAR(20) DEFAULT 'active',
    created_date        DATETIME2 DEFAULT GETUTCDATE(),

    FOREIGN KEY (event_id) REFERENCES dbo.retail_intel_events(event_id),
    INDEX IX_retail_intel_overlays_card (dashboard_card),
    INDEX IX_retail_intel_overlays_priority (display_priority),
    INDEX IX_retail_intel_overlays_dates (start_date, end_date),
    INDEX IX_retail_intel_overlays_status (status)
);

-- =============================================================================
-- Seed Data: Initial Sources Configuration
-- =============================================================================
PRINT 'Seeding initial retail intelligence sources...';

INSERT INTO dbo.retail_intel_sources (source_name, source_type, source_url, reliability_score, status) VALUES
('Philippine Retailers Association', 'api', 'https://pra.org.ph/api/v1', 0.85, 'active'),
('Kantar Philippines', 'research', 'https://kantar.com/philippines', 0.90, 'active'),
('Nielsen Philippines', 'research', 'https://nielsen.com/ph', 0.95, 'active'),
('Department of Trade and Industry', 'api', 'https://dti.gov.ph/api', 0.80, 'active'),
('Business World Online', 'news', 'https://bworldonline.com', 0.75, 'active'),
('Philippine Daily Inquirer Business', 'news', 'https://business.inquirer.net', 0.75, 'active'),
('Manila Bulletin Business', 'news', 'https://mb.com.ph/business', 0.70, 'active'),
('Euromonitor International', 'research', 'https://euromonitor.com', 0.88, 'active'),
('Statista Philippines', 'research', 'https://statista.com/markets/408/philippines', 0.82, 'active'),
('Social Media Intelligence', 'social', 'https://api.socialmedia.ph', 0.60, 'active');

-- =============================================================================
-- Views: Core Intelligence Queries
-- =============================================================================

-- View: Recent High-Impact Events
GO
CREATE VIEW dbo.v_retail_intel_recent_events AS
SELECT TOP 100
    e.event_id,
    e.event_type,
    e.brand_name,
    e.category_name,
    e.event_title,
    e.event_description,
    e.event_date,
    e.confidence_score,
    e.relevance_score,
    e.impact_level,
    s.source_name,
    s.reliability_score,
    COUNT(c.claim_id) as claim_count
FROM dbo.retail_intel_events e
    INNER JOIN dbo.retail_intel_sources s ON e.source_id = s.source_id
    LEFT JOIN dbo.retail_intel_claims c ON e.event_id = c.event_id
WHERE e.status = 'active'
    AND e.collection_date >= DATEADD(day, -30, GETUTCDATE())
GROUP BY e.event_id, e.event_type, e.brand_name, e.category_name,
         e.event_title, e.event_description, e.event_date,
         e.confidence_score, e.relevance_score, e.impact_level,
         s.source_name, s.reliability_score
ORDER BY e.relevance_score DESC, e.confidence_score DESC;
GO

-- View: Brand Intelligence Summary
GO
CREATE VIEW dbo.v_retail_intel_brand_summary AS
SELECT
    e.brand_name,
    COUNT(DISTINCT e.event_id) as total_events,
    COUNT(DISTINCT c.claim_id) as total_claims,
    AVG(e.confidence_score) as avg_confidence,
    AVG(e.relevance_score) as avg_relevance,
    MAX(e.event_date) as latest_event_date,
    STRING_AGG(e.event_type, ', ') WITHIN GROUP (ORDER BY e.event_date DESC) as recent_event_types
FROM dbo.retail_intel_events e
    LEFT JOIN dbo.retail_intel_claims c ON e.event_id = c.event_id
WHERE e.status = 'active'
    AND e.brand_name IS NOT NULL
    AND e.collection_date >= DATEADD(day, -90, GETUTCDATE())
GROUP BY e.brand_name;
GO

-- =============================================================================
-- Stored Procedures: Intelligence Operations
-- =============================================================================

-- Procedure: Clean Old Intelligence Data
GO
CREATE PROCEDURE dbo.sp_cleanup_old_intelligence
    @days_to_keep INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cutoff_date DATETIME2 = DATEADD(day, -@days_to_keep, GETUTCDATE());

    -- Archive old overlays
    UPDATE dbo.retail_intel_overlays
    SET status = 'archived'
    WHERE created_date < @cutoff_date
        AND status = 'active';

    -- Archive old events with low relevance
    UPDATE dbo.retail_intel_events
    SET status = 'archived'
    WHERE collection_date < @cutoff_date
        AND relevance_score < 0.3
        AND status = 'active';

    PRINT CONCAT('Archived intelligence data older than ', @days_to_keep, ' days');
END;
GO

-- Procedure: Update Source Reliability
GO
CREATE PROCEDURE dbo.sp_update_source_reliability
    @source_id UNIQUEIDENTIFIER,
    @new_reliability DECIMAL(3,2)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.retail_intel_sources
    SET reliability_score = @new_reliability,
        updated_date = GETUTCDATE()
    WHERE source_id = @source_id;

    PRINT CONCAT('Updated reliability score for source: ', @source_id);
END;
GO

-- =============================================================================
-- Indexes for Performance Optimization
-- =============================================================================

-- Composite indexes for common query patterns
CREATE INDEX IX_retail_intel_events_brand_date
ON dbo.retail_intel_events (brand_name, event_date DESC, relevance_score DESC);

CREATE INDEX IX_retail_intel_events_category_impact
ON dbo.retail_intel_events (category_name, impact_level, confidence_score DESC);

CREATE INDEX IX_retail_intel_claims_brand_type
ON dbo.retail_intel_claims (brand_name, claim_type, confidence_score DESC);

-- =============================================================================
-- Permissions and Security
-- =============================================================================

-- Grant permissions to analytics users
-- Note: Actual permissions will be configured based on existing security model

PRINT 'Retail Intelligence schema created successfully!';
PRINT 'Ready for Isko DeepResearch Agent deployment.';
GO