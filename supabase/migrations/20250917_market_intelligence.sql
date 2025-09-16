-- Market Intelligence Database Schema
-- Comprehensive system for Philippine FMCG market data, pricing, and brand intelligence
-- Created: 2025-09-17

BEGIN;

-- =============================================
-- MARKET INTELLIGENCE CORE TABLES
-- =============================================

-- Market category intelligence and sizing data
CREATE TABLE IF NOT EXISTS metadata.market_intelligence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Category Information
    category TEXT NOT NULL,
    subcategory TEXT,
    market_type TEXT NOT NULL, -- 'fmcg', 'beverages', 'personal_care', etc.
    
    -- Market Sizing (in PHP millions unless specified)
    market_size_php DECIMAL(12,2), -- Market size in PHP millions
    market_size_usd DECIMAL(12,2), -- Market size in USD millions  
    market_size_year INTEGER, -- Year of data
    
    -- Growth Metrics
    cagr_percent DECIMAL(5,2), -- Compound Annual Growth Rate
    growth_forecast_years INTEGER, -- Forecast period
    yoy_growth_percent DECIMAL(5,2), -- Year-over-year growth
    
    -- Market Characteristics
    market_concentration TEXT, -- 'high', 'medium', 'low'
    key_trends TEXT[], -- Market trends array
    growth_drivers TEXT[], -- Growth factor array
    challenges TEXT[], -- Market challenges
    
    -- Consumer Data
    penetration_percent DECIMAL(5,2), -- Household penetration
    consumption_per_capita_php DECIMAL(10,2), -- Per capita spending
    primary_channels TEXT[], -- Distribution channels
    
    -- Geographic Data
    metro_manila_share DECIMAL(5,2), -- MM market share
    luzon_share DECIMAL(5,2),
    visayas_share DECIMAL(5,2),
    mindanao_share DECIMAL(5,2),
    
    -- Data Quality
    confidence_score DECIMAL(3,2) DEFAULT 0.8,
    data_freshness DATE,
    source_quality TEXT DEFAULT 'medium', -- 'high', 'medium', 'low'
    
    -- Sources and Metadata
    primary_sources TEXT[], -- Source citations
    research_methodology TEXT,
    data_limitations TEXT[],
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_by TEXT DEFAULT 'market_intelligence_migration'
);

-- Brand market metrics and competitive positioning
CREATE TABLE IF NOT EXISTS metadata.brand_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Brand Identity
    brand_name TEXT NOT NULL,
    official_name TEXT NOT NULL,
    parent_company TEXT,
    category TEXT NOT NULL,
    subcategory TEXT,
    
    -- Market Position
    market_share_percent DECIMAL(5,2), -- Category market share
    market_share_rank INTEGER, -- Ranking in category
    market_share_year INTEGER,
    
    -- Consumer Reach (Kantar metrics)
    consumer_reach_points DECIMAL(12,1), -- CRP in millions
    crp_rank INTEGER, -- National CRP ranking
    crp_year INTEGER,
    
    -- Brand Performance
    household_penetration DECIMAL(5,2), -- % households buying
    purchase_frequency DECIMAL(8,2), -- Purchases per household
    brand_loyalty_index DECIMAL(5,2), -- Loyalty score
    
    -- Competitive Position
    position_type TEXT, -- 'leader', 'challenger', 'follower', 'niche'
    competitive_advantage TEXT[], -- Key advantages
    threats TEXT[], -- Competitive threats
    
    -- Growth Metrics
    brand_growth_yoy DECIMAL(5,2), -- YoY growth %
    fastest_growing BOOLEAN DEFAULT false,
    declining_brand BOOLEAN DEFAULT false,
    
    -- Premium/Value Position
    price_positioning TEXT, -- 'premium', 'mainstream', 'value', 'economy'
    price_premium_percent DECIMAL(5,2), -- % above/below category average
    
    -- Regional Performance
    strong_regions TEXT[], -- Regions where brand leads
    weak_regions TEXT[], -- Regions with low share
    expansion_opportunities TEXT[],
    
    -- Data Quality & Sources
    confidence_score DECIMAL(3,2) DEFAULT 0.8,
    data_freshness DATE,
    source_types TEXT[], -- 'kantar', 'nielsen', 'euromonitor', etc.
    validation_status TEXT DEFAULT 'unverified',
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_by TEXT DEFAULT 'system'
);

