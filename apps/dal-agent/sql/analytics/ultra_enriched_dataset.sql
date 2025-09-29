-- =====================================================
-- ULTRA-ENRICHED 150+ COLUMN DATASET
-- Combines original 80 columns with cultural clustering + conversation intelligence
-- Focus: Comprehensive analytics without credit risk features
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER VIEW dbo.v_ultra_enriched_dataset AS
WITH sku_items AS (
    -- Extract SKU-level data from JSON payload (from original dataset)
    SELECT
        pt.canonical_tx_id,
        JSON_VALUE(item.value, '$.sku') AS sku_code,
        JSON_VALUE(item.value, '$.brand') AS item_brand,
        JSON_VALUE(item.value, '$.category') AS item_category,
        TRY_CONVERT(INT, JSON_VALUE(item.value, '$.quantity')) AS item_quantity,
        TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.unitPrice')) AS item_unit_price,
        TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.total')) AS item_total,
        ROW_NUMBER() OVER (PARTITION BY pt.canonical_tx_id ORDER BY JSON_VALUE(item.value, '$.total') DESC) AS item_rank
    FROM dbo.PayloadTransactions pt
    CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS item
    WHERE pt.payload_json IS NOT NULL
      AND ISJSON(pt.payload_json) = 1
),
behavioral_patterns AS (
    -- Calculate customer behavioral metrics over time
    SELECT
        FacialID,
        -- Purchase behavior analytics
        COUNT(*) AS lifetime_transactions,
        AVG(CAST(COALESCE(si.TransactionValue, pt.amount) AS FLOAT)) AS lifetime_avg_value,
        STDEV(CAST(COALESCE(si.TransactionValue, pt.amount) AS FLOAT)) AS lifetime_value_volatility,

        -- Time pattern analytics
        STDEV(DATEPART(hour, si.CreatedDate)) AS visit_time_consistency,
        COUNT(DISTINCT CAST(si.TransactionDate AS DATE)) AS unique_visit_days,
        DATEDIFF(day, MIN(si.TransactionDate), MAX(si.TransactionDate)) AS customer_lifespan,

        -- Store loyalty metrics
        COUNT(DISTINCT si.StoreID) AS stores_visited_lifetime,
        CASE
            WHEN COUNT(DISTINCT si.StoreID) = 1 THEN 'Single_Store_Loyal'
            WHEN COUNT(DISTINCT si.StoreID) <= 3 THEN 'Multi_Store_Regular'
            ELSE 'Store_Explorer'
        END AS store_loyalty_type,

        -- Frequency patterns
        COUNT(*) * 1.0 / NULLIF(DATEDIFF(day, MIN(si.TransactionDate), MAX(si.TransactionDate)), 0) AS transaction_frequency,

        -- Value trends
        (SELECT AVG(CAST(COALESCE(TransactionValue, amount) AS FLOAT))
         FROM dbo.SalesInteractions si2
         LEFT JOIN dbo.PayloadTransactions pt2 ON si2.canonical_tx_id = pt2.canonical_tx_id
         WHERE si2.FacialID = si.FacialID
         AND si2.TransactionDate >= DATEADD(month, -1, MAX(si.TransactionDate))) AS recent_avg_value,

        -- Emotional patterns
        COUNT(CASE WHEN si.EmotionalState = 'happy' THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0) AS happiness_ratio,
        COUNT(CASE WHEN si.EmotionalState IN ('sad', 'angry', 'frustrated') THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0) AS negative_emotion_ratio

    FROM dbo.SalesInteractions si
    LEFT JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
    WHERE si.FacialID IS NOT NULL
    GROUP BY FacialID
)
SELECT
    -- =====================================================
    -- ORIGINAL CORE COLUMNS (80+ from complete_flattened_dataset)
    -- =====================================================

    -- Core identifiers
    si.canonical_tx_id AS transaction_id,
    si.InteractionID AS interaction_id,
    pt.sessionId AS session_id,
    pt.deviceId AS device_id,

    -- Temporal dimensions
    si.TransactionDate AS transaction_date,
    CAST(si.CreatedDate AS TIME) AS transaction_time,
    YEAR(si.TransactionDate) AS year_number,
    MONTH(si.TransactionDate) AS month_number,
    DATENAME(month, si.TransactionDate) AS month_name,
    DATEPART(quarter, si.TransactionDate) AS quarter_number,
    DATEPART(week, si.TransactionDate) AS week_number,
    DATEPART(dayofyear, si.TransactionDate) AS day_of_year,
    DATENAME(weekday, si.TransactionDate) AS day_name,
    DATEPART(weekday, si.TransactionDate) AS day_of_week_number,
    CASE WHEN DATEPART(weekday, si.TransactionDate) IN (1,7) THEN 'Weekend' ELSE 'Weekday' END AS weekday_vs_weekend,

    -- Time hierarchy
    DATEPART(hour, si.CreatedDate) AS hour_24,
    DATEPART(minute, si.CreatedDate) AS minute_number,
    CASE WHEN DATEPART(hour, si.CreatedDate) < 12 THEN 'AM' ELSE 'PM' END AS am_pm,

    -- Time categories
    CASE
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 6 AND 8 THEN 'Early-Morning'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 9 AND 11 THEN 'Late-Morning'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 12 AND 14 THEN 'Lunch-Time'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 15 AND 17 THEN 'Afternoon'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 18 AND 20 THEN 'Evening'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 21 AND 23 THEN 'Night'
        ELSE 'Late-Night'
    END AS time_of_day_category,

    -- Store hierarchy
    si.StoreID AS store_id,
    s.StoreName AS store_name,
    r.RegionName AS region_name,
    p.ProvinceName AS province_name,
    m.MunicipalityName AS municipality_name,
    b.BarangayName AS barangay_name,

    -- Customer demographics
    si.FacialID AS customer_facial_id,
    si.Age AS customer_age,
    si.Gender AS customer_gender,
    si.EmotionalState AS customer_emotion,
    CASE
        WHEN si.Age BETWEEN 18 AND 24 THEN '18-24'
        WHEN si.Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN si.Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN si.Age BETWEEN 45 AND 54 THEN '45-54'
        WHEN si.Age BETWEEN 55 AND 64 THEN '55-64'
        WHEN si.Age >= 65 THEN '65+'
        ELSE 'Unknown'
    END AS age_bracket,

    -- Transaction measures
    COALESCE(si.TransactionValue, pt.amount) AS transaction_amount,
    si.BasketSize AS basket_size,
    si.WasSubstitution AS was_substitution,

    -- SKU-level data
    sku1.sku_code AS primary_sku,
    sku1.item_brand AS primary_item_brand,
    sku1.item_category AS primary_item_category,
    sku1.item_quantity AS primary_item_quantity,
    sku1.item_unit_price AS primary_item_unit_price,
    sku1.item_total AS primary_item_total,

    -- =====================================================
    -- FILIPINO CULTURAL INSIGHTS (from cultural clustering)
    -- =====================================================

    -- Cultural personas
    COALESCE(fp.filipino_persona, 'General-Customer') AS filipino_persona,
    COALESCE(fp.suki_loyalty_level, 'Unknown') AS suki_loyalty_level,
    COALESCE(fp.tingi_behavior_type, 'Unknown') AS tingi_behavior_type,
    COALESCE(fp.payday_behavior, 'Unknown') AS payday_behavior,
    COALESCE(fp.community_role, 'Unknown') AS community_role,
    COALESCE(fp.shopping_motivation, 'Unknown') AS shopping_motivation,
    COALESCE(fp.operational_recommendation, 'Standard approach') AS operational_recommendation,

    -- Cultural metrics
    COALESCE(fp.suki_loyalty_index, 0) AS suki_loyalty_index,
    COALESCE(fp.tingi_preference_score, 0) AS tingi_preference_score,
    COALESCE(fp.payday_correlation_score, 0) AS payday_correlation_score,
    COALESCE(fp.community_purchase_indicator, 0) AS community_purchase_indicator,
    COALESCE(fp.weather_adaptability_score, 0) AS weather_adaptability_score,
    COALESCE(fp.persona_confidence, 0) AS persona_confidence,

    -- =====================================================
    -- CONVERSATION INTELLIGENCE (15 columns)
    -- =====================================================

    -- Language and communication
    COALESCE(ci.language_detected, 'Unknown') AS conversation_language,
    COALESCE(ci.conversation_intent, 'Unknown') AS conversation_intent,
    COALESCE(ci.politeness_score, 0) AS politeness_score,
    COALESCE(ci.urgency_level, 'Normal') AS urgency_level,
    COALESCE(ci.satisfaction_indicator, 'Unknown') AS satisfaction_indicator,
    COALESCE(ci.social_relationship, 'No_Special_Address') AS social_relationship,
    COALESCE(ci.conversation_length_category, 'Silent') AS conversation_length_category,
    COALESCE(ci.text_clarity, 'Unclear') AS text_clarity,
    COALESCE(ci.interaction_complexity, 'Standard') AS interaction_complexity,

    -- Product mentions from conversation
    ci.cigarette_brand_mentioned,
    ci.beverage_mentioned,
    ci.digital_product_mentioned,
    ci.quantity_kg_mentioned,
    ci.packaging_mentioned,

    -- Conversation flags
    COALESCE(ci.is_filipino_conversation, 0) AS is_filipino_conversation,
    COALESCE(ci.is_business_intent, 0) AS is_business_intent,
    COALESCE(ci.is_polite_customer, 0) AS is_polite_customer,
    COALESCE(ci.is_satisfied_customer, 0) AS is_satisfied_customer,
    COALESCE(ci.is_urgent_request, 0) AS is_urgent_request,

    -- =====================================================
    -- BEHAVIORAL PATTERNS (20 columns)
    -- =====================================================

    -- Lifetime customer metrics
    bp.lifetime_transactions,
    bp.lifetime_avg_value,
    bp.lifetime_value_volatility,
    bp.visit_time_consistency,
    bp.unique_visit_days,
    bp.customer_lifespan,
    bp.stores_visited_lifetime,
    bp.store_loyalty_type,
    bp.transaction_frequency,
    bp.recent_avg_value,
    bp.happiness_ratio,
    bp.negative_emotion_ratio,

    -- Purchase decision patterns
    CASE
        WHEN COALESCE(bp.recent_avg_value, 0) > COALESCE(bp.lifetime_avg_value, 0) * 1.2 THEN 'Increasing_Spend'
        WHEN COALESCE(bp.recent_avg_value, 0) < COALESCE(bp.lifetime_avg_value, 0) * 0.8 THEN 'Decreasing_Spend'
        ELSE 'Stable_Spend'
    END AS spending_trend,

    -- Loyalty scoring
    CASE
        WHEN bp.stores_visited_lifetime = 1 AND bp.lifetime_transactions >= 10 THEN 'High_Store_Loyalty'
        WHEN bp.stores_visited_lifetime <= 2 AND bp.lifetime_transactions >= 5 THEN 'Medium_Store_Loyalty'
        ELSE 'Low_Store_Loyalty'
    END AS store_loyalty_score,

    -- Visit consistency
    CASE
        WHEN bp.visit_time_consistency < 2 THEN 'Very_Consistent'
        WHEN bp.visit_time_consistency < 4 THEN 'Somewhat_Consistent'
        ELSE 'Inconsistent'
    END AS visit_consistency_level,

    -- Customer maturity
    CASE
        WHEN bp.customer_lifespan >= 90 THEN 'Mature_Customer'
        WHEN bp.customer_lifespan >= 30 THEN 'Developing_Customer'
        WHEN bp.customer_lifespan >= 7 THEN 'New_Customer'
        ELSE 'First_Time_Customer'
    END AS customer_maturity_stage,

    -- Emotional stability
    CASE
        WHEN bp.happiness_ratio > 0.6 THEN 'Generally_Happy'
        WHEN bp.negative_emotion_ratio > 0.3 THEN 'Often_Negative'
        ELSE 'Emotionally_Neutral'
    END AS emotional_profile,

    -- =====================================================
    -- PRODUCT AFFINITY (18 columns)
    -- =====================================================

    -- Category diversity
    (SELECT COUNT(DISTINCT item_category)
     FROM sku_items si_sub
     WHERE si_sub.canonical_tx_id = si.canonical_tx_id) AS category_diversity_count,

    -- Brand variety
    (SELECT COUNT(DISTINCT item_brand)
     FROM sku_items si_sub
     WHERE si_sub.canonical_tx_id = si.canonical_tx_id) AS brand_variety_count,

    -- Price point preference
    CASE
        WHEN COALESCE(si.TransactionValue, pt.amount) > 200 THEN 'Premium_Buyer'
        WHEN COALESCE(si.TransactionValue, pt.amount) > 100 THEN 'Mid_Range_Buyer'
        WHEN COALESCE(si.TransactionValue, pt.amount) > 50 THEN 'Budget_Conscious'
        ELSE 'Price_Sensitive'
    END AS price_point_preference,

    -- Basket composition
    CASE
        WHEN si.BasketSize >= 5 THEN 'Large_Basket'
        WHEN si.BasketSize >= 3 THEN 'Medium_Basket'
        WHEN si.BasketSize >= 1 THEN 'Small_Basket'
        ELSE 'Unknown_Basket'
    END AS basket_size_category,

    -- Substitution behavior
    CASE
        WHEN si.WasSubstitution = 1 THEN 'Accepts_Substitution'
        ELSE 'Specific_Purchase'
    END AS substitution_behavior,

    -- Product category flags
    CASE WHEN sku1.item_category LIKE '%cigarette%' OR sku1.item_category LIKE '%tobacco%' THEN 1 ELSE 0 END AS buys_cigarettes,
    CASE WHEN sku1.item_category LIKE '%beverage%' OR sku1.item_category LIKE '%drink%' THEN 1 ELSE 0 END AS buys_beverages,
    CASE WHEN sku1.item_category LIKE '%snack%' OR sku1.item_category LIKE '%candy%' THEN 1 ELSE 0 END AS buys_snacks,
    CASE WHEN sku1.item_category LIKE '%personal care%' OR sku1.item_category LIKE '%hygiene%' THEN 1 ELSE 0 END AS buys_personal_care,

    -- Digital service adoption
    CASE WHEN ci.digital_product_mentioned IS NOT NULL THEN 1 ELSE 0 END AS uses_digital_services,

    -- =====================================================
    -- ECONOMIC INDICATORS (12 columns)
    -- =====================================================

    -- Spending power indicators
    CASE
        WHEN COALESCE(si.TransactionValue, pt.amount) > COALESCE(bp.lifetime_avg_value, 50) * 1.5 THEN 'Above_Average_Spend'
        WHEN COALESCE(si.TransactionValue, pt.amount) < COALESCE(bp.lifetime_avg_value, 50) * 0.5 THEN 'Below_Average_Spend'
        ELSE 'Normal_Spend'
    END AS relative_spending_power,

    -- Value seeking behavior
    CASE
        WHEN ci.conversation_intent = 'Price_Inquiry' THEN 'Price_Conscious'
        WHEN COALESCE(fp.tingi_preference_score, 0) > 0.7 THEN 'Value_Seeker'
        ELSE 'Standard_Buyer'
    END AS value_seeking_behavior,

    -- Purchase timing patterns
    CASE
        WHEN COALESCE(fp.payday_correlation_score, 0) > 0.4 THEN 'Payday_Dependent'
        WHEN bp.transaction_frequency > 0.5 THEN 'Frequent_Shopper'
        ELSE 'Occasional_Shopper'
    END AS purchase_timing_pattern,

    -- Economic segment
    CASE
        WHEN COALESCE(si.TransactionValue, pt.amount) > 200 AND bp.transaction_frequency > 0.3 THEN 'High_Value_Frequent'
        WHEN COALESCE(si.TransactionValue, pt.amount) > 100 AND bp.transaction_frequency > 0.2 THEN 'Medium_Value_Regular'
        WHEN COALESCE(si.TransactionValue, pt.amount) <= 50 THEN 'Low_Value_Customer'
        ELSE 'Standard_Customer'
    END AS economic_segment,

    -- =====================================================
    -- PREDICTIVE INDICATORS (10 columns)
    -- =====================================================

    -- Churn risk
    CASE
        WHEN DATEDIFF(day, si.TransactionDate, GETDATE()) > 30 AND bp.transaction_frequency > 0.1 THEN 'High_Churn_Risk'
        WHEN DATEDIFF(day, si.TransactionDate, GETDATE()) > 14 THEN 'Medium_Churn_Risk'
        ELSE 'Low_Churn_Risk'
    END AS churn_risk_level,

    -- Growth potential
    CASE
        WHEN bp.lifetime_transactions < 5 AND COALESCE(si.TransactionValue, pt.amount) > 100 THEN 'High_Growth_Potential'
        WHEN bp.stores_visited_lifetime = 1 AND bp.lifetime_transactions >= 5 THEN 'Upsell_Opportunity'
        ELSE 'Standard_Growth'
    END AS growth_potential,

    -- Satisfaction trend
    CASE
        WHEN ci.satisfaction_indicator LIKE '%High%' AND bp.happiness_ratio > 0.5 THEN 'Highly_Satisfied'
        WHEN ci.satisfaction_indicator = 'Dissatisfaction' OR bp.negative_emotion_ratio > 0.3 THEN 'At_Risk'
        ELSE 'Neutral_Satisfaction'
    END AS satisfaction_trend,

    -- Engagement level
    CASE
        WHEN ci.conversation_length_category IN ('Long', 'Very_Long') AND ci.is_polite_customer = 1 THEN 'Highly_Engaged'
        WHEN ci.conversation_length_category = 'Silent' THEN 'Non_Verbal'
        ELSE 'Standard_Engagement'
    END AS engagement_level,

    -- =====================================================
    -- STORE OPTIMIZATION (8 columns)
    -- =====================================================

    -- Peak hour impact
    CASE
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 7 AND 9 THEN 'Morning_Rush_Customer'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 12 AND 14 THEN 'Lunch_Rush_Customer'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 17 AND 19 THEN 'Evening_Rush_Customer'
        ELSE 'Off_Peak_Customer'
    END AS peak_hour_impact,

    -- Service efficiency indicator
    CASE
        WHEN ci.urgency_level = 'Urgent' THEN 'Needs_Fast_Service'
        WHEN ci.conversation_length_category IN ('Long', 'Very_Long') THEN 'Needs_Detailed_Service'
        WHEN ci.conversation_length_category = 'Silent' THEN 'Prefers_Minimal_Interaction'
        ELSE 'Standard_Service'
    END AS service_preference,

    -- Inventory impact
    CASE
        WHEN ci.conversation_intent = 'Product_Availability' THEN 'Stock_Checker'
        WHEN si.WasSubstitution = 1 THEN 'Flexible_On_Stock'
        ELSE 'Standard_Stock_Impact'
    END AS inventory_impact,

    -- Staff interaction quality
    CASE
        WHEN ci.politeness_score > 0.5 AND ci.satisfaction_indicator LIKE '%High%' THEN 'Positive_Interaction'
        WHEN ci.satisfaction_indicator = 'Dissatisfaction' THEN 'Challenging_Interaction'
        ELSE 'Standard_Interaction'
    END AS staff_interaction_quality,

    -- =====================================================
    -- COMPOSITE SCORES
    -- =====================================================

    -- Overall customer value score
    (COALESCE(bp.lifetime_avg_value, 0) / 100.0 * 0.3 +
     COALESCE(bp.transaction_frequency, 0) * 0.3 +
     COALESCE(fp.suki_loyalty_index, 0) * 0.2 +
     COALESCE(ci.politeness_score, 0) * 0.1 +
     CASE WHEN ci.satisfaction_indicator LIKE '%High%' THEN 0.1 ELSE 0 END) AS customer_value_score,

    -- Cultural alignment score
    (COALESCE(fp.suki_loyalty_index, 0) * 0.4 +
     COALESCE(ci.politeness_score, 0) * 0.3 +
     CASE WHEN ci.language_detected = 'Filipino' THEN 0.3 ELSE 0 END) AS cultural_alignment_score

