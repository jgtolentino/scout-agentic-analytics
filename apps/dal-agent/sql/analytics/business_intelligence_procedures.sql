-- =================================================================
-- BUSINESS INTELLIGENCE PROCEDURES
-- Automated analytics and reporting procedures for Scout v7
-- Created: September 29, 2025
-- =================================================================

-- 1. Daily Analytics Report Generation
-- Automated daily summary report with key insights
CREATE OR ALTER PROCEDURE dbo.sp_generate_daily_analytics_report
    @report_date DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Default to yesterday if no date provided
    IF @report_date IS NULL
        SET @report_date = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE);

    -- Create temporary table for report data
    CREATE TABLE #daily_report (
        metric_category VARCHAR(50),
        metric_name VARCHAR(100),
        metric_value DECIMAL(18,2),
        comparison_value DECIMAL(18,2),
        variance_pct DECIMAL(10,2),
        status VARCHAR(20),
        insight TEXT
    );

    -- Transaction Metrics
    INSERT INTO #daily_report
    SELECT
        'Transactions' as metric_category,
        'Total Transactions' as metric_name,
        COUNT(*) as metric_value,
        LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE)) as comparison_value,
        CASE
            WHEN LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE)) > 0
            THEN ((COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE))) /
                  CAST(LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE)) AS FLOAT)) * 100
            ELSE 0
        END as variance_pct,
        CASE
            WHEN COUNT(*) > LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE)) THEN 'Growth'
            WHEN COUNT(*) < LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE)) THEN 'Decline'
            ELSE 'Stable'
        END as status,
        CONCAT('Total transactions: ', COUNT(*), '. ',
               CASE
                   WHEN COUNT(*) > LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE))
                   THEN 'Positive growth trend.'
                   WHEN COUNT(*) < LAG(COUNT(*)) OVER (ORDER BY CAST(TransactionDate AS DATE))
                   THEN 'Declining activity - investigate causes.'
                   ELSE 'Stable activity levels.'
               END) as insight
    FROM dbo.v_ultra_enriched_dataset
    WHERE CAST(TransactionDate AS DATE) IN (@report_date, DATEADD(DAY, -1, @report_date))
    GROUP BY CAST(TransactionDate AS DATE)
    HAVING CAST(TransactionDate AS DATE) = @report_date;

    -- Revenue Metrics
    INSERT INTO #daily_report
    SELECT
        'Revenue' as metric_category,
        'Total Revenue' as metric_name,
        SUM(amount) as metric_value,
        (SELECT SUM(amount) FROM dbo.v_ultra_enriched_dataset
         WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date)) as comparison_value,
        CASE
            WHEN (SELECT SUM(amount) FROM dbo.v_ultra_enriched_dataset
                  WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date)) > 0
            THEN ((SUM(amount) - (SELECT SUM(amount) FROM dbo.v_ultra_enriched_dataset
                                  WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date))) /
                  (SELECT SUM(amount) FROM dbo.v_ultra_enriched_dataset
                   WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date))) * 100
            ELSE 0
        END as variance_pct,
        CASE
            WHEN SUM(amount) > (SELECT SUM(amount) FROM dbo.v_ultra_enriched_dataset
                               WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date)) THEN 'Growth'
            WHEN SUM(amount) < (SELECT SUM(amount) FROM dbo.v_ultra_enriched_dataset
                               WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date)) THEN 'Decline'
            ELSE 'Stable'
        END as status,
        CONCAT('Revenue: ₱', FORMAT(SUM(amount), 'N2'), '. Average per transaction: ₱', FORMAT(AVG(amount), 'N2')) as insight
    FROM dbo.v_ultra_enriched_dataset
    WHERE CAST(TransactionDate AS DATE) = @report_date;

    -- Customer Satisfaction Metrics
    INSERT INTO #daily_report
    SELECT
        'Customer Experience' as metric_category,
        'Satisfaction Score' as metric_name,
        AVG(emotional_satisfaction_index) * 100 as metric_value,
        (SELECT AVG(emotional_satisfaction_index) * 100 FROM dbo.v_ultra_enriched_dataset
         WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date)) as comparison_value,
        ((AVG(emotional_satisfaction_index) -
          (SELECT AVG(emotional_satisfaction_index) FROM dbo.v_ultra_enriched_dataset
           WHERE CAST(TransactionDate AS DATE) = DATEADD(DAY, -1, @report_date))) * 100) as variance_pct,
        CASE
            WHEN AVG(emotional_satisfaction_index) >= 0.7 THEN 'Excellent'
            WHEN AVG(emotional_satisfaction_index) >= 0.6 THEN 'Good'
            WHEN AVG(emotional_satisfaction_index) >= 0.5 THEN 'Fair'
            ELSE 'Poor'
        END as status,
        CONCAT('Customer satisfaction: ', FORMAT(AVG(emotional_satisfaction_index) * 100, 'N1'), '%. ',
               CASE
                   WHEN AVG(emotional_satisfaction_index) >= 0.7 THEN 'Excellent customer experience.'
                   WHEN AVG(emotional_satisfaction_index) >= 0.5 THEN 'Acceptable satisfaction levels.'
                   ELSE 'Satisfaction needs improvement - review service quality.'
               END) as insight
    FROM dbo.v_ultra_enriched_dataset
    WHERE CAST(TransactionDate AS DATE) = @report_date;

    -- Return report
    SELECT * FROM #daily_report ORDER BY metric_category, metric_name;

    -- Cleanup
    DROP TABLE #daily_report;
