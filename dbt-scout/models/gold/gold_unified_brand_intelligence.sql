{{ config(
    materialized='table',
    tags=['gold', 'unified', 'brand', 'intelligence'],
    post_hook=[
        "SELECT metadata.emit_lineage_complete('gold_unified_brand_intelligence', '{{ var(\"job_run_id\", gen_random_uuid()) }}'::UUID)",
        "INSERT INTO metadata.quality_metrics (dataset, layer, metric_name, metric_value, dimension, measured_at, job_run_id) VALUES ('{{ this }}', 'gold', 'brand_intelligence_metrics_count', (SELECT COUNT(*) FROM {{ this }}), 'completeness', NOW(), '{{ var(\"job_run_id\", null) }}'::UUID)"
    ]
) }}

/*
  Gold Layer: Unified Brand Intelligence
  
  Executive brand performance analytics combining:
  - Scout Edge retail brand detection and transaction data
  - Drive Intelligence creative campaign and document analysis
  - Cross-channel brand attribution and effectiveness measurement
  - Creative-to-retail impact correlation and ROI analysis
  
  Refreshed: Daily at 8 AM
  SLA: Available within 2 hours of Silver layer completion
*/

WITH brand_extraction AS (
    -- Extract and standardize brand entities from both systems
    SELECT 
        source_system,
        primary_id,
        event_date,
        content_type,
        business_domain,
        geographic_segment,
        brand_touchpoint_type,
        unified_brand_impact,
        
        -- Extract individual brands from arrays/JSON
        CASE 
            WHEN source_system = 'scout_edge' THEN
                jsonb_array_elements_text(
                    CASE 
                        WHEN jsonb_typeof(brand_entities) = 'array' THEN brand_entities
                        ELSE '[]'::jsonb
                    END
                )
            WHEN source_system = 'drive_intelligence' THEN
                unnest(
                    CASE 
                        WHEN brand_entities IS NOT NULL THEN brand_entities
                        ELSE ARRAY[]::text[]
                    END
                )
            ELSE NULL
        END as brand_name,
        
        revenue_amount,
        content_volume,
        confidence_tier,
        quality_score,
        business_value,
        temporal_freshness,
        source_processed_at
        
    FROM {{ ref('silver_unified_scout_analytics') }}
    WHERE brand_engagement_count > 0
    AND event_date >= CURRENT_DATE - INTERVAL '180 days'  -- 6 months of data
    AND quality_score >= 0.4
),

