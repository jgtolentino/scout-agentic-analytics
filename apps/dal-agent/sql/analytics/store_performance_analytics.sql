-- =================================================================
-- STORE PERFORMANCE ANALYTICS
-- Operational analytics for store managers using ultra-enriched dataset
-- Created: September 29, 2025
-- =================================================================

-- 1. Store Performance Summary View
-- Real-time operational metrics for store managers
CREATE OR ALTER VIEW dbo.v_store_performance_summary AS
WITH store_metrics AS (
    SELECT
        StoreID,
        COUNT(*) as total_transactions,
        COUNT(DISTINCT FacialID) as unique_customers,
        COUNT(DISTINCT customer_behavior_segment) as behavior_segments,
        AVG(amount) as avg_transaction_amount,
        SUM(amount) as total_revenue,
        MIN(TransactionDate) as first_transaction,
        MAX(TransactionDate) as last_transaction,

        -- Customer experience metrics
        AVG(politeness_score) as avg_politeness_score,
        AVG(emotional_satisfaction_index) as avg_satisfaction,
        SUM(CASE WHEN language_detected = 'Filipino' THEN 1 ELSE 0 END) as filipino_transactions,
        SUM(CASE WHEN language_detected = 'English' THEN 1 ELSE 0 END) as english_transactions,
        SUM(CASE WHEN language_detected = 'Silent' THEN 1 ELSE 0 END) as silent_transactions,

        -- Operational patterns
        AVG(suki_loyalty_index) as avg_suki_loyalty,
        AVG(tingi_preference_score) as avg_tingi_preference,
        AVG(payday_correlation_score) as avg_payday_pattern,
        COUNT(DISTINCT Age) as age_diversity,

        -- Product insights
        SUM(item_count) as total_items_sold,
        COUNT(DISTINCT primary_category) as category_diversity,

        -- Peak hour analysis
        COUNT(CASE WHEN DATEPART(HOUR, TransactionDate) BETWEEN 7 AND 11 THEN 1 END) as morning_rush_count,
        COUNT(CASE WHEN DATEPART(HOUR, TransactionDate) BETWEEN 12 AND 14 THEN 1 END) as lunch_rush_count,
        COUNT(CASE WHEN DATEPART(HOUR, TransactionDate) BETWEEN 17 AND 20 THEN 1 END) as evening_rush_count

    FROM dbo.v_ultra_enriched_dataset
    WHERE StoreID IS NOT NULL
    GROUP BY StoreID
),
store_rankings AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as revenue_rank,
        ROW_NUMBER() OVER (ORDER BY avg_satisfaction DESC) as satisfaction_rank,
        ROW_NUMBER() OVER (ORDER BY avg_suki_loyalty DESC) as loyalty_rank,
        ROW_NUMBER() OVER (ORDER BY unique_customers DESC) as customer_count_rank
    FROM store_metrics
)
SELECT
    s.*,
    -- Performance indicators
    CASE
        WHEN revenue_rank <= 3 THEN 'Top Performer'
        WHEN revenue_rank <= 6 THEN 'Good Performer'
        ELSE 'Needs Attention'
    END as revenue_performance_tier,

    CASE
        WHEN avg_satisfaction >= 0.7 THEN 'High Satisfaction'
        WHEN avg_satisfaction >= 0.5 THEN 'Moderate Satisfaction'
        ELSE 'Low Satisfaction'
    END as satisfaction_tier,

    CASE
        WHEN avg_suki_loyalty >= 0.7 THEN 'Strong Suki Culture'
        WHEN avg_suki_loyalty >= 0.4 THEN 'Developing Suki'
        ELSE 'Transactional'
    END as loyalty_culture,

    -- Activity patterns
    CAST(filipino_transactions AS FLOAT) / total_transactions as filipino_ratio,
    CAST(silent_transactions AS FLOAT) / total_transactions as silent_ratio,
    CAST(morning_rush_count AS FLOAT) / total_transactions as morning_rush_ratio,
    CAST(evening_rush_count AS FLOAT) / total_transactions as evening_rush_ratio,

    DATEDIFF(DAY, first_transaction, last_transaction) as operation_days
