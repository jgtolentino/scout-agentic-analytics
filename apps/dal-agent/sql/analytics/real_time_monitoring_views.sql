-- =================================================================
-- REAL-TIME MONITORING VIEWS
-- Live operational monitoring for Scout v7 Platform
-- Created: September 29, 2025
-- =================================================================

-- 1. Live Transaction Monitor
-- Real-time transaction flow and health monitoring
CREATE OR ALTER VIEW dbo.v_live_transaction_monitor AS
WITH recent_activity AS (
    SELECT
        StoreID,
        COUNT(*) as transactions_last_hour,
        COUNT(DISTINCT FacialID) as unique_customers_last_hour,
        AVG(amount) as avg_amount_last_hour,
        SUM(amount) as revenue_last_hour,
        AVG(emotional_satisfaction_index) as avg_satisfaction_last_hour,
        MAX(TransactionDate) as last_transaction_time,

        -- System health indicators
        COUNT(CASE WHEN canonical_tx_id IS NOT NULL THEN 1 END) as valid_transactions,
        COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) as facial_recognized_transactions,
        COUNT(CASE WHEN detected_brands IS NOT NULL AND detected_brands != '' THEN 1 END) as brand_detected_transactions,

        -- Communication patterns
        COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_transactions,
        COUNT(CASE WHEN language_detected IN ('Filipino', 'English', 'Mixed') THEN 1 END) as verbal_transactions,

        -- Alert indicators
        COUNT(CASE WHEN emotional_satisfaction_index < 0.3 THEN 1 END) as low_satisfaction_count,
        COUNT(CASE WHEN politeness_score < 0.2 THEN 1 END) as low_politeness_count

    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= DATEADD(HOUR, -1, GETDATE())
    GROUP BY StoreID
),
today_comparison AS (
    SELECT
        StoreID,
        COUNT(*) as transactions_today,
        AVG(amount) as avg_amount_today,
        SUM(amount) as revenue_today
    FROM dbo.v_ultra_enriched_dataset
    WHERE CAST(TransactionDate AS DATE) = CAST(GETDATE() AS DATE)
    GROUP BY StoreID
),
yesterday_comparison AS (
    SELECT
        StoreID,
        COUNT(*) as transactions_yesterday,
        AVG(amount) as avg_amount_yesterday,
        SUM(amount) as revenue_yesterday
    FROM dbo.v_ultra_enriched_dataset
    WHERE CAST(TransactionDate AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
    GROUP BY StoreID
)
SELECT
    ra.*,
    tc.transactions_today,
    tc.revenue_today,
    yc.transactions_yesterday,
    yc.revenue_yesterday,

    -- Performance indicators
    CASE
        WHEN ra.transactions_last_hour = 0 THEN 'Inactive'
        WHEN ra.transactions_last_hour < 5 THEN 'Low Activity'
        WHEN ra.transactions_last_hour BETWEEN 5 AND 15 THEN 'Normal Activity'
        WHEN ra.transactions_last_hour > 15 THEN 'High Activity'
    END as activity_status,

    -- System health
    CASE
        WHEN CAST(ra.valid_transactions AS FLOAT) / ra.transactions_last_hour < 0.9 THEN 'System Issues'
        WHEN CAST(ra.facial_recognized_transactions AS FLOAT) / ra.transactions_last_hour < 0.7 THEN 'Facial Recognition Issues'
        WHEN ra.avg_satisfaction_last_hour < 0.4 THEN 'Customer Experience Issues'
        ELSE 'Healthy'
    END as system_health,

    -- Trend analysis
    CASE
        WHEN tc.transactions_today > yc.transactions_yesterday THEN 'Increasing'
        WHEN tc.transactions_today < yc.transactions_yesterday THEN 'Decreasing'
        ELSE 'Stable'
    END as daily_trend,

    -- Ratios for dashboard display
    CAST(ra.facial_recognized_transactions AS FLOAT) / NULLIF(ra.transactions_last_hour, 0) * 100 as facial_recognition_rate,
    CAST(ra.silent_transactions AS FLOAT) / NULLIF(ra.transactions_last_hour, 0) * 100 as silent_transaction_rate,
    CAST(ra.low_satisfaction_count AS FLOAT) / NULLIF(ra.transactions_last_hour, 0) * 100 as low_satisfaction_rate,

    GETDATE() as monitor_timestamp

FROM recent_activity ra
LEFT JOIN today_comparison tc ON ra.StoreID = tc.StoreID
LEFT JOIN yesterday_comparison yc ON ra.StoreID = yc.StoreID;

-- 2. System Health Dashboard
-- Overall platform health and performance metrics
CREATE OR ALTER VIEW dbo.v_system_health_dashboard AS
WITH system_metrics AS (
    SELECT
        COUNT(*) as total_transactions_last_hour,
        COUNT(DISTINCT StoreID) as active_stores,
        COUNT(DISTINCT FacialID) as unique_customers_last_hour,
        SUM(amount) as total_revenue_last_hour,
        AVG(amount) as avg_transaction_amount,

        -- Data quality metrics
        COUNT(CASE WHEN canonical_tx_id IS NOT NULL THEN 1 END) as valid_transaction_ids,
        COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) as facial_data_available,
        COUNT(CASE WHEN detected_brands IS NOT NULL AND detected_brands != '' THEN 1 END) as brand_detection_success,
        COUNT(CASE WHEN primary_category != 'unspecified' THEN 1 END) as category_classification_success,

        -- Customer experience metrics
        AVG(emotional_satisfaction_index) as avg_platform_satisfaction,
        AVG(politeness_score) as avg_platform_politeness,

        -- Conversation intelligence metrics
        COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) as filipino_conversations,
        COUNT(CASE WHEN language_detected = 'English' THEN 1 END) as english_conversations,
        COUNT(CASE WHEN language_detected = 'Mixed' THEN 1 END) as mixed_conversations,
        COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_conversations,

        -- Alert conditions
        COUNT(CASE WHEN emotional_satisfaction_index < 0.3 THEN 1 END) as critical_satisfaction_alerts,
        COUNT(CASE WHEN politeness_score < 0.2 THEN 1 END) as communication_alerts

    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= DATEADD(HOUR, -1, GETDATE())
),
historical_comparison AS (
    SELECT
        COUNT(*) as transactions_same_hour_yesterday,
        AVG(amount) as avg_amount_same_hour_yesterday,
        AVG(emotional_satisfaction_index) as satisfaction_same_hour_yesterday
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= DATEADD(HOUR, -25, GETDATE())
      AND TransactionDate < DATEADD(HOUR, -24, GETDATE())
)
SELECT
    sm.*,
    hc.transactions_same_hour_yesterday,
    hc.avg_amount_same_hour_yesterday,
    hc.satisfaction_same_hour_yesterday,

    -- Platform health scores (0-100)
    CASE
        WHEN sm.total_transactions_last_hour = 0 THEN 0
        ELSE CAST(sm.valid_transaction_ids AS FLOAT) / sm.total_transactions_last_hour * 100
    END as transaction_validity_score,

    CASE
        WHEN sm.total_transactions_last_hour = 0 THEN 0
        ELSE CAST(sm.facial_data_available AS FLOAT) / sm.total_transactions_last_hour * 100
    END as facial_recognition_score,

    CASE
        WHEN sm.total_transactions_last_hour = 0 THEN 0
        ELSE CAST(sm.brand_detection_success AS FLOAT) / sm.total_transactions_last_hour * 100
    END as brand_detection_score,

    CASE
        WHEN sm.total_transactions_last_hour = 0 THEN 0
        ELSE CAST(sm.category_classification_success AS FLOAT) / sm.total_transactions_last_hour * 100
    END as category_classification_score,

    sm.avg_platform_satisfaction * 100 as customer_satisfaction_score,

    -- Overall platform health (weighted average)
    (
        (CASE WHEN sm.total_transactions_last_hour = 0 THEN 0 ELSE CAST(sm.valid_transaction_ids AS FLOAT) / sm.total_transactions_last_hour END * 0.3) +
        (CASE WHEN sm.total_transactions_last_hour = 0 THEN 0 ELSE CAST(sm.facial_data_available AS FLOAT) / sm.total_transactions_last_hour END * 0.2) +
        (CASE WHEN sm.total_transactions_last_hour = 0 THEN 0 ELSE CAST(sm.brand_detection_success AS FLOAT) / sm.total_transactions_last_hour END * 0.2) +
        (sm.avg_platform_satisfaction * 0.3)
    ) * 100 as overall_platform_health_score,

    -- Status indicators
    CASE
        WHEN sm.total_transactions_last_hour = 0 THEN 'System Down'
        WHEN sm.active_stores < 3 THEN 'Limited Operations'
        WHEN sm.avg_platform_satisfaction < 0.3 THEN 'Customer Experience Critical'
        WHEN CAST(sm.valid_transaction_ids AS FLOAT) / sm.total_transactions_last_hour < 0.8 THEN 'Data Quality Issues'
        ELSE 'Operational'
    END as platform_status,

    -- Performance vs yesterday same hour
    CASE
        WHEN sm.total_transactions_last_hour > hc.transactions_same_hour_yesterday * 1.1 THEN 'Significantly Higher'
        WHEN sm.total_transactions_last_hour > hc.transactions_same_hour_yesterday THEN 'Higher'
        WHEN sm.total_transactions_last_hour < hc.transactions_same_hour_yesterday * 0.9 THEN 'Significantly Lower'
        WHEN sm.total_transactions_last_hour < hc.transactions_same_hour_yesterday THEN 'Lower'
        ELSE 'Similar'
    END as performance_vs_yesterday,

    GETDATE() as dashboard_timestamp

