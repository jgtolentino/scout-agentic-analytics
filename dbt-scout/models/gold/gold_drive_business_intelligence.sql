{{ config(
    materialized='table',
    post_hook=[
        "CALL metadata.record_lineage_event('{{ this }}', 'gold_drive_business_intelligence', 'COMPLETE')",
        "CALL metadata.update_medallion_health('gold', '{{ this }}', 'drive_business_intelligence')"
    ],
    tags=['gold', 'drive', 'business_intelligence', 'executive']
) }}

/*
    Gold layer: Comprehensive Google Drive business intelligence
    Executive-ready analytics for TBWA Scout Analytics Platform
    Supports: Creative intelligence, financial insights, research analytics, strategic planning
*/

WITH silver_documents AS (
    SELECT 
        file_id,
        document_title,
        author_name,
        creation_date,
        detected_language,
        estimated_word_count,
        file_category,
        document_type,
        business_domain,
        document_version,
        key_topics,
        sentiment_score,
        urgency_level,
        mentioned_brands,
        mentioned_competitors,
        financial_figures,
        mentioned_dates,
        quality_score,
        content_completeness,
        content_density_score,
        business_relevance_score,
        document_freshness_days,
        content_freshness,
        business_priority,
        has_pii_risk,
        risk_level,
        confidentiality_level,
        file_size_bytes,
        document_created_at,
        last_modified,
        creation_month,
        creation_year,
        silver_processed_at
    FROM {{ ref('silver_drive_intelligence') }}
),

-- =====================================================
-- EXECUTIVE DOCUMENT PERFORMANCE METRICS
-- =====================================================

document_performance_metrics AS (
    SELECT 
        CURRENT_DATE as analysis_date,
        'daily' as reporting_period,
        
        -- Volume metrics
        COUNT(*) as total_documents,
        COUNT(*) FILTER (WHERE DATE(silver_processed_at) = CURRENT_DATE) as documents_processed_today,
        COUNT(*) FILTER (WHERE document_freshness_days <= 7) as recent_documents,
        COUNT(*) FILTER (WHERE document_freshness_days > 365) as legacy_documents,
        
        -- Quality distribution
        ROUND(AVG(quality_score), 3) as avg_quality_score,
        COUNT(*) FILTER (WHERE quality_score >= 0.8) as high_quality_documents,
        COUNT(*) FILTER (WHERE quality_score < 0.5) as low_quality_documents,
        COUNT(*) FILTER (WHERE content_completeness = 'complete') as complete_documents,
        
        -- Business value distribution
        COUNT(*) FILTER (WHERE business_priority = 'critical') as critical_documents,
        COUNT(*) FILTER (WHERE business_priority = 'high') as high_priority_documents,
        COUNT(*) FILTER (WHERE business_relevance_score >= 0.8) as high_relevance_documents,
        
        -- Risk and compliance
        COUNT(*) FILTER (WHERE has_pii_risk = true) as pii_risk_documents,
        COUNT(*) FILTER (WHERE risk_level = 'high_risk') as high_risk_documents,
        COUNT(*) FILTER (WHERE confidentiality_level IN ('confidential', 'restricted')) as confidential_documents,
        
        -- Content insights
        ROUND(AVG(business_relevance_score), 3) as avg_business_relevance,
        ROUND(AVG(content_density_score), 3) as avg_content_density,
        COUNT(*) FILTER (WHERE urgency_level = 'critical') as urgent_documents,
        
        -- Storage optimization
        ROUND(SUM(file_size_bytes)::numeric / (1024^3), 2) as total_storage_gb,
        ROUND(AVG(file_size_bytes)::numeric / (1024^2), 2) as avg_file_size_mb
    
    FROM silver_documents
),

-- =====================================================
-- BUSINESS DOMAIN ANALYTICS
-- =====================================================

domain_performance AS (
    SELECT 
        business_domain,
        COUNT(*) as document_count,
        ROUND(AVG(quality_score), 3) as avg_quality,
        ROUND(AVG(business_relevance_score), 3) as avg_relevance,
        COUNT(*) FILTER (WHERE business_priority IN ('critical', 'high')) as high_priority_count,
        COUNT(*) FILTER (WHERE document_freshness_days <= 30) as recent_count,
        COUNT(*) FILTER (WHERE has_pii_risk = true) as pii_risk_count,
        
        -- Domain-specific metrics
        CASE business_domain
            WHEN 'creative_intelligence' THEN 
                COUNT(*) FILTER (WHERE ARRAY_LENGTH(mentioned_brands, 1) > 0)
            WHEN 'financial_management' THEN 
                COUNT(*) FILTER (WHERE ARRAY_LENGTH(financial_figures, 1) > 0)
            WHEN 'market_research' THEN 
                COUNT(*) FILTER (WHERE ARRAY_LENGTH(mentioned_competitors, 1) > 0)
            ELSE 0
        END as domain_specific_insights,
        
        ROUND(SUM(file_size_bytes)::numeric / (1024^2), 2) as total_size_mb,
        MAX(last_modified) as latest_activity
        
    FROM silver_documents
    GROUP BY business_domain
),