-- Comprehensive retail pricing intelligence
CREATE TABLE IF NOT EXISTS metadata.retail_pricing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Product Identity
    brand_name TEXT NOT NULL,
    sku_description TEXT NOT NULL,
    pack_size TEXT,
    variant TEXT, -- flavor, color, type
    
    -- Pricing Data
    srp_php DECIMAL(8,2) NOT NULL, -- Suggested Retail Price
    actual_retail_php DECIMAL(8,2), -- Observed retail price
    wholesale_php DECIMAL(8,2), -- Wholesale price if available
    
    -- Price Context
    channel TEXT NOT NULL, -- 'sari-sari', 'supermarket', 'convenience', 'hypermarket'
    region TEXT, -- 'metro_manila', 'luzon', 'visayas', 'mindanao'
    specific_location TEXT, -- City or specific location
    
    -- Time Dimensions
    price_date DATE NOT NULL,
    effective_from DATE,
    effective_to DATE,
    is_promotional BOOLEAN DEFAULT false,
    promotion_type TEXT, -- 'buy1take1', 'discount', 'bundle'
    
    -- Price Analysis
    category_avg_php DECIMAL(8,2), -- Category average price
    price_index DECIMAL(5,2), -- Price vs category average (1.0 = average)
    competitor_avg_php DECIMAL(8,2), -- Direct competitor average
    
    -- Unit Economics
    price_per_gram DECIMAL(8,4), -- Price per gram/ml
    price_per_serving DECIMAL(6,2), -- Price per serving
    value_score DECIMAL(4,2), -- Value for money score
    
    -- Market Context
    inflation_adjusted_price DECIMAL(8,2), -- Inflation adjusted
    currency_date DATE, -- Date for currency conversion
    exchange_rate_usd DECIMAL(8,4), -- PHP to USD rate
    
    -- Data Quality
    price_source TEXT NOT NULL, -- 'dti', 'nielsen', 'kantar', 'field_survey'
    confidence_level DECIMAL(3,2) DEFAULT 0.8,
    validation_method TEXT, -- How price was verified
    data_collector TEXT, -- Who collected the data
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Competitive benchmarking and head-to-head comparisons
CREATE TABLE IF NOT EXISTS metadata.competitor_benchmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Comparison Setup
    primary_brand TEXT NOT NULL,
    competitor_brand TEXT NOT NULL,
    category TEXT NOT NULL,
    comparison_type TEXT, -- 'direct', 'indirect', 'substitute'
    
    -- Market Share Comparison
    primary_share DECIMAL(5,2),
    competitor_share DECIMAL(5,2),
    share_gap DECIMAL(6,2), -- Difference in market share
    
    -- Pricing Comparison
    primary_avg_price DECIMAL(8,2),
    competitor_avg_price DECIMAL(8,2),
    price_premium_percent DECIMAL(5,2), -- Price difference %
    price_positioning TEXT, -- 'premium', 'parity', 'value'
    
    -- Performance Metrics
    primary_growth_yoy DECIMAL(5,2),
    competitor_growth_yoy DECIMAL(5,2),
    growth_advantage DECIMAL(5,2), -- Growth rate difference
    
    -- Consumer Metrics
    primary_crp DECIMAL(12,1),
    competitor_crp DECIMAL(12,1),
    reach_advantage DECIMAL(12,1), -- CRP difference
    
    -- Strategic Assessment
    competitive_intensity TEXT, -- 'high', 'medium', 'low'
    threat_level TEXT, -- 'high', 'medium', 'low'
    opportunity_areas TEXT[], -- Where to compete
    
    -- SWOT Analysis
    primary_strengths TEXT[],
    primary_weaknesses TEXT[],
    competitor_strengths TEXT[],
    competitor_weaknesses TEXT[],
    
    -- Data Context
    benchmark_date DATE NOT NULL,
    analysis_timeframe TEXT, -- Period analyzed
    confidence_score DECIMAL(3,2) DEFAULT 0.75,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Brand detection enhancement with market intelligence