FROM dbo.SalesInteractions si
LEFT JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
LEFT JOIN analytics.v_stg_stores s ON si.StoreID = s.store_id
LEFT JOIN dbo.Region r ON r.RegionID = s.region
LEFT JOIN dbo.Province p ON p.ProvinceID = s.province
LEFT JOIN dbo.Municipality m ON m.MunicipalityID = s.city_municipality
LEFT JOIN dbo.Barangay b ON b.BarangayID = s.barangay

-- Join SKU data
LEFT JOIN sku_items sku1 ON si.canonical_tx_id = sku1.canonical_tx_id AND sku1.item_rank = 1

-- Join Filipino personas
LEFT JOIN dbo.ncr_filipino_persona_results fp ON si.FacialID = fp.FacialID

-- Join conversation intelligence
LEFT JOIN dbo.conversation_intelligence_results ci ON si.canonical_tx_id = ci.canonical_tx_id

-- Join behavioral patterns
LEFT JOIN behavioral_patterns bp ON si.FacialID = bp.FacialID

WHERE si.canonical_tx_id IS NOT NULL;
GO

-- Create materialized ultra-enriched dataset
CREATE OR ALTER PROCEDURE dbo.sp_refresh_ultra_enriched_dataset
AS
BEGIN
    -- Ensure dependencies are up to date
    EXEC dbo.sp_refresh_ncr_cultural_clustering;
    EXEC dbo.sp_refresh_conversation_intelligence;

    -- Drop and recreate materialized view
    IF OBJECT_ID('dbo.ultra_enriched_dataset_results', 'U') IS NOT NULL
        DROP TABLE dbo.ultra_enriched_dataset_results;

    SELECT *
    INTO dbo.ultra_enriched_dataset_results
    FROM dbo.v_ultra_enriched_dataset;

    -- Create comprehensive indexes
    CREATE CLUSTERED INDEX CX_UltraEnriched_TxID
    ON dbo.ultra_enriched_dataset_results (transaction_id);

    CREATE NONCLUSTERED INDEX IX_UltraEnriched_Persona_Analysis
    ON dbo.ultra_enriched_dataset_results (filipino_persona, conversation_language, economic_segment)
    INCLUDE (customer_value_score, cultural_alignment_score);

    CREATE NONCLUSTERED INDEX IX_UltraEnriched_Store_Analytics
    ON dbo.ultra_enriched_dataset_results (store_id, transaction_date, peak_hour_impact)
    INCLUDE (transaction_amount, satisfaction_indicator, churn_risk_level);

    CREATE NONCLUSTERED INDEX IX_UltraEnriched_Customer_Journey
    ON dbo.ultra_enriched_dataset_results (customer_facial_id, customer_maturity_stage)
    INCLUDE (lifetime_transactions, customer_value_score);

    PRINT 'Ultra-enriched dataset refreshed successfully with 150+ analytical columns.';