-- =====================================================
-- CREATIVE INTELLIGENCE ANALYTICS
-- =====================================================

creative_intelligence AS (
    SELECT 
        'Creative Intelligence' as analytics_category,
        COUNT(*) FILTER (WHERE business_domain = 'creative_intelligence') as total_creative_assets,
        COUNT(*) FILTER (WHERE business_domain = 'creative_intelligence' AND document_type = 'creative_brief') as creative_briefs,
        COUNT(*) FILTER (WHERE business_domain = 'creative_intelligence' AND document_type = 'client_presentation') as client_presentations,
        
        -- Brand analysis
        (
            SELECT COUNT(DISTINCT brand) 
            FROM silver_documents s,
            LATERAL unnest(s.mentioned_brands) as brand
            WHERE s.business_domain = 'creative_intelligence'
        ) as unique_brands_mentioned,
        
        -- Campaign effectiveness indicators
        COUNT(*) FILTER (WHERE business_domain = 'creative_intelligence' AND sentiment_score > 0.5) as positive_sentiment_assets,
        COUNT(*) FILTER (WHERE business_domain = 'creative_intelligence' AND urgency_level = 'critical') as urgent_creative_requests,
        
        -- Quality metrics for creative work
        ROUND(AVG(quality_score) FILTER (WHERE business_domain = 'creative_intelligence'), 3) as avg_creative_quality,
        ROUND(AVG(business_relevance_score) FILTER (WHERE business_domain = 'creative_intelligence'), 3) as avg_creative_relevance
        
    FROM silver_documents
),

-- =====================================================
-- FINANCIAL INTELLIGENCE ANALYTICS
-- =====================================================

financial_intelligence AS (
    SELECT 
        'Financial Intelligence' as analytics_category,
        COUNT(*) FILTER (WHERE business_domain = 'financial_management') as total_financial_documents,
        COUNT(*) FILTER (WHERE business_domain = 'financial_management' AND document_type = 'financial_report') as financial_reports,
        
        -- Financial insights
        (
            SELECT COUNT(DISTINCT amount) 
            FROM silver_documents s,
            LATERAL unnest(s.financial_figures) as amount
            WHERE s.business_domain = 'financial_management'
        ) as unique_financial_figures,
        
        COUNT(*) FILTER (WHERE business_domain = 'financial_management' AND urgency_level IN ('critical', 'high')) as urgent_financial_items,
        COUNT(*) FILTER (WHERE business_domain = 'financial_management' AND has_pii_risk = true) as sensitive_financial_docs,
        
        -- Compliance tracking
        COUNT(*) FILTER (WHERE business_domain = 'financial_management' AND confidentiality_level = 'restricted') as restricted_financial_docs,
        
        -- Financial document quality
        ROUND(AVG(quality_score) FILTER (WHERE business_domain = 'financial_management'), 3) as avg_financial_quality,
        ROUND(AVG(content_completeness = 'complete'::boolean::int) FILTER (WHERE business_domain = 'financial_management'), 3) as financial_completeness_rate
        
    FROM silver_documents
),

-- =====================================================
-- RESEARCH INTELLIGENCE ANALYTICS
-- =====================================================

research_intelligence AS (
    SELECT 
        'Research Intelligence' as analytics_category,
        COUNT(*) FILTER (WHERE business_domain = 'market_research') as total_research_documents,
        COUNT(*) FILTER (WHERE business_domain = 'market_research' AND document_type = 'market_research') as market_research_reports,
        COUNT(*) FILTER (WHERE business_domain = 'market_research' AND document_type = 'competitive_analysis') as competitive_analyses,
        
        -- Research insights
        (
            SELECT COUNT(DISTINCT competitor) 
            FROM silver_documents s,
            LATERAL unnest(s.mentioned_competitors) as competitor
            WHERE s.business_domain = 'market_research'
        ) as unique_competitors_tracked,
        
        -- Research quality and relevance
        ROUND(AVG(quality_score) FILTER (WHERE business_domain = 'market_research'), 3) as avg_research_quality,
        ROUND(AVG(business_relevance_score) FILTER (WHERE business_domain = 'market_research'), 3) as avg_research_relevance,
        
        -- Strategic importance
        COUNT(*) FILTER (WHERE business_domain = 'market_research' AND business_priority = 'critical') as critical_research_items,
        COUNT(*) FILTER (WHERE business_domain = 'market_research' AND sentiment_score < -0.3) as concerning_research_findings
        
    FROM silver_documents
),

-- =====================================================
-- DOCUMENT LIFECYCLE ANALYTICS
-- =====================================================

