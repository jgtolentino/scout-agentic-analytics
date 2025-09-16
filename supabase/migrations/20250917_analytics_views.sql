-- Advanced Analytics Views for Market Intelligence
-- Comprehensive business intelligence views for Scout Edge platform
-- Created: 2025-09-17

BEGIN;

-- =============================================
-- ADVANCED ANALYTICS VIEWS
-- =============================================

-- Brand Performance Dashboard
CREATE OR REPLACE VIEW analytics.brand_performance_dashboard AS
SELECT 
    bm.brand_name,
    bm.official_name,
    bm.parent_company,
    bm.category,
    bm.market_share_percent,
    bm.consumer_reach_points,
    bm.crp_rank,
    bm.position_type,
    bm.price_positioning,
    bm.brand_growth_yoy,
    
    -- Pricing Intelligence
    AVG(rp.srp_php) as avg_price_php,
    MIN(rp.srp_php) as min_price_php,
    MAX(rp.srp_php) as max_price_php,
    STDDEV(rp.srp_php) as price_volatility,
    AVG(rp.price_index) as vs_category_avg,
    
    -- Channel Performance
    COUNT(DISTINCT rp.channel) as channels_available,
    string_agg(DISTINCT rp.channel, ', ' ORDER BY rp.channel) as channel_list,
    
    -- Market Context
    mi.market_size_php as category_size_php,
    mi.cagr_percent as category_growth,
    
    -- Detection Intelligence
    bdi.detection_accuracy,
    bdi.market_share_weight,
    bdi.crp_weight,
    
    -- Competitive Metrics
    COUNT(DISTINCT cb.competitor_brand) as direct_competitors,
    
    -- Performance Tier Classification
    CASE 
        WHEN bm.consumer_reach_points >= 500 THEN 'Tier 1 - National Leader'
        WHEN bm.consumer_reach_points >= 200 THEN 'Tier 2 - Strong Brand'
        WHEN bm.consumer_reach_points >= 100 THEN 'Tier 3 - Established'
        ELSE 'Tier 4 - Emerging/Niche'
    END as brand_tier,
    
    -- Value Proposition
    CASE 
        WHEN AVG(rp.price_index) > 1.2 THEN 'Premium'
        WHEN AVG(rp.price_index) > 0.9 THEN 'Mainstream' 
        ELSE 'Value'
    END as value_proposition,
    
    -- Growth Classification
    CASE 
        WHEN bm.brand_growth_yoy > 10 THEN 'High Growth'
        WHEN bm.brand_growth_yoy > 5 THEN 'Moderate Growth'
        WHEN bm.brand_growth_yoy > 0 THEN 'Stable'
        ELSE 'Declining'
    END as growth_status,
    
    -- Last Update
    GREATEST(bm.updated_at, MAX(rp.created_at), bdi.updated_at) as last_updated

FROM metadata.brand_metrics bm
LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name
    AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'
LEFT JOIN metadata.market_intelligence mi ON bm.category = mi.category
LEFT JOIN metadata.brand_detection_intelligence bdi ON bm.brand_name = bdi.brand_name
LEFT JOIN metadata.competitor_benchmarks cb ON bm.brand_name = cb.primary_brand

GROUP BY 
    bm.brand_name, bm.official_name, bm.parent_company, bm.category,
    bm.market_share_percent, bm.consumer_reach_points, bm.crp_rank,
    bm.position_type, bm.price_positioning, bm.brand_growth_yoy,
    mi.market_size_php, mi.cagr_percent, bdi.detection_accuracy,
    bdi.market_share_weight, bdi.crp_weight, bm.updated_at, bdi.updated_at

ORDER BY bm.consumer_reach_points DESC NULLS LAST;