END;

-- 2. Store Performance Ranking Procedure
-- Generate store performance rankings with insights
CREATE OR ALTER PROCEDURE dbo.sp_store_performance_ranking
    @ranking_period_days INT = 7,
    @ranking_criteria VARCHAR(20) = 'revenue' -- revenue, satisfaction, activity, suki_loyalty
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_date DATE = DATEADD(DAY, -@ranking_period_days, GETDATE());

    WITH store_metrics AS (
        SELECT
            StoreID,
            COUNT(*) as total_transactions,
            COUNT(DISTINCT FacialID) as unique_customers,
            SUM(amount) as total_revenue,
            AVG(amount) as avg_transaction_amount,
            AVG(emotional_satisfaction_index) as avg_satisfaction,
            AVG(suki_loyalty_index) as avg_suki_loyalty,
            AVG(politeness_score) as avg_politeness,

            -- Activity consistency (transactions per day)
            COUNT(*) / CAST(@ranking_period_days AS FLOAT) as avg_daily_transactions,

            -- Communication patterns
            COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_transactions,
            COUNT(CASE WHEN language_detected IN ('Filipino', 'English', 'Mixed') THEN 1 END) as verbal_transactions,

            -- Cultural metrics
            AVG(tingi_preference_score) as avg_tingi_preference,
            COUNT(CASE WHEN suki_loyalty_index >= 0.7 THEN 1 END) as strong_suki_customers

        FROM dbo.v_ultra_enriched_dataset
        WHERE TransactionDate >= @start_date
          AND StoreID IS NOT NULL
        GROUP BY StoreID
    ),
    store_rankings AS (
        SELECT
            *,
            -- Different ranking criteria
            ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as revenue_rank,
            ROW_NUMBER() OVER (ORDER BY avg_satisfaction DESC) as satisfaction_rank,
            ROW_NUMBER() OVER (ORDER BY total_transactions DESC) as activity_rank,
            ROW_NUMBER() OVER (ORDER BY avg_suki_loyalty DESC) as suki_loyalty_rank,

            -- Performance scores (0-100)
            avg_satisfaction * 100 as satisfaction_score,
            avg_suki_loyalty * 100 as suki_loyalty_score,
            avg_politeness * 100 as politeness_score,

            -- Engagement rate
            CASE
                WHEN total_transactions > 0
                THEN CAST(verbal_transactions AS FLOAT) / total_transactions * 100
                ELSE 0
            END as engagement_rate

        FROM store_metrics
    )
    SELECT
        StoreID,
        total_transactions,
        unique_customers,
        FORMAT(total_revenue, 'C', 'en-PH') as total_revenue_formatted,
        FORMAT(avg_transaction_amount, 'C', 'en-PH') as avg_transaction_amount_formatted,
        FORMAT(satisfaction_score, 'N1') + '%' as satisfaction_score_formatted,
        FORMAT(suki_loyalty_score, 'N1') + '%' as suki_loyalty_score_formatted,
        FORMAT(engagement_rate, 'N1') + '%' as engagement_rate_formatted,
        avg_daily_transactions,

        -- Selected ranking
        CASE @ranking_criteria
            WHEN 'revenue' THEN revenue_rank
            WHEN 'satisfaction' THEN satisfaction_rank
            WHEN 'activity' THEN activity_rank
            WHEN 'suki_loyalty' THEN suki_loyalty_rank
            ELSE revenue_rank
        END as overall_rank,

        -- Performance tier
        CASE
            WHEN CASE @ranking_criteria
                     WHEN 'revenue' THEN revenue_rank
                     WHEN 'satisfaction' THEN satisfaction_rank
                     WHEN 'activity' THEN activity_rank
                     WHEN 'suki_loyalty' THEN suki_loyalty_rank
                     ELSE revenue_rank
                 END <= 3 THEN 'Top Performer'
            WHEN CASE @ranking_criteria
                     WHEN 'revenue' THEN revenue_rank
                     WHEN 'satisfaction' THEN satisfaction_rank
                     WHEN 'activity' THEN activity_rank
                     WHEN 'suki_loyalty' THEN suki_loyalty_rank
                     ELSE revenue_rank
                 END <= 6 THEN 'Good Performer'
            ELSE 'Needs Attention'
        END as performance_tier,

        -- Insights
        CONCAT(
            'Rank #',
            CASE @ranking_criteria
                WHEN 'revenue' THEN revenue_rank
                WHEN 'satisfaction' THEN satisfaction_rank
                WHEN 'activity' THEN activity_rank
                WHEN 'suki_loyalty' THEN suki_loyalty_rank
                ELSE revenue_rank
            END,
            ' in ', @ranking_criteria, '. ',
            CASE
                WHEN satisfaction_score >= 70 THEN 'High customer satisfaction. '
                WHEN satisfaction_score >= 50 THEN 'Moderate satisfaction. '
                ELSE 'Satisfaction needs improvement. '
            END,
            CASE
                WHEN suki_loyalty_score >= 60 THEN 'Strong suki relationships.'
                WHEN suki_loyalty_score >= 40 THEN 'Developing community ties.'
                ELSE 'Focus on building customer relationships.'
            END
        ) as performance_insights

    FROM store_rankings
    ORDER BY
        CASE @ranking_criteria
            WHEN 'revenue' THEN revenue_rank
            WHEN 'satisfaction' THEN satisfaction_rank
            WHEN 'activity' THEN activity_rank
            WHEN 'suki_loyalty' THEN suki_loyalty_rank
            ELSE revenue_rank
        END;