-- Standardize brand names and create brand taxonomy
standardized_brands AS (
    SELECT 
        *,
        -- Standardize brand names (handle variations and aliases)
        CASE 
            WHEN UPPER(brand_name) IN ('COCA-COLA', 'COCA COLA', 'COKE', 'COCA_COLA') THEN 'Coca-Cola'
            WHEN UPPER(brand_name) IN ('PEPSI', 'PEPSI-COLA', 'PEPSI COLA') THEN 'Pepsi'
            WHEN UPPER(brand_name) IN ('NESTLE', 'NESTLÉ') THEN 'Nestle'
            WHEN UPPER(brand_name) IN ('UNILEVER', 'UL') THEN 'Unilever'
            WHEN UPPER(brand_name) IN ('P&G', 'PROCTER & GAMBLE', 'PROCTER AND GAMBLE') THEN 'P&G'
            WHEN UPPER(brand_name) IN ('JOLLIBEE', 'JB') THEN 'Jollibee'
            WHEN UPPER(brand_name) IN ('SM', 'SM SUPERMALLS', 'SM MALL') THEN 'SM'
            WHEN UPPER(brand_name) IN ('AYALA', 'AYALA LAND', 'AYALA MALLS') THEN 'Ayala'
            WHEN UPPER(brand_name) IN ('BDO', 'BDO UNIBANK') THEN 'BDO'
            WHEN UPPER(brand_name) IN ('GLOBE', 'GLOBE TELECOM') THEN 'Globe'
            WHEN UPPER(brand_name) IN ('SMART', 'SMART COMMUNICATIONS') THEN 'Smart'
            WHEN UPPER(brand_name) IN ('PLDT') THEN 'PLDT'
            WHEN UPPER(brand_name) IN ('ABS-CBN', 'ABS CBN') THEN 'ABS-CBN'
            WHEN UPPER(brand_name) IN ('GMA', 'GMA NETWORK') THEN 'GMA'
            WHEN UPPER(brand_name) IN ('SAN MIGUEL', 'SMC') THEN 'San Miguel'
            WHEN UPPER(brand_name) IN ('EMPERADOR', 'EMP') THEN 'Emperador'
            WHEN UPPER(brand_name) IN ('DEL MONTE') THEN 'Del Monte'
            WHEN UPPER(brand_name) IN ('CENTURY TUNA', 'CENTURY') THEN 'Century Tuna'
            WHEN UPPER(brand_name) IN ('ALASKA', 'ALASKA MILK') THEN 'Alaska'
            WHEN UPPER(brand_name) IN ('MAGNOLIA') THEN 'Magnolia'
            WHEN UPPER(brand_name) IN ('SELECTA') THEN 'Selecta'
            ELSE INITCAP(brand_name)
        END as standardized_brand_name,
        
        -- Brand category classification
        CASE 
            WHEN UPPER(brand_name) IN ('COCA-COLA', 'COCA COLA', 'COKE', 'PEPSI', 'PEPSI-COLA') THEN 'Beverages'
            WHEN UPPER(brand_name) IN ('NESTLE', 'DEL MONTE', 'CENTURY TUNA', 'ALASKA', 'MAGNOLIA', 'SELECTA') THEN 'Food & Nutrition'
            WHEN UPPER(brand_name) IN ('UNILEVER', 'P&G') THEN 'Personal Care & Home'
            WHEN UPPER(brand_name) IN ('JOLLIBEE') THEN 'Quick Service Restaurant'
            WHEN UPPER(brand_name) IN ('SM', 'AYALA') THEN 'Retail & Malls'
            WHEN UPPER(brand_name) IN ('BDO') THEN 'Financial Services'
            WHEN UPPER(brand_name) IN ('GLOBE', 'SMART', 'PLDT') THEN 'Telecommunications'
            WHEN UPPER(brand_name) IN ('ABS-CBN', 'GMA') THEN 'Media & Entertainment'
            WHEN UPPER(brand_name) IN ('SAN MIGUEL', 'EMPERADOR') THEN 'Alcoholic Beverages'
            ELSE 'Other'
        END as brand_category,
        
        -- Market tier classification
        CASE 
            WHEN UPPER(brand_name) IN ('COCA-COLA', 'NESTLE', 'UNILEVER', 'P&G', 'JOLLIBEE', 'SM', 'AYALA', 'BDO', 'GLOBE', 'SMART', 'ABS-CBN', 'SAN MIGUEL') THEN 'Tier 1 - Market Leader'
            WHEN UPPER(brand_name) IN ('PEPSI', 'DEL MONTE', 'CENTURY TUNA', 'ALASKA', 'MAGNOLIA', 'PLDT', 'GMA', 'EMPERADOR') THEN 'Tier 2 - Major Player'
            WHEN UPPER(brand_name) IN ('SELECTA') THEN 'Tier 3 - Niche Leader'
            ELSE 'Tier 4 - Other'
        END as brand_tier
        
    FROM brand_extraction
    WHERE brand_name IS NOT NULL
    AND LENGTH(TRIM(brand_name)) > 0
),

