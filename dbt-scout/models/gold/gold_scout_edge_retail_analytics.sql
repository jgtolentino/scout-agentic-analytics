{{ config(
    materialized='table',
    tags=['gold', 'scout_edge', 'retail', 'analytics'],
    post_hook=[
        "SELECT metadata.emit_lineage_complete('gold_scout_edge_retail_analytics', '{{ var(\"job_run_id\", gen_random_uuid()) }}'::UUID)",
        "INSERT INTO metadata.quality_metrics (dataset, layer, metric_name, metric_value, dimension, measured_at, job_run_id) VALUES ('{{ this }}', 'gold', 'scout_edge_metrics_count', (SELECT COUNT(*) FROM {{ this }}), 'completeness', NOW(), '{{ var(\"job_run_id\", null) }}'::UUID)"
    ]
) }}

/*
  Gold Layer: Scout Edge Retail Analytics
  
  Executive dashboard for Scout Edge IoT retail intelligence including:
  - Store performance metrics and trends
  - Brand detection effectiveness and insights
  - Transaction patterns and customer behavior
  - Device operational health and coverage
  - Revenue attribution and business impact
  
  Refreshed: Every 4 hours during business hours
  SLA: Available within 30 minutes of Silver layer completion
*/

WITH scout_edge_base AS (
    SELECT 
        event_date,
        device_id,
        store_id,
        geographic_segment,
        retail_format,
        total_amount as revenue_amount,
        item_count,
        detected_brands_count,
        brand_detection_confidence,
        confidence_tier,
        engagement_diversity,
        unified_brand_impact,
        time_period,
        day_type,
        transaction_category,
        basket_size_category,
        quality_score,
        business_value,
        has_rich_context,
        processing_time_ms,
        temporal_freshness,
        privacy_risk_level,
        source_processed_at
    FROM {{ ref('silver_unified_scout_analytics') }}
    WHERE source_system = 'scout_edge'
    AND event_date >= CURRENT_DATE - INTERVAL '90 days'  -- Focus on recent 3 months
    AND quality_score >= 0.3  -- Quality threshold for executive analytics
),

-- Daily store performance metrics
daily_store_metrics AS (
    SELECT 
        event_date,
        device_id,
        store_id,
        geographic_segment,
        retail_format,
        
        -- Transaction volume metrics
        COUNT(*) as daily_transaction_count,
        COUNT(DISTINCT CASE WHEN revenue_amount > 0 THEN primary_id END) as revenue_transactions,
        
        -- Revenue metrics
        SUM(revenue_amount) as daily_revenue,
        AVG(revenue_amount) as avg_transaction_value,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue_amount) as median_transaction_value,
        MAX(revenue_amount) as max_transaction_value,
        
        -- Basket analytics
        AVG(item_count) as avg_basket_size,
        SUM(item_count) as total_items_sold,
        COUNT(*) FILTER (WHERE basket_size_category = 'bulk_purchase') as bulk_purchases,
        
        -- Brand intelligence metrics
        AVG(detected_brands_count) as avg_brands_per_transaction,
        SUM(detected_brands_count) as total_brand_detections,
        COUNT(*) FILTER (WHERE detected_brands_count > 0) as brand_detection_transactions,
        AVG(brand_detection_confidence) as avg_brand_confidence,
        COUNT(*) FILTER (WHERE confidence_tier = 'high_confidence') as high_confidence_detections,
        
        -- Operational metrics
        COUNT(*) FILTER (WHERE has_rich_context = true) as rich_context_transactions,
        AVG(processing_time_ms) as avg_processing_time,
        COUNT(*) FILTER (WHERE quality_score >= 0.8) as high_quality_transactions,
        
        -- Time pattern analysis
        COUNT(*) FILTER (WHERE time_period = 'morning') as morning_transactions,
        COUNT(*) FILTER (WHERE time_period = 'afternoon') as afternoon_transactions,
        COUNT(*) FILTER (WHERE time_period = 'evening') as evening_transactions,
        COUNT(*) FILTER (WHERE day_type = 'weekend') as weekend_transactions,
        
        -- Business value distribution
        COUNT(*) FILTER (WHERE business_value = 'high_value') as high_value_transactions,
        COUNT(*) FILTER (WHERE business_value = 'medium_value') as medium_value_transactions,
        
        -- Privacy compliance
        COUNT(*) FILTER (WHERE privacy_risk_level = 'high_privacy_risk') as high_privacy_risk_count,
        
        -- Data quality indicators
        MIN(source_processed_at) as earliest_processing_time,
        MAX(source_processed_at) as latest_processing_time
        
    FROM scout_edge_base
    GROUP BY event_date, device_id, store_id, geographic_segment, retail_format
),