END;

-- 3. Customer Behavior Analysis Procedure
-- Analyze customer behavior patterns and generate insights
CREATE OR ALTER PROCEDURE dbo.sp_customer_behavior_analysis
    @analysis_period_days INT = 30,
    @min_transactions_per_customer INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_date DATE = DATEADD(DAY, -@analysis_period_days, GETDATE());

    -- Customer behavior analysis
    WITH customer_behavior AS (
        SELECT
            FacialID,
            COUNT(*) as transaction_count,
            COUNT(DISTINCT StoreID) as stores_visited,
            COUNT(DISTINCT CAST(TransactionDate AS DATE)) as days_active,
            AVG(amount) as avg_spending,
            SUM(amount) as total_spending,
            MIN(TransactionDate) as first_transaction,
            MAX(TransactionDate) as last_transaction,

            -- Behavioral patterns
            AVG(suki_loyalty_index) as avg_suki_loyalty,
            AVG(tingi_preference_score) as avg_tingi_preference,
            AVG(payday_correlation_score) as avg_payday_correlation,
            AVG(emotional_satisfaction_index) as avg_satisfaction,

            -- Communication patterns
            MODE() WITHIN GROUP (ORDER BY language_detected) as preferred_language,
            AVG(politeness_score) as avg_politeness,

            -- Demographics
            MODE() WITHIN GROUP (ORDER BY Age) as most_common_age,
            MODE() WITHIN GROUP (ORDER BY Gender) as gender,
            MODE() WITHIN GROUP (ORDER BY customer_behavior_segment) as behavior_segment,

            -- Shopping patterns
            AVG(item_count) as avg_items_per_transaction,
            MODE() WITHIN GROUP (ORDER BY primary_category) as favorite_category

        FROM dbo.v_ultra_enriched_dataset
        WHERE TransactionDate >= @start_date
          AND FacialID IS NOT NULL
        GROUP BY FacialID
        HAVING COUNT(*) >= @min_transactions_per_customer
    ),
    customer_segments AS (
        SELECT
            *,
            -- Customer value segmentation
            CASE
                WHEN total_spending >= PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY total_spending) OVER () THEN 'High Value'
                WHEN total_spending >= PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_spending) OVER () THEN 'Medium Value'
                ELSE 'Low Value'
            END as value_segment,

            -- Loyalty segmentation
            CASE
                WHEN avg_suki_loyalty >= 0.7 THEN 'Suki Customer'
                WHEN avg_suki_loyalty >= 0.4 THEN 'Regular Customer'
                ELSE 'Occasional Customer'
            END as loyalty_segment,

            -- Shopping frequency
            CASE
                WHEN transaction_count >= 20 THEN 'Very Frequent'
                WHEN transaction_count >= 10 THEN 'Frequent'
                WHEN transaction_count >= 5 THEN 'Regular'
                ELSE 'Infrequent'
            END as frequency_segment,

            -- Store loyalty
            CASE
                WHEN stores_visited = 1 THEN 'Single Store Loyal'
                WHEN stores_visited = 2 THEN 'Two Store Preference'
                ELSE 'Multi Store Shopper'
            END as store_loyalty_segment

        FROM customer_behavior
    )
    -- Customer behavior summary
    SELECT
        behavior_segment,
        value_segment,
        loyalty_segment,
        frequency_segment,
        store_loyalty_segment,
        COUNT(*) as customer_count,
        AVG(total_spending) as avg_total_spending,
        AVG(avg_spending) as avg_transaction_amount,
        AVG(transaction_count) as avg_transaction_frequency,
        AVG(avg_satisfaction) as avg_satisfaction_score,

        -- Behavioral insights
        CONCAT(
            COUNT(*), ' customers in ', behavior_segment, ' segment. ',
            'Average spending: ₱', FORMAT(AVG(total_spending), 'N2'), '. ',
            CASE
                WHEN AVG(avg_satisfaction) >= 0.7 THEN 'High satisfaction group - focus on retention.'
                WHEN AVG(avg_satisfaction) >= 0.5 THEN 'Moderate satisfaction - opportunity for improvement.'
                ELSE 'Low satisfaction - requires immediate attention.'
            END
        ) as segment_insights,

        -- Recommendations
        CASE behavior_segment
            WHEN 'Kapitbahay-Suki' THEN 'Maintain personal relationships, offer loyalty rewards, cultural events'
            WHEN 'Nanay-Family-Provider' THEN 'Family bundles, bulk discounts, credit options'
            WHEN 'Payday-Bulk-Buyer' THEN 'Payday promotions (15th/30th), volume discounts'
            WHEN 'Tito-Convenience-Shopper' THEN 'Quick service, premium convenience items'
            WHEN 'Young-Digital-Native' THEN 'Digital payment options, social media engagement'
            WHEN 'Senior-Traditional-Customer' THEN 'Personal service, traditional products, respect cultural preferences'
            ELSE 'Standard customer service approach'
        END as recommendations

    FROM customer_segments
    GROUP BY behavior_segment, value_segment, loyalty_segment, frequency_segment, store_loyalty_segment
    ORDER BY customer_count DESC;