-- Aggregate brand performance across channels
brand_channel_performance AS (
    SELECT 
        standardized_brand_name,
        brand_category,
        brand_tier,
        source_system,
        brand_touchpoint_type,
        event_date,
        
        -- Volume metrics
        COUNT(*) as touchpoint_count,
        COUNT(DISTINCT primary_id) as unique_interactions,
        SUM(content_volume) as total_content_volume,
        
        -- Revenue attribution
        SUM(revenue_amount) as attributed_revenue,
        AVG(revenue_amount) as avg_revenue_per_touchpoint,
        COUNT(*) FILTER (WHERE revenue_amount > 0) as revenue_generating_touchpoints,
        
        -- Quality and confidence metrics
        AVG(quality_score) as avg_quality_score,
        COUNT(*) FILTER (WHERE confidence_tier = 'high_confidence') as high_confidence_touchpoints,
        COUNT(*) FILTER (WHERE confidence_tier = 'medium_confidence') as medium_confidence_touchpoints,
        
        -- Geographic distribution
        COUNT(DISTINCT geographic_segment) as geographic_reach,
        
        -- Business impact assessment
        COUNT(*) FILTER (WHERE unified_brand_impact = 'high_impact') as high_impact_touchpoints,
        COUNT(*) FILTER (WHERE unified_brand_impact = 'medium_impact') as medium_impact_touchpoints,
        COUNT(*) FILTER (WHERE unified_brand_impact = 'low_impact') as low_impact_touchpoints,
        
        -- Temporal freshness
        COUNT(*) FILTER (WHERE temporal_freshness IN ('very_fresh', 'fresh', 'current')) as fresh_touchpoints,
        
        -- Processing metadata
        MIN(source_processed_at) as earliest_processed_at,
        MAX(source_processed_at) as latest_processed_at
        
    FROM standardized_brands
    GROUP BY standardized_brand_name, brand_category, brand_tier, source_system, brand_touchpoint_type, event_date
),

-- Cross-channel brand attribution and correlation
cross_channel_analysis AS (
    SELECT 
        standardized_brand_name,
        brand_category,
        brand_tier,
        event_date,
        
        -- Cross-channel presence
        COUNT(DISTINCT source_system) as channel_presence_count,
        COUNT(DISTINCT brand_touchpoint_type) as touchpoint_type_count,
        
        -- Channel-specific metrics
        SUM(touchpoint_count) FILTER (WHERE source_system = 'scout_edge') as retail_touchpoints,
        SUM(touchpoint_count) FILTER (WHERE source_system = 'drive_intelligence') as creative_touchpoints,
        
        SUM(attributed_revenue) FILTER (WHERE source_system = 'scout_edge') as retail_attributed_revenue,
        SUM(attributed_revenue) FILTER (WHERE source_system = 'drive_intelligence') as creative_estimated_revenue,
        
        -- Quality comparison across channels
        AVG(avg_quality_score) FILTER (WHERE source_system = 'scout_edge') as retail_avg_quality,
        AVG(avg_quality_score) FILTER (WHERE source_system = 'drive_intelligence') as creative_avg_quality,
        
        -- Confidence comparison
        SUM(high_confidence_touchpoints) FILTER (WHERE source_system = 'scout_edge') as retail_high_confidence,
        SUM(high_confidence_touchpoints) FILTER (WHERE source_system = 'drive_intelligence') as creative_high_confidence,
        
        -- Geographic reach comparison
        MAX(geographic_reach) FILTER (WHERE source_system = 'scout_edge') as retail_geographic_reach,
        MAX(geographic_reach) FILTER (WHERE source_system = 'drive_intelligence') as creative_geographic_reach,
        
        -- Business impact aggregation
        SUM(high_impact_touchpoints) as total_high_impact,
        SUM(medium_impact_touchpoints) as total_medium_impact,
        SUM(low_impact_touchpoints) as total_low_impact,
        
        -- Total performance
        SUM(touchpoint_count) as total_touchpoints,
        SUM(unique_interactions) as total_unique_interactions,
        SUM(attributed_revenue) as total_attributed_revenue,
        AVG(avg_quality_score) as overall_avg_quality
        
    FROM brand_channel_performance
    GROUP BY standardized_brand_name, brand_category, brand_tier, event_date
),

-- Weekly and monthly aggregations
brand_temporal_performance AS (
    SELECT 
        standardized_brand_name,
        brand_category,
        brand_tier,
        DATE_TRUNC('week', event_date) as week_start,
        DATE_TRUNC('month', event_date) as month_start,
        
        -- Weekly metrics
        SUM(total_touchpoints) as weekly_touchpoints,
        SUM(total_attributed_revenue) as weekly_revenue,
        AVG(overall_avg_quality) as weekly_avg_quality,
        COUNT(DISTINCT event_date) as active_days_in_week,
        
        -- Cross-channel presence
        AVG(channel_presence_count) as avg_channel_presence,
        SUM(retail_touchpoints) as weekly_retail_touchpoints,
        SUM(creative_touchpoints) as weekly_creative_touchpoints,
        
        -- Performance indicators
        SUM(total_high_impact) as weekly_high_impact,
        SUM(retail_attributed_revenue) as weekly_retail_revenue,
        SUM(creative_estimated_revenue) as weekly_creative_revenue,
        
        -- Growth calculation helpers
        LAG(SUM(total_attributed_revenue)) OVER (
            PARTITION BY standardized_brand_name 
            ORDER BY DATE_TRUNC('week', event_date)
        ) as prev_week_revenue
        
    FROM cross_channel_analysis
    GROUP BY standardized_brand_name, brand_category, brand_tier, DATE_TRUNC('week', event_date), DATE_TRUNC('month', event_date)
),