FROM store_rankings s;

-- 2. Store Customer Behavior Breakdown
-- Detailed customer segment analysis per store
CREATE OR ALTER VIEW dbo.v_store_customer_segments AS
SELECT
    StoreID,
    customer_behavior_segment,
    COUNT(*) as segment_transactions,
    COUNT(DISTINCT FacialID) as segment_customers,
    AVG(amount) as segment_avg_amount,
    SUM(amount) as segment_revenue,
    AVG(suki_loyalty_index) as segment_suki_loyalty,
    AVG(tingi_preference_score) as segment_tingi_preference,
    AVG(emotional_satisfaction_index) as segment_satisfaction,

    -- Percentage of store total
    CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER (PARTITION BY StoreID) * 100 as pct_of_store_transactions,

    -- Revenue contribution
    CAST(SUM(amount) AS FLOAT) / SUM(SUM(amount)) OVER (PARTITION BY StoreID) * 100 as pct_of_store_revenue,

    -- Communication preferences
    SUM(CASE WHEN language_detected = 'Filipino' THEN 1 ELSE 0 END) as filipino_count,
    SUM(CASE WHEN language_detected = 'English' THEN 1 ELSE 0 END) as english_count,
    SUM(CASE WHEN language_detected = 'Silent' THEN 1 ELSE 0 END) as silent_count,

    -- Most common age group
    MODE() WITHIN GROUP (ORDER BY Age) as most_common_age,
    MODE() WITHIN GROUP (ORDER BY Gender) as most_common_gender

FROM dbo.v_ultra_enriched_dataset
WHERE StoreID IS NOT NULL AND customer_behavior_segment IS NOT NULL
GROUP BY StoreID, customer_behavior_segment;

-- 3. Store Peak Hours Analysis
-- Hour-by-hour operational patterns
CREATE OR ALTER VIEW dbo.v_store_peak_hours AS
WITH hourly_data AS (
    SELECT
        StoreID,
        DATEPART(HOUR, TransactionDate) as transaction_hour,
        COUNT(*) as transaction_count,
        COUNT(DISTINCT FacialID) as unique_customers,
        AVG(amount) as avg_amount,
        SUM(amount) as total_revenue,
        AVG(politeness_score) as avg_politeness,
        AVG(emotional_satisfaction_index) as avg_satisfaction,

        -- Language patterns by hour
        SUM(CASE WHEN language_detected = 'Filipino' THEN 1 ELSE 0 END) as filipino_count,
        SUM(CASE WHEN language_detected = 'Silent' THEN 1 ELSE 0 END) as silent_count,

        -- Customer types by hour
        AVG(suki_loyalty_index) as avg_suki_loyalty,
        AVG(tingi_preference_score) as avg_tingi_preference

    FROM dbo.v_ultra_enriched_dataset
    WHERE StoreID IS NOT NULL
      AND TransactionDate IS NOT NULL
      AND DATEPART(HOUR, TransactionDate) BETWEEN 6 AND 22  -- Operating hours
    GROUP BY StoreID, DATEPART(HOUR, TransactionDate)
),
store_totals AS (
    SELECT
        StoreID,
        SUM(transaction_count) as store_total_transactions,
        AVG(avg_amount) as store_avg_amount
    FROM hourly_data
    GROUP BY StoreID
)
SELECT
    h.*,
    st.store_total_transactions,

    -- Hour performance vs store average
    CAST(h.transaction_count AS FLOAT) / st.store_total_transactions * 100 as pct_of_daily_transactions,
    h.avg_amount - st.store_avg_amount as amount_vs_store_avg,

    -- Peak identification
    CASE
        WHEN CAST(h.transaction_count AS FLOAT) / st.store_total_transactions > 0.08 THEN 'Peak Hour'
        WHEN CAST(h.transaction_count AS FLOAT) / st.store_total_transactions > 0.05 THEN 'Busy Hour'
        WHEN CAST(h.transaction_count AS FLOAT) / st.store_total_transactions > 0.03 THEN 'Normal Hour'
        ELSE 'Slow Hour'
    END as hour_classification,

    -- Hour labels
    CASE
        WHEN transaction_hour BETWEEN 6 AND 8 THEN 'Early Morning'
        WHEN transaction_hour BETWEEN 9 AND 11 THEN 'Morning Rush'
        WHEN transaction_hour BETWEEN 12 AND 14 THEN 'Lunch Time'
        WHEN transaction_hour BETWEEN 15 AND 17 THEN 'Afternoon'
        WHEN transaction_hour BETWEEN 18 AND 20 THEN 'Evening Rush'
        WHEN transaction_hour BETWEEN 21 AND 22 THEN 'Late Evening'
        ELSE 'Off Hours'
    END as time_period

