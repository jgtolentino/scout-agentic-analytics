{{ config(
    materialized='table',
    tags=['gold', 'executive', 'kpis'],
    post_hook=[
        "SELECT metadata.emit_lineage_complete('gold_executive_kpis', '{{ var(\"job_run_id\", gen_random_uuid()) }}'::UUID)",
        "INSERT INTO metadata.quality_metrics (dataset, layer, metric_name, metric_value, dimension, measured_at, job_run_id) VALUES ('{{ this }}', 'gold', 'executive_kpi_count', (SELECT COUNT(*) FROM {{ this }}), 'completeness', NOW(), '{{ var(\"job_run_id\", null) }}'::UUID)"
    ]
) }}

/*
  Gold Layer: Executive KPIs
  
  Business-ready executive dashboard metrics including:
  - Daily/Monthly active customers
  - Revenue trends and growth rates
  - Store performance metrics
  - Geographic distribution
  - Customer demographic insights
  
  Refreshed: Daily at 6 AM
  SLA: Available within 1 hour of Silver layer completion
*/

WITH daily_metrics AS (
  SELECT 
    transaction_date_only AS metric_date,
    
    -- Customer metrics
    COUNT(DISTINCT facial_id) AS daily_active_customers,
    COUNT(*) AS total_interactions,
    
    -- Store metrics
    COUNT(DISTINCT store_id) AS active_stores,
    
    -- Geographic metrics
    COUNT(DISTINCT region_name) AS active_regions,
    COUNT(DISTINCT province_name) AS active_provinces,
    COUNT(DISTINCT municipality_name) AS active_municipalities,
    
    -- Product metrics
    COUNT(DISTINCT product_id) AS active_products,
    
    -- Demographic insights
    COUNT(*) FILTER (WHERE gender = 'Male') AS male_interactions,
    COUNT(*) FILTER (WHERE gender = 'Female') AS female_interactions,
    COUNT(*) FILTER (WHERE age_group = '18-24') AS young_adult_interactions,
    COUNT(*) FILTER (WHERE age_group = '25-34') AS adult_interactions,
    COUNT(*) FILTER (WHERE age_group = '35-44') AS middle_age_interactions,
    COUNT(*) FILTER (WHERE age_group = '45-54') AS mature_interactions,
    COUNT(*) FILTER (WHERE age_group = '55+') AS senior_interactions,
    
    -- Temporal patterns
    COUNT(*) FILTER (WHERE hour_of_day BETWEEN 9 AND 11) AS morning_peak,
    COUNT(*) FILTER (WHERE hour_of_day BETWEEN 12 AND 14) AS lunch_peak,
    COUNT(*) FILTER (WHERE hour_of_day BETWEEN 17 AND 19) AS evening_peak,
    COUNT(*) FILTER (WHERE is_weekend = TRUE) AS weekend_interactions,
    
    -- Data quality metrics
    COUNT(*) FILTER (WHERE data_quality_score = 'high') AS high_quality_records,
    COUNT(*) FILTER (WHERE data_quality_score = 'medium') AS medium_quality_records,
    COUNT(*) FILTER (WHERE data_quality_score = 'low') AS low_quality_records,
    
    -- Emotional state analysis
    COUNT(*) FILTER (WHERE emotional_state = 'Happy') AS happy_interactions,
    COUNT(*) FILTER (WHERE emotional_state = 'Neutral') AS neutral_interactions,
    COUNT(*) FILTER (WHERE emotional_state = 'Sad') AS sad_interactions
    
  FROM {{ ref('silver_interactions') }}
  WHERE transaction_date_only >= '{{ var("start_date") }}'::DATE
    AND transaction_date_only <= CURRENT_DATE
  GROUP BY transaction_date_only
),

-- Monthly aggregations
monthly_metrics AS (
  SELECT 
    DATE_TRUNC('month', metric_date) AS metric_month,
    
    -- Aggregated monthly metrics
    AVG(daily_active_customers) AS avg_daily_active_customers,
    SUM(total_interactions) AS monthly_total_interactions,
    MAX(daily_active_customers) AS peak_daily_customers,
    MIN(daily_active_customers) AS min_daily_customers,
    
    -- Growth calculations (month-over-month)
    LAG(SUM(total_interactions)) OVER (ORDER BY DATE_TRUNC('month', metric_date)) AS prev_month_interactions,
    
    -- Store performance
    AVG(active_stores) AS avg_active_stores,
    MAX(active_stores) AS peak_active_stores,
    
    -- Quality trends
    AVG(high_quality_records::FLOAT / NULLIF(total_interactions, 0) * 100) AS avg_quality_percentage,
    
    -- Demographic trends
    AVG(male_interactions::FLOAT / NULLIF(total_interactions, 0) * 100) AS male_percentage,
    AVG(female_interactions::FLOAT / NULLIF(total_interactions, 0) * 100) AS female_percentage,
    
    -- Temporal patterns
    AVG(weekend_interactions::FLOAT / NULLIF(total_interactions, 0) * 100) AS weekend_percentage
    
  FROM daily_metrics
  GROUP BY DATE_TRUNC('month', metric_date)
),