-- Growth rate calculations
brand_growth_analysis AS (
    SELECT *,
        CASE 
            WHEN prev_week_revenue > 0 
            THEN ROUND(
                ((weekly_revenue - prev_week_revenue)::FLOAT / prev_week_revenue * 100), 
                2
            )
            ELSE NULL 
        END as week_over_week_revenue_growth_pct
    FROM brand_temporal_performance
),

-- Top brand performance summary (last 30 days)
top_brand_performance AS (
    SELECT 
        standardized_brand_name,
        brand_category,
        brand_tier,
        
        -- Performance metrics (last 30 days)
        SUM(total_touchpoints) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as touchpoints_30d,
        SUM(total_attributed_revenue) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as revenue_30d,
        AVG(overall_avg_quality) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as avg_quality_30d,
        
        -- Channel distribution
        AVG(channel_presence_count) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as avg_channel_presence_30d,
        SUM(retail_touchpoints) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as retail_touchpoints_30d,
        SUM(creative_touchpoints) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as creative_touchpoints_30d,
        
        -- Geographic and impact reach
        MAX(retail_geographic_reach) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as max_retail_reach_30d,
        MAX(creative_geographic_reach) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as max_creative_reach_30d,
        SUM(total_high_impact) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as high_impact_30d,
        
        -- Confidence and quality indicators
        AVG(retail_avg_quality) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as retail_quality_30d,
        AVG(creative_avg_quality) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as creative_quality_30d,
        
        -- Activity metrics
        COUNT(DISTINCT event_date) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as active_days_30d,
        MAX(event_date) as last_activity_date,
        
        -- Growth indicators
        AVG(week_over_week_revenue_growth_pct) FILTER (WHERE week_start >= CURRENT_DATE - INTERVAL '8 weeks') as avg_growth_rate_8w
        
    FROM cross_channel_analysis cca
    LEFT JOIN brand_growth_analysis bga ON cca.standardized_brand_name = bga.standardized_brand_name 
        AND cca.event_date >= bga.week_start 
        AND cca.event_date < bga.week_start + INTERVAL '7 days'
    GROUP BY standardized_brand_name, brand_category, brand_tier
),

