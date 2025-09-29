-- Scout Conversation AI - Gold Layer Views
-- Creates enriched views joining AI analysis with transactional data
-- Enables business intelligence on sentiment, key phrases, and conversation metrics

USE [SQL-TBWA-ProjectScout-Reporting-Prod];

-- Create gold schema if it doesn't exist
IF SCHEMA_ID('gold') IS NULL
    EXEC('CREATE SCHEMA gold');

-- Drop views if they exist (for clean development)
IF OBJECT_ID('gold.v_conversation_insights', 'V') IS NOT NULL
    DROP VIEW gold.v_conversation_insights;

IF OBJECT_ID('gold.v_sentiment_analysis', 'V') IS NOT NULL
    DROP VIEW gold.v_sentiment_analysis;

IF OBJECT_ID('gold.v_key_phrases_summary', 'V') IS NOT NULL
    DROP VIEW gold.v_key_phrases_summary;

IF OBJECT_ID('gold.v_conversation_metrics', 'V') IS NOT NULL
    DROP VIEW gold.v_conversation_metrics;

-- Main conversation insights view - joins AI analysis with transaction data
CREATE VIEW gold.v_conversation_insights AS
SELECT
    -- Transaction identifiers
    tx.TransactionID,
    tx.InteractionID,
    tx.CustomerID,
    tx.StoreID,
    tx.TransactionDate,

    -- Store and location context
    s.StoreName,
    s.RegionName,
    s.ProvinceName,
    s.CityName,

    -- Transaction details
    tx.TotalAmount,
    tx.ItemCount,
    tx.BrandName,
    tx.CategoryName,
    tx.SubCategoryName,
    tx.IsPremium,
    tx.IsTobacco,
    tx.IsLaundry,

    -- AI Analysis Results
    ai.sentiment,
    ai.sentiment_pos,
    ai.sentiment_neu,
    ai.sentiment_neg,
    ai.sentiment_score,
    ai.key_phrases,
    ai.key_phrases_count,
    ai.language,
    ai.language_confidence,
    ai.original_text,
    ai.text_length,
    ai.word_count,
    ai.processing_timestamp,
    ai.processing_status,

    -- Derived insights
    CASE
        WHEN ai.sentiment_score > 0.2 THEN 'Highly Positive'
        WHEN ai.sentiment_score > 0.0 THEN 'Positive'
        WHEN ai.sentiment_score > -0.2 THEN 'Neutral'
        WHEN ai.sentiment_score > -0.5 THEN 'Negative'
        ELSE 'Highly Negative'
    END as sentiment_category,

    CASE
        WHEN ai.text_length > 500 THEN 'Long'
        WHEN ai.text_length > 100 THEN 'Medium'
        ELSE 'Short'
    END as text_length_category,

    CASE
        WHEN ai.language_confidence > 0.95 THEN 'High'
        WHEN ai.language_confidence > 0.8 THEN 'Medium'
        ELSE 'Low'
    END as language_confidence_level

FROM mart_tx tx
INNER JOIN silver.conversation_ai ai
    ON tx.TransactionID = ai.canonical_tx_id
INNER JOIN dim_store s
    ON tx.StoreID = s.StoreID
WHERE ai.processing_status = 'completed'
    AND ai.sentiment IS NOT NULL;

