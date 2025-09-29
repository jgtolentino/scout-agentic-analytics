-- =============================================================================
-- retail_intelligence_integration_views.sql
-- Isko DeepResearch Agent - Scout Analytics Integration Views
-- =============================================================================
-- Views that connect external market intelligence with Scout internal metrics
-- Provides contextual overlays and competitive intelligence for dashboards
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

PRINT 'Creating retail intelligence integration views...';

-- =============================================================================
-- View: Brand Market Intelligence with Scout Metrics
-- Combines external intelligence with internal brand performance
-- =============================================================================
GO
CREATE OR ALTER VIEW dbo.v_brand_market_intelligence AS
WITH scout_brand_metrics AS (
    SELECT
        sib.BrandName,
        COUNT(DISTINCT si.InteractionID) as total_interactions,
        AVG(CAST(sib.Confidence AS DECIMAL(5,2))) as avg_brand_confidence,
        COUNT(DISTINCT CASE WHEN si.TransactionDate >= DATEADD(day, -30, GETUTCDATE()) THEN si.InteractionID END) as recent_interactions,
        MAX(si.TransactionDate) as last_interaction_date,
        STRING_AGG(CAST(si.EmotionalState AS NVARCHAR(MAX)), ', ') as emotional_states
    FROM dbo.SalesInteractionBrands sib
        INNER JOIN dbo.SalesInteractions si ON sib.InteractionID = si.InteractionID
    WHERE sib.Confidence > 0.5
        AND sib.BrandName IS NOT NULL
        AND sib.BrandName != 'Unknown'
    GROUP BY sib.BrandName
),
external_intelligence AS (
    SELECT
        e.brand_name,
        COUNT(DISTINCT e.event_id) as intelligence_events_count,
        COUNT(DISTINCT c.claim_id) as market_claims_count,
        AVG(e.confidence_score) as avg_intelligence_confidence,
        AVG(e.relevance_score) as avg_relevance,
        MAX(e.event_date) as latest_intelligence_date,
        STRING_AGG(e.event_type, ', ') as event_types,
        SUM(CASE WHEN e.impact_level = 'high' THEN 1 ELSE 0 END) as high_impact_events,
        SUM(CASE WHEN e.impact_level = 'critical' THEN 1 ELSE 0 END) as critical_events
    FROM dbo.retail_intel_events e
        LEFT JOIN dbo.retail_intel_claims c ON e.event_id = c.event_id
    WHERE e.status = 'active'
        AND e.collection_date >= DATEADD(day, -90, GETUTCDATE())
        AND e.brand_name IS NOT NULL
    GROUP BY e.brand_name
)
SELECT
    COALESCE(sb.BrandName, ei.brand_name) as brand_name,

    -- Scout Internal Metrics
    ISNULL(sb.total_interactions, 0) as scout_total_interactions,
    ISNULL(sb.avg_brand_confidence, 0) as scout_brand_confidence,
    ISNULL(sb.recent_interactions, 0) as scout_recent_interactions,
    sb.last_interaction_date as scout_last_activity,
    sb.emotional_states as scout_emotional_states,

    -- External Intelligence Metrics
    ISNULL(ei.intelligence_events_count, 0) as external_events_count,
    ISNULL(ei.market_claims_count, 0) as external_claims_count,
    ISNULL(ei.avg_intelligence_confidence, 0) as external_confidence,
    ISNULL(ei.avg_relevance, 0) as external_relevance,
    ei.latest_intelligence_date as external_last_activity,
    ei.event_types as external_event_types,
    ISNULL(ei.high_impact_events, 0) as external_high_impact_count,
    ISNULL(ei.critical_events, 0) as external_critical_count,

    -- Composite Intelligence Score
    CASE
        WHEN sb.BrandName IS NOT NULL AND ei.brand_name IS NOT NULL THEN
            (ISNULL(sb.avg_brand_confidence, 0) * 0.6) + (ISNULL(ei.avg_relevance, 0) * 0.4)
        WHEN sb.BrandName IS NOT NULL THEN sb.avg_brand_confidence
        WHEN ei.brand_name IS NOT NULL THEN ei.avg_relevance
        ELSE 0
    END as composite_intelligence_score,

    -- Alert Indicators
    CASE
        WHEN ei.critical_events > 0 THEN 'CRITICAL'
        WHEN ei.high_impact_events > 0 THEN 'HIGH'
        WHEN ei.intelligence_events_count > 5 THEN 'MEDIUM'
        ELSE 'LOW'
    END as market_attention_level,

    -- Data Quality Indicators
    CASE WHEN sb.BrandName IS NOT NULL THEN 1 ELSE 0 END as has_scout_data,
    CASE WHEN ei.brand_name IS NOT NULL THEN 1 ELSE 0 END as has_external_data,

    GETUTCDATE() as report_generated_date