document_lifecycle AS (
    SELECT 
        document_type,
        COUNT(*) as total_count,
        ROUND(AVG(document_freshness_days), 1) as avg_age_days,
        COUNT(*) FILTER (WHERE content_freshness = 'very_fresh') as very_fresh_count,
        COUNT(*) FILTER (WHERE content_freshness = 'stale') as stale_count,
        
        -- Version and update patterns
        ROUND(AVG(CAST(document_version AS numeric)), 2) as avg_version_number,
        COUNT(DISTINCT document_title) as unique_document_series,
        
        -- Quality evolution
        ROUND(AVG(quality_score), 3) as avg_quality,
        ROUND(AVG(business_relevance_score), 3) as avg_relevance,
        
        -- Risk distribution
        COUNT(*) FILTER (WHERE risk_level = 'high_risk') as high_risk_count,
        ROUND(AVG(has_pii_risk::int), 3) as pii_risk_rate
        
    FROM silver_documents
    GROUP BY document_type
    HAVING COUNT(*) >= 3  -- Only show document types with sufficient volume
),

-- =====================================================
-- TEMPORAL TRENDS ANALYTICS
-- =====================================================

temporal_trends AS (
    SELECT 
        creation_year,
        creation_month,
        COUNT(*) as documents_created,
        ROUND(AVG(quality_score), 3) as avg_quality,
        COUNT(*) FILTER (WHERE business_priority IN ('critical', 'high')) as high_priority_docs,
        COUNT(*) FILTER (WHERE has_pii_risk = true) as pii_risk_docs,
        ROUND(SUM(file_size_bytes)::numeric / (1024^2), 2) as total_size_mb,
        
        -- Business domain distribution by time
        COUNT(*) FILTER (WHERE business_domain = 'creative_intelligence') as creative_docs,
        COUNT(*) FILTER (WHERE business_domain = 'financial_management') as financial_docs,
        COUNT(*) FILTER (WHERE business_domain = 'market_research') as research_docs,
        COUNT(*) FILTER (WHERE business_domain = 'strategic_planning') as strategy_docs
        
    FROM silver_documents
    WHERE creation_year >= 2020  -- Focus on recent years
    GROUP BY creation_year, creation_month
),

-- =====================================================
-- FINAL CONSOLIDATED ANALYTICS
-- =====================================================

consolidated_analytics AS (
    SELECT 
        -- Executive summary metrics
        (SELECT * FROM document_performance_metrics) as performance_summary,
        
        -- Domain analytics
        ARRAY_AGG(domain_performance.*) as domain_breakdown,
        
        -- Specialized intelligence
        (SELECT * FROM creative_intelligence) as creative_insights,
        (SELECT * FROM financial_intelligence) as financial_insights,
        (SELECT * FROM research_intelligence) as research_insights,
        
        -- Lifecycle and trends
        ARRAY_AGG(document_lifecycle.*) as lifecycle_analysis,
        ARRAY_AGG(temporal_trends.*) as temporal_trends,
        
        -- Meta analytics
        CURRENT_TIMESTAMP as analytics_generated_at,
        '{{ invocation_id }}' as dbt_run_id,
        'gold_drive_business_intelligence' as analytics_layer
)

-- Return the comprehensive business intelligence summary
SELECT 
    -- Performance Overview
    (performance_summary).analysis_date,
    (performance_summary).total_documents,
    (performance_summary).documents_processed_today,
    (performance_summary).high_quality_documents,
    (performance_summary).critical_documents,
    (performance_summary).pii_risk_documents,
    (performance_summary).avg_quality_score,
    (performance_summary).avg_business_relevance,
    (performance_summary).total_storage_gb,
    
    -- Creative Intelligence KPIs
    (creative_insights).total_creative_assets,
    (creative_insights).creative_briefs,
    (creative_insights).unique_brands_mentioned,
    (creative_insights).positive_sentiment_assets,
    (creative_insights).avg_creative_quality,
    
    -- Financial Intelligence KPIs
    (financial_insights).total_financial_documents,
    (financial_insights).financial_reports,
    (financial_insights).unique_financial_figures,
    (financial_insights).sensitive_financial_docs,
    (financial_insights).avg_financial_quality,
    
    -- Research Intelligence KPIs
    (research_insights).total_research_documents,
    (research_insights).market_research_reports,
    (research_insights).unique_competitors_tracked,
    (research_insights).critical_research_items,
    (research_insights).avg_research_quality,
    
    -- Risk and Compliance Overview
    (performance_summary).high_risk_documents,
    (performance_summary).confidential_documents,
    (performance_summary).urgent_documents,
    
    -- System Performance
    analytics_generated_at,
    dbt_run_id,
    
    -- Detailed breakdowns (as JSON for dashboard consumption)
    TO_JSON(domain_breakdown) as domain_analytics_json,
    TO_JSON(lifecycle_analysis) as document_lifecycle_json,
    TO_JSON(temporal_trends) as temporal_trends_json

FROM consolidated_analytics