CREATE TABLE IF NOT EXISTS metadata.brand_detection_intelligence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Brand Identity (links to enhanced_brand_master)
    brand_id UUID REFERENCES metadata.enhanced_brand_master(id),
    brand_name TEXT NOT NULL,
    
    -- Market Intelligence Weighting
    market_share_weight DECIMAL(4,3) DEFAULT 1.0, -- Detection weight by market share
    crp_weight DECIMAL(4,3) DEFAULT 1.0, -- Detection weight by consumer reach
    category_dominance DECIMAL(3,2), -- Share within category for context
    
    -- Detection Enhancement
    context_boost_keywords TEXT[], -- Words that boost brand confidence
    disambiguation_rules JSONB, -- Rules for similar brand names
    category_context_required BOOLEAN DEFAULT false,
    
    -- Audio/Speech Specific
    audio_priority INTEGER DEFAULT 1, -- Priority in speech recognition
    common_mispronunciations TEXT[], -- Frequent speech errors
    regional_pronunciations TEXT[], -- Regional variations
    
    -- Performance Metrics
    detection_accuracy DECIMAL(4,3), -- Historical accuracy score
    false_positive_rate DECIMAL(4,3), -- False positive frequency
    disambiguation_success DECIMAL(4,3), -- Disambiguation accuracy
    
    -- Market-Informed Rules
    substitute_brands TEXT[], -- Brands often confused with this one
    exclusive_contexts TEXT[], -- Contexts where only this brand applies
    category_exclusions TEXT[], -- Categories where this brand doesn't apply
    
    -- Seasonal/Temporal
    seasonal_boost_months INTEGER[], -- Months with higher likelihood
    time_based_weights JSONB, -- Time-based detection adjustments
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    last_performance_update DATE
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Market Intelligence Indexes
CREATE INDEX idx_market_intelligence_category ON metadata.market_intelligence(category);
CREATE INDEX idx_market_intelligence_freshness ON metadata.market_intelligence(data_freshness);
CREATE INDEX idx_market_intelligence_size ON metadata.market_intelligence(market_size_php DESC);

-- Brand Metrics Indexes  
CREATE INDEX idx_brand_metrics_name ON metadata.brand_metrics(brand_name);
CREATE INDEX idx_brand_metrics_category ON metadata.brand_metrics(category);
CREATE INDEX idx_brand_metrics_share ON metadata.brand_metrics(market_share_percent DESC);
CREATE INDEX idx_brand_metrics_crp ON metadata.brand_metrics(consumer_reach_points DESC);
CREATE INDEX idx_brand_metrics_company ON metadata.brand_metrics(parent_company);

-- Pricing Indexes
CREATE INDEX idx_retail_pricing_brand_date ON metadata.retail_pricing(brand_name, price_date DESC);
CREATE INDEX idx_retail_pricing_channel_region ON metadata.retail_pricing(channel, region);
CREATE INDEX idx_retail_pricing_category_date ON metadata.retail_pricing(brand_name, price_date DESC);
CREATE INDEX idx_retail_pricing_srp ON metadata.retail_pricing(srp_php);

-- Competitor Benchmarks Indexes
CREATE INDEX idx_competitor_primary ON metadata.competitor_benchmarks(primary_brand);
CREATE INDEX idx_competitor_category ON metadata.competitor_benchmarks(category);
CREATE INDEX idx_competitor_date ON metadata.competitor_benchmarks(benchmark_date DESC);

-- Brand Detection Intelligence Indexes
CREATE INDEX idx_brand_detection_name ON metadata.brand_detection_intelligence(brand_name);
CREATE INDEX idx_brand_detection_accuracy ON metadata.brand_detection_intelligence(detection_accuracy DESC);
CREATE INDEX idx_brand_detection_market_weight ON metadata.brand_detection_intelligence(market_share_weight DESC);