END;

-- 4. Cultural Insights Analysis Procedure
-- Filipino sari-sari store cultural patterns analysis
CREATE OR ALTER PROCEDURE dbo.sp_cultural_insights_analysis
    @analysis_period_days INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_date DATE = DATEADD(DAY, -@analysis_period_days, GETDATE());

    -- Cultural patterns analysis
    WITH cultural_metrics AS (
        SELECT
            StoreID,

            -- Suki culture strength
            AVG(suki_loyalty_index) as avg_suki_loyalty,
            COUNT(CASE WHEN suki_loyalty_index >= 0.7 THEN 1 END) as strong_suki_count,
            COUNT(CASE WHEN suki_loyalty_index BETWEEN 0.4 AND 0.69 THEN 1 END) as developing_suki_count,

            -- Tingi preferences
            AVG(tingi_preference_score) as avg_tingi_preference,
            COUNT(CASE WHEN tingi_preference_score >= 0.7 THEN 1 END) as strong_tingi_count,

            -- Payday patterns
            AVG(payday_correlation_score) as avg_payday_correlation,
            COUNT(CASE WHEN payday_correlation_score >= 0.6 THEN 1 END) as payday_dependent_count,

            -- Language preferences
            COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) as filipino_conversations,
            COUNT(CASE WHEN language_detected = 'English' THEN 1 END) as english_conversations,
            COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_conversations,

            -- Community connection
            AVG(politeness_score) as avg_politeness,
            AVG(emotional_satisfaction_index) as avg_satisfaction,

            COUNT(*) as total_transactions,
            COUNT(DISTINCT FacialID) as unique_customers

        FROM dbo.v_ultra_enriched_dataset
        WHERE TransactionDate >= @start_date
          AND StoreID IS NOT NULL
        GROUP BY StoreID
    ),
    store_cultural_types AS (
        SELECT
            *,
            -- Cultural store classification
            CASE
                WHEN avg_suki_loyalty >= 0.6 AND avg_tingi_preference >= 0.6 THEN 'Traditional Sari-Sari'
                WHEN avg_suki_loyalty >= 0.6 THEN 'Relationship-Focused Store'
                WHEN avg_tingi_preference >= 0.6 THEN 'Convenience-Focused Store'
                ELSE 'Transitional Store'
            END as cultural_store_type,

            -- Communication style
            CASE
                WHEN filipino_conversations > english_conversations AND filipino_conversations > silent_conversations THEN 'Filipino-Dominant'
                WHEN english_conversations > filipino_conversations AND english_conversations > silent_conversations THEN 'English-Dominant'
                WHEN silent_conversations > filipino_conversations AND silent_conversations > english_conversations THEN 'Silent-Preferred'
                ELSE 'Mixed Communication'
            END as communication_style,

            -- Community strength
            CASE
                WHEN avg_suki_loyalty >= 0.7 AND avg_politeness >= 0.7 THEN 'Strong Community Hub'
                WHEN avg_suki_loyalty >= 0.5 AND avg_politeness >= 0.5 THEN 'Developing Community'
                ELSE 'Transactional Business'
            END as community_strength

        FROM cultural_metrics
    )
    -- Cultural analysis summary
    SELECT
        cultural_store_type,
        communication_style,
        community_strength,
        COUNT(*) as store_count,
        AVG(avg_suki_loyalty) * 100 as avg_suki_loyalty_pct,
        AVG(avg_tingi_preference) * 100 as avg_tingi_preference_pct,
        AVG(avg_payday_correlation) * 100 as avg_payday_pattern_pct,
        AVG(avg_satisfaction) * 100 as avg_satisfaction_pct,

        -- Cultural insights
        CONCAT(
            COUNT(*), ' stores classified as ', cultural_store_type, '. ',
            'Suki loyalty: ', FORMAT(AVG(avg_suki_loyalty) * 100, 'N1'), '%. ',
            'Communication: ', communication_style, '. ',
            CASE cultural_store_type
                WHEN 'Traditional Sari-Sari' THEN 'Strong cultural foundation - maintain personal touch and community focus.'
                WHEN 'Relationship-Focused Store' THEN 'Good suki culture - enhance with traditional sari-sari elements.'
                WHEN 'Convenience-Focused Store' THEN 'Modern approach - consider cultural adaptation for better connection.'
                ELSE 'Mixed characteristics - opportunity to strengthen cultural identity.'
            END
        ) as cultural_insights,

        -- Recommendations
        CASE cultural_store_type
            WHEN 'Traditional Sari-Sari' THEN 'Celebrate and preserve culture: local events, personal service, credit arrangements, family focus'
            WHEN 'Relationship-Focused Store' THEN 'Build on relationships: loyalty programs, community involvement, personal recognition'
            WHEN 'Convenience-Focused Store' THEN 'Add cultural elements: Filipino greetings, personal conversations, flexible payment'
            ELSE 'Define store identity: choose between traditional values or modern convenience approach'
        END as cultural_recommendations

    FROM store_cultural_types
    GROUP BY cultural_store_type, communication_style, community_strength
    ORDER BY store_count DESC;
