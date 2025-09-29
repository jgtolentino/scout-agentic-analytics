-- Scout Conversation AI - Silver Layer Setup
-- Creates the foundation for storing AI analysis results from Text Analytics

USE [SQL-TBWA-ProjectScout-Reporting-Prod];

-- Create silver schema if it doesn't exist
IF SCHEMA_ID('silver') IS NULL
    EXEC('CREATE SCHEMA silver');

-- Drop table if exists (for clean development)
IF OBJECT_ID('silver.conversation_ai', 'U') IS NOT NULL
    DROP TABLE silver.conversation_ai;

-- Create the main conversation AI results table
CREATE TABLE silver.conversation_ai (
    -- Primary identification
    canonical_tx_id         NVARCHAR(64)    NOT NULL,       -- Links to mart_tx.TransactionID
    interaction_id          NVARCHAR(64)    NULL,           -- Original interaction identifier

    -- AI Analysis Results
    sentiment               NVARCHAR(20)    NULL,           -- positive|neutral|negative
    sentiment_pos           DECIMAL(9,6)    NULL,           -- Positive confidence score (0-1)
    sentiment_neu           DECIMAL(9,6)    NULL,           -- Neutral confidence score (0-1)
    sentiment_neg           DECIMAL(9,6)    NULL,           -- Negative confidence score (0-1)
    sentiment_score         AS (COALESCE(sentiment_pos, 0) - COALESCE(sentiment_neg, 0)),  -- Computed sentiment (-1 to +1)

    -- Text Analysis
    key_phrases             NVARCHAR(MAX)   NULL,           -- Semicolon-delimited key phrases
    key_phrases_count       AS (LEN(key_phrases) - LEN(REPLACE(key_phrases, ';', '')) + 1), -- Count of phrases
    language                NVARCHAR(10)    NULL,           -- ISO language code (e.g., 'en', 'tl', 'ceb')
    language_confidence     DECIMAL(9,6)    NULL,           -- Language detection confidence

    -- Source Data
    original_text           NVARCHAR(MAX)   NULL,           -- Original conversation text
    text_length             AS (LEN(original_text)),        -- Character count
    word_count              AS (LEN(TRIM(original_text)) - LEN(REPLACE(TRIM(original_text), ' ', '')) + 1), -- Word count

    -- Metadata
    processing_timestamp    DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    processing_version      NVARCHAR(20)    NULL DEFAULT 'TextAnalytics-v3.1',
    processing_status       NVARCHAR(20)    NOT NULL DEFAULT 'completed',    -- completed|failed|partial
    error_message           NVARCHAR(500)   NULL,           -- Error details if processing failed

    -- Audit fields
    created_date            DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_date           DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),

    -- Constraints
    CONSTRAINT PK_silver_conversation_ai PRIMARY KEY (canonical_tx_id),
    CONSTRAINT CK_sentiment CHECK (sentiment IN ('positive', 'neutral', 'negative') OR sentiment IS NULL),
    CONSTRAINT CK_sentiment_scores CHECK (
        (sentiment_pos IS NULL OR (sentiment_pos >= 0 AND sentiment_pos <= 1)) AND
        (sentiment_neu IS NULL OR (sentiment_neu >= 0 AND sentiment_neu <= 1)) AND
        (sentiment_neg IS NULL OR (sentiment_neg >= 0 AND sentiment_neg <= 1))
    ),
    CONSTRAINT CK_processing_status CHECK (processing_status IN ('completed', 'failed', 'partial'))
);

-- Create indexes for optimal performance
CREATE INDEX IX_silver_conversation_ai_sentiment
    ON silver.conversation_ai(sentiment)
    WHERE sentiment IS NOT NULL;

CREATE INDEX IX_silver_conversation_ai_language
    ON silver.conversation_ai(language)
    WHERE language IS NOT NULL;

CREATE INDEX IX_silver_conversation_ai_processing
    ON silver.conversation_ai(processing_timestamp, processing_status);

CREATE INDEX IX_silver_conversation_ai_text_metrics
    ON silver.conversation_ai(text_length, word_count)
    WHERE text_length > 0;

-- Create a view for easy data quality monitoring
CREATE OR ALTER VIEW silver.v_conversation_ai_quality AS
SELECT
    processing_status,
    language,
    sentiment,
    COUNT(*) as record_count,
    AVG(CAST(text_length AS FLOAT)) as avg_text_length,
    AVG(CAST(word_count AS FLOAT)) as avg_word_count,
    AVG(CAST(key_phrases_count AS FLOAT)) as avg_phrases_count,
    AVG(sentiment_pos) as avg_sentiment_pos,
    AVG(sentiment_neu) as avg_sentiment_neu,
    AVG(sentiment_neg) as avg_sentiment_neg,
    AVG(language_confidence) as avg_lang_confidence,
    MIN(processing_timestamp) as earliest_processing,
    MAX(processing_timestamp) as latest_processing