FROM system_metrics sm
CROSS JOIN historical_comparison hc;

-- 3. Store Activity Heatmap
-- Real-time store activity visualization data
CREATE OR ALTER VIEW dbo.v_store_activity_heatmap AS
WITH store_hourly_activity AS (
    SELECT
        StoreID,
        DATEPART(HOUR, TransactionDate) as hour_of_day,
        COUNT(*) as transaction_count,
        AVG(emotional_satisfaction_index) as avg_satisfaction,
        COUNT(DISTINCT FacialID) as unique_customers,
        SUM(amount) as revenue
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= DATEADD(DAY, -1, GETDATE())  -- Last 24 hours
    GROUP BY StoreID, DATEPART(HOUR, TransactionDate)
),
store_activity_summary AS (
    SELECT
        StoreID,
        SUM(transaction_count) as total_transactions_24h,
        AVG(avg_satisfaction) as overall_satisfaction_24h,
        SUM(unique_customers) as total_unique_customers_24h,
        SUM(revenue) as total_revenue_24h,
        MAX(transaction_count) as peak_hour_transactions
    FROM store_hourly_activity
    GROUP BY StoreID
)
SELECT
    sha.StoreID,
    sha.hour_of_day,
    sha.transaction_count,
    sha.avg_satisfaction,
    sha.unique_customers,
    sha.revenue,
    sas.total_transactions_24h,
    sas.overall_satisfaction_24h,
    sas.peak_hour_transactions,

    -- Activity intensity (0-1 scale)
    CASE
        WHEN sas.peak_hour_transactions = 0 THEN 0
        ELSE CAST(sha.transaction_count AS FLOAT) / sas.peak_hour_transactions
    END as activity_intensity,

    -- Satisfaction level
    CASE
        WHEN sha.avg_satisfaction >= 0.7 THEN 'High'
        WHEN sha.avg_satisfaction >= 0.5 THEN 'Medium'
        WHEN sha.avg_satisfaction >= 0.3 THEN 'Low'
        ELSE 'Critical'
    END as satisfaction_level,

    -- Hour classification
    CASE
        WHEN sha.hour_of_day BETWEEN 6 AND 9 THEN 'Morning'
        WHEN sha.hour_of_day BETWEEN 10 AND 11 THEN 'Late Morning'
        WHEN sha.hour_of_day BETWEEN 12 AND 14 THEN 'Lunch'
        WHEN sha.hour_of_day BETWEEN 15 AND 17 THEN 'Afternoon'
        WHEN sha.hour_of_day BETWEEN 18 AND 20 THEN 'Evening'
        WHEN sha.hour_of_day BETWEEN 21 AND 22 THEN 'Night'
        ELSE 'Off Hours'
    END as time_period,

    -- Performance indicators
    CASE
        WHEN CAST(sha.transaction_count AS FLOAT) / sas.peak_hour_transactions > 0.8 THEN 'Peak'
        WHEN CAST(sha.transaction_count AS FLOAT) / sas.peak_hour_transactions > 0.5 THEN 'Busy'
        WHEN CAST(sha.transaction_count AS FLOAT) / sas.peak_hour_transactions > 0.2 THEN 'Moderate'
        ELSE 'Slow'
    END as activity_level,

    GETDATE() as heatmap_timestamp