END;

-- 5. Operational Alerts Generation Procedure
-- Generate automated alerts for operational issues
CREATE OR ALTER PROCEDURE dbo.sp_generate_operational_alerts
    @alert_period_hours INT = 2,
    @min_transactions_for_alert INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @alert_start_time DATETIME = DATEADD(HOUR, -@alert_period_hours, GETDATE());

    -- Create alerts table
    CREATE TABLE #operational_alerts (
        alert_id INT IDENTITY(1,1),
        store_id INT,
        alert_type VARCHAR(50),
        alert_priority VARCHAR(10),
        alert_message TEXT,
        metric_value DECIMAL(10,2),
        threshold_value DECIMAL(10,2),
        recommendation TEXT,
        alert_timestamp DATETIME DEFAULT GETDATE()
    );

    -- Low satisfaction alerts
    INSERT INTO #operational_alerts (store_id, alert_type, alert_priority, alert_message, metric_value, threshold_value, recommendation)
    SELECT
        StoreID,
        'Low Customer Satisfaction',
        CASE WHEN AVG(emotional_satisfaction_index) < 0.3 THEN 'High' ELSE 'Medium' END,
        CONCAT('Customer satisfaction dropped to ', FORMAT(AVG(emotional_satisfaction_index) * 100, 'N1'), '% at Store ', StoreID),
        AVG(emotional_satisfaction_index) * 100,
        50.0,
        'Review recent customer interactions, check product quality, train staff on customer service'
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= @alert_start_time
      AND StoreID IS NOT NULL
    GROUP BY StoreID
    HAVING COUNT(*) >= @min_transactions_for_alert
       AND AVG(emotional_satisfaction_index) < 0.5;

    -- High silent transaction alerts
    INSERT INTO #operational_alerts (store_id, alert_type, alert_priority, alert_message, metric_value, threshold_value, recommendation)
    SELECT
        StoreID,
        'High Silent Transactions',
        'Medium',
        CONCAT(FORMAT(CAST(COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) AS FLOAT) / COUNT(*) * 100, 'N1'),
               '% of transactions are silent at Store ', StoreID),
        CAST(COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) AS FLOAT) / COUNT(*) * 100,
        60.0,
        'Check audio equipment, train staff to engage customers, investigate environmental factors'
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= @alert_start_time
      AND StoreID IS NOT NULL
    GROUP BY StoreID
    HAVING COUNT(*) >= @min_transactions_for_alert
       AND CAST(COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) AS FLOAT) / COUNT(*) > 0.6;

    -- Low activity alerts
    INSERT INTO #operational_alerts (store_id, alert_type, alert_priority, alert_message, metric_value, threshold_value, recommendation)
    SELECT
        StoreID,
        'Low Store Activity',
        'Low',
        CONCAT('Only ', COUNT(*), ' transactions in last ', @alert_period_hours, ' hours at Store ', StoreID),
        COUNT(*),
        @min_transactions_for_alert,
        'Check store operations, verify opening hours, ensure proper equipment function'
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= @alert_start_time
      AND StoreID IS NOT NULL
    GROUP BY StoreID
    HAVING COUNT(*) < @min_transactions_for_alert;

    -- Facial recognition issues
    INSERT INTO #operational_alerts (store_id, alert_type, alert_priority, alert_message, metric_value, threshold_value, recommendation)
    SELECT
        StoreID,
        'Facial Recognition Issues',
        'High',
        CONCAT('Facial recognition rate dropped to ',
               FORMAT(CAST(COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) AS FLOAT) / COUNT(*) * 100, 'N1'),
               '% at Store ', StoreID),
        CAST(COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) AS FLOAT) / COUNT(*) * 100,
        70.0,
        'Check camera positioning, clean lenses, verify lighting conditions, restart facial recognition system'
    FROM dbo.v_ultra_enriched_dataset
    WHERE TransactionDate >= @alert_start_time
      AND StoreID IS NOT NULL
    GROUP BY StoreID
    HAVING COUNT(*) >= @min_transactions_for_alert
       AND CAST(COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) AS FLOAT) / COUNT(*) < 0.7;

    -- Return alerts sorted by priority
    SELECT
        alert_id,
        store_id,
        alert_type,
        alert_priority,
        alert_message,
        metric_value,
        threshold_value,
        recommendation,
        alert_timestamp
    FROM #operational_alerts
    ORDER BY
        CASE alert_priority
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            WHEN 'Low' THEN 3
        END,
        store_id;

    -- Cleanup
    DROP TABLE #operational_alerts;