-- Executive brand intelligence summary
executive_brand_summary AS (
    SELECT 
        'unified_brand_intelligence' as analytics_domain,
        CURRENT_DATE as report_date,
        
        -- Brand portfolio overview
        COUNT(DISTINCT standardized_brand_name) as total_brands_tracked,
        COUNT(DISTINCT standardized_brand_name) FILTER (WHERE touchpoints_30d > 0) as active_brands_30d,
        COUNT(DISTINCT brand_category) as brand_categories_covered,
        
        -- Performance distribution
        COUNT(*) FILTER (WHERE brand_tier = 'Tier 1 - Market Leader') as tier1_brands,
        COUNT(*) FILTER (WHERE brand_tier = 'Tier 2 - Major Player') as tier2_brands,
        COUNT(*) FILTER (WHERE brand_tier = 'Tier 3 - Niche Leader') as tier3_brands,
        
        -- Business impact (last 30 days)
        SUM(touchpoints_30d) as total_brand_touchpoints_30d,
        SUM(revenue_30d) as total_brand_revenue_30d,
        AVG(revenue_30d) as avg_brand_revenue_30d,
        
        -- Cross-channel effectiveness
        AVG(avg_channel_presence_30d) as avg_cross_channel_presence,
        SUM(retail_touchpoints_30d) as total_retail_touchpoints_30d,
        SUM(creative_touchpoints_30d) as total_creative_touchpoints_30d,
        
        -- Quality indicators
        AVG(avg_quality_30d) as network_brand_quality_30d,
        AVG(retail_quality_30d) as avg_retail_brand_quality_30d,
        AVG(creative_quality_30d) as avg_creative_brand_quality_30d,
        
        -- Growth indicators
        AVG(avg_growth_rate_8w) as avg_brand_growth_rate_8w,
        COUNT(*) FILTER (WHERE avg_growth_rate_8w > 10) as high_growth_brands,
        COUNT(*) FILTER (WHERE avg_growth_rate_8w < -10) as declining_brands,
        
        -- Geographic reach
        AVG(max_retail_reach_30d) as avg_retail_geographic_reach,
        AVG(max_creative_reach_30d) as avg_creative_geographic_reach,
        
        -- Data freshness
        MAX(last_activity_date) as latest_brand_activity_date,
        COUNT(*) FILTER (WHERE last_activity_date >= CURRENT_DATE - INTERVAL '7 days') as recently_active_brands,
        
        -- Top performer identification
        (SELECT standardized_brand_name FROM top_brand_performance ORDER BY revenue_30d DESC LIMIT 1) as top_revenue_brand,
        (SELECT standardized_brand_name FROM top_brand_performance ORDER BY touchpoints_30d DESC LIMIT 1) as most_active_brand,
        (SELECT standardized_brand_name FROM top_brand_performance ORDER BY avg_growth_rate_8w DESC LIMIT 1) as fastest_growing_brand,
        
        -- Metadata
        NOW() as calculated_at,
        '{{ var("job_run_id", "unknown") }}' as job_run_id
        
    FROM top_brand_performance
)

-- Final unified brand intelligence results
SELECT 
    'executive_summary' as metric_type,
    'brand_portfolio' as metric_category,
    'overview' as metric_subcategory,
    total_brands_tracked::text as metric_value,
    'brands' as metric_unit,
    'Total brands tracked across all channels' as metric_description,
    report_date as metric_date,
    calculated_at,
    job_run_id
FROM executive_brand_summary

UNION ALL

SELECT 'executive_summary', 'brand_portfolio', 'activity', active_brands_30d::text, 'brands', 'Active brands in last 30 days', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'brand_portfolio', 'coverage', brand_categories_covered::text, 'categories', 'Brand categories with coverage', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'performance', 'touchpoints', total_brand_touchpoints_30d::text, 'touchpoints', 'Total brand touchpoints in last 30 days', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'performance', 'revenue', ROUND(total_brand_revenue_30d, 2)::text, 'PHP', 'Total brand-attributed revenue in last 30 days', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'channel_effectiveness', 'retail', total_retail_touchpoints_30d::text, 'touchpoints', 'Retail brand touchpoints (Scout Edge)', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'channel_effectiveness', 'creative', total_creative_touchpoints_30d::text, 'touchpoints', 'Creative brand touchpoints (Drive Intelligence)', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'quality', 'overall', ROUND(network_brand_quality_30d * 100, 1)::text, 'percent', 'Overall brand detection quality score', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'growth', 'average', ROUND(avg_brand_growth_rate_8w, 1)::text, 'percent', 'Average brand growth rate (8 weeks)', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'top_performers', 'revenue_leader', top_revenue_brand, 'brand', 'Top revenue-generating brand (30 days)', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'top_performers', 'activity_leader', most_active_brand, 'brand', 'Most active brand across channels (30 days)', report_date, calculated_at, job_run_id FROM executive_brand_summary
UNION ALL
SELECT 'executive_summary', 'top_performers', 'growth_leader', fastest_growing_brand, 'brand', 'Fastest growing brand (8 weeks)', report_date, calculated_at, job_run_id FROM executive_brand_summary

UNION ALL

-- Brand performance details
SELECT 
    'brand_performance' as metric_type,
    standardized_brand_name as metric_category,
    brand_tier as metric_subcategory,
    revenue_30d::text as metric_value,
    'PHP' as metric_unit,
    'Brand revenue performance (30 days)' as metric_description,
    last_activity_date as metric_date,
    NOW() as calculated_at,
    '{{ var("job_run_id", "unknown") }}' as job_run_id
FROM top_brand_performance
WHERE touchpoints_30d > 0

ORDER BY metric_type, metric_category, metric_subcategory