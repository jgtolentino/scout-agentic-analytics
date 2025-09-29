-- =====================================================
-- NCR ENHANCED CLUSTERING WITH FILIPINO CULTURAL INSIGHTS
-- Transforms basic clustering into culturally-aware sari-sari store intelligence
-- Focus: Operational insights and customer understanding (NO credit risk features)
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create enhanced clustering features with Filipino cultural dimensions
CREATE OR ALTER VIEW dbo.v_ncr_cultural_clustering_features AS
WITH matched_ncr_data AS (
    -- Only include transactions that have BOTH facial data AND payload data
    SELECT
        si.FacialID,
        si.Age,
        si.Gender,
        si.StoreID,
        si.TransactionDate,
        si.CreatedDate,
        si.BasketSize,
        si.WasSubstitution,
        si.TranscriptionText,
        si.EmotionalState,
        COALESCE(si.TransactionValue, pt.amount) AS TransactionValue
    FROM dbo.SalesInteractions si
    INNER JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
    JOIN analytics.v_stg_stores s ON si.StoreID = s.store_id
    WHERE s.region = 'NCR'
      AND si.FacialID IS NOT NULL
      AND si.Age IS NOT NULL
      AND si.Age BETWEEN 15 AND 80  -- Filter realistic ages
),
ncr_cultural_behavior AS (
    SELECT
        FacialID,
        Age,
        Gender,
        COUNT(*) AS total_transactions,
        COUNT(DISTINCT StoreID) AS stores_visited,
        COUNT(DISTINCT CAST(TransactionDate AS DATE)) AS days_active,
        AVG(CAST(TransactionValue AS FLOAT)) AS avg_transaction_value,
        MIN(TransactionValue) AS min_transaction_value,
        MAX(TransactionValue) AS max_transaction_value,
        STDEV(TransactionValue) AS transaction_value_stddev,

        -- =====================================================
        -- FILIPINO CULTURAL PATTERNS
        -- =====================================================

        -- Suki Relationship Index (Store Loyalty in Filipino Culture)
        CASE
            WHEN COUNT(DISTINCT StoreID) = 1 AND COUNT(*) >= 10 THEN 1.0  -- Strong suki
            WHEN COUNT(DISTINCT StoreID) <= 2 AND COUNT(*) >= 7 THEN 0.7   -- Developing suki
            WHEN COUNT(DISTINCT StoreID) <= 2 AND COUNT(*) >= 3 THEN 0.5   -- Regular customer
            ELSE 0.2  -- Casual relationship
        END AS suki_loyalty_index,

        -- Tingi Culture Preference (Small quantity purchasing)
        CASE
            WHEN AVG(CAST(TransactionValue AS FLOAT)) < 50 THEN 1.0   -- High tingi preference
            WHEN AVG(CAST(TransactionValue AS FLOAT)) < 100 THEN 0.6  -- Mixed tingi/bulk
            WHEN AVG(CAST(TransactionValue AS FLOAT)) < 200 THEN 0.3  -- Occasional tingi
            ELSE 0.1  -- Bulk buyer
        END AS tingi_preference_score,

        -- Payday Cycle Correlation (15th and 30th salary patterns)
        COUNT(CASE WHEN DAY(TransactionDate) IN (14,15,16,29,30,31,1) THEN 1 END) * 1.0 /
            NULLIF(COUNT(*), 0) AS payday_correlation_score,

        -- Community/Family Buying Indicator (Bayanihan spirit)
        CASE
            WHEN AVG(CAST(BasketSize AS FLOAT)) > 5 THEN 0.9  -- Likely buying for family/neighbors
            WHEN AVG(CAST(BasketSize AS FLOAT)) > 3 THEN 0.6  -- Mixed personal/family
            WHEN AVG(CAST(BasketSize AS FLOAT)) > 1 THEN 0.3  -- Personal with some sharing
            ELSE 0.1  -- Individual only
        END AS community_purchase_indicator,

        -- =====================================================
        -- TEMPORAL PATTERNS (Filipino Business Hours)
        -- =====================================================

        -- Filipino time-of-day patterns
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 6 AND 8 THEN 1 END) AS early_morning_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 9 AND 11 THEN 1 END) AS late_morning_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 12 AND 14 THEN 1 END) AS lunch_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 15 AND 17 THEN 1 END) AS afternoon_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 18 AND 20 THEN 1 END) AS evening_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 21 AND 23 THEN 1 END) AS night_transactions,

        -- Work week vs weekend patterns
        COUNT(CASE WHEN DATEPART(weekday, TransactionDate) IN (2,3,4,5,6) THEN 1 END) AS weekday_transactions,
        COUNT(CASE WHEN DATEPART(weekday, TransactionDate) IN (1,7) THEN 1 END) AS weekend_transactions,

        -- =====================================================
        -- BEHAVIORAL INDICATORS
        -- =====================================================

        -- Shopping behavior patterns
        AVG(CAST(BasketSize AS FLOAT)) AS avg_basket_size,
        COUNT(CASE WHEN WasSubstitution = 1 THEN 1 END) AS substitution_count,
        AVG(LEN(COALESCE(TranscriptionText, ''))) AS avg_conversation_length,

        -- Customer lifecycle metrics
        DATEDIFF(day, MIN(TransactionDate), MAX(TransactionDate)) AS customer_lifespan_days,
        COUNT(*) * 1.0 / NULLIF(DATEDIFF(day, MIN(TransactionDate), MAX(TransactionDate)), 0) AS transaction_frequency,

        -- Emotional engagement patterns
        COUNT(CASE WHEN EmotionalState IN ('happy', 'satisfied', 'excited') THEN 1 END) AS positive_emotions,
        COUNT(CASE WHEN EmotionalState IN ('sad', 'angry', 'frustrated') THEN 1 END) AS negative_emotions,
        COUNT(CASE WHEN EmotionalState = 'neutral' THEN 1 END) AS neutral_emotions,

        -- Preferred shopping patterns
        DATEPART(hour, AVG(CAST(CAST(CreatedDate AS TIME) AS FLOAT))) AS preferred_shopping_hour,
        DATEPART(weekday, MIN(TransactionDate)) AS first_visit_weekday,

        -- =====================================================
        -- SEASONAL & CULTURAL PATTERNS
        -- =====================================================

        -- "Ber" months activity (Filipino Christmas season)
        COUNT(CASE WHEN MONTH(TransactionDate) IN (9,10,11,12) THEN 1 END) AS ber_months_activity,
        COUNT(CASE WHEN MONTH(TransactionDate) IN (3,4,5) THEN 1 END) AS summer_activity,

        -- Weather adaptability (monsoon seasons)
        CASE
            WHEN COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 6 AND 10 THEN 1 END) >
                 COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 15 AND 19 THEN 1 END)
            THEN 1.0  -- Morning preference (avoids afternoon rain)
            ELSE 0.5  -- Flexible timing
        END AS weather_adaptability_score

    FROM matched_ncr_data
    GROUP BY FacialID, Age, Gender
    HAVING COUNT(*) >= 2  -- At least 2 transactions for pattern analysis
),
feature_normalization AS (
    SELECT
        *,
        -- Normalize clustering features (0-1 scale) for ML algorithms
        (total_transactions - MIN(total_transactions) OVER()) * 1.0 /
            NULLIF(MAX(total_transactions) OVER() - MIN(total_transactions) OVER(), 0) AS norm_total_transactions,

        (avg_transaction_value - MIN(avg_transaction_value) OVER()) * 1.0 /
            NULLIF(MAX(avg_transaction_value) OVER() - MIN(avg_transaction_value) OVER(), 0) AS norm_avg_transaction_value,

        (stores_visited - MIN(stores_visited) OVER()) * 1.0 /
            NULLIF(MAX(stores_visited) OVER() - MIN(stores_visited) OVER(), 0) AS norm_stores_visited,

        (avg_basket_size - MIN(avg_basket_size) OVER()) * 1.0 /
            NULLIF(MAX(avg_basket_size) OVER() - MIN(avg_basket_size) OVER(), 0) AS norm_avg_basket_size,

        (transaction_frequency - MIN(transaction_frequency) OVER()) * 1.0 /
            NULLIF(MAX(transaction_frequency) OVER() - MIN(transaction_frequency) OVER(), 0) AS norm_transaction_frequency,

        -- Cultural preference indicators
        CASE
            WHEN weekday_transactions > weekend_transactions THEN 1.0
            ELSE 0.0
        END AS weekday_preference,

        -- Time preference scoring for Filipino business patterns
        CASE
            WHEN early_morning_transactions >= late_morning_transactions
                 AND early_morning_transactions >= afternoon_transactions THEN 1.0  -- Early bird
            WHEN lunch_transactions >= early_morning_transactions
                 AND lunch_transactions >= afternoon_transactions THEN 0.8  -- Lunch break shopper
            WHEN afternoon_transactions >= early_morning_transactions
                 AND afternoon_transactions >= evening_transactions THEN 0.6  -- Afternoon regular
            WHEN evening_transactions >= afternoon_transactions THEN 0.4  -- Evening shopper
            ELSE 0.2  -- Night owl
        END AS time_preference_score

    FROM ncr_cultural_behavior
)
SELECT
    FacialID,
    Age,
    Gender,
    total_transactions,
    stores_visited,
    days_active,
    avg_transaction_value,
    avg_basket_size,
    transaction_frequency,
    customer_lifespan_days,

    -- =====================================================
    -- FILIPINO CULTURAL METRICS
    -- =====================================================
    suki_loyalty_index,
    tingi_preference_score,
    payday_correlation_score,
    community_purchase_indicator,
    weather_adaptability_score,
    ber_months_activity,
    summer_activity,

    -- =====================================================
    -- NORMALIZED CLUSTERING FEATURES
    -- =====================================================
    norm_total_transactions,
    norm_avg_transaction_value,
    norm_stores_visited,
    norm_avg_basket_size,
    norm_transaction_frequency,
    weekday_preference,
    time_preference_score,

    -- =====================================================
    -- BEHAVIORAL PATTERNS
    -- =====================================================
    early_morning_transactions,
    late_morning_transactions,
    lunch_transactions,
    afternoon_transactions,
    evening_transactions,
    night_transactions,
    weekday_transactions,
    weekend_transactions,
    substitution_count,
    avg_conversation_length,
    positive_emotions,
    negative_emotions,
    neutral_emotions,
    preferred_shopping_hour,

    -- =====================================================
    -- COMPOSITE FILIPINO CLUSTERING SCORE
    -- =====================================================
    (norm_total_transactions * 0.20 +
     norm_avg_transaction_value * 0.15 +
     norm_stores_visited * 0.10 +
     norm_avg_basket_size * 0.10 +
     norm_transaction_frequency * 0.15 +
     suki_loyalty_index * 0.15 +
     tingi_preference_score * 0.10 +
     community_purchase_indicator * 0.05) AS filipino_composite_clustering_score