FROM hourly_data h
JOIN store_totals st ON h.StoreID = st.StoreID
ORDER BY h.StoreID, h.transaction_hour;

-- 4. Store Product Performance
-- Category and item performance per store
CREATE OR ALTER VIEW dbo.v_store_product_performance AS
WITH store_category_data AS (
    SELECT
        StoreID,
        primary_category,
        COUNT(*) as category_transactions,
        COUNT(DISTINCT FacialID) as category_customers,
        SUM(item_count) as total_items,
        AVG(amount) as avg_transaction_amount,
        SUM(amount) as category_revenue,

        -- Customer satisfaction by category
        AVG(emotional_satisfaction_index) as category_satisfaction,
        AVG(politeness_score) as category_politeness,

        -- Customer behavior
        AVG(suki_loyalty_index) as category_suki_loyalty,
        AVG(tingi_preference_score) as category_tingi_preference,

        -- Top brands in category
        STRING_AGG(detected_brands, ', ') WITHIN GROUP (ORDER BY detected_brands) as brands_in_category

    FROM dbo.v_ultra_enriched_dataset
    WHERE StoreID IS NOT NULL
      AND primary_category IS NOT NULL
      AND primary_category != 'unspecified'
    GROUP BY StoreID, primary_category
),
store_totals AS (
    SELECT
        StoreID,
        SUM(category_transactions) as store_total_transactions,
        SUM(category_revenue) as store_total_revenue
    FROM store_category_data
    GROUP BY StoreID
)
SELECT
    scd.*,
    st.store_total_transactions,
    st.store_total_revenue,

    -- Category performance metrics
    CAST(scd.category_transactions AS FLOAT) / st.store_total_transactions * 100 as pct_of_store_transactions,
    CAST(scd.category_revenue AS FLOAT) / st.store_total_revenue * 100 as pct_of_store_revenue,

    -- Category ranking within store
    ROW_NUMBER() OVER (PARTITION BY scd.StoreID ORDER BY scd.category_revenue DESC) as revenue_rank_in_store,
    ROW_NUMBER() OVER (PARTITION BY scd.StoreID ORDER BY scd.category_transactions DESC) as transaction_rank_in_store,

    -- Performance indicators
    CASE
        WHEN CAST(scd.category_revenue AS FLOAT) / st.store_total_revenue > 0.2 THEN 'Top Category'
        WHEN CAST(scd.category_revenue AS FLOAT) / st.store_total_revenue > 0.1 THEN 'Important Category'
        WHEN CAST(scd.category_revenue AS FLOAT) / st.store_total_revenue > 0.05 THEN 'Regular Category'
        ELSE 'Minor Category'
    END as category_importance,

    CASE
        WHEN category_satisfaction >= 0.7 THEN 'High Satisfaction'
        WHEN category_satisfaction >= 0.5 THEN 'Moderate Satisfaction'
        ELSE 'Needs Improvement'
    END as satisfaction_level

FROM store_category_data scd
JOIN store_totals st ON scd.StoreID = st.StoreID
ORDER BY scd.StoreID, scd.category_revenue DESC;

