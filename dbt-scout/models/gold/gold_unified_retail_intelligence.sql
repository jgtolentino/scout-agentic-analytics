-- Gold Unified Retail Intelligence
-- Executive analytics combining Scout Edge IoT + Azure Legacy data
-- Cross-channel insights with demographic and behavioral intelligence

{{ config(
    materialized='table',
    indexes=[
        {'columns': ['brand_name', 'analysis_period'], 'type': 'btree'},
        {'columns': ['store_id'], 'type': 'btree'}
    ]
) }}

WITH base_metrics AS (
    SELECT 
        brand_name,
        store_id,
        transaction_source,
        DATE_TRUNC('month', transaction_timestamp) as analysis_period,
        
        -- Volume Metrics
        COUNT(*) as transaction_count,
        SUM(peso_value) as total_revenue,
        AVG(peso_value) as avg_transaction_value,
        SUM(units_per_transaction) as total_units,
        AVG(basket_size) as avg_basket_size,
        
        -- Quality & Performance
        AVG(data_quality_score) as avg_quality_score,
        AVG(duration_seconds) as avg_transaction_duration,
        AVG(COALESCE(confidence_score, handshake_score)) as avg_confidence,
        
        -- Source-Specific Metrics
        COUNT(CASE WHEN transaction_source = 'scout_edge' THEN 1 END) as iot_transactions,
        COUNT(CASE WHEN transaction_source = 'azure_legacy' THEN 1 END) as survey_transactions,
        
        -- Payment & Behavior
        COUNT(CASE WHEN payment_method = 'cash' THEN 1 END) as cash_transactions,
        COUNT(CASE WHEN payment_method = 'gcash' THEN 1 END) as digital_transactions,
        
        -- Demographics (Azure only)
        COUNT(CASE WHEN gender IS NOT NULL THEN 1 END) as demographic_available,
        COUNT(CASE WHEN campaign_influenced = true THEN 1 END) as campaign_influenced_count
        
    FROM {{ ref('silver_unified_transactions') }}
    WHERE analysis_period >= '2024-01-01'
    GROUP BY brand_name, store_id, transaction_source, analysis_period
),

brand_intelligence AS (
    SELECT 
        brand_name,
        analysis_period,
        
        -- Cross-Source Validation
        COUNT(DISTINCT store_id) as store_presence,
        COUNT(DISTINCT transaction_source) as data_source_count,
        
        -- Combined Metrics
        SUM(transaction_count) as total_transactions,
        SUM(total_revenue) as brand_revenue,
        AVG(avg_transaction_value) as brand_avg_value,
        SUM(total_units) as brand_total_units,
        
        -- Performance Analytics
        AVG(avg_quality_score) as brand_data_quality,
        AVG(avg_transaction_duration) as brand_avg_duration,
        AVG(avg_confidence) as brand_detection_confidence,
        
        -- Digital Adoption
        SUM(digital_transactions)::decimal / NULLIF(SUM(transaction_count), 0) as digital_payment_rate,
        
        -- Marketing Effectiveness
        SUM(campaign_influenced_count)::decimal / NULLIF(SUM(demographic_available), 0) as campaign_influence_rate,
        
        -- IoT vs Survey Comparison
        SUM(iot_transactions) as iot_volume,
        SUM(survey_transactions) as survey_volume,
        SUM(iot_transactions)::decimal / NULLIF(SUM(transaction_count), 0) as iot_data_percentage,
        
        -- Growth Metrics
        LAG(SUM(total_revenue)) OVER (PARTITION BY brand_name ORDER BY analysis_period) as prev_period_revenue,
        LAG(SUM(transaction_count)) OVER (PARTITION BY brand_name ORDER BY analysis_period) as prev_period_transactions
        
    FROM base_metrics
    GROUP BY brand_name, analysis_period
),

store_performance AS (
    SELECT 
        store_id,
        analysis_period,
        
        -- Store Metrics
        COUNT(DISTINCT brand_name) as brand_variety,
        SUM(transaction_count) as store_transactions,
        SUM(total_revenue) as store_revenue,
        AVG(avg_transaction_value) as store_avg_transaction,
        
        -- Data Source Coverage
        COUNT(DISTINCT transaction_source) as data_sources_active,
        SUM(iot_transactions) as iot_coverage,
        SUM(survey_transactions) as survey_coverage,
        
        -- Operational Efficiency
        AVG(avg_transaction_duration) as avg_service_time,
        AVG(avg_quality_score) as store_data_quality,
        
        -- Customer Behavior
        AVG(avg_basket_size) as store_avg_basket,
        SUM(digital_transactions)::decimal / NULLIF(SUM(transaction_count), 0) as store_digital_rate
        
    FROM base_metrics
    GROUP BY store_id, analysis_period
)

-- Final unified intelligence model
SELECT 
    -- Identity
    bi.brand_name,
    bi.analysis_period,
    
    -- Brand Performance
    bi.total_transactions,
    bi.brand_revenue,
    bi.brand_avg_value,
    bi.brand_total_units,
    bi.store_presence,
    
    -- Data Intelligence
    bi.data_source_count,
    bi.brand_data_quality,
    bi.brand_detection_confidence,
    bi.iot_data_percentage,
    
    -- Business Insights
    bi.digital_payment_rate,
    bi.campaign_influence_rate,
    
    -- Growth Analytics
    CASE 
        WHEN bi.prev_period_revenue IS NOT NULL 
        THEN (bi.brand_revenue - bi.prev_period_revenue) / bi.prev_period_revenue 
        ELSE NULL 
    END as revenue_growth_rate,
    
    CASE 
        WHEN bi.prev_period_transactions IS NOT NULL 
        THEN (bi.total_transactions - bi.prev_period_transactions)::decimal / bi.prev_period_transactions 
        ELSE NULL 
    END as transaction_growth_rate,
    
    -- Performance Tiers
    CASE 
        WHEN bi.brand_revenue >= 1000000 THEN 'Tier 1: Premium'
        WHEN bi.brand_revenue >= 500000 THEN 'Tier 2: Growth' 
        WHEN bi.brand_revenue >= 100000 THEN 'Tier 3: Developing'
        ELSE 'Tier 4: Emerging'
    END as brand_performance_tier,
    
    -- Data Maturity Score  
    (
        CASE WHEN bi.data_source_count >= 2 THEN 25 ELSE 0 END +
        CASE WHEN bi.brand_data_quality >= 0.9 THEN 25 ELSE bi.brand_data_quality * 25 END +
        CASE WHEN bi.iot_data_percentage >= 0.1 THEN 25 ELSE bi.iot_data_percentage * 250 END +
        CASE WHEN bi.store_presence >= 3 THEN 25 ELSE bi.store_presence * 8.33 END
    ) as data_maturity_score,
    
    -- Recommendations
    CASE 
        WHEN bi.iot_data_percentage < 0.05 THEN 'Expand IoT Coverage'
        WHEN bi.digital_payment_rate < 0.3 THEN 'Promote Digital Payments' 
        WHEN bi.campaign_influence_rate < 0.2 THEN 'Enhance Marketing'
        WHEN bi.brand_data_quality < 0.8 THEN 'Improve Data Quality'
        ELSE 'Optimize Performance'
    END as strategic_recommendation,
    
    current_timestamp as generated_at
    
FROM brand_intelligence bi
WHERE bi.total_transactions >= 10  -- Filter for statistical significance
ORDER BY bi.brand_revenue DESC, bi.analysis_period DESC