-- =============================================
-- FUNCTIONS FOR MARKET INTELLIGENCE
-- =============================================

-- Get comprehensive brand intelligence
CREATE OR REPLACE FUNCTION get_brand_intelligence(p_brand_name TEXT)
RETURNS TABLE (
    brand_name TEXT,
    category TEXT,
    market_share DECIMAL(5,2),
    crp DECIMAL(12,1),
    market_position TEXT,
    price_positioning TEXT,
    avg_price DECIMAL(8,2),
    growth_rate DECIMAL(5,2),
    key_competitors TEXT[],
    market_size_php DECIMAL(12,2),
    confidence_score DECIMAL(3,2)
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bm.brand_name,
        bm.category,
        bm.market_share_percent,
        bm.consumer_reach_points,
        bm.position_type,
        bm.price_positioning,
        AVG(rp.srp_php) as avg_price,
        bm.brand_growth_yoy,
        ARRAY_AGG(DISTINCT cb.competitor_brand) FILTER (WHERE cb.competitor_brand IS NOT NULL),
        mi.market_size_php,
        GREATEST(bm.confidence_score, mi.confidence_score, 0.5) as confidence_score
    FROM metadata.brand_metrics bm
    LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name 
        AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'
    LEFT JOIN metadata.competitor_benchmarks cb ON bm.brand_name = cb.primary_brand
    LEFT JOIN metadata.market_intelligence mi ON bm.category = mi.category
    WHERE bm.brand_name ILIKE p_brand_name
    GROUP BY 
        bm.brand_name, bm.category, bm.market_share_percent, 
        bm.consumer_reach_points, bm.position_type, bm.price_positioning,
        bm.brand_growth_yoy, mi.market_size_php, bm.confidence_score, mi.confidence_score;
END;
$$;

-- Enhanced brand matching with market intelligence
CREATE OR REPLACE FUNCTION match_brands_with_intelligence(
    p_input_text TEXT,
    p_confidence_threshold DECIMAL DEFAULT 0.6,
    p_use_market_weights BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    brand_name TEXT,
    match_confidence DECIMAL(4,3),
    match_type TEXT,
    market_share DECIMAL(5,2),
    detection_weight DECIMAL(4,3),
    category TEXT,
    context_match BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_normalized_input TEXT;
BEGIN
    -- Normalize input text
    v_normalized_input := LOWER(TRIM(p_input_text));
    
    RETURN QUERY
    WITH brand_matches AS (
        SELECT 
            ebm.brand_name,
            ebm.category,
            -- Base similarity score
            GREATEST(
                similarity(v_normalized_input, LOWER(ebm.brand_name)),
                similarity(v_normalized_input, LOWER(ebm.official_name)),
                COALESCE(
                    (SELECT MAX(similarity(v_normalized_input, LOWER(alias)))
                     FROM unnest(ebm.detection_aliases) as alias), 0
                )
            ) as base_confidence,
            -- Market intelligence weighting
            CASE 
                WHEN p_use_market_weights THEN
                    COALESCE(bdi.market_share_weight, 1.0) * 
                    COALESCE(bdi.crp_weight, 1.0) *
                    CASE 
                        WHEN bm.market_share_percent > 20 THEN 1.2
                        WHEN bm.market_share_percent > 10 THEN 1.1
                        WHEN bm.market_share_percent > 5 THEN 1.0
                        ELSE 0.9
                    END
                ELSE 1.0
            END as market_weight,
            bm.market_share_percent,
            COALESCE(bdi.detection_accuracy, ebm.detection_confidence) as detection_weight,
            -- Context matching
            CASE 
                WHEN ebm.context_keywords IS NOT NULL THEN
                    EXISTS (
                        SELECT 1 FROM unnest(ebm.context_keywords) as keyword
                        WHERE v_normalized_input LIKE '%' || keyword || '%'
                    )
                ELSE false
            END as context_match
        FROM metadata.enhanced_brand_master ebm
        LEFT JOIN metadata.brand_metrics bm ON ebm.brand_name = bm.brand_name
        LEFT JOIN metadata.brand_detection_intelligence bdi ON ebm.id = bdi.brand_id
        WHERE ebm.is_active = true
    )
    SELECT 
        bm.brand_name,
        ROUND(
            (bm.base_confidence * bm.market_weight * 
             CASE WHEN bm.context_match THEN 1.1 ELSE 1.0 END)::numeric, 3
        ) as match_confidence,
        CASE 
            WHEN bm.base_confidence >= 0.9 THEN 'exact'
            WHEN bm.base_confidence >= 0.7 THEN 'high'
            WHEN bm.base_confidence >= 0.5 THEN 'medium'
            ELSE 'low'
        END as match_type,
        bm.market_share_percent,
        bm.detection_weight,
        bm.category,
        bm.context_match
    FROM brand_matches bm
    WHERE (bm.base_confidence * bm.market_weight) >= p_confidence_threshold
    ORDER BY match_confidence DESC, bm.market_share_percent DESC NULLS LAST
    LIMIT 10;
END;
$$;

-- Get category market intelligence summary
CREATE OR REPLACE FUNCTION get_category_intelligence(p_category TEXT DEFAULT NULL)
RETURNS TABLE (
    category TEXT,
    market_size_php DECIMAL(12,2),
    growth_rate DECIMAL(5,2),
    top_brands TEXT[],
    market_leader TEXT,
    leader_share DECIMAL(5,2),
    concentration_level TEXT,
    avg_price_php DECIMAL(8,2),
    key_trends TEXT[]
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH category_stats AS (
        SELECT 
            mi.category,
            mi.market_size_php,
            mi.cagr_percent,
            mi.market_concentration,
            mi.key_trends,
            AVG(rp.srp_php) as avg_price,
            -- Get top 3 brands by market share
            ARRAY_AGG(
                bm.brand_name ORDER BY bm.market_share_percent DESC NULLS LAST
            ) FILTER (WHERE bm.market_share_percent IS NOT NULL) as all_brands,
            MAX(bm.market_share_percent) as max_share,
            (ARRAY_AGG(
                bm.brand_name ORDER BY bm.market_share_percent DESC NULLS LAST
            ) FILTER (WHERE bm.market_share_percent IS NOT NULL))[1] as leader
        FROM metadata.market_intelligence mi
        LEFT JOIN metadata.brand_metrics bm ON mi.category = bm.category
        LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name 
            AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'
        WHERE p_category IS NULL OR mi.category ILIKE p_category
        GROUP BY mi.category, mi.market_size_php, mi.cagr_percent, 
                mi.market_concentration, mi.key_trends
    )
    SELECT 
        cs.category,
        cs.market_size_php,
        cs.cagr_percent,
        cs.all_brands[1:3], -- Top 3 brands
        cs.leader,
        cs.max_share,
        cs.market_concentration,
        cs.avg_price,
        cs.key_trends
    FROM category_stats cs
    ORDER BY cs.market_size_php DESC NULLS LAST;
END;
$$;

-- =============================================
-- VIEWS FOR ANALYTICS
-- =============================================

-- Brand competitive landscape view
CREATE OR REPLACE VIEW analytics.brand_competitive_landscape AS
SELECT 
    bm.brand_name,
    bm.category,
    bm.market_share_percent,
    bm.consumer_reach_points,
    bm.position_type,
    bm.price_positioning,
    AVG(rp.srp_php) as avg_price_php,
    COUNT(DISTINCT cb.competitor_brand) as direct_competitors,
    bm.brand_growth_yoy,
    RANK() OVER (PARTITION BY bm.category ORDER BY bm.market_share_percent DESC) as category_rank,
    CASE 
        WHEN bm.market_share_percent >= 20 THEN 'Market Leader'
        WHEN bm.market_share_percent >= 10 THEN 'Strong Player'
        WHEN bm.market_share_percent >= 5 THEN 'Established Brand'
        ELSE 'Niche/Emerging'
    END as market_position_tier
FROM metadata.brand_metrics bm
LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name 
    AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'
LEFT JOIN metadata.competitor_benchmarks cb ON bm.brand_name = cb.primary_brand
GROUP BY 
    bm.brand_name, bm.category, bm.market_share_percent,
    bm.consumer_reach_points, bm.position_type, bm.price_positioning,
    bm.brand_growth_yoy;

-- Market category overview
CREATE OR REPLACE VIEW analytics.market_category_overview AS
SELECT 
    mi.category,
    mi.market_size_php,
    mi.cagr_percent,
    mi.market_concentration,
    COUNT(bm.brand_name) as tracked_brands,
    SUM(bm.market_share_percent) as total_tracked_share,
    AVG(rp.srp_php) as avg_price_php,
    MAX(bm.market_share_percent) as leader_share,
    mi.penetration_percent,
    mi.consumption_per_capita_php,
    array_length(mi.key_trends, 1) as trend_count
FROM metadata.market_intelligence mi
LEFT JOIN metadata.brand_metrics bm ON mi.category = bm.category
LEFT JOIN metadata.retail_pricing rp ON bm.brand_name = rp.brand_name 
    AND rp.price_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY 
    mi.category, mi.market_size_php, mi.cagr_percent,
    mi.market_concentration, mi.penetration_percent,
    mi.consumption_per_capita_php, mi.key_trends;

-- Price intelligence dashboard
CREATE OR REPLACE VIEW analytics.price_intelligence_dashboard AS
SELECT 
    rp.brand_name,
    rp.category,
    rp.channel,
    rp.region,
    COUNT(*) as price_points,
    AVG(rp.srp_php) as avg_srp,
    MIN(rp.srp_php) as min_price,
    MAX(rp.srp_php) as max_price,
    STDDEV(rp.srp_php) as price_volatility,
    AVG(rp.price_index) as vs_category_avg,
    COUNT(*) FILTER (WHERE rp.is_promotional = true) as promotional_count,
    MAX(rp.price_date) as last_updated
FROM metadata.retail_pricing rp
WHERE rp.price_date >= CURRENT_DATE - INTERVAL '180 days'
GROUP BY rp.brand_name, rp.category, rp.channel, rp.region;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA metadata TO authenticated, anon;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO authenticated, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, anon;

-- Update audit timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_market_intelligence_updated_at BEFORE UPDATE ON metadata.market_intelligence 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_brand_metrics_updated_at BEFORE UPDATE ON metadata.brand_metrics 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_retail_pricing_updated_at BEFORE UPDATE ON metadata.retail_pricing 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_competitor_benchmarks_updated_at BEFORE UPDATE ON metadata.competitor_benchmarks 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_brand_detection_intelligence_updated_at BEFORE UPDATE ON metadata.brand_detection_intelligence 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comments for documentation
COMMENT ON TABLE metadata.market_intelligence IS 'Philippine FMCG market sizing, trends, and category intelligence';
COMMENT ON TABLE metadata.brand_metrics IS 'Brand market share, consumer reach, and competitive positioning data';
COMMENT ON TABLE metadata.retail_pricing IS 'Comprehensive retail pricing intelligence with SRP and channel data';
COMMENT ON TABLE metadata.competitor_benchmarks IS 'Head-to-head competitive analysis and benchmarking';
COMMENT ON TABLE metadata.brand_detection_intelligence IS 'Market-informed brand detection enhancement and disambiguation';

COMMENT ON FUNCTION get_brand_intelligence(TEXT) IS 'Get comprehensive market intelligence for a specific brand';
COMMENT ON FUNCTION match_brands_with_intelligence(TEXT, DECIMAL, BOOLEAN) IS 'Enhanced brand matching using market intelligence weighting';
COMMENT ON FUNCTION get_category_intelligence(TEXT) IS 'Get market intelligence summary for categories';

COMMIT;