FROM silver.conversation_ai
GROUP BY processing_status, language, sentiment;

-- Sample data for testing (uncomment when ready to test)
/*
INSERT INTO silver.conversation_ai (
    canonical_tx_id, interaction_id, sentiment, sentiment_pos, sentiment_neu, sentiment_neg,
    key_phrases, language, language_confidence, original_text, processing_status
) VALUES
    ('TX001', 'INT001', 'positive', 0.85, 0.10, 0.05, 'great product; excellent service; satisfied customer', 'en', 0.99, 'The customer was very happy with the product and mentioned excellent service quality.', 'completed'),
    ('TX002', 'INT002', 'negative', 0.15, 0.20, 0.65, 'poor quality; expensive price; disappointed', 'en', 0.98, 'Customer complained about poor quality and high prices, expressing disappointment.', 'completed'),
    ('TX003', 'INT003', 'neutral', 0.40, 0.50, 0.10, 'standard product; regular purchase; routine transaction', 'en', 0.97, 'Regular customer making a routine purchase of standard products.', 'completed'),
    ('TX004', 'INT004', 'positive', 0.75, 0.20, 0.05, 'magandang produkto; masayang customer', 'tl', 0.95, 'Ang customer ay masaya sa produkto at serbisyo.', 'completed'),
    ('TX005', 'INT005', 'neutral', 0.35, 0.55, 0.10, 'normal nga transaction; regular customer', 'ceb', 0.90, 'Normal nga pagpalit, regular customer.', 'completed');
*/

-- Create stored procedure for data quality reporting
CREATE OR ALTER PROCEDURE silver.sp_conversation_ai_quality_report
AS
BEGIN
    SET NOCOUNT ON;

    -- Summary statistics
    SELECT
        'Summary Statistics' as ReportSection,
        COUNT(*) as TotalRecords,
        COUNT(CASE WHEN processing_status = 'completed' THEN 1 END) as CompletedRecords,
        COUNT(CASE WHEN processing_status = 'failed' THEN 1 END) as FailedRecords,
        COUNT(CASE WHEN sentiment IS NOT NULL THEN 1 END) as RecordsWithSentiment,
        COUNT(CASE WHEN key_phrases IS NOT NULL THEN 1 END) as RecordsWithKeyPhrases,
        COUNT(DISTINCT language) as UniqueLanguages,
        AVG(CAST(text_length AS FLOAT)) as AvgTextLength,
        MIN(processing_timestamp) as EarliestRecord,
        MAX(processing_timestamp) as LatestRecord;

    -- Language distribution
    SELECT
        'Language Distribution' as ReportSection,
        language,
        COUNT(*) as RecordCount,
        AVG(language_confidence) as AvgConfidence,
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM silver.conversation_ai) as Percentage
    FROM silver.conversation_ai
    WHERE language IS NOT NULL
    GROUP BY language
    ORDER BY RecordCount DESC;

    -- Sentiment distribution
    SELECT
        'Sentiment Distribution' as ReportSection,
        sentiment,
        COUNT(*) as RecordCount,
        AVG(sentiment_pos) as AvgPositive,
        AVG(sentiment_neu) as AvgNeutral,
        AVG(sentiment_neg) as AvgNegative,
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM silver.conversation_ai WHERE sentiment IS NOT NULL) as Percentage
    FROM silver.conversation_ai
    WHERE sentiment IS NOT NULL
    GROUP BY sentiment
    ORDER BY RecordCount DESC;

    -- Processing errors (if any)
    IF EXISTS (SELECT 1 FROM silver.conversation_ai WHERE processing_status = 'failed')
    BEGIN
        SELECT
            'Processing Errors' as ReportSection,
            canonical_tx_id,
            error_message,
            processing_timestamp
        FROM silver.conversation_ai
        WHERE processing_status = 'failed'
        ORDER BY processing_timestamp DESC;
    END
END;

-- Grant permissions (adjust as needed for your environment)
-- GRANT SELECT, INSERT, UPDATE ON silver.conversation_ai TO [YourDataflowServicePrincipal];
-- GRANT EXECUTE ON silver.sp_conversation_ai_quality_report TO [YourReportingUsers];

PRINT '✅ Silver layer conversation_ai table created successfully';
PRINT 'Next steps:';
PRINT '1. Configure Dataflow Gen2 to populate this table';
PRINT '2. Test with sample data';
PRINT '3. Run: EXEC silver.sp_conversation_ai_quality_report';
PRINT '4. Create Gold layer views';

SELECT
    'Table Created' as Status,
    OBJECT_NAME(object_id) as TableName,
    schema_name(schema_id) as SchemaName
FROM sys.objects
WHERE name = 'conversation_ai' AND schema_id = SCHEMA_ID('silver');