END;

-- 6. Performance Trends Analysis Procedure
-- Analyze performance trends over time
CREATE OR ALTER PROCEDURE dbo.sp_performance_trends_analysis
    @trend_period_days INT = 30,
    @comparison_period_days INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @current_period_start DATE = DATEADD(DAY, -@trend_period_days, GETDATE());
    DECLARE @previous_period_start DATE = DATEADD(DAY, -(@trend_period_days + @comparison_period_days), GETDATE());
    DECLARE @previous_period_end DATE = DATEADD(DAY, -@trend_period_days, GETDATE());

    -- Current period metrics
    WITH current_metrics AS (
        SELECT
            'Current Period' as period_name,
            COUNT(*) as total_transactions,
            COUNT(DISTINCT StoreID) as active_stores,
            COUNT(DISTINCT FacialID) as unique_customers,
            SUM(amount) as total_revenue,
            AVG(amount) as avg_transaction_amount,
            AVG(emotional_satisfaction_index) as avg_satisfaction,
            AVG(suki_loyalty_index) as avg_suki_loyalty,
            AVG(politeness_score) as avg_politeness,

            -- Communication patterns
            COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) as filipino_conversations,
            COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_conversations,

            -- System performance
            COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) as facial_recognized,
            COUNT(CASE WHEN detected_brands IS NOT NULL AND detected_brands != '' THEN 1 END) as brand_detected

        FROM dbo.v_ultra_enriched_dataset
        WHERE TransactionDate >= @current_period_start
    ),
    previous_metrics AS (
        SELECT
            'Previous Period' as period_name,
            COUNT(*) as total_transactions,
            COUNT(DISTINCT StoreID) as active_stores,
            COUNT(DISTINCT FacialID) as unique_customers,
            SUM(amount) as total_revenue,
            AVG(amount) as avg_transaction_amount,
            AVG(emotional_satisfaction_index) as avg_satisfaction,
            AVG(suki_loyalty_index) as avg_suki_loyalty,
            AVG(politeness_score) as avg_politeness,

            COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) as filipino_conversations,
            COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) as silent_conversations,

            COUNT(CASE WHEN FacialID IS NOT NULL THEN 1 END) as facial_recognized,
            COUNT(CASE WHEN detected_brands IS NOT NULL AND detected_brands != '' THEN 1 END) as brand_detected

        FROM dbo.v_ultra_enriched_dataset
        WHERE TransactionDate >= @previous_period_start
          AND TransactionDate < @previous_period_end
    ),
    trend_analysis AS (
        SELECT
            c.total_transactions as current_transactions,
            p.total_transactions as previous_transactions,
            c.total_revenue as current_revenue,
            p.total_revenue as previous_revenue,
            c.avg_satisfaction as current_satisfaction,
            p.avg_satisfaction as previous_satisfaction,
            c.avg_suki_loyalty as current_suki_loyalty,
            p.avg_suki_loyalty as previous_suki_loyalty,

            -- Calculate percentage changes
            CASE WHEN p.total_transactions > 0
                 THEN ((c.total_transactions - p.total_transactions) / CAST(p.total_transactions AS FLOAT)) * 100
                 ELSE 0 END as transaction_growth_pct,

            CASE WHEN p.total_revenue > 0
                 THEN ((c.total_revenue - p.total_revenue) / p.total_revenue) * 100
                 ELSE 0 END as revenue_growth_pct,

            (c.avg_satisfaction - p.avg_satisfaction) * 100 as satisfaction_change_pts,
            (c.avg_suki_loyalty - p.avg_suki_loyalty) * 100 as suki_loyalty_change_pts,

            -- System performance trends
            CASE WHEN c.total_transactions > 0
                 THEN CAST(c.facial_recognized AS FLOAT) / c.total_transactions * 100
                 ELSE 0 END as current_facial_recognition_rate,

            CASE WHEN p.total_transactions > 0
                 THEN CAST(p.facial_recognized AS FLOAT) / p.total_transactions * 100
                 ELSE 0 END as previous_facial_recognition_rate

        FROM current_metrics c
        CROSS JOIN previous_metrics p
    )
    SELECT
        FORMAT(current_transactions, 'N0') + ' vs ' + FORMAT(previous_transactions, 'N0') as transactions_comparison,
        FORMAT(transaction_growth_pct, 'N1') + '%' as transaction_growth,

        FORMAT(current_revenue, 'C', 'en-PH') + ' vs ' + FORMAT(previous_revenue, 'C', 'en-PH') as revenue_comparison,
        FORMAT(revenue_growth_pct, 'N1') + '%' as revenue_growth,

        FORMAT(current_satisfaction * 100, 'N1') + '% vs ' + FORMAT(previous_satisfaction * 100, 'N1') + '%' as satisfaction_comparison,
        FORMAT(satisfaction_change_pts, 'N1') + ' pts' as satisfaction_change,

        FORMAT(current_suki_loyalty * 100, 'N1') + '% vs ' + FORMAT(previous_suki_loyalty * 100, 'N1') + '%' as suki_loyalty_comparison,
        FORMAT(suki_loyalty_change_pts, 'N1') + ' pts' as suki_loyalty_change,

        -- Trend interpretation
        CASE
            WHEN transaction_growth_pct > 10 THEN 'Strong Growth'
            WHEN transaction_growth_pct > 5 THEN 'Moderate Growth'
            WHEN transaction_growth_pct > -5 THEN 'Stable'
            WHEN transaction_growth_pct > -10 THEN 'Moderate Decline'
            ELSE 'Significant Decline'
        END as transaction_trend,

        CASE
            WHEN satisfaction_change_pts > 5 THEN 'Improving'
            WHEN satisfaction_change_pts > -5 THEN 'Stable'
            ELSE 'Declining'
        END as satisfaction_trend,

        -- Strategic insights
        CONCAT(
            'Performance trend: ',
            CASE
                WHEN transaction_growth_pct > 5 AND satisfaction_change_pts > 0 THEN 'Positive growth with improved experience'
                WHEN transaction_growth_pct > 5 AND satisfaction_change_pts < 0 THEN 'Growth but declining satisfaction - scale with quality'
                WHEN transaction_growth_pct < -5 AND satisfaction_change_pts > 0 THEN 'Declining activity but improving experience - boost marketing'
                WHEN transaction_growth_pct < -5 AND satisfaction_change_pts < 0 THEN 'Declining activity and satisfaction - urgent intervention needed'
                ELSE 'Stable performance - maintain current strategies'
            END
        ) as strategic_insights

    FROM trend_analysis;