-- Category Deep Dive Analysis
CREATE OR REPLACE VIEW analytics.category_deep_dive AS
SELECT 
    mi.category,
    mi.market_size_php,
    mi.market_size_usd,
    mi.cagr_percent,
    mi.market_concentration,
    mi.penetration_percent,
    mi.consumption_per_capita_php,
    
    -- Brand Analysis
    COUNT(bm.brand_name) as total_brands,
    COUNT(bm.brand_name) FILTER (WHERE bm.market_share_percent >= 10) as major_brands,
    COUNT(bm.brand_name) FILTER (WHERE bm.position_type = 'leader') as market_leaders,
    
    -- Market Share Distribution
    SUM(bm.market_share_percent) as total_tracked_share,
    MAX(bm.market_share_percent) as leader_share,
    AVG(bm.market_share_percent) as avg_brand_share,
    
    -- CRP Analysis  
    SUM(bm.consumer_reach_points) as total_category_crp,
    MAX(bm.consumer_reach_points) as top_brand_crp,
    AVG(bm.consumer_reach_points) as avg_brand_crp,
    
    -- Price Analysis
    AVG(rp.srp_php) as avg_category_price,
    MIN(rp.srp_php) as lowest_price,
    MAX(rp.srp_php) as highest_price,
    STDDEV(rp.srp_php) as price_spread,
    
    -- Growth Analysis
    AVG(bm.brand_growth_yoy) as avg_brand_growth,
    MAX(bm.brand_growth_yoy) as fastest_growth,
    MIN(bm.brand_growth_yoy) as slowest_growth,
    
    -- Channel Distribution
    COUNT(DISTINCT rp.channel) as channels_served,
    string_agg(DISTINCT rp.channel, ', ' ORDER BY rp.channel) as channel_presence,
    
    -- Competitive Intensity
    AVG(
        (SELECT COUNT(*) FROM metadata.competitor_benchmarks cb2 
         WHERE cb2.primary_brand = bm.brand_name)
    ) as avg_competitors_per_brand,
    
    -- Key Insights
    array_agg(DISTINCT mi.key_trends) as market_trends,
    array_agg(DISTINCT mi.growth_drivers) as growth_drivers,
    array_agg(DISTINCT mi.challenges) as market_challenges,
    
    -- Category Health Score (0-100)
    LEAST(100, GREATEST(0,
        -- Market size factor (30%)
        (CASE WHEN mi.market_size_php > 50000 THEN 30 
              WHEN mi.market_size_php > 20000 THEN 25
              WHEN mi.market_size_php > 10000 THEN 20
              ELSE 15 END) +
        -- Growth factor (25%)
        (CASE WHEN mi.cagr_percent > 8 THEN 25
              WHEN mi.cagr_percent > 5 THEN 20
              WHEN mi.cagr_percent > 2 THEN 15
              ELSE 10 END) +
        -- Competition factor (20%)
        (CASE WHEN mi.market_concentration = 'high' THEN 15
              WHEN mi.market_concentration = 'medium' THEN 20
              ELSE 10 END) +
        -- Penetration factor (15%)
        (CASE WHEN mi.penetration_percent > 80 THEN 15
              WHEN mi.penetration_percent > 60 THEN 12
              WHEN mi.penetration_percent > 40 THEN 8
              ELSE 5 END) +
        -- Brand diversity factor (10%)
        (CASE WHEN COUNT(bm.brand_name) > 10 THEN 10
              WHEN COUNT(bm.brand_name) > 5 THEN 8
              WHEN COUNT(bm.brand_name) > 3 THEN 6
              ELSE 4 END)
    )) as category_health_score,
    
    -- Data Quality
    mi.confidence_score as data_confidence,
    mi.data_freshness

FROM metadata.market_intelligence mi
LEFT JOIN metadata.brand_metrics bm ON mi.category = bm.category
LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name 
    AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'

GROUP BY 
    mi.category, mi.market_size_php, mi.market_size_usd, mi.cagr_percent,
    mi.market_concentration, mi.penetration_percent, mi.consumption_per_capita_php,
    mi.key_trends, mi.growth_drivers, mi.challenges, mi.confidence_score, mi.data_freshness

ORDER BY mi.market_size_php DESC NULLS LAST;