-- 5. Store Cultural Patterns Analysis
-- Filipino sari-sari store cultural insights
CREATE OR ALTER VIEW dbo.v_store_cultural_patterns AS
SELECT
    StoreID,

    -- Suki relationship strength
    AVG(suki_loyalty_index) as avg_suki_loyalty,
    COUNT(CASE WHEN suki_loyalty_index >= 0.7 THEN 1 END) as strong_suki_customers,
    COUNT(CASE WHEN suki_loyalty_index BETWEEN 0.4 AND 0.69 THEN 1 END) as developing_suki_customers,
    COUNT(CASE WHEN suki_loyalty_index < 0.4 THEN 1 END) as transactional_customers,

    -- Tingi (small quantity) culture
    AVG(tingi_preference_score) as avg_tingi_preference,
    COUNT(CASE WHEN tingi_preference_score >= 0.7 THEN 1 END) as strong_tingi_customers,

    -- Payday patterns (15th and 30th)
    AVG(payday_correlation_score) as avg_payday_correlation,
    COUNT(CASE WHEN payday_correlation_score >= 0.6 THEN 1 END) as payday_dependent_customers,

    -- Language and communication patterns
    COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) as filipino_transactions,
    COUNT(CASE WHEN language_detected = 'English' THEN 1 END) as english_transactions,
    COUNT(CASE WHEN language_detected = 'Mixed' THEN 1 END) as mixed_language_transactions,
    COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_transactions,

    -- Community connection indicators
    AVG(politeness_score) as avg_politeness,
    AVG(emotional_satisfaction_index) as avg_satisfaction,
    COUNT(DISTINCT neighborhood_persona) as persona_diversity,

    -- Age and gender patterns
    COUNT(CASE WHEN Age BETWEEN 18 AND 30 THEN 1 END) as young_adult_customers,
    COUNT(CASE WHEN Age BETWEEN 31 AND 45 THEN 1 END) as adult_customers,
    COUNT(CASE WHEN Age BETWEEN 46 AND 60 THEN 1 END) as mature_customers,
    COUNT(CASE WHEN Gender = 'Female' THEN 1 END) as female_customers,
    COUNT(CASE WHEN Gender = 'Male' THEN 1 END) as male_customers,

    COUNT(*) as total_transactions,
    COUNT(DISTINCT FacialID) as unique_customers,

    -- Cultural classification
    CASE
        WHEN AVG(suki_loyalty_index) >= 0.6 AND AVG(tingi_preference_score) >= 0.6 THEN 'Traditional Sari-Sari'
        WHEN AVG(suki_loyalty_index) >= 0.6 THEN 'Relationship-Focused'
        WHEN AVG(tingi_preference_score) >= 0.6 THEN 'Convenience-Focused'
        ELSE 'Transitional Store'
    END as cultural_store_type,

    -- Communication preference
    CASE
        WHEN COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) >
             COUNT(CASE WHEN language_detected = 'English' THEN 1 END) THEN 'Filipino-Dominant'
        WHEN COUNT(CASE WHEN language_detected = 'English' THEN 1 END) >
             COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) THEN 'English-Dominant'
        WHEN COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) >
             COUNT(CASE WHEN language_detected != 'Silent' THEN 1 END) THEN 'Silent-Dominant'
        ELSE 'Balanced Communication'
    END as communication_pattern

FROM dbo.v_ultra_enriched_dataset
WHERE StoreID IS NOT NULL
GROUP BY StoreID
ORDER BY StoreID;

