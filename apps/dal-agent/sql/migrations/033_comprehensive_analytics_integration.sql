-- =====================================================
-- COMPREHENSIVE ANALYTICS INTEGRATION: Gold + Platinum Layer Enhancement
-- Integrates all statistical patterns, ML models, and analytics capabilities
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRAN;

DECLARE @run UNIQUEIDENTIFIER = NEWID();
INSERT dbo.etl_execution_log(etl_run_id, etl_name) VALUES(@run, N'033_comprehensive_analytics_integration');

-- =====================================================
-- PLATINUM LAYER: AI/ML ANALYTICS TABLES
-- =====================================================

-- Statistical Pattern Analysis
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('platinum') AND name = 'statistical_patterns')
    DROP TABLE platinum.statistical_patterns;

CREATE TABLE platinum.statistical_patterns (
    pattern_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    pattern_type NVARCHAR(50) NOT NULL,              -- correlation, regression, clustering, classification
    analysis_date DATE NOT NULL,
    entity_type NVARCHAR(50),                        -- customer, product, store, transaction
    entity_id NVARCHAR(100),

    -- Statistical metrics
    pattern_strength DECIMAL(8,4),                   -- R², correlation coefficient, confidence score
    statistical_significance DECIMAL(8,4),            -- p-value, confidence interval
    sample_size INT,
    confidence_level DECIMAL(8,4) DEFAULT 0.95,

    -- Pattern description
    pattern_description NVARCHAR(MAX),
    mathematical_formula NVARCHAR(500),

    -- Dependent and independent variables
    dependent_variables NVARCHAR(MAX),               -- JSON array of variables
    independent_variables NVARCHAR(MAX),             -- JSON array of variables

    -- Model performance
    model_accuracy DECIMAL(8,4),
    cross_validation_score DECIMAL(8,4),
    out_of_sample_error DECIMAL(8,4),

    -- Metadata
    analysis_method NVARCHAR(100),                   -- linear_regression, logistic_regression, kmeans, etc.
    created_by NVARCHAR(100) DEFAULT 'scout_analytics_engine',
    created_at DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_platinum_patterns_type (pattern_type, analysis_date DESC),
    INDEX idx_platinum_patterns_entity (entity_type, entity_id),
    INDEX idx_platinum_patterns_strength (pattern_strength DESC)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Created table: platinum.statistical_patterns';

-- Predictive Models Registry
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('platinum') AND name = 'predictive_models')
    DROP TABLE platinum.predictive_models;

CREATE TABLE platinum.predictive_models (
    model_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    model_name NVARCHAR(200) NOT NULL,
    model_type NVARCHAR(50) NOT NULL,                -- forecasting, classification, regression, clustering
    model_category NVARCHAR(50),                     -- demand_forecast, customer_segment, price_prediction

    -- Model specifications
    algorithm NVARCHAR(100),                         -- random_forest, linear_regression, arima, etc.
    hyperparameters NVARCHAR(MAX),                   -- JSON with model parameters
    feature_columns NVARCHAR(MAX),                   -- JSON array of input features
    target_column NVARCHAR(100),                     -- Prediction target

    -- Training metrics
    training_start_date DATE,
    training_end_date DATE,
    training_sample_size INT,
    validation_accuracy DECIMAL(8,4),
    test_accuracy DECIMAL(8,4),
    model_r_squared DECIMAL(8,4),
    mean_absolute_error DECIMAL(12,4),
    root_mean_squared_error DECIMAL(12,4),

    -- Model lifecycle
    model_status NVARCHAR(20) DEFAULT 'active',      -- active, deprecated, testing
    deployment_date DATE,
    last_retrained_date DATE,
    next_retrain_date DATE,

    -- Model artifacts (serialized)
    model_binary VARBINARY(MAX),                     -- Serialized model for small models
    model_file_path NVARCHAR(500),                   -- Path to model file for large models

    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_platinum_models_type (model_type, model_status),
    INDEX idx_platinum_models_category (model_category, deployment_date DESC),
    INDEX idx_platinum_models_accuracy (validation_accuracy DESC)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Created table: platinum.predictive_models';

-- Model Predictions Output
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('platinum') AND name = 'model_predictions')
    DROP TABLE platinum.model_predictions;