-- Competitive Landscape Matrix
CREATE OR REPLACE VIEW analytics.competitive_landscape_matrix AS
SELECT 
    cb.category,
    cb.primary_brand,
    cb.competitor_brand,
    cb.comparison_type,
    
    -- Market Share Comparison
    cb.primary_share,
    cb.competitor_share,
    cb.share_gap,
    CASE 
        WHEN ABS(cb.share_gap) <= 2 THEN 'Neck-and-neck'
        WHEN cb.share_gap > 2 THEN 'Primary leads'
        ELSE 'Competitor leads'
    END as share_position,
    
    -- CRP Comparison  
    cb.primary_crp,
    cb.competitor_crp,
    cb.reach_advantage,
    
    -- Pricing Comparison
    p1.avg_price as primary_avg_price,
    p2.avg_price as competitor_avg_price,
    ROUND(((p1.avg_price - p2.avg_price) / p2.avg_price * 100)::numeric, 1) as price_premium_percent,
    
    -- Growth Comparison
    bm1.brand_growth_yoy as primary_growth,
    bm2.brand_growth_yoy as competitor_growth,
    (bm1.brand_growth_yoy - bm2.brand_growth_yoy) as growth_advantage,
    
    -- Position Analysis
    bm1.position_type as primary_position,
    bm2.position_type as competitor_position,
    bm1.price_positioning as primary_price_pos,
    bm2.price_positioning as competitor_price_pos,
    
    -- Competitive Intensity
    cb.competitive_intensity,
    cb.threat_level,
    
    -- Strategic Assessment
    CASE 
        WHEN cb.share_gap > 10 AND cb.reach_advantage > 100 THEN 'Dominant'
        WHEN cb.share_gap > 5 AND cb.reach_advantage > 50 THEN 'Leading'
        WHEN ABS(cb.share_gap) <= 5 THEN 'Competitive'
        WHEN cb.share_gap < -5 THEN 'Trailing'
        ELSE 'Niche'
    END as competitive_status,
    
    -- Opportunity Assessment
    CASE 
        WHEN p1.avg_price < p2.avg_price AND cb.primary_share < cb.competitor_share THEN 'Value Advantage Underutilized'
        WHEN p1.avg_price > p2.avg_price AND cb.primary_share > cb.competitor_share THEN 'Premium Position Justified'
        WHEN bm1.brand_growth_yoy > bm2.brand_growth_yoy + 5 THEN 'Gaining Momentum'
        WHEN bm2.brand_growth_yoy > bm1.brand_growth_yoy + 5 THEN 'Losing Ground'
        ELSE 'Stable Competition'
    END as strategic_insight,
    
    cb.benchmark_date,
    cb.confidence_score

FROM metadata.competitor_benchmarks cb
LEFT JOIN metadata.brand_metrics bm1 ON cb.primary_brand = bm1.brand_name
LEFT JOIN metadata.brand_metrics bm2 ON cb.competitor_brand = bm2.brand_name
LEFT JOIN (
    SELECT brand_name, AVG(srp_php) as avg_price 
    FROM metadata.retail_pricing 
    WHERE price_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY brand_name
) p1 ON cb.primary_brand = p1.brand_name
LEFT JOIN (
    SELECT brand_name, AVG(srp_php) as avg_price 
    FROM metadata.retail_pricing 
    WHERE price_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY brand_name
) p2 ON cb.competitor_brand = p2.brand_name

ORDER BY cb.category, cb.primary_share DESC NULLS LAST;