FROM store_hourly_activity sha
JOIN store_activity_summary sas ON sha.StoreID = sas.StoreID
ORDER BY sha.StoreID, sha.hour_of_day;

-- 4. Customer Experience Real-Time Monitor
-- Live customer satisfaction and experience tracking
CREATE OR ALTER VIEW dbo.v_customer_experience_monitor AS
WITH recent_experience AS (
    SELECT
        StoreID,
        COUNT(*) as total_interactions,

        -- Satisfaction metrics
        AVG(emotional_satisfaction_index) as avg_satisfaction,
        COUNT(CASE WHEN emotional_satisfaction_index >= 0.7 THEN 1 END) as high_satisfaction_count,
        COUNT(CASE WHEN emotional_satisfaction_index < 0.3 THEN 1 END) as low_satisfaction_count,

        -- Communication quality
        AVG(politeness_score) as avg_politeness,
        COUNT(CASE WHEN politeness_score >= 0.7 THEN 1 END) as polite_interactions,
        COUNT(CASE WHEN politeness_score < 0.3 THEN 1 END) as impolite_interactions,

        -- Language patterns
        COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) as filipino_interactions,
        COUNT(CASE WHEN language_detected = 'English' THEN 1 END) as english_interactions,
        COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_interactions,

        -- Cultural patterns
        AVG(suki_loyalty_index) as avg_suki_loyalty,
        COUNT(CASE WHEN suki_loyalty_index >= 0.7 THEN 1 END) as strong_suki_interactions,

        -- Alert conditions
        COUNT(CASE WHEN emotional_satisfaction_index < 0.2 THEN 1 END) as critical_satisfaction_alerts,
        COUNT(CASE WHEN politeness_score < 0.2 THEN 1 END) as critical_politeness_alerts,

        -- Recent timestamp
        MAX(TransactionDate) as last_interaction_time

    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= DATEADD(HOUR, -2, GETDATE())  -- Last 2 hours
    GROUP BY StoreID
),
experience_trends AS (
    SELECT
        StoreID,
        AVG(emotional_satisfaction_index) as satisfaction_4h_ago,
        AVG(politeness_score) as politeness_4h_ago
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= DATEADD(HOUR, -6, GETDATE())
      AND TransactionDate < DATEADD(HOUR, -4, GETDATE())
    GROUP BY StoreID
)
SELECT
    re.*,
    et.satisfaction_4h_ago,
    et.politeness_4h_ago,

    -- Experience scores (0-100)
    re.avg_satisfaction * 100 as satisfaction_score,
    re.avg_politeness * 100 as politeness_score,

    -- Experience health status
    CASE
        WHEN re.avg_satisfaction < 0.3 THEN 'Critical'
        WHEN re.avg_satisfaction < 0.5 THEN 'Poor'
        WHEN re.avg_satisfaction < 0.7 THEN 'Fair'
        ELSE 'Good'
    END as experience_status,

    -- Trend analysis
    CASE
        WHEN re.avg_satisfaction > et.satisfaction_4h_ago + 0.1 THEN 'Improving'
        WHEN re.avg_satisfaction < et.satisfaction_4h_ago - 0.1 THEN 'Declining'
        ELSE 'Stable'
    END as satisfaction_trend,

    CASE
        WHEN re.avg_politeness > et.politeness_4h_ago + 0.1 THEN 'Improving'
        WHEN re.avg_politeness < et.politeness_4h_ago - 0.1 THEN 'Declining'
        ELSE 'Stable'
    END as politeness_trend,

    -- Cultural engagement
    CASE
        WHEN CAST(re.filipino_interactions AS FLOAT) / re.total_interactions > 0.6 THEN 'Filipino-Dominant'
        WHEN CAST(re.english_interactions AS FLOAT) / re.total_interactions > 0.6 THEN 'English-Dominant'
        WHEN CAST(re.silent_interactions AS FLOAT) / re.total_interactions > 0.6 THEN 'Silent-Dominant'
        ELSE 'Mixed Languages'
    END as language_pattern,

    -- Alert priorities
    CASE
        WHEN re.critical_satisfaction_alerts > 0 OR re.critical_politeness_alerts > 0 THEN 'High'
        WHEN re.low_satisfaction_count > re.total_interactions * 0.3 THEN 'Medium'
        WHEN re.avg_satisfaction < 0.5 THEN 'Low'
        ELSE 'None'
    END as alert_priority,

    -- Ratios for display
    CAST(re.high_satisfaction_count AS FLOAT) / NULLIF(re.total_interactions, 0) * 100 as high_satisfaction_rate,
    CAST(re.silent_interactions AS FLOAT) / NULLIF(re.total_interactions, 0) * 100 as silent_interaction_rate,
    CAST(re.strong_suki_interactions AS FLOAT) / NULLIF(re.total_interactions, 0) * 100 as strong_suki_rate,

    GETDATE() as monitor_timestamp