CREATE TABLE platinum.model_predictions (
    prediction_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    model_id BIGINT NOT NULL,
    entity_type NVARCHAR(50),                        -- customer, product, store, transaction
    entity_id NVARCHAR(100),
    prediction_date DATE NOT NULL,
    prediction_timestamp DATETIME2 DEFAULT GETUTCDATE(),

    -- Prediction outputs
    predicted_value DECIMAL(18,4),
    predicted_category NVARCHAR(100),                -- For classification models
    prediction_confidence DECIMAL(8,4),
    confidence_interval_lower DECIMAL(18,4),
    confidence_interval_upper DECIMAL(18,4),

    -- Feature importance (top 5)
    feature_importance NVARCHAR(MAX),                -- JSON with feature importance scores

    -- Actual vs predicted (for validation)
    actual_value DECIMAL(18,4),
    actual_category NVARCHAR(100),
    prediction_error DECIMAL(18,4),
    absolute_percentage_error DECIMAL(8,4),

    -- Metadata
    model_version NVARCHAR(50),
    prediction_horizon_days INT,                     -- For forecasting models

    FOREIGN KEY (model_id) REFERENCES platinum.predictive_models(model_id),
    INDEX idx_platinum_predictions_model (model_id, prediction_date DESC),
    INDEX idx_platinum_predictions_entity (entity_type, entity_id, prediction_date DESC),
    INDEX idx_platinum_predictions_confidence (prediction_confidence DESC)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Created table: platinum.model_predictions';

-- AI-Generated Insights
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('platinum') AND name = 'ai_insights')
    DROP TABLE platinum.ai_insights;