FROM scout_brand_metrics sb
    FULL OUTER JOIN external_intelligence ei ON sb.BrandName = ei.brand_name;

GO

-- =============================================================================
-- View: Category Market Intelligence and Trends
-- Category-level intelligence with trend analysis
-- =============================================================================
GO
CREATE OR ALTER VIEW dbo.v_category_market_intelligence AS
WITH scout_category_metrics AS (
    SELECT
        nt.nielsen_category_name,
        COUNT(DISTINCT si.InteractionID) as total_interactions,
        COUNT(DISTINCT pt.canonical_tx_id) as total_transactions,
        SUM(CAST(pt.amount AS DECIMAL(10,2))) as total_revenue,
        AVG(CAST(pt.amount AS DECIMAL(10,2))) as avg_transaction_value,
        COUNT(DISTINCT pt.storeId) as store_coverage,
        MAX(si.TransactionDate) as last_activity_date
    FROM dbo.PayloadTransactions pt
        INNER JOIN dbo.SalesInteractions si ON pt.canonical_tx_id = si.canonical_tx_id
        LEFT JOIN dbo.SalesInteractionBrands sib ON si.InteractionID = sib.InteractionID
        LEFT JOIN dbo.NielsenTaxonomy nt ON sib.BrandName = nt.brand_name
    WHERE pt.canonical_tx_id IS NOT NULL
        AND nt.nielsen_category_name IS NOT NULL
    GROUP BY nt.nielsen_category_name
),
external_category_intelligence AS (
    SELECT
        COALESCE(e.nielsen_category, e.category_name) as category_name,
        COUNT(DISTINCT e.event_id) as intelligence_events_count,
        COUNT(DISTINCT c.claim_id) as market_claims_count,
        AVG(e.confidence_score) as avg_confidence,
        AVG(e.relevance_score) as avg_relevance,
        MAX(e.event_date) as latest_intelligence_date,
        COUNT(DISTINCT e.brand_name) as brands_mentioned_count,
        SUM(CASE WHEN e.event_type = 'market_trend' THEN 1 ELSE 0 END) as trend_events,
        SUM(CASE WHEN e.event_type = 'price_change' THEN 1 ELSE 0 END) as price_events,
        SUM(CASE WHEN e.event_type = 'product_launch' THEN 1 ELSE 0 END) as launch_events,
        SUM(CASE WHEN e.impact_level = 'high' OR e.impact_level = 'critical' THEN 1 ELSE 0 END) as high_impact_events
    FROM dbo.retail_intel_events e
        LEFT JOIN dbo.retail_intel_claims c ON e.event_id = c.event_id
    WHERE e.status = 'active'
        AND e.collection_date >= DATEADD(day, -90, GETUTCDATE())
        AND (e.nielsen_category IS NOT NULL OR e.category_name IS NOT NULL)
    GROUP BY COALESCE(e.nielsen_category, e.category_name)
)
SELECT
    COALESCE(sc.nielsen_category_name, ec.category_name) as category_name,

    -- Scout Internal Metrics
    ISNULL(sc.total_interactions, 0) as scout_interactions,
    ISNULL(sc.total_transactions, 0) as scout_transactions,
    ISNULL(sc.total_revenue, 0) as scout_revenue,
    ISNULL(sc.avg_transaction_value, 0) as scout_avg_transaction_value,
    ISNULL(sc.store_coverage, 0) as scout_store_coverage,
    sc.last_activity_date as scout_last_activity,

    -- External Intelligence Metrics
    ISNULL(ec.intelligence_events_count, 0) as external_events_count,
    ISNULL(ec.market_claims_count, 0) as external_claims_count,
    ISNULL(ec.avg_confidence, 0) as external_confidence,
    ISNULL(ec.avg_relevance, 0) as external_relevance,
    ec.latest_intelligence_date as external_last_activity,
    ISNULL(ec.brands_mentioned_count, 0) as external_brands_mentioned,
    ISNULL(ec.trend_events, 0) as external_trend_events,
    ISNULL(ec.price_events, 0) as external_price_events,
    ISNULL(ec.launch_events, 0) as external_launch_events,
    ISNULL(ec.high_impact_events, 0) as external_high_impact_events,

    -- Market Activity Score
    CASE
        WHEN ec.intelligence_events_count >= 10 THEN 'HIGH'
        WHEN ec.intelligence_events_count >= 5 THEN 'MEDIUM'
        WHEN ec.intelligence_events_count >= 1 THEN 'LOW'
        ELSE 'NONE'
    END as market_activity_level,

    -- Category Health Score (combination of internal performance and external attention)
    CASE
        WHEN sc.total_transactions > 100 AND ec.intelligence_events_count > 5 THEN 'STRONG'
        WHEN sc.total_transactions > 50 OR ec.intelligence_events_count > 3 THEN 'MODERATE'
        WHEN sc.total_transactions > 0 OR ec.intelligence_events_count > 0 THEN 'EMERGING'
        ELSE 'MINIMAL'
    END as category_health_score,

    GETUTCDATE() as report_generated_date