-- Weekly aggregations for trend analysis
weekly_performance AS (
    SELECT 
        DATE_TRUNC('week', event_date) as week_start,
        device_id,
        store_id,
        geographic_segment,
        
        -- Weekly totals
        SUM(daily_transaction_count) as weekly_transactions,
        SUM(daily_revenue) as weekly_revenue,
        AVG(avg_transaction_value) as avg_weekly_transaction_value,
        
        -- Growth calculations
        LAG(SUM(daily_revenue)) OVER (
            PARTITION BY device_id, store_id 
            ORDER BY DATE_TRUNC('week', event_date)
        ) as prev_week_revenue,
        
        -- Brand performance
        AVG(avg_brands_per_transaction) as avg_weekly_brands_per_transaction,
        SUM(total_brand_detections) as weekly_brand_detections,
        AVG(avg_brand_confidence) as avg_weekly_brand_confidence,
        
        -- Operational performance
        AVG(avg_processing_time) as avg_weekly_processing_time,
        SUM(high_quality_transactions) as weekly_high_quality_count,
        
        -- Active days
        COUNT(DISTINCT event_date) as active_days_in_week
        
    FROM daily_store_metrics
    GROUP BY DATE_TRUNC('week', event_date), device_id, store_id, geographic_segment
),

-- Growth rate calculations
weekly_growth AS (
    SELECT *,
        CASE 
            WHEN prev_week_revenue > 0 
            THEN ROUND(
                ((weekly_revenue - prev_week_revenue)::FLOAT / prev_week_revenue * 100), 
                2
            )
            ELSE NULL 
        END as week_over_week_revenue_growth_pct
    FROM weekly_performance
),

-- Device health and operational metrics
device_performance AS (
    SELECT 
        device_id,
        store_id,
        geographic_segment,
        retail_format,
        
        -- Current period (last 30 days)
        COUNT(*) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as transactions_last_30d,
        SUM(daily_revenue) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as revenue_last_30d,
        AVG(avg_processing_time) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as avg_processing_time_30d,
        
        -- Brand detection effectiveness
        AVG(avg_brand_confidence) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as brand_confidence_30d,
        AVG(total_brand_detections::FLOAT / NULLIF(daily_transaction_count, 0)) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as brand_detection_rate_30d,
        
        -- Quality metrics
        AVG(high_quality_transactions::FLOAT / NULLIF(daily_transaction_count, 0) * 100) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as quality_rate_30d,
        
        -- Operational health
        COUNT(DISTINCT event_date) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as active_days_30d,
        MAX(event_date) as last_transaction_date,
        EXTRACT(DAYS FROM (CURRENT_DATE - MAX(event_date))) as days_since_last_transaction,
        
        -- Device status assessment
        CASE 
            WHEN MAX(event_date) >= CURRENT_DATE - INTERVAL '1 day' THEN 'active'
            WHEN MAX(event_date) >= CURRENT_DATE - INTERVAL '7 days' THEN 'recent'
            WHEN MAX(event_date) >= CURRENT_DATE - INTERVAL '30 days' THEN 'inactive'
            ELSE 'offline'
        END as device_status,
        
        -- Performance benchmarks
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY daily_revenue) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as median_daily_revenue_30d,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY daily_revenue) FILTER (WHERE event_date >= CURRENT_DATE - INTERVAL '30 days') as p90_daily_revenue_30d
        
    FROM daily_store_metrics
    GROUP BY device_id, store_id, geographic_segment, retail_format
),