-- Price Intelligence Dashboard
CREATE OR REPLACE VIEW analytics.price_intelligence_dashboard AS
SELECT 
    rp.brand_name,
    rp.sku_description,
    rp.pack_size,
    rp.category,
    
    -- Current Pricing
    rp.srp_php,
    rp.actual_retail_php,
    rp.channel,
    rp.region,
    
    -- Competitive Context
    rp.category_avg_php,
    rp.price_index,
    rp.competitor_avg_php,
    
    -- Value Metrics
    rp.price_per_gram,
    rp.price_per_serving,
    rp.value_score,
    
    -- Market Position
    CASE 
        WHEN rp.price_index >= 1.3 THEN 'Ultra Premium'
        WHEN rp.price_index >= 1.15 THEN 'Premium'
        WHEN rp.price_index >= 0.9 THEN 'Mainstream'
        WHEN rp.price_index >= 0.75 THEN 'Value'
        ELSE 'Economy'
    END as price_tier,
    
    -- Price Trends (comparing to 90-day average)
    rp.srp_php - LAG(rp.srp_php, 1) OVER (
        PARTITION BY rp.brand_name, rp.sku_description 
        ORDER BY rp.price_date
    ) as price_change_php,
    
    -- Inflation Analysis
    rp.inflation_adjusted_price,
    ROUND((rp.srp_php / rp.inflation_adjusted_price - 1) * 100, 1) as inflation_impact_percent,
    
    -- Channel Analysis
    AVG(rp.srp_php) OVER (PARTITION BY rp.brand_name, rp.channel) as channel_avg_price,
    rp.srp_php - AVG(rp.srp_php) OVER (PARTITION BY rp.brand_name, rp.channel) as vs_channel_avg,
    
    -- Regional Analysis
    AVG(rp.srp_php) OVER (PARTITION BY rp.brand_name, rp.region) as regional_avg_price,
    rp.srp_php - AVG(rp.srp_php) OVER (PARTITION BY rp.brand_name, rp.region) as vs_regional_avg,
    
    -- Promotional Status
    rp.is_promotional,
    rp.promotion_type,
    
    -- Data Quality
    rp.price_source,
    rp.confidence_level,
    rp.price_date,
    
    -- Alerts
    CASE 
        WHEN rp.price_index > 1.5 THEN 'High Premium Alert'
        WHEN rp.price_index < 0.6 THEN 'Deep Discount Alert'
        WHEN rp.confidence_level < 0.7 THEN 'Data Quality Alert'
        WHEN rp.price_date < CURRENT_DATE - INTERVAL '30 days' THEN 'Stale Data Alert'
        ELSE 'Normal'
    END as price_alert

FROM metadata.retail_pricing rp
WHERE rp.price_date >= CURRENT_DATE - INTERVAL '180 days'
ORDER BY rp.brand_name, rp.price_date DESC;