FROM scout_category_metrics sc
    FULL OUTER JOIN external_category_intelligence ec ON sc.nielsen_category_name = ec.category_name;

GO

-- =============================================================================
-- View: Competitive Landscape Intelligence
-- Brand-to-brand competitive analysis with market intelligence
-- =============================================================================
GO
CREATE OR ALTER VIEW dbo.v_competitive_landscape_intelligence AS
WITH brand_performance AS (
    SELECT
        sib.BrandName,
        nt.nielsen_category_name,
        COUNT(DISTINCT si.InteractionID) as interaction_count,
        COUNT(DISTINCT pt.canonical_tx_id) as transaction_count,
        SUM(CAST(pt.amount AS DECIMAL(10,2))) as total_revenue,
        AVG(CAST(sib.Confidence AS DECIMAL(5,2))) as avg_confidence,
        ROW_NUMBER() OVER (PARTITION BY nt.nielsen_category_name ORDER BY COUNT(DISTINCT pt.canonical_tx_id) DESC) as category_rank
    FROM dbo.SalesInteractionBrands sib
        INNER JOIN dbo.SalesInteractions si ON sib.InteractionID = si.InteractionID
        INNER JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
        LEFT JOIN dbo.NielsenTaxonomy nt ON sib.BrandName = nt.brand_name
    WHERE sib.Confidence > 0.5
        AND pt.canonical_tx_id IS NOT NULL
        AND nt.nielsen_category_name IS NOT NULL
    GROUP BY sib.BrandName, nt.nielsen_category_name
),
competitive_intelligence AS (
    SELECT
        e.brand_name,
        e.nielsen_category,
        COUNT(DISTINCT CASE WHEN e.event_type = 'competitive_move' THEN e.event_id END) as competitive_moves,
        COUNT(DISTINCT CASE WHEN e.event_type = 'product_launch' THEN e.event_id END) as product_launches,
        COUNT(DISTINCT CASE WHEN e.event_type = 'promotion' THEN e.event_id END) as promotions,
        AVG(e.relevance_score) as avg_market_relevance,
        MAX(e.event_date) as latest_competitive_activity
    FROM dbo.retail_intel_events e
    WHERE e.status = 'active'
        AND e.collection_date >= DATEADD(day, -60, GETUTCDATE())
        AND e.brand_name IS NOT NULL
        AND e.nielsen_category IS NOT NULL
    GROUP BY e.brand_name, e.nielsen_category
)
SELECT
    bp.BrandName as brand_name,
    bp.nielsen_category_name as category_name,
    bp.interaction_count as scout_interactions,
    bp.transaction_count as scout_transactions,
    bp.total_revenue as scout_revenue,
    bp.avg_confidence as scout_brand_confidence,
    bp.category_rank as scout_category_rank,

    -- Competitive Intelligence
    ISNULL(ci.competitive_moves, 0) as external_competitive_moves,
    ISNULL(ci.product_launches, 0) as external_product_launches,
    ISNULL(ci.promotions, 0) as external_promotions,
    ISNULL(ci.avg_market_relevance, 0) as external_market_relevance,
    ci.latest_competitive_activity as external_last_activity,

    -- Competitive Position Indicators
    CASE
        WHEN bp.category_rank <= 3 THEN 'MARKET_LEADER'
        WHEN bp.category_rank <= 10 THEN 'MAJOR_PLAYER'
        WHEN bp.category_rank <= 20 THEN 'NICHE_PLAYER'
        ELSE 'EMERGING'
    END as competitive_position,

    -- Market Threat Level
    CASE
        WHEN ci.competitive_moves >= 3 THEN 'HIGH_THREAT'
        WHEN ci.competitive_moves >= 1 OR ci.product_launches >= 2 THEN 'MEDIUM_THREAT'
        WHEN ci.promotions >= 2 THEN 'LOW_THREAT'
        ELSE 'MINIMAL_THREAT'
    END as competitive_threat_level,

    -- Overall Competitive Score
    (bp.category_rank * -0.1 + 10) + -- Position score (higher rank = lower score)
    (ISNULL(ci.avg_market_relevance, 0) * 5) + -- Market relevance bonus
    (CASE WHEN ci.competitive_moves > 0 THEN -2 ELSE 0 END) as competitive_score,

    GETUTCDATE() as report_generated_date