-- 6. Store Operational Alerts
-- Real-time alerts and recommendations for store managers
CREATE OR ALTER VIEW dbo.v_store_operational_alerts AS
WITH recent_data AS (
    -- Focus on last 7 days of data
    SELECT *
    FROM dbo.v_ultra_enriched_dataset
    WHERE StoreID IS NOT NULL
      AND TransactionDate >= DATEADD(DAY, -7, GETDATE())
),
store_alerts AS (
    SELECT
        StoreID,
        COUNT(*) as recent_transactions,
        AVG(emotional_satisfaction_index) as recent_satisfaction,
        AVG(politeness_score) as recent_politeness,
        COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_count,
        COUNT(DISTINCT FacialID) as recent_unique_customers,
        AVG(amount) as recent_avg_amount,

        -- Alert conditions
        CASE
            WHEN AVG(emotional_satisfaction_index) < 0.4 THEN 'Low Satisfaction Alert'
            WHEN AVG(politeness_score) < 0.3 THEN 'Communication Issues'
            WHEN COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) > COUNT(*) * 0.6 THEN 'High Silent Transactions'
            WHEN COUNT(*) < 10 THEN 'Low Activity Alert'
            ELSE 'Normal Operations'
        END as alert_type,

        CASE
            WHEN AVG(emotional_satisfaction_index) < 0.3 OR AVG(politeness_score) < 0.2 THEN 'High'
            WHEN AVG(emotional_satisfaction_index) < 0.4 OR AVG(politeness_score) < 0.3 THEN 'Medium'
            WHEN COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) > COUNT(*) * 0.6 THEN 'Medium'
            WHEN COUNT(*) < 10 THEN 'Low'
            ELSE 'None'
        END as alert_priority

    FROM recent_data
    GROUP BY StoreID
)
SELECT
    sa.*,

    -- Recommendations based on alerts
    CASE
        WHEN alert_type = 'Low Satisfaction Alert' THEN 'Review customer service training. Check product quality and pricing.'
        WHEN alert_type = 'Communication Issues' THEN 'Train staff on polite customer interaction. Review conversation patterns.'
        WHEN alert_type = 'High Silent Transactions' THEN 'Investigate why customers are not speaking. Check equipment or environment.'
        WHEN alert_type = 'Low Activity Alert' THEN 'Review store operations. Check if store is properly open and accessible.'
        ELSE 'Continue current operations. Monitor trends.'
    END as recommendation,

    GETDATE() as alert_generated_at

FROM store_alerts sa
WHERE alert_type != 'Normal Operations'
ORDER BY
    CASE alert_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END,
    StoreID;

-- =================================================================
-- DOCUMENTATION AND USAGE NOTES
-- =================================================================

/*
STORE PERFORMANCE ANALYTICS VIEWS CREATED:

1. v_store_performance_summary
   - Overall store performance metrics
   - Revenue, customer satisfaction, loyalty patterns
   - Peak hour analysis and operational insights

2. v_store_customer_segments
   - Customer behavior breakdown by store
   - Segment revenue contribution and characteristics
   - Communication and demographic patterns

3. v_store_peak_hours
   - Hour-by-hour operational patterns
   - Peak time identification and customer behavior
   - Revenue and satisfaction trends by time

4. v_store_product_performance
   - Category performance per store
   - Revenue contribution and customer satisfaction by product
   - Brand analysis and category ranking

5. v_store_cultural_patterns
   - Filipino sari-sari store cultural insights
   - Suki relationships, tingi preferences, payday patterns
   - Communication preferences and community connection

6. v_store_operational_alerts
   - Real-time alerts for store managers
   - Performance issues and recommendations
   - Priority-based alert system

USAGE EXAMPLES:

-- Get overall performance for Store 102
SELECT * FROM dbo.v_store_performance_summary WHERE StoreID = 102;

-- Check current alerts for all stores
SELECT * FROM dbo.v_store_operational_alerts ORDER BY alert_priority;

-- Analyze peak hours for Store 103
SELECT * FROM dbo.v_store_peak_hours WHERE StoreID = 103 ORDER BY transaction_hour;

-- Review cultural patterns across all stores
SELECT StoreID, cultural_store_type, communication_pattern
FROM dbo.v_store_cultural_patterns;

BUSINESS VALUE:
- Store managers get actionable operational insights
- Cultural adaptation for Filipino sari-sari store context
- Real-time alerts for performance issues
- Data-driven decision making for store operations
- Customer experience optimization based on conversation analysis
*/