-- Market Opportunity Analysis
CREATE OR REPLACE VIEW analytics.market_opportunity_analysis AS
SELECT 
    mi.category,
    mi.market_size_php,
    mi.cagr_percent,
    mi.penetration_percent,
    
    -- Market Characteristics
    mi.market_concentration,
    mi.key_trends,
    mi.growth_drivers,
    mi.challenges,
    
    -- Category Leader Analysis
    bm_leader.brand_name as market_leader,
    bm_leader.market_share_percent as leader_share,
    bm_leader.consumer_reach_points as leader_crp,
    
    -- Market Gaps Analysis
    (100 - COALESCE(SUM(bm.market_share_percent), 0)) as untracked_share,
    COUNT(bm.brand_name) as tracked_brands,
    
    -- Price Opportunity
    MAX(rp.srp_php) - MIN(rp.srp_php) as price_range_php,
    STDDEV(rp.srp_php) as price_volatility,
    AVG(rp.price_index) as avg_price_positioning,
    
    -- Growth Opportunity Score (0-100)
    LEAST(100, GREATEST(0,
        -- Market size factor (25%)
        (CASE WHEN mi.market_size_php > 100000 THEN 25
              WHEN mi.market_size_php > 50000 THEN 20
              WHEN mi.market_size_php > 20000 THEN 15
              ELSE 10 END) +
        -- Growth rate factor (30%)
        (CASE WHEN mi.cagr_percent > 10 THEN 30
              WHEN mi.cagr_percent > 7 THEN 25
              WHEN mi.cagr_percent > 4 THEN 20
              ELSE 10 END) +
        -- Penetration gap factor (20%)
        (CASE WHEN mi.penetration_percent < 70 THEN 20
              WHEN mi.penetration_percent < 85 THEN 15
              WHEN mi.penetration_percent < 95 THEN 10
              ELSE 5 END) +
        -- Market concentration factor (15%)
        (CASE WHEN mi.market_concentration = 'low' THEN 15
              WHEN mi.market_concentration = 'medium' THEN 12
              ELSE 8 END) +
        -- Untracked share factor (10%)
        (CASE WHEN (100 - COALESCE(SUM(bm.market_share_percent), 0)) > 30 THEN 10
              WHEN (100 - COALESCE(SUM(bm.market_share_percent), 0)) > 15 THEN 7
              ELSE 4 END)
    )) as opportunity_score,
    
    -- Opportunity Classification
    CASE 
        WHEN mi.cagr_percent > 10 AND mi.penetration_percent < 80 THEN 'High Growth + Low Penetration'
        WHEN mi.cagr_percent > 8 THEN 'High Growth Market'
        WHEN mi.penetration_percent < 70 THEN 'Penetration Opportunity'
        WHEN mi.market_concentration = 'low' THEN 'Fragmented Market'
        WHEN (100 - COALESCE(SUM(bm.market_share_percent), 0)) > 25 THEN 'Share Gap Opportunity'
        ELSE 'Mature Market'
    END as opportunity_type,
    
    -- Key Recommendations
    CASE 
        WHEN mi.cagr_percent > 10 AND mi.market_concentration = 'low' THEN 
            'Fast-growing fragmented market - consider aggressive expansion'
        WHEN mi.penetration_percent < 70 AND mi.market_size_php > 50000 THEN 
            'Large addressable market with room for penetration growth'
        WHEN (100 - COALESCE(SUM(bm.market_share_percent), 0)) > 30 THEN 
            'Significant untracked share suggests niche brand opportunities'
        WHEN STDDEV(rp.srp_php) > AVG(rp.srp_php) * 0.3 THEN 
            'High price volatility suggests pricing optimization opportunity'
        ELSE 'Monitor competitive dynamics and defend position'
    END as strategic_recommendation,
    
    -- Regional Opportunities
    CASE 
        WHEN mi.metro_manila_share > 50 THEN 'Expand to provincial markets'
        WHEN mi.mindanao_share < 15 THEN 'Mindanao expansion opportunity' 
        WHEN mi.visayas_share < 20 THEN 'Visayas market development'
        ELSE 'Well-distributed market'
    END as geographic_opportunity,
    
    mi.data_freshness,
    mi.confidence_score

FROM metadata.market_intelligence mi
LEFT JOIN metadata.brand_metrics bm ON mi.category = bm.category
LEFT JOIN metadata.brand_metrics bm_leader ON mi.category = bm_leader.category 
    AND bm_leader.market_share_rank = 1
LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name
    AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'

GROUP BY 
    mi.category, mi.market_size_php, mi.cagr_percent, mi.penetration_percent,
    mi.market_concentration, mi.key_trends, mi.growth_drivers, mi.challenges,
    bm_leader.brand_name, bm_leader.market_share_percent, bm_leader.consumer_reach_points,
    mi.metro_manila_share, mi.mindanao_share, mi.visayas_share,
    mi.data_freshness, mi.confidence_score

ORDER BY 
    (LEAST(100, GREATEST(0,
        (CASE WHEN mi.market_size_php > 100000 THEN 25 WHEN mi.market_size_php > 50000 THEN 20 WHEN mi.market_size_php > 20000 THEN 15 ELSE 10 END) +
        (CASE WHEN mi.cagr_percent > 10 THEN 30 WHEN mi.cagr_percent > 7 THEN 25 WHEN mi.cagr_percent > 4 THEN 20 ELSE 10 END) +
        (CASE WHEN mi.penetration_percent < 70 THEN 20 WHEN mi.penetration_percent < 85 THEN 15 WHEN mi.penetration_percent < 95 THEN 10 ELSE 5 END) +
        (CASE WHEN mi.market_concentration = 'low' THEN 15 WHEN mi.market_concentration = 'medium' THEN 12 ELSE 8 END) +
        (CASE WHEN (100 - COALESCE(SUM(bm.market_share_percent), 0)) > 30 THEN 10 WHEN (100 - COALESCE(SUM(bm.market_share_percent), 0)) > 15 THEN 7 ELSE 4 END)
    ))) DESC;