-- Geographic and retail format analysis
geographic_performance AS (
    SELECT 
        geographic_segment,
        retail_format,
        
        -- Store and device coverage
        COUNT(DISTINCT device_id) as active_devices,
        COUNT(DISTINCT store_id) as active_stores,
        
        -- Aggregated performance (last 30 days)
        SUM(transactions_last_30d) as total_transactions_30d,
        SUM(revenue_last_30d) as total_revenue_30d,
        AVG(revenue_last_30d) as avg_store_revenue_30d,
        
        -- Quality and efficiency
        AVG(brand_confidence_30d) as avg_brand_confidence_30d,
        AVG(brand_detection_rate_30d) as avg_brand_detection_rate_30d,
        AVG(quality_rate_30d) as avg_quality_rate_30d,
        AVG(avg_processing_time_30d) as avg_processing_time_30d,
        
        -- Operational health distribution
        COUNT(*) FILTER (WHERE device_status = 'active') as active_devices_count,
        COUNT(*) FILTER (WHERE device_status = 'recent') as recent_devices_count,
        COUNT(*) FILTER (WHERE device_status = 'inactive') as inactive_devices_count,
        COUNT(*) FILTER (WHERE device_status = 'offline') as offline_devices_count,
        
        -- Performance distribution
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue_last_30d) as q1_store_revenue_30d,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue_last_30d) as q3_store_revenue_30d
        
    FROM device_performance
    GROUP BY geographic_segment, retail_format
),

-- Executive summary metrics
executive_summary AS (
    SELECT 
        'scout_edge_retail' as analytics_domain,
        CURRENT_DATE as report_date,
        
        -- Network overview
        (SELECT COUNT(DISTINCT device_id) FROM device_performance WHERE device_status IN ('active', 'recent')) as operational_devices,
        (SELECT COUNT(DISTINCT store_id) FROM device_performance WHERE device_status IN ('active', 'recent')) as operational_stores,
        (SELECT COUNT(DISTINCT geographic_segment) FROM device_performance WHERE device_status IN ('active', 'recent')) as active_regions,
        
        -- Business performance (last 30 days)
        (SELECT SUM(transactions_last_30d) FROM device_performance) as total_transactions_30d,
        (SELECT SUM(revenue_last_30d) FROM device_performance) as total_revenue_30d,
        (SELECT AVG(revenue_last_30d) FROM device_performance WHERE device_status IN ('active', 'recent')) as avg_store_revenue_30d,
        
        -- Technology performance
        (SELECT AVG(brand_confidence_30d) FROM device_performance WHERE device_status IN ('active', 'recent')) as network_brand_confidence,
        (SELECT AVG(brand_detection_rate_30d) FROM device_performance WHERE device_status IN ('active', 'recent')) as network_brand_detection_rate,
        (SELECT AVG(quality_rate_30d) FROM device_performance WHERE device_status IN ('active', 'recent')) as network_quality_rate,
        (SELECT AVG(avg_processing_time_30d) FROM device_performance WHERE device_status IN ('active', 'recent')) as network_avg_processing_time,
        
        -- Growth indicators (comparing last 30 days to previous 30 days)
        (SELECT 
            CASE 
                WHEN SUM(prev_week_revenue) > 0 
                THEN ROUND(
                    ((SUM(weekly_revenue) - SUM(prev_week_revenue))::FLOAT / SUM(prev_week_revenue) * 100), 
                    2
                )
                ELSE NULL 
            END
         FROM weekly_growth 
         WHERE week_start >= CURRENT_DATE - INTERVAL '8 weeks'
        ) as month_over_month_revenue_growth_pct,
        
        -- Data freshness and quality
        (SELECT MAX(last_transaction_date) FROM device_performance) as latest_transaction_date,
        (SELECT MIN(days_since_last_transaction) FROM device_performance WHERE device_status = 'active') as min_days_since_transaction,
        (SELECT AVG(days_since_last_transaction) FROM device_performance WHERE device_status IN ('active', 'recent')) as avg_days_since_transaction,
        
        -- Operational alerts
        (SELECT COUNT(*) FROM device_performance WHERE device_status = 'offline') as offline_devices_alert,
        (SELECT COUNT(*) FROM device_performance WHERE days_since_last_transaction > 7 AND device_status != 'offline') as stale_devices_alert,
        (SELECT COUNT(*) FROM device_performance WHERE quality_rate_30d < 50) as low_quality_devices_alert,
        
        -- Performance benchmarks
        (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue_last_30d) FROM device_performance WHERE device_status IN ('active', 'recent')) as median_store_revenue_30d,
        (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY revenue_last_30d) FROM device_performance WHERE device_status IN ('active', 'recent')) as p90_store_revenue_30d,
        
        -- Metadata
        NOW() as calculated_at,
        '{{ var("job_run_id", "unknown") }}' as job_run_id
),