FROM recent_experience re
LEFT JOIN experience_trends et ON re.StoreID = et.StoreID
WHERE re.total_interactions > 0
ORDER BY
    CASE
        WHEN re.critical_satisfaction_alerts > 0 OR re.critical_politeness_alerts > 0 THEN 1
        WHEN re.avg_satisfaction < 0.3 THEN 2
        ELSE 3
    END,
    re.StoreID;

-- 5. Platform Performance KPI Dashboard
-- Key performance indicators for executive dashboard
CREATE OR ALTER VIEW dbo.v_platform_performance_kpi AS
WITH kpi_calculations AS (
    SELECT
        -- Transaction metrics
        COUNT(*) as total_transactions_today,
        COUNT(DISTINCT StoreID) as active_stores_today,
        COUNT(DISTINCT FacialID) as unique_customers_today,
        SUM(amount) as total_revenue_today,
        AVG(amount) as avg_transaction_amount_today,

        -- Quality metrics
        AVG(emotional_satisfaction_index) as avg_satisfaction_today,
        AVG(politeness_score) as avg_politeness_today,

        -- System performance
        COUNT(CASE WHEN canonical_tx_id IS NOT NULL THEN 1 END) as valid_transactions_today,
        COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) as facial_recognized_today,
        COUNT(CASE WHEN detected_brands IS NOT NULL AND detected_brands != '' THEN 1 END) as brand_detected_today,

        -- Cultural insights
        AVG(suki_loyalty_index) as avg_suki_loyalty_today,
        AVG(tingi_preference_score) as avg_tingi_preference_today,

        -- Conversation intelligence
        COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_transactions_today,
        COUNT(CASE WHEN language_detected IN ('Filipino', 'English', 'Mixed') THEN 1 END) as verbal_transactions_today

    FROM dbo.v_ultra_enriched_dataset
    WHERE CAST(TransactionDate AS DATE) = CAST(GETDATE() AS DATE)
),
yesterday_comparison AS (
    SELECT
        COUNT(*) as total_transactions_yesterday,
        SUM(amount) as total_revenue_yesterday,
        AVG(emotional_satisfaction_index) as avg_satisfaction_yesterday,
        COUNT(DISTINCT FacialID) as unique_customers_yesterday
    FROM dbo.v_ultra_enriched_dataset
    WHERE CAST(TransactionDate AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
),
last_week_comparison AS (
    SELECT
        COUNT(*) / 7.0 as avg_daily_transactions_last_week,
        SUM(amount) / 7.0 as avg_daily_revenue_last_week,
        AVG(emotional_satisfaction_index) as avg_satisfaction_last_week
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= DATEADD(DAY, -7, GETDATE())
      AND TransactionDate < CAST(GETDATE() AS DATE)
)
SELECT
    kpi.*,
    yc.total_transactions_yesterday,
    yc.total_revenue_yesterday,
    yc.avg_satisfaction_yesterday,
    yc.unique_customers_yesterday,
    lw.avg_daily_transactions_last_week,
    lw.avg_daily_revenue_last_week,
    lw.avg_satisfaction_last_week,

    -- Performance indicators (0-100 scores)
    kpi.avg_satisfaction_today * 100 as customer_satisfaction_score,

    CASE
        WHEN kpi.total_transactions_today = 0 THEN 0
        ELSE CAST(kpi.valid_transactions_today AS FLOAT) / kpi.total_transactions_today * 100
    END as data_quality_score,

    CASE
        WHEN kpi.total_transactions_today = 0 THEN 0
        ELSE CAST(kpi.facial_recognized_today AS FLOAT) / kpi.total_transactions_today * 100
    END as facial_recognition_rate,

    CASE
        WHEN kpi.total_transactions_today = 0 THEN 0
        ELSE CAST(kpi.verbal_transactions_today AS FLOAT) / kpi.total_transactions_today * 100
    END as conversation_engagement_rate,

    kpi.avg_suki_loyalty_today * 100 as suki_relationship_score,

    -- Growth indicators
    CASE
        WHEN yc.total_transactions_yesterday = 0 THEN 0
        ELSE ((CAST(kpi.total_transactions_today AS FLOAT) - yc.total_transactions_yesterday) / yc.total_transactions_yesterday) * 100
    END as transaction_growth_vs_yesterday,

    CASE
        WHEN yc.total_revenue_yesterday = 0 THEN 0
        ELSE ((kpi.total_revenue_today - yc.total_revenue_yesterday) / yc.total_revenue_yesterday) * 100
    END as revenue_growth_vs_yesterday,

    CASE
        WHEN lw.avg_daily_transactions_last_week = 0 THEN 0
        ELSE ((kpi.total_transactions_today - lw.avg_daily_transactions_last_week) / lw.avg_daily_transactions_last_week) * 100
    END as transaction_growth_vs_last_week,

    -- Status indicators
    CASE
        WHEN kpi.avg_satisfaction_today >= 0.7 THEN 'Excellent'
        WHEN kpi.avg_satisfaction_today >= 0.6 THEN 'Good'
        WHEN kpi.avg_satisfaction_today >= 0.5 THEN 'Fair'
        WHEN kpi.avg_satisfaction_today >= 0.4 THEN 'Poor'
        ELSE 'Critical'
    END as satisfaction_status,

    CASE
        WHEN kpi.total_transactions_today > yc.total_transactions_yesterday * 1.1 THEN 'Strong Growth'
        WHEN kpi.total_transactions_today > yc.total_transactions_yesterday THEN 'Growth'
        WHEN kpi.total_transactions_today > yc.total_transactions_yesterday * 0.9 THEN 'Stable'
        WHEN kpi.total_transactions_today > yc.total_transactions_yesterday * 0.8 THEN 'Decline'
        ELSE 'Significant Decline'
    END as activity_trend,

    CAST(GETDATE() AS DATE) as kpi_date,
    GETDATE() as last_updated

FROM kpi_calculations kpi
CROSS JOIN yesterday_comparison yc
CROSS JOIN last_week_comparison lw;

-- =================================================================
-- DOCUMENTATION AND USAGE NOTES
-- =================================================================

/*
REAL-TIME MONITORING VIEWS CREATED:

1. v_live_transaction_monitor
   - Last hour activity per store
   - System health indicators and trends
   - Facial recognition and data quality monitoring

2. v_system_health_dashboard
   - Overall platform health score
   - Data quality and system performance metrics
   - Comparative analysis vs previous periods

3. v_store_activity_heatmap
   - 24-hour activity visualization data
   - Hour-by-hour intensity mapping
   - Peak time identification

4. v_customer_experience_monitor
   - Real-time customer satisfaction tracking
   - Communication quality and cultural patterns
   - Experience trend analysis and alerts

5. v_platform_performance_kpi
   - Executive dashboard KPIs
   - Growth indicators and status summaries
   - Comprehensive platform performance metrics

MONITORING DASHBOARD QUERIES:

-- Check current system health
SELECT platform_status, overall_platform_health_score, active_stores
FROM dbo.v_system_health_dashboard;

-- Get store activity alerts
SELECT StoreID, activity_status, system_health, daily_trend
FROM dbo.v_live_transaction_monitor
WHERE system_health != 'Healthy'
ORDER BY last_transaction_time DESC;

-- Monitor customer experience issues
SELECT StoreID, experience_status, alert_priority, satisfaction_trend
FROM dbo.v_customer_experience_monitor
WHERE alert_priority IN ('High', 'Medium')
ORDER BY alert_priority, avg_satisfaction;

-- Today's KPI summary
SELECT customer_satisfaction_score, transaction_growth_vs_yesterday,
       revenue_growth_vs_yesterday, activity_trend
FROM dbo.v_platform_performance_kpi;

BUSINESS VALUE:
- Real-time operational visibility
- Proactive issue detection and alerting
- Cultural pattern monitoring for Filipino context
- Data quality and system health tracking
- Executive dashboard for strategic decisions
*/