FROM brand_performance bp
    LEFT JOIN competitive_intelligence ci ON bp.BrandName = ci.brand_name
                                          AND bp.nielsen_category_name = ci.nielsen_category
WHERE bp.category_rank <= 50; -- Focus on top 50 brands per category

GO

-- =============================================================================
-- View: Dashboard Alert Intelligence
-- Active alerts and overlays for dashboard integration
-- =============================================================================
GO
CREATE OR ALTER VIEW dbo.v_dashboard_alert_intelligence AS
SELECT TOP 100 PERCENT
    o.overlay_id,
    o.dashboard_card,
    o.overlay_type,
    o.overlay_message,
    o.display_priority,
    o.target_brands,
    o.target_categories,

    -- Event Context
    e.event_type,
    e.brand_name,
    e.category_name,
    e.event_title,
    e.event_date,
    e.confidence_score,
    e.relevance_score,
    e.impact_level,

    -- Source Information
    s.source_name,
    s.source_type,
    s.reliability_score,

    -- Claims Summary
    (SELECT COUNT(*) FROM dbo.retail_intel_claims c WHERE c.event_id = e.event_id) as claims_count,
    (SELECT AVG(confidence_score) FROM dbo.retail_intel_claims c WHERE c.event_id = e.event_id) as avg_claim_confidence,

    -- Display Logic
    CASE
        WHEN o.end_date IS NULL OR o.end_date > GETUTCDATE() THEN 1
        ELSE 0
    END as is_active,

    CASE
        WHEN o.target_brands IS NOT NULL THEN STRING_AGG(o.target_brands, ',')
        ELSE 'ALL'
    END as brand_filter,

    CASE
        WHEN o.target_categories IS NOT NULL THEN STRING_AGG(o.target_categories, ',')
        ELSE 'ALL'
    END as category_filter,

    o.created_date as overlay_created_date,
    e.collection_date as intelligence_collected_date

FROM dbo.retail_intel_overlays o
    INNER JOIN dbo.retail_intel_events e ON o.event_id = e.event_id
    INNER JOIN dbo.retail_intel_sources s ON e.source_id = s.source_id
WHERE o.status = 'active'
    AND e.status = 'active'
    AND (o.end_date IS NULL OR o.end_date > GETUTCDATE())
    AND o.start_date <= GETUTCDATE()
GROUP BY o.overlay_id, o.dashboard_card, o.overlay_type, o.overlay_message,
         o.display_priority, o.target_brands, o.target_categories,
         e.event_type, e.brand_name, e.category_name, e.event_title,
         e.event_date, e.confidence_score, e.relevance_score, e.impact_level,
         s.source_name, s.source_type, s.reliability_score,
         o.created_date, e.collection_date, o.end_date
ORDER BY o.display_priority ASC, e.relevance_score DESC;

GO