FROM feature_normalization;
GO

-- Create Filipino Persona Classifications
CREATE OR ALTER VIEW dbo.v_ncr_filipino_personas AS
WITH cultural_segments AS (
    SELECT
        *,
        -- =====================================================
        -- FILIPINO SARI-SARI STORE PERSONA CLASSIFICATION
        -- =====================================================
        CASE
            -- The "Kapitbahay Suki" (Loyal Neighbor)
            WHEN suki_loyalty_index > 0.7 AND tingi_preference_score > 0.6
                 AND early_morning_transactions > late_morning_transactions
            THEN 'Kapitbahay-Suki-Morning-Regular'

            -- The "Nanay Provider" (Mother/Family Shopper)
            WHEN Gender = 'Female' AND Age BETWEEN 30 AND 50
                 AND community_purchase_indicator > 0.6
                 AND weekend_transactions > weekday_transactions * 0.3
            THEN 'Nanay-Family-Provider'

            -- The "Payday Shopper" (Salary-based bulk buyer)
            WHEN payday_correlation_score > 0.4 AND avg_transaction_value > 150
            THEN 'Payday-Bulk-Buyer'

            -- The "Tingi Expert" (Small quantity specialist)
            WHEN tingi_preference_score > 0.8 AND transaction_frequency > 0.3
            THEN 'Daily-Tingi-Customer'

            -- The "Manong/Ate Regular" (Respectful regular customer)
            WHEN suki_loyalty_index > 0.5 AND avg_conversation_length > 10
                 AND positive_emotions > negative_emotions
            THEN 'Manong-Ate-Regular'

            -- The "Working Professional" (Rush hour shopper)
            WHEN (early_morning_transactions > 0 OR evening_transactions > 0)
                 AND weekday_transactions > weekend_transactions * 2
                 AND DATEPART(hour, preferred_shopping_hour) IN (7,8,18,19)
            THEN 'Working-Professional-Rush'

            -- The "Weekend Warrior" (Weekly stock-upper)
            WHEN weekend_transactions > weekday_transactions
                 AND avg_transaction_value > 100
                 AND community_purchase_indicator > 0.5
            THEN 'Weekend-Stock-Upper'

            -- The "Student Regular" (Young consistent buyer)
            WHEN Age BETWEEN 18 AND 25 AND tingi_preference_score > 0.7
                 AND afternoon_transactions > morning_transactions
            THEN 'Student-Regular'

            -- The "Senior Loyal" (Older loyal customer)
            WHEN Age > 55 AND suki_loyalty_index > 0.6
                 AND morning_transactions > evening_transactions
            THEN 'Senior-Loyal-Customer'

            -- The "Seasonal Shopper" (Ber months active)
            WHEN ber_months_activity > summer_activity * 1.5
                 AND avg_transaction_value > avg_transaction_value * 1.2
            THEN 'Seasonal-Holiday-Shopper'

            -- The "Weather-Wise" (Adapts to rain/weather)
            WHEN weather_adaptability_score > 0.8
                 AND early_morning_transactions > afternoon_transactions
            THEN 'Weather-Wise-Shopper'

            -- The "Flexible Friend" (No fixed patterns, adaptable)
            WHEN substitution_count > 0 AND stores_visited > 1
                 AND ABS(weekday_transactions - weekend_transactions) < 2
            THEN 'Flexible-Adaptive-Customer'

            ELSE 'General-NCR-Customer'
        END AS filipino_persona,

        -- =====================================================
        -- CULTURAL BEHAVIOR CLASSIFICATION
        -- =====================================================
        CASE
            WHEN suki_loyalty_index > 0.7 THEN 'High-Suki-Loyalty'
            WHEN suki_loyalty_index > 0.5 THEN 'Moderate-Suki-Loyalty'
            ELSE 'Low-Suki-Loyalty'
        END AS suki_loyalty_level,

        CASE
            WHEN tingi_preference_score > 0.8 THEN 'Pure-Tingi-Buyer'
            WHEN tingi_preference_score > 0.6 THEN 'Mixed-Tingi-Bulk'
            WHEN tingi_preference_score > 0.3 THEN 'Occasional-Tingi'
            ELSE 'Bulk-Buyer'
        END AS tingi_behavior_type,

        CASE
            WHEN payday_correlation_score > 0.5 THEN 'Strong-Payday-Pattern'
            WHEN payday_correlation_score > 0.3 THEN 'Moderate-Payday-Pattern'
            ELSE 'No-Payday-Pattern'
        END AS payday_behavior,

        CASE
            WHEN community_purchase_indicator > 0.7 THEN 'Community-Leader-Buyer'
            WHEN community_purchase_indicator > 0.5 THEN 'Family-Provider'
            WHEN community_purchase_indicator > 0.3 THEN 'Personal-Plus-Family'
            ELSE 'Individual-Buyer'
        END AS community_role,

        -- Confidence score for persona assignment based on data completeness
        CASE
            WHEN total_transactions >= 10 AND days_active >= 7 THEN 0.9
            WHEN total_transactions >= 5 AND days_active >= 3 THEN 0.8
            WHEN total_transactions >= 3 AND days_active >= 2 THEN 0.7
            ELSE 0.6
        END AS persona_confidence

    FROM dbo.v_ncr_cultural_clustering_features
),
persona_insights AS (
    SELECT
        *,
        -- =====================================================
        -- BUSINESS INSIGHTS BY PERSONA
        -- =====================================================
        CASE filipino_persona
            WHEN 'Kapitbahay-Suki-Morning-Regular' THEN
                'Stock fresh items by 6AM, build personal relationship'
            WHEN 'Nanay-Family-Provider' THEN
                'Weekend family promotions, bulk packaging options'
            WHEN 'Payday-Bulk-Buyer' THEN
                'Prepare inventory for 15th/30th, offer payment flexibility'
            WHEN 'Daily-Tingi-Customer' THEN
                'Ensure sachet availability, create tingi bundles'
            WHEN 'Working-Professional-Rush' THEN
                'Quick checkout, grab-and-go items, extended hours'
            WHEN 'Weekend-Stock-Upper' THEN
                'Friday restocking critical, weekend staff planning'
            ELSE 'Standard customer service approach'
        END AS operational_recommendation,

        -- Shopping motivation insights
        CASE filipino_persona
            WHEN 'Kapitbahay-Suki-Morning-Regular' THEN 'Routine-Convenience'
            WHEN 'Nanay-Family-Provider' THEN 'Family-Care-Focused'
            WHEN 'Payday-Bulk-Buyer' THEN 'Budget-Cycle-Management'
            WHEN 'Daily-Tingi-Customer' THEN 'Small-Budget-Frequent'
            WHEN 'Working-Professional-Rush' THEN 'Time-Pressed-Convenience'
            WHEN 'Weekend-Stock-Upper' THEN 'Weekly-Planning'
            ELSE 'General-Shopping'
        END AS shopping_motivation

    FROM cultural_segments
)
SELECT * FROM persona_insights;
GO