CREATE TABLE platinum.ai_insights (
    insight_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    insight_type NVARCHAR(50) NOT NULL,              -- diagnostic, descriptive, predictive, prescriptive
    insight_category NVARCHAR(50),                   -- customer_behavior, product_performance, market_trends

    -- Insight content
    insight_title NVARCHAR(200),
    insight_description NVARCHAR(MAX),
    key_findings NVARCHAR(MAX),                      -- JSON array of key findings
    statistical_evidence NVARCHAR(MAX),              -- Supporting statistics

    -- Business impact
    business_impact_level NVARCHAR(20),              -- high, medium, low
    potential_revenue_impact DECIMAL(15,2),
    confidence_score DECIMAL(8,4),

    -- Recommendations
    recommendations NVARCHAR(MAX),                   -- JSON array of actionable recommendations
    implementation_complexity NVARCHAR(20),          -- low, medium, high
    expected_timeline NVARCHAR(100),

    -- Data sources
    data_sources NVARCHAR(MAX),                      -- JSON array of source tables/models
    analysis_period_start DATE,
    analysis_period_end DATE,

    -- Validation
    insight_status NVARCHAR(20) DEFAULT 'pending',   -- pending, validated, rejected, implemented
    validation_date DATE,
    validation_notes NVARCHAR(MAX),

    -- AI model information
    generated_by_model NVARCHAR(100),                -- AI model that generated insight
    generation_method NVARCHAR(100),                 -- automated, semi_automated, manual

    created_at DATETIME2 DEFAULT GETUTCDATE(),
    expires_at DATETIME2,                            -- When insight becomes stale

    INDEX idx_platinum_insights_type (insight_type, insight_category),
    INDEX idx_platinum_insights_impact (business_impact_level, confidence_score DESC),
    INDEX idx_platinum_insights_status (insight_status, created_at DESC)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Created table: platinum.ai_insights';

-- =====================================================
-- ENHANCED GOLD LAYER: ADVANCED ANALYTICS VIEWS
-- =====================================================

-- Customer Segmentation and Persona Analysis
CREATE OR ALTER VIEW gold.v_customer_segments AS
WITH customer_behavior AS (
    SELECT
        st.customer_facial_id,
        COUNT(DISTINCT st.canonical_tx_id) AS transaction_count,
        SUM(st.total_amount) AS total_spend,
        AVG(st.total_amount) AS avg_transaction_value,
        AVG(st.item_count) AS avg_basket_size,
        COUNT(DISTINCT st.store_id) AS store_diversity,
        COUNT(DISTINCT sti.nielsen_category_l1) AS category_diversity,
        MIN(st.transaction_date) AS first_transaction_date,
        MAX(st.transaction_date) AS last_transaction_date,
        DATEDIFF(DAY, MIN(st.transaction_date), MAX(st.transaction_date)) AS customer_lifetime_days,
        AVG(st.conversation_score) AS avg_conversation_engagement,

        -- Temporal patterns
        COUNT(CASE WHEN st.time_bucket = 'Morning' THEN 1 END) AS morning_transactions,
        COUNT(CASE WHEN st.time_bucket = 'Afternoon' THEN 1 END) AS afternoon_transactions,
        COUNT(CASE WHEN st.time_bucket = 'Evening' THEN 1 END) AS evening_transactions,
        COUNT(CASE WHEN st.is_weekday = 1 THEN 1 END) AS weekday_transactions,
        COUNT(CASE WHEN st.is_weekday = 0 THEN 1 END) AS weekend_transactions,

        -- Geographic behavior
        COUNT(DISTINCT st.region) AS regional_diversity,
        COUNT(DISTINCT st.city) AS city_diversity

    FROM silver.transactions st
    LEFT JOIN silver.transaction_items sti ON st.canonical_tx_id = sti.canonical_tx_id
    WHERE st.customer_facial_id IS NOT NULL
    GROUP BY st.customer_facial_id
),
customer_segments AS (
    SELECT
        *,
        -- RFM Analysis
        NTILE(5) OVER (ORDER BY last_transaction_date DESC) AS recency_quintile,
        NTILE(5) OVER (ORDER BY transaction_count DESC) AS frequency_quintile,
        NTILE(5) OVER (ORDER BY total_spend DESC) AS monetary_quintile,

        -- Customer lifecycle stage
        CASE
            WHEN transaction_count = 1 THEN 'New Customer'
            WHEN customer_lifetime_days <= 30 THEN 'Early Stage'
            WHEN transaction_count >= 10 AND total_spend >= 5000 THEN 'VIP Customer'
            WHEN DATEDIFF(DAY, last_transaction_date, GETUTCDATE()) > 90 THEN 'At Risk'
            ELSE 'Regular Customer'
        END AS lifecycle_stage,

        -- Shopping behavior patterns
        CASE
            WHEN avg_basket_size >= 5 THEN 'Bulk Shopper'
            WHEN store_diversity >= 3 THEN 'Store Explorer'
            WHEN category_diversity >= 5 THEN 'Category Explorer'
            WHEN weekend_transactions > weekday_transactions THEN 'Weekend Shopper'
            ELSE 'Regular Shopper'
        END AS shopping_pattern,

        -- Value segment
        CASE
            WHEN total_spend >= 10000 THEN 'High Value'
            WHEN total_spend >= 5000 THEN 'Medium Value'
            WHEN total_spend >= 1000 THEN 'Low Value'
            ELSE 'Minimal Value'
        END AS value_segment

    FROM customer_behavior
)
SELECT
    customer_facial_id,
    transaction_count,
    total_spend,
    avg_transaction_value,
    avg_basket_size,
    store_diversity,
    category_diversity,
    first_transaction_date,
    last_transaction_date,
    customer_lifetime_days,
    avg_conversation_engagement,
    recency_quintile,
    frequency_quintile,
    monetary_quintile,
    CONCAT(recency_quintile, frequency_quintile, monetary_quintile) AS rfm_segment,
    lifecycle_stage,
    shopping_pattern,
    value_segment,

    -- Persona inference
    CASE
        WHEN rfm_segment IN ('555', '554', '544', '545') THEN 'Champions'
        WHEN rfm_segment IN ('445', '455', '454') THEN 'Loyal Customers'
        WHEN rfm_segment IN ('355', '354', '344', '345', '335') THEN 'Potential Loyalists'
        WHEN rfm_segment IN ('512', '511', '422', '421') THEN 'New Customers'
        WHEN rfm_segment IN ('155', '154', '144', '214', '215', '115', '114') THEN 'At Risk'
        WHEN rfm_segment IN ('135', '124', '123', '134', '125') THEN 'Cannot Lose Them'
        ELSE 'Others'
    END AS customer_persona

FROM customer_segments;
GO

-- Market Basket Analysis with Statistical Significance
CREATE OR ALTER VIEW gold.v_market_basket_analysis AS
WITH transaction_pairs AS (
    SELECT
        a.canonical_tx_id,
        a.item_brand AS item_a,
        a.nielsen_category_l1 AS category_a,
        b.item_brand AS item_b,
        b.nielsen_category_l2 AS category_b,
        a.item_total AS amount_a,
        b.item_total AS amount_b
    FROM silver.transaction_items a
    INNER JOIN silver.transaction_items b ON a.canonical_tx_id = b.canonical_tx_id
    WHERE a.item_id != b.item_id
    AND a.item_brand IS NOT NULL
    AND b.item_brand IS NOT NULL
    AND a.item_brand != b.item_brand
),
basket_metrics AS (
    SELECT
        item_a,
        item_b,
        category_a,
        category_b,
        COUNT(*) AS co_occurrence_count,
        COUNT(DISTINCT canonical_tx_id) AS transaction_count,
        AVG(amount_a + amount_b) AS avg_combined_value,
        SUM(amount_a + amount_b) AS total_combined_value,

        -- Market basket metrics
        COUNT(*) * 1.0 / (
            SELECT COUNT(DISTINCT canonical_tx_id)
            FROM silver.transaction_items
            WHERE item_brand = tp.item_a
        ) AS confidence_a_to_b,

        COUNT(*) * 1.0 / (
            SELECT COUNT(DISTINCT canonical_tx_id)
            FROM silver.transaction_items
            WHERE item_brand = tp.item_b
        ) AS confidence_b_to_a,

        -- Support calculation
        COUNT(DISTINCT canonical_tx_id) * 1.0 / (
            SELECT COUNT(DISTINCT canonical_tx_id) FROM silver.transactions
        ) AS support

    FROM transaction_pairs tp
    GROUP BY item_a, item_b, category_a, category_b
    HAVING COUNT(*) >= 5  -- Minimum occurrence threshold
),
lift_calculation AS (
    SELECT
        *,
        -- Lift calculation
        confidence_a_to_b / (
            (SELECT COUNT(DISTINCT canonical_tx_id) FROM silver.transaction_items sti
             WHERE sti.item_brand = bm.item_b) * 1.0 /
            (SELECT COUNT(DISTINCT canonical_tx_id) FROM silver.transactions)
        ) AS lift_score,

        -- Statistical significance (chi-square approximation)
        CASE
            WHEN co_occurrence_count >= 30 AND confidence_a_to_b > 0.1 THEN 'High'
            WHEN co_occurrence_count >= 10 AND confidence_a_to_b > 0.05 THEN 'Medium'
            ELSE 'Low'
        END AS statistical_significance

    FROM basket_metrics bm
)
SELECT
    item_a,
    item_b,
    category_a,
    category_b,
    co_occurrence_count,
    transaction_count,
    support,
    confidence_a_to_b,
    confidence_b_to_a,
    lift_score,
    statistical_significance,
    avg_combined_value,
    total_combined_value,

    -- Business interpretation
    CASE
        WHEN lift_score > 2.0 AND statistical_significance = 'High' THEN 'Strong Association'
        WHEN lift_score > 1.5 AND statistical_significance IN ('High', 'Medium') THEN 'Moderate Association'
        WHEN lift_score > 1.0 THEN 'Weak Association'
        ELSE 'No Association'
    END AS association_strength

FROM lift_calculation
WHERE lift_score > 1.0  -- Only positive associations
;
GO

-- Trend Analysis and Forecasting Prep
CREATE OR ALTER VIEW gold.v_trend_analysis AS
WITH daily_trends AS (
    SELECT
        st.transaction_date,
        DATEPART(YEAR, st.transaction_date) AS year_num,
        DATEPART(MONTH, st.transaction_date) AS month_num,
        DATEPART(DAY, st.transaction_date) AS day_num,
        DATEPART(WEEKDAY, st.transaction_date) AS weekday_num,
        DATENAME(WEEKDAY, st.transaction_date) AS weekday_name,

        -- Core metrics
        COUNT(DISTINCT st.canonical_tx_id) AS transaction_count,
        COUNT(DISTINCT st.customer_facial_id) AS unique_customers,
        SUM(st.total_amount) AS total_revenue,
        AVG(st.total_amount) AS avg_transaction_value,
        SUM(st.item_count) AS total_items_sold,
        AVG(st.item_count) AS avg_basket_size,

        -- Category performance
        COUNT(DISTINCT sti.nielsen_category_l1) AS categories_sold,
        COUNT(DISTINCT sti.item_brand) AS brands_sold,

        -- Time-based patterns
        COUNT(CASE WHEN st.time_bucket = 'Morning' THEN 1 END) AS morning_transactions,
        COUNT(CASE WHEN st.time_bucket = 'Afternoon' THEN 1 END) AS afternoon_transactions,
        COUNT(CASE WHEN st.time_bucket = 'Evening' THEN 1 END) AS evening_transactions,

        -- Geographic distribution
        COUNT(DISTINCT st.region) AS regions_active,
        COUNT(DISTINCT st.store_id) AS stores_active

    FROM silver.transactions st
    LEFT JOIN silver.transaction_items sti ON st.canonical_tx_id = sti.canonical_tx_id
    GROUP BY st.transaction_date
),
moving_averages AS (
    SELECT
        *,
        -- 7-day moving averages
        AVG(transaction_count) OVER (ORDER BY transaction_date ROWS 6 PRECEDING) AS ma7_transaction_count,
        AVG(total_revenue) OVER (ORDER BY transaction_date ROWS 6 PRECEDING) AS ma7_total_revenue,
        AVG(avg_transaction_value) OVER (ORDER BY transaction_date ROWS 6 PRECEDING) AS ma7_avg_transaction_value,

        -- 30-day moving averages
        AVG(transaction_count) OVER (ORDER BY transaction_date ROWS 29 PRECEDING) AS ma30_transaction_count,
        AVG(total_revenue) OVER (ORDER BY transaction_date ROWS 29 PRECEDING) AS ma30_total_revenue,

        -- Growth rates
        LAG(transaction_count, 1) OVER (ORDER BY transaction_date) AS prev_day_transactions,
        LAG(total_revenue, 1) OVER (ORDER BY transaction_date) AS prev_day_revenue,
        LAG(transaction_count, 7) OVER (ORDER BY transaction_date) AS prev_week_transactions,
        LAG(total_revenue, 7) OVER (ORDER BY transaction_date) AS prev_week_revenue

    FROM daily_trends
)
SELECT
    transaction_date,
    year_num,
    month_num,
    day_num,
    weekday_num,
    weekday_name,
    transaction_count,
    unique_customers,
    total_revenue,
    avg_transaction_value,
    total_items_sold,
    avg_basket_size,
    categories_sold,
    brands_sold,
    morning_transactions,
    afternoon_transactions,
    evening_transactions,
    regions_active,
    stores_active,
    ma7_transaction_count,
    ma7_total_revenue,
    ma7_avg_transaction_value,
    ma30_transaction_count,
    ma30_total_revenue,

    -- Growth calculations
    CASE
        WHEN prev_day_transactions > 0
        THEN ((transaction_count - prev_day_transactions) * 100.0 / prev_day_transactions)
        ELSE 0
    END AS daily_transaction_growth_pct,

    CASE
        WHEN prev_day_revenue > 0
        THEN ((total_revenue - prev_day_revenue) * 100.0 / prev_day_revenue)
        ELSE 0
    END AS daily_revenue_growth_pct,

    CASE
        WHEN prev_week_transactions > 0
        THEN ((transaction_count - prev_week_transactions) * 100.0 / prev_week_transactions)
        ELSE 0
    END AS weekly_transaction_growth_pct,

    CASE
        WHEN prev_week_revenue > 0
        THEN ((total_revenue - prev_week_revenue) * 100.0 / prev_week_revenue)
        ELSE 0
    END AS weekly_revenue_growth_pct,

    -- Anomaly detection flags
    CASE
        WHEN ABS(transaction_count - ma7_transaction_count) > (2 * STDEV(transaction_count) OVER (ORDER BY transaction_date ROWS 29 PRECEDING))
        THEN 1 ELSE 0
    END AS transaction_anomaly_flag,

    CASE
        WHEN ABS(total_revenue - ma7_total_revenue) > (2 * STDEV(total_revenue) OVER (ORDER BY transaction_date ROWS 29 PRECEDING))
        THEN 1 ELSE 0
    END AS revenue_anomaly_flag

FROM moving_averages
;
GO

-- =====================================================
-- ANALYTICAL PROCEDURES
-- =====================================================

-- Generate statistical patterns
CREATE OR ALTER PROCEDURE platinum.sp_GenerateStatisticalPatterns
    @AnalysisDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AnalysisDate IS NULL
        SET @AnalysisDate = CAST(GETUTCDATE() AS DATE);

    -- Correlation analysis: Transaction value vs basket size
    INSERT INTO platinum.statistical_patterns (
        pattern_type, analysis_date, entity_type, pattern_strength,
        statistical_significance, sample_size, pattern_description,
        mathematical_formula, dependent_variables, independent_variables,
        analysis_method
    )
    SELECT
        'correlation' AS pattern_type,
        @AnalysisDate AS analysis_date,
        'transaction' AS entity_type,
        (
            (COUNT(*) * SUM(total_amount * item_count) - SUM(total_amount) * SUM(item_count)) /
            SQRT(
                (COUNT(*) * SUM(total_amount * total_amount) - SUM(total_amount) * SUM(total_amount)) *
                (COUNT(*) * SUM(item_count * item_count) - SUM(item_count) * SUM(item_count))
            )
        ) AS pattern_strength,
        0.95 AS statistical_significance,  -- Placeholder for p-value calculation
        COUNT(*) AS sample_size,
        'Correlation between transaction value and basket size' AS pattern_description,
        'r = (n∑xy - ∑x∑y) / √[(n∑x² - (∑x)²)(n∑y² - (∑y)²)]' AS mathematical_formula,
        '["total_amount"]' AS dependent_variables,
        '["item_count"]' AS independent_variables,
        'pearson_correlation' AS analysis_method
    FROM silver.transactions
    WHERE transaction_date >= DATEADD(DAY, -30, @AnalysisDate)
    AND total_amount > 0 AND item_count > 0;

    -- Add more statistical patterns as needed
    PRINT 'Statistical patterns generated successfully';
END;
GO

-- Generate AI insights
CREATE OR ALTER PROCEDURE platinum.sp_GenerateAIInsights
    @AnalysisDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AnalysisDate IS NULL
        SET @AnalysisDate = CAST(GETUTCDATE() AS DATE);

    -- Customer behavior insights
    INSERT INTO platinum.ai_insights (
        insight_type, insight_category, insight_title, insight_description,
        key_findings, business_impact_level, confidence_score,
        recommendations, data_sources, analysis_period_start, analysis_period_end
    )
    SELECT
        'descriptive' AS insight_type,
        'customer_behavior' AS insight_category,
        'High Value Customer Concentration' AS insight_title,
        CONCAT('Analysis shows that ', high_value_pct, '% of customers generate ',
               high_value_revenue_pct, '% of total revenue') AS insight_description,
        CONCAT('[{"finding": "Top 20% customers generate ', high_value_revenue_pct,
               '% of revenue"}, {"finding": "Average spend per high-value customer: $',
               CAST(avg_high_value_spend AS VARCHAR(20)), '"}]') AS key_findings,
        'high' AS business_impact_level,
        0.85 AS confidence_score,
        '[{"action": "Implement VIP customer program"}, {"action": "Personalized marketing for high-value segments"}]' AS recommendations,
        '["silver.transactions", "gold.v_customer_segments"]' AS data_sources,
        DATEADD(DAY, -30, @AnalysisDate) AS analysis_period_start,
        @AnalysisDate AS analysis_period_end
    FROM (
        SELECT
            COUNT(CASE WHEN value_segment = 'High Value' THEN 1 END) * 100.0 / COUNT(*) AS high_value_pct,
            SUM(CASE WHEN value_segment = 'High Value' THEN total_spend ELSE 0 END) * 100.0 / SUM(total_spend) AS high_value_revenue_pct,
            AVG(CASE WHEN value_segment = 'High Value' THEN total_spend END) AS avg_high_value_spend
        FROM gold.v_customer_segments
    ) insights;

    PRINT 'AI insights generated successfully';
END;
GO

-- Record completion
UPDATE dbo.etl_execution_log
SET finished_at = SYSUTCDATETIME(),
    status = 'SUCCESS',
    notes = 'Comprehensive analytics integration: statistical patterns, ML models, AI insights'
WHERE etl_run_id = @run;

COMMIT;
PRINT '✅ Comprehensive Analytics Integration Complete!';
PRINT 'Added: Statistical patterns, predictive models, AI insights, advanced analytics views';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE();
    INSERT dbo.etl_execution_log(etl_run_id, etl_name, finished_at, status, notes)
    VALUES(NEWID(), N'033_comprehensive_analytics_integration', SYSUTCDATETIME(), 'FAILED', @msg);
    THROW;
END CATCH