END;
GO

-- Sample usage queries (commented for reference)
/*
-- Execute full dataset refresh
EXEC dbo.sp_refresh_ultra_enriched_dataset;

-- Comprehensive persona analysis
SELECT filipino_persona, conversation_language, economic_segment,
       COUNT(*) as customer_count,
       AVG(customer_value_score) as avg_value_score,
       AVG(cultural_alignment_score) as avg_cultural_score
FROM dbo.ultra_enriched_dataset_results
GROUP BY filipino_persona, conversation_language, economic_segment
ORDER BY customer_count DESC;

-- Store performance insights
SELECT store_id, store_name,
       COUNT(*) as total_transactions,
       AVG(customer_value_score) as avg_customer_value,
       COUNT(CASE WHEN satisfaction_indicator LIKE '%High%' THEN 1 END) * 100.0 / COUNT(*) as satisfaction_rate,
       COUNT(CASE WHEN churn_risk_level = 'Low_Churn_Risk' THEN 1 END) * 100.0 / COUNT(*) as retention_rate
FROM dbo.ultra_enriched_dataset_results
WHERE store_id IS NOT NULL
GROUP BY store_id, store_name
ORDER BY avg_customer_value DESC;

-- Cultural insights analysis
SELECT conversation_language, suki_loyalty_level, tingi_behavior_type,
       COUNT(*) as frequency,
       AVG(transaction_amount) as avg_transaction,
       AVG(politeness_score) as avg_politeness
FROM dbo.ultra_enriched_dataset_results
WHERE conversation_language != 'Silent'
GROUP BY conversation_language, suki_loyalty_level, tingi_behavior_type
ORDER BY frequency DESC;
*/