-- Growth rate calculations
growth_metrics AS (
  SELECT *,
    CASE 
      WHEN prev_month_interactions > 0 
      THEN ROUND(
        ((monthly_total_interactions - prev_month_interactions)::FLOAT / prev_month_interactions * 100), 
        2
      )
      ELSE NULL 
    END AS month_over_month_growth_pct
  FROM monthly_metrics
),

-- Final executive KPIs with current period focus
current_period_kpis AS (
  SELECT 
    'current_month' AS period_type,
    DATE_TRUNC('month', CURRENT_DATE) AS period_start,
    CURRENT_DATE AS period_end,
    
    -- Current month metrics
    SUM(dm.total_interactions) AS total_interactions,
    AVG(dm.daily_active_customers) AS avg_daily_customers,
    COUNT(DISTINCT dm.metric_date) AS active_days,
    
    -- Performance indicators
    MAX(dm.daily_active_customers) AS peak_daily_customers,
    MIN(dm.daily_active_customers) AS min_daily_customers,
    STDDEV(dm.daily_active_customers) AS customer_volatility,
    
    -- Quality indicators
    AVG(dm.high_quality_records::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS quality_score_pct,
    
    -- Business health indicators
    COUNT(DISTINCT dm.metric_date) FILTER (WHERE dm.daily_active_customers > 0) AS healthy_days,
    AVG(dm.active_stores) AS avg_active_stores,
    
    -- Growth indicators (compared to previous month)
    gm.month_over_month_growth_pct,
    
    -- Demographic insights
    AVG(dm.male_interactions::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS male_customer_pct,
    AVG(dm.female_interactions::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS female_customer_pct,
    
    -- Operational insights
    AVG(dm.weekend_interactions::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS weekend_activity_pct,
    AVG((dm.morning_peak + dm.lunch_peak + dm.evening_peak)::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS peak_hours_pct,
    
    -- Data freshness and quality
    MAX(dm.metric_date) AS latest_data_date,
    EXTRACT(EPOCH FROM (NOW() - MAX(dm.metric_date))) / 3600 AS data_freshness_hours,
    
    -- Metadata
    NOW() AS calculated_at,
    '{{ var("job_run_id", "unknown") }}' AS job_run_id
    
  FROM daily_metrics dm
  LEFT JOIN growth_metrics gm ON DATE_TRUNC('month', dm.metric_date) = gm.metric_month
  WHERE dm.metric_date >= DATE_TRUNC('month', CURRENT_DATE)
  GROUP BY gm.month_over_month_growth_pct

  UNION ALL

  SELECT 
    'previous_month' AS period_type,
    DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month') AS period_start,
    (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 day')::DATE AS period_end,
    
    -- Previous month metrics for comparison
    SUM(dm.total_interactions) AS total_interactions,
    AVG(dm.daily_active_customers) AS avg_daily_customers,
    COUNT(DISTINCT dm.metric_date) AS active_days,
    
    MAX(dm.daily_active_customers) AS peak_daily_customers,
    MIN(dm.daily_active_customers) AS min_daily_customers,
    STDDEV(dm.daily_active_customers) AS customer_volatility,
    
    AVG(dm.high_quality_records::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS quality_score_pct,
    
    COUNT(DISTINCT dm.metric_date) FILTER (WHERE dm.daily_active_customers > 0) AS healthy_days,
    AVG(dm.active_stores) AS avg_active_stores,
    
    gm.month_over_month_growth_pct,
    
    AVG(dm.male_interactions::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS male_customer_pct,
    AVG(dm.female_interactions::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS female_customer_pct,
    
    AVG(dm.weekend_interactions::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS weekend_activity_pct,
    AVG((dm.morning_peak + dm.lunch_peak + dm.evening_peak)::FLOAT / NULLIF(dm.total_interactions, 0) * 100) AS peak_hours_pct,
    
    MAX(dm.metric_date) AS latest_data_date,
    EXTRACT(EPOCH FROM (NOW() - MAX(dm.metric_date))) / 3600 AS data_freshness_hours,
    
    NOW() AS calculated_at,
    '{{ var("job_run_id", "unknown") }}' AS job_run_id
    
  FROM daily_metrics dm
  LEFT JOIN growth_metrics gm ON DATE_TRUNC('month', dm.metric_date) = gm.metric_month
  WHERE dm.metric_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
    AND dm.metric_date < DATE_TRUNC('month', CURRENT_DATE)
  GROUP BY gm.month_over_month_growth_pct
)

SELECT * FROM current_period_kpis
ORDER BY period_type DESC