-- Final unified results
final_results AS (
    -- Executive summary
    SELECT 
        'executive_summary' as metric_type,
        analytics_domain as metric_category,
        'network_overview' as metric_subcategory,
        operational_devices::text as metric_value,
        'devices' as metric_unit,
        'Operational Scout Edge devices in network' as metric_description,
        report_date as metric_date,
        calculated_at,
        job_run_id
    FROM executive_summary
    
    UNION ALL
    
    SELECT 'executive_summary', analytics_domain, 'network_overview', operational_stores::text, 'stores', 'Operational stores with Scout Edge coverage', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'network_overview', active_regions::text, 'regions', 'Geographic regions with active Scout Edge presence', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'business_performance', total_transactions_30d::text, 'transactions', 'Total transactions captured in last 30 days', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'business_performance', ROUND(total_revenue_30d, 2)::text, 'PHP', 'Total revenue tracked in last 30 days', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'business_performance', ROUND(avg_store_revenue_30d, 2)::text, 'PHP', 'Average store revenue in last 30 days', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'technology_performance', ROUND(network_brand_confidence * 100, 1)::text, 'percent', 'Network-wide brand detection confidence', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'technology_performance', ROUND(network_brand_detection_rate * 100, 1)::text, 'percent', 'Network-wide brand detection rate', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'technology_performance', ROUND(network_quality_rate, 1)::text, 'percent', 'Network-wide data quality rate', report_date, calculated_at, job_run_id FROM executive_summary
    UNION ALL
    SELECT 'executive_summary', analytics_domain, 'technology_performance', ROUND(network_avg_processing_time, 0)::text, 'milliseconds', 'Network-wide average processing time', report_date, calculated_at, job_run_id FROM executive_summary
    
    UNION ALL
    
    -- Geographic performance metrics
    SELECT 
        'geographic_performance' as metric_type,
        geographic_segment as metric_category,
        retail_format as metric_subcategory,
        total_revenue_30d::text as metric_value,
        'PHP' as metric_unit,
        'Geographic segment revenue performance (30 days)' as metric_description,
        CURRENT_DATE as metric_date,
        NOW() as calculated_at,
        '{{ var("job_run_id", "unknown") }}' as job_run_id
    FROM geographic_performance
    
    UNION ALL
    
    -- Device health metrics
    SELECT 
        'device_health' as metric_type,
        device_id as metric_category,
        device_status as metric_subcategory,
        revenue_last_30d::text as metric_value,
        'PHP' as metric_unit,
        'Device revenue performance and health status' as metric_description,
        last_transaction_date as metric_date,
        NOW() as calculated_at,
        '{{ var("job_run_id", "unknown") }}' as job_run_id
    FROM device_performance
)

SELECT * FROM final_results
ORDER BY metric_type, metric_category, metric_subcategory