-- Create materialized clustering results for performance
CREATE OR ALTER PROCEDURE dbo.sp_refresh_ncr_cultural_clustering
AS
BEGIN
    -- Drop and recreate materialized view for performance
    IF OBJECT_ID('dbo.ncr_filipino_persona_results', 'U') IS NOT NULL
        DROP TABLE dbo.ncr_filipino_persona_results;

    SELECT *
    INTO dbo.ncr_filipino_persona_results
    FROM dbo.v_ncr_filipino_personas;

    -- Create indexes for performance
    CREATE CLUSTERED INDEX CX_NCR_Filipino_FacialID
    ON dbo.ncr_filipino_persona_results (FacialID);

    CREATE NONCLUSTERED INDEX IX_NCR_Filipino_Persona
    ON dbo.ncr_filipino_persona_results (filipino_persona)
    INCLUDE (total_transactions, avg_transaction_value, persona_confidence);

    CREATE NONCLUSTERED INDEX IX_NCR_Cultural_Metrics
    ON dbo.ncr_filipino_persona_results (suki_loyalty_level, tingi_behavior_type, payday_behavior)
    INCLUDE (FacialID, Age, Gender);

    PRINT 'NCR Filipino cultural clustering analysis refreshed successfully.';
END;
GO

-- Sample analysis queries (commented for reference)
/*
-- Execute cultural clustering analysis
EXEC dbo.sp_refresh_ncr_cultural_clustering;

-- View Filipino persona distribution
SELECT filipino_persona, COUNT(*) as customer_count,
       AVG(avg_transaction_value) as avg_value,
       AVG(persona_confidence) as avg_confidence
FROM dbo.ncr_filipino_persona_results
GROUP BY filipino_persona
ORDER BY customer_count DESC;

-- Cultural behavior analysis
SELECT suki_loyalty_level, tingi_behavior_type, COUNT(*) as frequency
FROM dbo.ncr_filipino_persona_results
GROUP BY suki_loyalty_level, tingi_behavior_type
ORDER BY frequency DESC;

-- Operational insights by persona
SELECT filipino_persona, operational_recommendation, shopping_motivation,
       COUNT(*) as customer_count
FROM dbo.ncr_filipino_persona_results
WHERE persona_confidence >= 0.8
GROUP BY filipino_persona, operational_recommendation, shopping_motivation
ORDER BY customer_count DESC;
*/