-- Brand Health Index
CREATE OR REPLACE VIEW analytics.brand_health_index AS
SELECT 
    bm.brand_name,
    bm.category,
    bm.parent_company,
    
    -- Core Metrics
    bm.market_share_percent,
    bm.consumer_reach_points,
    bm.brand_growth_yoy,
    bm.household_penetration,
    
    -- Pricing Health
    AVG(rp.price_index) as avg_price_index,
    STDDEV(rp.srp_php) as price_stability,
    
    -- Market Context
    mi.market_size_php as category_size,
    mi.cagr_percent as category_growth,
    
    -- Competitive Position
    COUNT(cb.competitor_brand) as direct_competitors,
    bm.position_type,
    
    -- Brand Health Score (0-100)
    LEAST(100, GREATEST(0,
        -- Market Share Factor (25%)
        (CASE WHEN bm.market_share_percent > 25 THEN 25
              WHEN bm.market_share_percent > 15 THEN 20
              WHEN bm.market_share_percent > 10 THEN 15
              WHEN bm.market_share_percent > 5 THEN 10
              ELSE 5 END) +
        -- Growth Factor (25%)
        (CASE WHEN bm.brand_growth_yoy > 15 THEN 25
              WHEN bm.brand_growth_yoy > 10 THEN 20
              WHEN bm.brand_growth_yoy > 5 THEN 15
              WHEN bm.brand_growth_yoy > 0 THEN 10
              ELSE 0 END) +
        -- Consumer Reach Factor (20%)
        (CASE WHEN bm.consumer_reach_points > 500 THEN 20
              WHEN bm.consumer_reach_points > 300 THEN 16
              WHEN bm.consumer_reach_points > 150 THEN 12
              WHEN bm.consumer_reach_points > 50 THEN 8
              ELSE 4 END) +
        -- Price Positioning Factor (15%)
        (CASE WHEN AVG(rp.price_index) BETWEEN 0.9 AND 1.2 THEN 15
              WHEN AVG(rp.price_index) BETWEEN 0.7 AND 1.4 THEN 12
              WHEN AVG(rp.price_index) BETWEEN 0.5 AND 1.6 THEN 8
              ELSE 4 END) +
        -- Penetration Factor (15%)
        (CASE WHEN bm.household_penetration > 70 THEN 15
              WHEN bm.household_penetration > 50 THEN 12
              WHEN bm.household_penetration > 30 THEN 8
              WHEN bm.household_penetration > 10 THEN 5
              ELSE 2 END)
    )) as brand_health_score,
    
    -- Health Classification
    CASE 
        WHEN (LEAST(100, GREATEST(0,
            (CASE WHEN bm.market_share_percent > 25 THEN 25 WHEN bm.market_share_percent > 15 THEN 20 WHEN bm.market_share_percent > 10 THEN 15 WHEN bm.market_share_percent > 5 THEN 10 ELSE 5 END) +
            (CASE WHEN bm.brand_growth_yoy > 15 THEN 25 WHEN bm.brand_growth_yoy > 10 THEN 20 WHEN bm.brand_growth_yoy > 5 THEN 15 WHEN bm.brand_growth_yoy > 0 THEN 10 ELSE 0 END) +
            (CASE WHEN bm.consumer_reach_points > 500 THEN 20 WHEN bm.consumer_reach_points > 300 THEN 16 WHEN bm.consumer_reach_points > 150 THEN 12 WHEN bm.consumer_reach_points > 50 THEN 8 ELSE 4 END) +
            (CASE WHEN AVG(rp.price_index) BETWEEN 0.9 AND 1.2 THEN 15 WHEN AVG(rp.price_index) BETWEEN 0.7 AND 1.4 THEN 12 WHEN AVG(rp.price_index) BETWEEN 0.5 AND 1.6 THEN 8 ELSE 4 END) +
            (CASE WHEN bm.household_penetration > 70 THEN 15 WHEN bm.household_penetration > 50 THEN 12 WHEN bm.household_penetration > 30 THEN 8 WHEN bm.household_penetration > 10 THEN 5 ELSE 2 END)
        ))) >= 80 THEN 'Excellent'
        WHEN (LEAST(100, GREATEST(0,
            (CASE WHEN bm.market_share_percent > 25 THEN 25 WHEN bm.market_share_percent > 15 THEN 20 WHEN bm.market_share_percent > 10 THEN 15 WHEN bm.market_share_percent > 5 THEN 10 ELSE 5 END) +
            (CASE WHEN bm.brand_growth_yoy > 15 THEN 25 WHEN bm.brand_growth_yoy > 10 THEN 20 WHEN bm.brand_growth_yoy > 5 THEN 15 WHEN bm.brand_growth_yoy > 0 THEN 10 ELSE 0 END) +
            (CASE WHEN bm.consumer_reach_points > 500 THEN 20 WHEN bm.consumer_reach_points > 300 THEN 16 WHEN bm.consumer_reach_points > 150 THEN 12 WHEN bm.consumer_reach_points > 50 THEN 8 ELSE 4 END) +
            (CASE WHEN AVG(rp.price_index) BETWEEN 0.9 AND 1.2 THEN 15 WHEN AVG(rp.price_index) BETWEEN 0.7 AND 1.4 THEN 12 WHEN AVG(rp.price_index) BETWEEN 0.5 AND 1.6 THEN 8 ELSE 4 END) +
            (CASE WHEN bm.household_penetration > 70 THEN 15 WHEN bm.household_penetration > 50 THEN 12 WHEN bm.household_penetration > 30 THEN 8 WHEN bm.household_penetration > 10 THEN 5 ELSE 2 END)
        ))) >= 65 THEN 'Good'
        WHEN (LEAST(100, GREATEST(0,
            (CASE WHEN bm.market_share_percent > 25 THEN 25 WHEN bm.market_share_percent > 15 THEN 20 WHEN bm.market_share_percent > 10 THEN 15 WHEN bm.market_share_percent > 5 THEN 10 ELSE 5 END) +
            (CASE WHEN bm.brand_growth_yoy > 15 THEN 25 WHEN bm.brand_growth_yoy > 10 THEN 20 WHEN bm.brand_growth_yoy > 5 THEN 15 WHEN bm.brand_growth_yoy > 0 THEN 10 ELSE 0 END) +
            (CASE WHEN bm.consumer_reach_points > 500 THEN 20 WHEN bm.consumer_reach_points > 300 THEN 16 WHEN bm.consumer_reach_points > 150 THEN 12 WHEN bm.consumer_reach_points > 50 THEN 8 ELSE 4 END) +
            (CASE WHEN AVG(rp.price_index) BETWEEN 0.9 AND 1.2 THEN 15 WHEN AVG(rp.price_index) BETWEEN 0.7 AND 1.4 THEN 12 WHEN AVG(rp.price_index) BETWEEN 0.5 AND 1.6 THEN 8 ELSE 4 END) +
            (CASE WHEN bm.household_penetration > 70 THEN 15 WHEN bm.household_penetration > 50 THEN 12 WHEN bm.household_penetration > 30 THEN 8 WHEN bm.household_penetration > 10 THEN 5 ELSE 2 END)
        ))) >= 50 THEN 'Fair'
        ELSE 'Needs Attention'
    END as health_classification,
    
    -- Key Strengths and Weaknesses
    ARRAY[
        CASE WHEN bm.market_share_percent > 20 THEN 'Strong Market Position' END,
        CASE WHEN bm.brand_growth_yoy > 10 THEN 'High Growth' END,
        CASE WHEN bm.consumer_reach_points > 400 THEN 'Excellent Consumer Reach' END,
        CASE WHEN AVG(rp.price_index) BETWEEN 0.95 AND 1.15 THEN 'Optimal Price Positioning' END,
        CASE WHEN bm.household_penetration > 60 THEN 'High Penetration' END
    ] as strengths,
    
    ARRAY[
        CASE WHEN bm.market_share_percent < 5 THEN 'Low Market Share' END,
        CASE WHEN bm.brand_growth_yoy < 0 THEN 'Declining Growth' END,
        CASE WHEN bm.consumer_reach_points < 100 THEN 'Limited Consumer Reach' END,
        CASE WHEN AVG(rp.price_index) > 1.3 THEN 'Premium Pricing Risk' END,
        CASE WHEN AVG(rp.price_index) < 0.7 THEN 'Value Trap Risk' END,
        CASE WHEN bm.household_penetration < 30 THEN 'Low Penetration' END
    ] as areas_for_improvement,
    
    bm.data_freshness,
    bm.confidence_score