-- Sentiment analysis aggregation view
CREATE VIEW gold.v_sentiment_analysis AS
SELECT
    -- Grouping dimensions
    s.RegionName,
    s.ProvinceName,
    tx.BrandName,
    tx.CategoryName,
    CAST(tx.TransactionDate AS DATE) as analysis_date,
    DATEPART(YEAR, tx.TransactionDate) as analysis_year,
    DATEPART(MONTH, tx.TransactionDate) as analysis_month,

    -- Sentiment distribution
    COUNT(*) as total_interactions,
    COUNT(CASE WHEN ai.sentiment = 'positive' THEN 1 END) as positive_count,
    COUNT(CASE WHEN ai.sentiment = 'neutral' THEN 1 END) as neutral_count,
    COUNT(CASE WHEN ai.sentiment = 'negative' THEN 1 END) as negative_count,

    -- Sentiment percentages
    CAST(COUNT(CASE WHEN ai.sentiment = 'positive' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as positive_pct,
    CAST(COUNT(CASE WHEN ai.sentiment = 'neutral' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as neutral_pct,
    CAST(COUNT(CASE WHEN ai.sentiment = 'negative' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as negative_pct,

    -- Average sentiment scores
    AVG(ai.sentiment_pos) as avg_positive_score,
    AVG(ai.sentiment_neu) as avg_neutral_score,
    AVG(ai.sentiment_neg) as avg_negative_score,
    AVG(ai.sentiment_score) as avg_sentiment_score,

    -- Business impact metrics
    AVG(tx.TotalAmount) as avg_transaction_amount,
    SUM(tx.TotalAmount) as total_revenue,
    AVG(CASE WHEN ai.sentiment = 'positive' THEN tx.TotalAmount END) as avg_positive_revenue,
    AVG(CASE WHEN ai.sentiment = 'negative' THEN tx.TotalAmount END) as avg_negative_revenue,

    -- Text analysis metrics
    AVG(CAST(ai.text_length AS FLOAT)) as avg_text_length,
    AVG(CAST(ai.word_count AS FLOAT)) as avg_word_count,
    AVG(CAST(ai.key_phrases_count AS FLOAT)) as avg_phrases_count

FROM mart_tx tx
INNER JOIN silver.conversation_ai ai
    ON tx.TransactionID = ai.canonical_tx_id
INNER JOIN dim_store s
    ON tx.StoreID = s.StoreID
WHERE ai.processing_status = 'completed'
    AND ai.sentiment IS NOT NULL
GROUP BY
    s.RegionName,
    s.ProvinceName,
    tx.BrandName,
    tx.CategoryName,
    CAST(tx.TransactionDate AS DATE),
    DATEPART(YEAR, tx.TransactionDate),
    DATEPART(MONTH, tx.TransactionDate);

-- Key phrases analysis view
CREATE VIEW gold.v_key_phrases_summary AS
WITH phrase_split AS (
    SELECT
        ai.canonical_tx_id,
        tx.CategoryName,
        tx.BrandName,
        s.RegionName,
        ai.sentiment,
        LTRIM(RTRIM(value)) as phrase
    FROM mart_tx tx
    INNER JOIN silver.conversation_ai ai
        ON tx.TransactionID = ai.canonical_tx_id
    INNER JOIN dim_store s
        ON tx.StoreID = s.StoreID
    CROSS APPLY STRING_SPLIT(ai.key_phrases, ';')
    WHERE ai.processing_status = 'completed'
        AND ai.key_phrases IS NOT NULL
        AND LEN(LTRIM(RTRIM(value))) > 2
)
SELECT
    phrase,
    CategoryName,
    BrandName,
    RegionName,
    sentiment,
    COUNT(*) as phrase_frequency,
    COUNT(DISTINCT canonical_tx_id) as unique_transactions,

    -- Sentiment distribution for this phrase
    COUNT(CASE WHEN sentiment = 'positive' THEN 1 END) as positive_mentions,
    COUNT(CASE WHEN sentiment = 'neutral' THEN 1 END) as neutral_mentions,
    COUNT(CASE WHEN sentiment = 'negative' THEN 1 END) as negative_mentions,

    -- Phrase sentiment score
    CAST(COUNT(CASE WHEN sentiment = 'positive' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as positive_sentiment_pct,

    -- Ranking within category
    ROW_NUMBER() OVER (PARTITION BY CategoryName ORDER BY COUNT(*) DESC) as phrase_rank_in_category,
    ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) as phrase_rank_overall

FROM phrase_split
GROUP BY phrase, CategoryName, BrandName, RegionName, sentiment
HAVING COUNT(*) >= 3;  -- Filter out very rare phrases

-- Overall conversation metrics view
CREATE VIEW gold.v_conversation_metrics AS
SELECT
    -- Date dimensions
    CAST(tx.TransactionDate AS DATE) as metric_date,
    DATEPART(YEAR, tx.TransactionDate) as metric_year,
    DATEPART(MONTH, tx.TransactionDate) as metric_month,
    DATEPART(DAY, tx.TransactionDate) as metric_day,

    -- Geographic dimensions
    s.RegionName,
    s.ProvinceName,

    -- Business dimensions
    tx.CategoryName,
    tx.BrandName,
    CASE WHEN tx.IsPremium = 1 THEN 'Premium' ELSE 'Standard' END as brand_tier,

    -- Core metrics
    COUNT(*) as total_conversations,
    COUNT(CASE WHEN ai.processing_status = 'completed' THEN 1 END) as processed_conversations,
    COUNT(CASE WHEN ai.processing_status = 'failed' THEN 1 END) as failed_conversations,

    -- Processing success rate
    CAST(COUNT(CASE WHEN ai.processing_status = 'completed' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as processing_success_rate,

    -- Language distribution
    COUNT(CASE WHEN ai.language = 'en' THEN 1 END) as english_conversations,
    COUNT(CASE WHEN ai.language = 'tl' THEN 1 END) as tagalog_conversations,
    COUNT(CASE WHEN ai.language = 'ceb' THEN 1 END) as cebuano_conversations,
    COUNT(CASE WHEN ai.language NOT IN ('en', 'tl', 'ceb') AND ai.language IS NOT NULL THEN 1 END) as other_language_conversations,

    -- Sentiment distribution
    COUNT(CASE WHEN ai.sentiment = 'positive' THEN 1 END) as positive_conversations,
    COUNT(CASE WHEN ai.sentiment = 'neutral' THEN 1 END) as neutral_conversations,
    COUNT(CASE WHEN ai.sentiment = 'negative' THEN 1 END) as negative_conversations,

    -- Quality metrics
    AVG(ai.language_confidence) as avg_language_confidence,
    AVG(CAST(ai.text_length AS FLOAT)) as avg_conversation_length,
    AVG(CAST(ai.key_phrases_count AS FLOAT)) as avg_key_phrases_per_conversation,

    -- Business impact
    SUM(tx.TotalAmount) as total_revenue,
    AVG(tx.TotalAmount) as avg_transaction_value,

    -- Sentiment-revenue correlation
    AVG(CASE WHEN ai.sentiment = 'positive' THEN tx.TotalAmount END) as avg_positive_sentiment_revenue,
    AVG(CASE WHEN ai.sentiment = 'negative' THEN tx.TotalAmount END) as avg_negative_sentiment_revenue

FROM mart_tx tx
LEFT JOIN silver.conversation_ai ai
    ON tx.TransactionID = ai.canonical_tx_id
INNER JOIN dim_store s
    ON tx.StoreID = s.StoreID
GROUP BY
    CAST(tx.TransactionDate AS DATE),
    DATEPART(YEAR, tx.TransactionDate),
    DATEPART(MONTH, tx.TransactionDate),
    DATEPART(DAY, tx.TransactionDate),
    s.RegionName,
    s.ProvinceName,
    tx.CategoryName,
    tx.BrandName,
    CASE WHEN tx.IsPremium = 1 THEN 'Premium' ELSE 'Standard' END;

-- Create indexes for performance
CREATE INDEX IX_gold_conversation_insights_date
    ON gold.v_conversation_insights(TransactionDate, RegionName, CategoryName)
    WHERE sentiment IS NOT NULL;

-- Grant permissions (adjust as needed for your environment)
-- GRANT SELECT ON gold.v_conversation_insights TO [YourPowerBIServicePrincipal];
-- GRANT SELECT ON gold.v_sentiment_analysis TO [YourPowerBIServicePrincipal];
-- GRANT SELECT ON gold.v_key_phrases_summary TO [YourPowerBIServicePrincipal];
-- GRANT SELECT ON gold.v_conversation_metrics TO [YourPowerBIServicePrincipal];

PRINT '✅ Gold layer conversation AI views created successfully';
PRINT 'Available views:';
PRINT '1. gold.v_conversation_insights - Detailed transaction + AI analysis';
PRINT '2. gold.v_sentiment_analysis - Aggregated sentiment metrics';
PRINT '3. gold.v_key_phrases_summary - Key phrase frequency and sentiment';
PRINT '4. gold.v_conversation_metrics - Overall conversation analytics';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Test views with sample data';
PRINT '2. Update PBIP model to include AI tables';
PRINT '3. Create AI-specific DAX measures';
PRINT '4. Add sentiment analysis to existing reports';

-- Quick validation query
SELECT
    'Validation Check' as CheckType,
    COUNT(*) as TotalRecords,
    COUNT(DISTINCT CategoryName) as UniqueCategories,
    COUNT(DISTINCT RegionName) as UniqueRegions,
    AVG(CAST(sentiment_score AS FLOAT)) as AvgSentimentScore
FROM gold.v_conversation_insights
WHERE TransactionDate >= DATEADD(DAY, -30, GETDATE());