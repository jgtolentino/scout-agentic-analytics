-- =====================================================
-- NCR CLUSTERING-BASED PERSONA ANALYSIS
-- Uses production data LIMITED TO MATCHED TRANSACTIONS ONLY
-- (~4,791 transactions with both facial ID and PayloadTransactions data, 153 unique customers)
-- This ensures clustering is based on complete demographic + transaction data
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create clustering features for NCR customers (MATCHED TRANSACTIONS ONLY)
CREATE OR ALTER VIEW dbo.v_ncr_clustering_features AS
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
ncr_customer_behavior AS (
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

        -- Temporal patterns
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 6 AND 11 THEN 1 END) AS morning_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 12 AND 17 THEN 1 END) AS afternoon_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 18 AND 23 THEN 1 END) AS evening_transactions,
        COUNT(CASE WHEN DATEPART(hour, CreatedDate) BETWEEN 0 AND 5 THEN 1 END) AS night_transactions,

        -- Day of week patterns
        COUNT(CASE WHEN DATEPART(weekday, TransactionDate) IN (2,3,4,5,6) THEN 1 END) AS weekday_transactions,
        COUNT(CASE WHEN DATEPART(weekday, TransactionDate) IN (1,7) THEN 1 END) AS weekend_transactions,

        -- Behavioral indicators
        AVG(CAST(BasketSize AS FLOAT)) AS avg_basket_size,
        COUNT(CASE WHEN WasSubstitution = 1 THEN 1 END) AS substitution_count,
        AVG(LEN(TranscriptionText)) AS avg_conversation_length,

        -- Loyalty metrics
        DATEDIFF(day, MIN(TransactionDate), MAX(TransactionDate)) AS customer_lifespan_days,
        COUNT(*) * 1.0 / NULLIF(DATEDIFF(day, MIN(TransactionDate), MAX(TransactionDate)), 0) AS transaction_frequency,

        -- Emotional patterns
        COUNT(CASE WHEN EmotionalState IN ('happy', 'satisfied', 'excited') THEN 1 END) AS positive_emotions,
        COUNT(CASE WHEN EmotionalState IN ('sad', 'angry', 'frustrated') THEN 1 END) AS negative_emotions,
        COUNT(CASE WHEN EmotionalState = 'neutral' THEN 1 END) AS neutral_emotions,

        -- Time-based preferences
        DATEPART(hour, AVG(CAST(CAST(CreatedDate AS TIME) AS FLOAT))) AS preferred_shopping_hour,
        DATEPART(weekday, MIN(TransactionDate)) AS first_visit_weekday

    FROM matched_ncr_data
    GROUP BY FacialID, Age, Gender
    HAVING COUNT(*) >= 2  -- At least 2 transactions for pattern analysis
),
feature_normalization AS (
    SELECT
        *,
        -- Normalize features for clustering (0-1 scale)
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

        -- Calculate clustering scores
        CASE
            WHEN weekday_transactions > weekend_transactions THEN 1.0
            ELSE 0.0
        END AS weekday_preference,

        CASE
            WHEN morning_transactions >= afternoon_transactions AND morning_transactions >= evening_transactions THEN 1.0
            WHEN afternoon_transactions >= morning_transactions AND afternoon_transactions >= evening_transactions THEN 0.5
            ELSE 0.0
        END AS time_preference_score

    FROM ncr_customer_behavior
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

    -- Clustering features (normalized)
    norm_total_transactions,
    norm_avg_transaction_value,
    norm_stores_visited,
    norm_avg_basket_size,
    norm_transaction_frequency,
    weekday_preference,
    time_preference_score,

    -- Behavioral patterns
    morning_transactions,
    afternoon_transactions,
    evening_transactions,
    weekday_transactions,
    weekend_transactions,
    substitution_count,
    avg_conversation_length,
    positive_emotions,
    negative_emotions,
    neutral_emotions,

    -- Composite clustering score for initial segmentation
    (norm_total_transactions * 0.25 +
     norm_avg_transaction_value * 0.20 +
     norm_stores_visited * 0.15 +
     norm_avg_basket_size * 0.15 +
     norm_transaction_frequency * 0.25) AS composite_clustering_score

FROM feature_normalization;
GO

-- K-Means style clustering using SQL (5 clusters)
CREATE OR ALTER VIEW dbo.v_ncr_persona_clusters AS
WITH clustering_segments AS (
    SELECT
        *,
        -- Create 5 clusters based on composite score quintiles
        CASE
            WHEN composite_clustering_score >= 0.8 THEN 'High-Value-Frequent'
            WHEN composite_clustering_score >= 0.6 THEN 'Regular-Engaged'
            WHEN composite_clustering_score >= 0.4 THEN 'Moderate-Casual'
            WHEN composite_clustering_score >= 0.2 THEN 'Occasional-Budget'
            ELSE 'Low-Engagement'
        END AS primary_cluster,

        -- Secondary clustering based on behavioral patterns
        CASE
            WHEN weekday_preference = 1.0 AND time_preference_score = 1.0 THEN 'Weekday-Morning-Routine'
            WHEN weekday_preference = 1.0 AND time_preference_score = 0.5 THEN 'Weekday-Afternoon-Professional'
            WHEN weekday_preference = 1.0 AND time_preference_score = 0.0 THEN 'Weekday-Evening-Worker'
            WHEN weekday_preference = 0.0 AND weekend_transactions > weekday_transactions THEN 'Weekend-Social-Shopper'
            ELSE 'Flexible-Time-Shopper'
        END AS behavioral_cluster,

        -- Value-based clustering
        CASE
            WHEN avg_transaction_value > 200 THEN 'Premium-Spender'
            WHEN avg_transaction_value BETWEEN 100 AND 200 THEN 'Value-Conscious'
            WHEN avg_transaction_value BETWEEN 50 AND 100 THEN 'Budget-Mindful'
            ELSE 'Price-Sensitive'
        END AS value_cluster,

        -- Loyalty clustering
        CASE
            WHEN stores_visited = 1 AND total_transactions >= 10 THEN 'Store-Loyal'
            WHEN stores_visited <= 3 AND total_transactions >= 15 THEN 'Multi-Store-Regular'
            WHEN stores_visited > 3 AND total_transactions >= 20 THEN 'Store-Explorer'
            WHEN transaction_frequency > 0.5 THEN 'High-Frequency-Visitor'
            ELSE 'Occasional-Visitor'
        END AS loyalty_cluster

    FROM dbo.v_ncr_clustering_features
)
SELECT
    *,
    -- Create composite personas from multiple clustering dimensions
    CASE
        WHEN primary_cluster = 'High-Value-Frequent' AND behavioral_cluster LIKE '%Morning%' THEN 'NCR-Power-Shopper-Morning'
        WHEN primary_cluster = 'High-Value-Frequent' AND behavioral_cluster LIKE '%Professional%' THEN 'NCR-Executive-Lunch-Shopper'
        WHEN primary_cluster = 'High-Value-Frequent' AND behavioral_cluster LIKE '%Evening%' THEN 'NCR-After-Work-Premium'
        WHEN primary_cluster = 'Regular-Engaged' AND behavioral_cluster LIKE '%Weekend%' THEN 'NCR-Weekend-Family-Shopper'
        WHEN primary_cluster = 'Regular-Engaged' AND loyalty_cluster = 'Store-Loyal' THEN 'NCR-Neighborhood-Regular'
        WHEN primary_cluster = 'Moderate-Casual' AND value_cluster = 'Budget-Mindful' THEN 'NCR-Budget-Conscious-Casual'
        WHEN primary_cluster = 'Occasional-Budget' AND Age BETWEEN 18 AND 25 THEN 'NCR-Young-Occasional-Buyer'
        WHEN primary_cluster = 'Occasional-Budget' AND Age > 50 THEN 'NCR-Senior-Price-Sensitive'
        WHEN loyalty_cluster = 'Store-Explorer' AND value_cluster = 'Premium-Spender' THEN 'NCR-Affluent-Explorer'
        WHEN behavioral_cluster = 'Flexible-Time-Shopper' AND substitution_count > 0 THEN 'NCR-Adaptive-Flexible'
        ELSE 'NCR-General-Customer'
    END AS data_driven_persona,

    -- Confidence score for persona assignment
    CASE
        WHEN total_transactions >= 10 AND days_active >= 7 THEN 0.9
        WHEN total_transactions >= 5 AND days_active >= 3 THEN 0.8
        WHEN total_transactions >= 3 AND days_active >= 2 THEN 0.7
        ELSE 0.6
    END AS persona_confidence

FROM clustering_segments;
GO

-- Persona characteristics summary
CREATE OR ALTER VIEW dbo.v_ncr_persona_profiles AS
SELECT
    data_driven_persona,
    COUNT(*) AS customer_count,

    -- Demographics
    AVG(CAST(Age AS FLOAT)) AS avg_age,
    COUNT(CASE WHEN Gender = 'Female' THEN 1 END) * 100.0 / COUNT(*) AS female_percentage,

    -- Transaction patterns
    AVG(total_transactions) AS avg_total_transactions,
    AVG(avg_transaction_value) AS avg_transaction_value,
    AVG(avg_basket_size) AS avg_basket_size,
    AVG(stores_visited) AS avg_stores_visited,
    AVG(transaction_frequency) AS avg_transaction_frequency,

    -- Behavioral characteristics
    AVG(morning_transactions * 100.0 / NULLIF(total_transactions, 0)) AS morning_shopping_pct,
    AVG(afternoon_transactions * 100.0 / NULLIF(total_transactions, 0)) AS afternoon_shopping_pct,
    AVG(evening_transactions * 100.0 / NULLIF(total_transactions, 0)) AS evening_shopping_pct,
    AVG(weekday_transactions * 100.0 / NULLIF(total_transactions, 0)) AS weekday_shopping_pct,

    -- Emotional patterns
    AVG(positive_emotions * 100.0 / NULLIF(total_transactions, 0)) AS positive_emotion_pct,
    AVG(negative_emotions * 100.0 / NULLIF(total_transactions, 0)) AS negative_emotion_pct,

    -- Quality metrics
    AVG(persona_confidence) AS avg_confidence,

    -- Business insights
    SUM(total_transactions) AS total_persona_transactions,
    SUM(total_transactions * avg_transaction_value) AS total_persona_revenue

FROM dbo.v_ncr_persona_clusters
GROUP BY data_driven_persona;
GO

-- Create materialized clustering results for performance
CREATE OR ALTER PROCEDURE dbo.sp_refresh_ncr_clustering_analysis
AS
BEGIN
    -- Drop and recreate materialized view
    IF OBJECT_ID('dbo.ncr_persona_clustering_results', 'U') IS NOT NULL
        DROP TABLE dbo.ncr_persona_clustering_results;

    SELECT *
    INTO dbo.ncr_persona_clustering_results
    FROM dbo.v_ncr_persona_clusters;

    -- Create indexes for performance
    CREATE CLUSTERED INDEX CX_NCR_Clustering_FacialID
    ON dbo.ncr_persona_clustering_results (FacialID);

    CREATE NONCLUSTERED INDEX IX_NCR_Clustering_Persona
    ON dbo.ncr_persona_clustering_results (data_driven_persona)
    INCLUDE (total_transactions, avg_transaction_value, persona_confidence);

    PRINT 'NCR clustering analysis refreshed successfully.';
END;
GO

-- Performance analysis query for MATCHED TRANSACTIONS ONLY
/*
-- Execute clustering analysis (limited to ~4,791 matched transactions)
EXEC dbo.sp_refresh_ncr_clustering_analysis;

-- View persona distribution (153 unique customers with complete data)
SELECT * FROM dbo.v_ncr_persona_profiles
ORDER BY customer_count DESC;

-- High-confidence personas for marketing (matched transactions only)
SELECT data_driven_persona, COUNT(*) as high_confidence_customers,
       AVG(avg_transaction_value) as avg_value,
       AVG(total_transactions) as avg_frequency
FROM dbo.ncr_persona_clustering_results
WHERE persona_confidence >= 0.8
GROUP BY data_driven_persona
ORDER BY high_confidence_customers DESC;

-- Store preference by persona (using matched data only)
SELECT np.data_driven_persona, md.StoreID, s.store_name,
       COUNT(*) as visits,
       AVG(md.TransactionValue) as avg_value
FROM dbo.ncr_persona_clustering_results np
JOIN (
    SELECT si.FacialID, si.StoreID, COALESCE(si.TransactionValue, pt.amount) AS TransactionValue
    FROM dbo.SalesInteractions si
    INNER JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
    JOIN analytics.v_stg_stores s ON si.StoreID = s.store_id
    WHERE s.region = 'NCR'
) md ON np.FacialID = md.FacialID
JOIN analytics.v_stg_stores s ON md.StoreID = s.store_id
GROUP BY np.data_driven_persona, md.StoreID, s.store_name
ORDER BY np.data_driven_persona, visits DESC;
*/