FROM metadata.brand_metrics bm
LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name
    AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'
LEFT JOIN metadata.market_intelligence mi ON bm.category = mi.category
LEFT JOIN metadata.competitor_benchmarks cb ON bm.brand_name = cb.primary_brand

GROUP BY 
    bm.brand_name, bm.category, bm.parent_company, bm.market_share_percent,
    bm.consumer_reach_points, bm.brand_growth_yoy, bm.household_penetration,
    mi.market_size_php, mi.cagr_percent, bm.position_type,
    bm.data_freshness, bm.confidence_score

ORDER BY 
    (LEAST(100, GREATEST(0,
        (CASE WHEN bm.market_share_percent > 25 THEN 25 WHEN bm.market_share_percent > 15 THEN 20 WHEN bm.market_share_percent > 10 THEN 15 WHEN bm.market_share_percent > 5 THEN 10 ELSE 5 END) +
        (CASE WHEN bm.brand_growth_yoy > 15 THEN 25 WHEN bm.brand_growth_yoy > 10 THEN 20 WHEN bm.brand_growth_yoy > 5 THEN 15 WHEN bm.brand_growth_yoy > 0 THEN 10 ELSE 0 END) +
        (CASE WHEN bm.consumer_reach_points > 500 THEN 20 WHEN bm.consumer_reach_points > 300 THEN 16 WHEN bm.consumer_reach_points > 150 THEN 12 WHEN bm.consumer_reach_points > 50 THEN 8 ELSE 4 END) +
        (CASE WHEN AVG(rp.price_index) BETWEEN 0.9 AND 1.2 THEN 15 WHEN AVG(rp.price_index) BETWEEN 0.7 AND 1.4 THEN 12 WHEN AVG(rp.price_index) BETWEEN 0.5 AND 1.6 THEN 8 ELSE 4 END) +
        (CASE WHEN bm.household_penetration > 70 THEN 15 WHEN bm.household_penetration > 50 THEN 12 WHEN bm.household_penetration > 30 THEN 8 WHEN bm.household_penetration > 10 THEN 5 ELSE 2 END)
    ))) DESC;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO authenticated, anon;

-- Add comments for documentation
COMMENT ON VIEW analytics.brand_performance_dashboard IS 'Comprehensive brand performance metrics with market intelligence';
COMMENT ON VIEW analytics.category_deep_dive IS 'In-depth category analysis with market sizing and competitive dynamics';
COMMENT ON VIEW analytics.competitive_landscape_matrix IS 'Head-to-head competitive analysis with strategic insights';
COMMENT ON VIEW analytics.price_intelligence_dashboard IS 'Real-time pricing intelligence with market positioning';
COMMENT ON VIEW analytics.market_opportunity_analysis IS 'Market opportunity assessment with strategic recommendations';
COMMENT ON VIEW analytics.brand_health_index IS 'Brand health scoring with actionable insights';

COMMIT;