-- =============================================================================
-- View: Intelligence Summary Dashboard
-- High-level KPIs for intelligence monitoring
-- =============================================================================
GO
CREATE OR ALTER VIEW dbo.v_intelligence_summary_dashboard AS
SELECT
    -- Data Freshness
    (SELECT MAX(collection_date) FROM dbo.retail_intel_events WHERE status = 'active') as latest_intelligence_date,
    (SELECT COUNT(*) FROM dbo.retail_intel_events WHERE status = 'active' AND collection_date >= DATEADD(hour, -24, GETUTCDATE())) as events_last_24h,
    (SELECT COUNT(*) FROM dbo.retail_intel_events WHERE status = 'active' AND collection_date >= DATEADD(day, -7, GETUTCDATE())) as events_last_7d,
    (SELECT COUNT(*) FROM dbo.retail_intel_events WHERE status = 'active' AND collection_date >= DATEADD(day, -30, GETUTCDATE())) as events_last_30d,

    -- Source Performance
    (SELECT COUNT(*) FROM dbo.retail_intel_sources WHERE status = 'active') as active_sources,
    (SELECT COUNT(*) FROM dbo.retail_intel_sources WHERE status = 'active' AND last_accessed >= DATEADD(hour, -24, GETUTCDATE())) as sources_active_24h,
    (SELECT AVG(reliability_score) FROM dbo.retail_intel_sources WHERE status = 'active') as avg_source_reliability,

    -- Intelligence Quality
    (SELECT AVG(confidence_score) FROM dbo.retail_intel_events WHERE status = 'active' AND collection_date >= DATEADD(day, -7, GETUTCDATE())) as avg_confidence_7d,
    (SELECT AVG(relevance_score) FROM dbo.retail_intel_events WHERE status = 'active' AND collection_date >= DATEADD(day, -7, GETUTCDATE())) as avg_relevance_7d,
    (SELECT COUNT(*) FROM dbo.retail_intel_events WHERE status = 'active' AND relevance_score >= 0.7) as high_relevance_events,

    -- Claims and Validation
    (SELECT COUNT(*) FROM dbo.retail_intel_claims WHERE created_date >= DATEADD(day, -7, GETUTCDATE())) as claims_last_7d,
    (SELECT COUNT(*) FROM dbo.retail_intel_claims WHERE validation_status = 'verified') as verified_claims,
    (SELECT COUNT(*) FROM dbo.retail_intel_claims WHERE validation_status = 'pending') as pending_claims,

    -- Coverage Analysis
    (SELECT COUNT(DISTINCT brand_name) FROM dbo.retail_intel_events WHERE status = 'active' AND brand_name IS NOT NULL) as brands_covered,
    (SELECT COUNT(DISTINCT nielsen_category) FROM dbo.retail_intel_events WHERE status = 'active' AND nielsen_category IS NOT NULL) as categories_covered,

    -- Active Overlays
    (SELECT COUNT(*) FROM dbo.retail_intel_overlays WHERE status = 'active' AND (end_date IS NULL OR end_date > GETUTCDATE())) as active_overlays,
    (SELECT COUNT(*) FROM dbo.retail_intel_overlays WHERE status = 'active' AND display_priority <= 3) as high_priority_overlays,

    GETUTCDATE() as report_generated_date;

GO

-- =============================================================================
-- Indexes for Performance Optimization
-- =============================================================================

-- Optimize view performance with strategic indexes
CREATE INDEX IX_retail_intel_events_collection_date_status
ON dbo.retail_intel_events (collection_date DESC, status)
INCLUDE (brand_name, category_name, nielsen_category, confidence_score, relevance_score);

CREATE INDEX IX_retail_intel_claims_created_validation
ON dbo.retail_intel_claims (created_date DESC, validation_status)
INCLUDE (event_id, claim_type, confidence_score);

CREATE INDEX IX_retail_intel_overlays_active_priority
ON dbo.retail_intel_overlays (status, display_priority, start_date, end_date)
INCLUDE (dashboard_card, overlay_type, target_brands, target_categories);

-- =============================================================================
-- Permissions and Documentation
-- =============================================================================

PRINT 'Retail Intelligence Integration Views created successfully!';
PRINT '';
PRINT 'Available Views:';
PRINT '- v_brand_market_intelligence: Brand performance with external context';
PRINT '- v_category_market_intelligence: Category trends and market activity';
PRINT '- v_competitive_landscape_intelligence: Competitive positioning analysis';
PRINT '- v_dashboard_alert_intelligence: Active alerts for dashboard overlays';
PRINT '- v_intelligence_summary_dashboard: High-level intelligence KPIs';
PRINT '';
PRINT 'Ready for dashboard integration and API consumption.';

GO