END;

-- =================================================================
-- DOCUMENTATION AND USAGE NOTES
-- =================================================================

/*
BUSINESS INTELLIGENCE PROCEDURES CREATED:

1. sp_generate_daily_analytics_report
   - Daily performance summary with insights
   - Transaction, revenue, and satisfaction metrics
   - Comparative analysis with previous day

2. sp_store_performance_ranking
   - Store rankings by multiple criteria
   - Performance tiers and insights
   - Customizable ranking periods and criteria

3. sp_customer_behavior_analysis
   - Customer segmentation and behavior patterns
   - Value, loyalty, and frequency analysis
   - Recommendations for each segment

4. sp_cultural_insights_analysis
   - Filipino sari-sari store cultural patterns
   - Suki, tingi, and payday analysis
   - Cultural recommendations for stores

5. sp_generate_operational_alerts
   - Automated alert generation
   - Priority-based alert system
   - Actionable recommendations

6. sp_performance_trends_analysis
   - Trend analysis over time periods
   - Growth and performance indicators
   - Strategic insights and recommendations

USAGE EXAMPLES:

-- Generate daily report for yesterday
EXEC dbo.sp_generate_daily_analytics_report;

-- Rank stores by customer satisfaction
EXEC dbo.sp_store_performance_ranking @ranking_criteria = 'satisfaction';

-- Analyze customer behavior patterns
EXEC dbo.sp_customer_behavior_analysis @analysis_period_days = 30;

-- Get cultural insights
EXEC dbo.sp_cultural_insights_analysis;

-- Check for operational alerts
EXEC dbo.sp_generate_operational_alerts @alert_period_hours = 4;

-- Analyze performance trends
EXEC dbo.sp_performance_trends_analysis @trend_period_days = 30;

BUSINESS VALUE:
- Automated intelligence and insights
- Proactive operational monitoring
- Cultural adaptation for Filipino market
- Data-driven decision making
- Performance optimization guidance
*/