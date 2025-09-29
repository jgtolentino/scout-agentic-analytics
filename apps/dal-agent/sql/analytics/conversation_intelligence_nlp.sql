-- =====================================================
-- CONVERSATION INTELLIGENCE NLP PIPELINE
-- Processes 131,606 transcripts for business insights and operational intelligence
-- Focus: Language patterns, intent classification, customer satisfaction (NO credit features)
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create comprehensive conversation analysis view
CREATE OR ALTER VIEW dbo.v_conversation_intelligence AS
WITH cleaned_conversations AS (
    SELECT
        si.canonical_tx_id,
        si.FacialID,
        si.Age,
        si.Gender,
        si.StoreID,
        si.TransactionDate,
        si.CreatedDate,
        si.EmotionalState,
        si.TranscriptionText,
        si.BasketSize,
        si.WasSubstitution,

        -- Clean and normalize transcript
        LTRIM(RTRIM(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(si.TranscriptionText, '...', ''),
                            'music', ''),
                        '  ', ' '),
                    CHAR(13), ' '),
                CHAR(10), ' ')
        )) AS cleaned_text,

        LEN(COALESCE(si.TranscriptionText, '')) AS original_text_length

    FROM dbo.SalesInteractions si
    WHERE si.canonical_tx_id IS NOT NULL
),
language_analysis AS (
    SELECT
        *,
        -- =====================================================
        -- LANGUAGE DETECTION (Filipino/English/Mixed/Silent)
        -- =====================================================
        CASE
            -- Filipino language indicators
            WHEN cleaned_text LIKE '%salamat%' OR cleaned_text LIKE '%pabili%'
                 OR cleaned_text LIKE '%magkano%' OR cleaned_text LIKE '%ate%'
                 OR cleaned_text LIKE '%kuya%' OR cleaned_text LIKE '%po%'
                 OR cleaned_text LIKE '%opo%' OR cleaned_text LIKE '%sige%'
                 OR cleaned_text LIKE '%wala%' OR cleaned_text LIKE '%meron%'
            THEN 'Filipino'

            -- English language indicators
            WHEN cleaned_text LIKE '%thank you%' OR cleaned_text LIKE '%please%'
                 OR cleaned_text LIKE '%how much%' OR cleaned_text LIKE '%excuse me%'
                 OR cleaned_text LIKE '%sorry%' OR cleaned_text LIKE '%good%'
                 OR cleaned_text LIKE '%bye%' OR cleaned_text LIKE '%see you%'
            THEN 'English'

            -- Mixed language (code-switching)
            WHEN (cleaned_text LIKE '%salamat%' AND cleaned_text LIKE '%thank%')
                 OR (cleaned_text LIKE '%po%' AND cleaned_text LIKE '%please%')
                 OR (cleaned_text LIKE '%ate%' AND cleaned_text LIKE '%miss%')
            THEN 'Mixed'

            -- Silent transactions
            WHEN cleaned_text IS NULL OR LEN(cleaned_text) <= 1
            THEN 'Silent'

            -- Very short unclear text
            WHEN LEN(cleaned_text) < 5
            THEN 'Unclear'

            ELSE 'Unknown'
        END AS language_detected,

        -- =====================================================
        -- CONVERSATION INTENT CLASSIFICATION
        -- =====================================================
        CASE
            -- Purchase intent
            WHEN cleaned_text LIKE '%pabili%' OR cleaned_text LIKE '%bili%'
                 OR cleaned_text LIKE '%bibili%' OR cleaned_text LIKE '%buy%'
                 OR cleaned_text LIKE '%gusto%' OR cleaned_text LIKE '%want%'
            THEN 'Purchase_Intent'

            -- Price inquiry
            WHEN cleaned_text LIKE '%magkano%' OR cleaned_text LIKE '%how much%'
                 OR cleaned_text LIKE '%presyo%' OR cleaned_text LIKE '%price%'
                 OR cleaned_text LIKE '%bayad%'
            THEN 'Price_Inquiry'

            -- Product availability
            WHEN cleaned_text LIKE '%may%' AND cleaned_text LIKE '%ba%'
                 OR cleaned_text LIKE '%meron%' OR cleaned_text LIKE '%available%'
                 OR cleaned_text LIKE '%stock%'
            THEN 'Product_Availability'

            -- Gratitude/transaction completion
            WHEN cleaned_text LIKE '%salamat%' OR cleaned_text LIKE '%thank%'
                 OR cleaned_text LIKE '%maraming salamat%'
            THEN 'Gratitude'

            -- Complaint/issue
            WHEN cleaned_text LIKE '%wala%' OR cleaned_text LIKE '%ubos%'
                 OR cleaned_text LIKE '%walang%' OR cleaned_text LIKE '%out of%'
                 OR cleaned_text LIKE '%problem%'
            THEN 'Complaint_Issue'

            -- Greeting/social
            WHEN cleaned_text LIKE '%good morning%' OR cleaned_text LIKE '%magandang%'
                 OR cleaned_text LIKE '%hello%' OR cleaned_text LIKE '%hi%'
                 OR cleaned_text LIKE '%kumusta%'
            THEN 'Greeting_Social'

            -- Digital services
            WHEN cleaned_text LIKE '%load%' OR cleaned_text LIKE '%gcash%'
                 OR cleaned_text LIKE '%paymaya%' OR cleaned_text LIKE '%smart%'
                 OR cleaned_text LIKE '%globe%'
            THEN 'Digital_Service'

            -- Silent transactions
            WHEN cleaned_text IS NULL OR LEN(cleaned_text) <= 1
            THEN 'Silent'

            ELSE 'General_Conversation'
        END AS conversation_intent,

        -- =====================================================
        -- FILIPINO CULTURAL MARKERS
        -- =====================================================

        -- Politeness scoring (Filipino respect culture)
        (CASE WHEN cleaned_text LIKE '%po%' THEN 0.4 ELSE 0 END +
         CASE WHEN cleaned_text LIKE '%opo%' THEN 0.4 ELSE 0 END +
         CASE WHEN cleaned_text LIKE '%ate%' OR cleaned_text LIKE '%kuya%' THEN 0.3 ELSE 0 END +
         CASE WHEN cleaned_text LIKE '%salamat%' THEN 0.3 ELSE 0 END +
         CASE WHEN cleaned_text LIKE '%pasensya%' OR cleaned_text LIKE '%sorry%' THEN 0.2 ELSE 0 END +
         CASE WHEN cleaned_text LIKE '%sige%' THEN 0.1 ELSE 0 END) AS politeness_score,

        -- Urgency detection
        CASE
            WHEN cleaned_text LIKE '%dali%' OR cleaned_text LIKE '%quick%'
                 OR cleaned_text LIKE '%hurry%' OR cleaned_text LIKE '%bilisan%'
            THEN 'Urgent'
            WHEN cleaned_text LIKE '%wait%' OR cleaned_text LIKE '%sandali%'
                 OR cleaned_text LIKE '%tagal%' OR cleaned_text LIKE '%slowly%'
            THEN 'Patient'
            WHEN cleaned_text LIKE '%okay%' OR cleaned_text LIKE '%sige%'
                 OR cleaned_text LIKE '%fine%'
            THEN 'Calm'
            ELSE 'Normal'
        END AS urgency_level,

        -- Satisfaction indicators
        CASE
            WHEN cleaned_text LIKE '%salamat%' AND LEN(cleaned_text) > 20
            THEN 'High_Satisfaction'
            WHEN cleaned_text LIKE '%thank you very much%'
                 OR cleaned_text LIKE '%maraming salamat%'
            THEN 'Very_High_Satisfaction'
            WHEN cleaned_text LIKE '%okay%' OR cleaned_text LIKE '%sige%'
            THEN 'Neutral_Satisfaction'
            WHEN cleaned_text LIKE '%hindi%' OR cleaned_text LIKE '%ayaw%'
                 OR cleaned_text LIKE '%no%' OR cleaned_text LIKE '%dont%'
            THEN 'Dissatisfaction'
            WHEN cleaned_text IS NULL OR LEN(cleaned_text) <= 1
            THEN 'Silent_Transaction'
            ELSE 'Unknown_Satisfaction'
        END AS satisfaction_indicator,

        -- Social relationship indicators
        CASE
            WHEN cleaned_text LIKE '%ate%' OR cleaned_text LIKE '%kuya%'
            THEN 'Respectful_Address'
            WHEN cleaned_text LIKE '%tita%' OR cleaned_text LIKE '%tito%'
                 OR cleaned_text LIKE '%lola%' OR cleaned_text LIKE '%lolo%'
            THEN 'Family_Address'
            WHEN cleaned_text LIKE '%boss%' OR cleaned_text LIKE '%sir%'
                 OR cleaned_text LIKE '%maam%'
            THEN 'Formal_Address'
            WHEN cleaned_text LIKE '%dude%' OR cleaned_text LIKE '%bro%'
                 OR cleaned_text LIKE '%pare%'
            THEN 'Casual_Address'
            ELSE 'No_Special_Address'
        END AS social_relationship

    FROM cleaned_conversations
),
product_entity_extraction AS (
    SELECT
        *,
        -- =====================================================
        -- PRODUCT ENTITY EXTRACTION FROM CONVERSATIONS
        -- =====================================================

        -- Cigarette brands mentioned
        CASE
            WHEN cleaned_text LIKE '%marlboro%' THEN 'Marlboro'
            WHEN cleaned_text LIKE '%winston%' THEN 'Winston'
            WHEN cleaned_text LIKE '%philip morris%' THEN 'Philip Morris'
            WHEN cleaned_text LIKE '%lucky strike%' THEN 'Lucky Strike'
            ELSE NULL
        END AS cigarette_brand_mentioned,

        -- Beverages mentioned
        CASE
            WHEN cleaned_text LIKE '%coffee%' OR cleaned_text LIKE '%kape%' THEN 'Coffee'
            WHEN cleaned_text LIKE '%coke%' OR cleaned_text LIKE '%coca%' THEN 'Coca Cola'
            WHEN cleaned_text LIKE '%pepsi%' THEN 'Pepsi'
            WHEN cleaned_text LIKE '%sprite%' THEN 'Sprite'
            WHEN cleaned_text LIKE '%beer%' THEN 'Beer'
            ELSE NULL
        END AS beverage_mentioned,

        -- Digital products mentioned
        CASE
            WHEN cleaned_text LIKE '%load%' THEN 'E-Load'
            WHEN cleaned_text LIKE '%gcash%' THEN 'GCash'
            WHEN cleaned_text LIKE '%paymaya%' THEN 'PayMaya'
            WHEN cleaned_text LIKE '%smart%' THEN 'Smart Load'
            WHEN cleaned_text LIKE '%globe%' THEN 'Globe Load'
            ELSE NULL
        END AS digital_product_mentioned,

        -- Quantity/measurement mentions
        CASE
            WHEN cleaned_text LIKE '%1.5%kg%' OR cleaned_text LIKE '%1,5%kg%' THEN 1.5
            WHEN cleaned_text LIKE '%1%kg%' THEN 1.0
            WHEN cleaned_text LIKE '%500g%' OR cleaned_text LIKE '%half%kilo%' THEN 0.5
            WHEN cleaned_text LIKE '%250g%' OR cleaned_text LIKE '%quarter%' THEN 0.25
            ELSE NULL
        END AS quantity_kg_mentioned,

        -- Sachet/tingi indicators
        CASE
            WHEN cleaned_text LIKE '%sachet%' OR cleaned_text LIKE '%sashet%' THEN 'Sachet'
            WHEN cleaned_text LIKE '%piece%' OR cleaned_text LIKE '%piraso%' THEN 'Piece'
            WHEN cleaned_text LIKE '%pack%' THEN 'Pack'
            WHEN cleaned_text LIKE '%bottle%' OR cleaned_text LIKE '%bote%' THEN 'Bottle'
            ELSE NULL
        END AS packaging_mentioned

    FROM language_analysis
),
conversation_quality AS (
    SELECT
        *,
        -- =====================================================
        -- CONVERSATION QUALITY METRICS
        -- =====================================================

        -- Conversation completeness
        CASE
            WHEN original_text_length = 0 THEN 'Silent'
            WHEN original_text_length < 5 THEN 'Very_Short'
            WHEN original_text_length < 20 THEN 'Short'
            WHEN original_text_length < 50 THEN 'Medium'
            WHEN original_text_length < 100 THEN 'Long'
            ELSE 'Very_Long'
        END AS conversation_length_category,

        -- Text clarity (noise vs meaningful content)
        CASE
            WHEN cleaned_text LIKE '%music%' OR cleaned_text LIKE '%...%'
                 OR cleaned_text LIKE '%aaa%' OR cleaned_text LIKE '%ooo%'
            THEN 'Noisy'
            WHEN LEN(cleaned_text) > 0 AND conversation_intent != 'General_Conversation'
            THEN 'Clear'
            WHEN LEN(cleaned_text) > 10
            THEN 'Meaningful'
            ELSE 'Unclear'
        END AS text_clarity,

        -- Interaction complexity
        CASE
            WHEN conversation_intent IN ('Purchase_Intent', 'Price_Inquiry', 'Product_Availability')
                 AND (cigarette_brand_mentioned IS NOT NULL OR beverage_mentioned IS NOT NULL)
            THEN 'Complex_Transaction'
            WHEN conversation_intent = 'Gratitude' AND politeness_score > 0.5
            THEN 'Polite_Simple'
            WHEN conversation_intent = 'Silent'
            THEN 'Non_Verbal'
            ELSE 'Standard_Interaction'
        END AS interaction_complexity

    FROM product_entity_extraction
)
SELECT
    -- Core identifiers
    canonical_tx_id,
    FacialID,
    Age,
    Gender,
    StoreID,
    TransactionDate,
    CreatedDate,
    EmotionalState,

    -- Original and processed text
    TranscriptionText,
    cleaned_text,
    original_text_length,

    -- Language and intent analysis
    language_detected,
    conversation_intent,

    -- Cultural markers
    politeness_score,
    urgency_level,
    satisfaction_indicator,
    social_relationship,

    -- Product entities
    cigarette_brand_mentioned,
    beverage_mentioned,
    digital_product_mentioned,
    quantity_kg_mentioned,
    packaging_mentioned,

    -- Quality metrics
    conversation_length_category,
    text_clarity,
    interaction_complexity,

    -- Derived behavioral indicators
    BasketSize,
    WasSubstitution,

    -- Business intelligence flags
    CASE WHEN language_detected = 'Filipino' THEN 1 ELSE 0 END AS is_filipino_conversation,
    CASE WHEN conversation_intent IN ('Purchase_Intent', 'Price_Inquiry') THEN 1 ELSE 0 END AS is_business_intent,
    CASE WHEN politeness_score > 0.3 THEN 1 ELSE 0 END AS is_polite_customer,
    CASE WHEN satisfaction_indicator LIKE '%High%' THEN 1 ELSE 0 END AS is_satisfied_customer,
    CASE WHEN urgency_level = 'Urgent' THEN 1 ELSE 0 END AS is_urgent_request

FROM conversation_quality;
GO

-- Create conversation summary statistics view
CREATE OR ALTER VIEW dbo.v_conversation_statistics AS
SELECT
    -- Overall conversation metrics
    COUNT(*) AS total_conversations,
    COUNT(CASE WHEN language_detected != 'Silent' THEN 1 END) AS conversations_with_speech,
    COUNT(CASE WHEN language_detected = 'Silent' THEN 1 END) AS silent_transactions,

    -- Language distribution
    COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) AS filipino_conversations,
    COUNT(CASE WHEN language_detected = 'English' THEN 1 END) AS english_conversations,
    COUNT(CASE WHEN language_detected = 'Mixed' THEN 1 END) AS mixed_conversations,

    -- Intent distribution
    COUNT(CASE WHEN conversation_intent = 'Purchase_Intent' THEN 1 END) AS purchase_intents,
    COUNT(CASE WHEN conversation_intent = 'Price_Inquiry' THEN 1 END) AS price_inquiries,
    COUNT(CASE WHEN conversation_intent = 'Product_Availability' THEN 1 END) AS availability_checks,
    COUNT(CASE WHEN conversation_intent = 'Gratitude' THEN 1 END) AS gratitude_expressions,
    COUNT(CASE WHEN conversation_intent = 'Complaint_Issue' THEN 1 END) AS complaints,

    -- Quality metrics
    AVG(politeness_score) AS avg_politeness_score,
    COUNT(CASE WHEN is_satisfied_customer = 1 THEN 1 END) AS satisfied_customers,
    COUNT(CASE WHEN is_urgent_request = 1 THEN 1 END) AS urgent_requests,

    -- Product mentions
    COUNT(CASE WHEN cigarette_brand_mentioned IS NOT NULL THEN 1 END) AS cigarette_mentions,
    COUNT(CASE WHEN beverage_mentioned IS NOT NULL THEN 1 END) AS beverage_mentions,
    COUNT(CASE WHEN digital_product_mentioned IS NOT NULL THEN 1 END) AS digital_service_mentions

FROM dbo.v_conversation_intelligence;
GO

-- Create store-level conversation analysis
CREATE OR ALTER VIEW dbo.v_store_conversation_analysis AS
SELECT
    StoreID,
    COUNT(*) AS total_conversations,

    -- Language preferences by store
    COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN language_detected != 'Silent' THEN 1 END), 0) AS filipino_percentage,
    COUNT(CASE WHEN language_detected = 'English' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN language_detected != 'Silent' THEN 1 END), 0) AS english_percentage,

    -- Customer service metrics
    AVG(politeness_score) AS avg_customer_politeness,
    COUNT(CASE WHEN satisfaction_indicator LIKE '%High%' THEN 1 END) * 100.0 /
        NULLIF(COUNT(*), 0) AS satisfaction_rate,

    -- Operational indicators
    COUNT(CASE WHEN urgency_level = 'Urgent' THEN 1 END) AS urgent_requests,
    COUNT(CASE WHEN conversation_intent = 'Complaint_Issue' THEN 1 END) AS complaints,
    COUNT(CASE WHEN conversation_intent = 'Product_Availability' THEN 1 END) AS stock_inquiries,

    -- Product demand signals
    COUNT(CASE WHEN cigarette_brand_mentioned IS NOT NULL THEN 1 END) AS cigarette_demand,
    COUNT(CASE WHEN digital_product_mentioned IS NOT NULL THEN 1 END) AS digital_service_demand

FROM dbo.v_conversation_intelligence
WHERE StoreID IS NOT NULL
GROUP BY StoreID;
GO

-- Create materialized conversation analysis for performance
CREATE OR ALTER PROCEDURE dbo.sp_refresh_conversation_intelligence
AS
BEGIN
    -- Drop and recreate materialized view for performance
    IF OBJECT_ID('dbo.conversation_intelligence_results', 'U') IS NOT NULL
        DROP TABLE dbo.conversation_intelligence_results;

    SELECT *
    INTO dbo.conversation_intelligence_results
    FROM dbo.v_conversation_intelligence;

    -- Create indexes for performance
    CREATE CLUSTERED INDEX CX_Conversation_TxID
    ON dbo.conversation_intelligence_results (canonical_tx_id);

    CREATE NONCLUSTERED INDEX IX_Conversation_Language_Intent
    ON dbo.conversation_intelligence_results (language_detected, conversation_intent)
    INCLUDE (StoreID, satisfaction_indicator, politeness_score);

    CREATE NONCLUSTERED INDEX IX_Conversation_Store_Analysis
    ON dbo.conversation_intelligence_results (StoreID, TransactionDate)
    INCLUDE (language_detected, conversation_intent, satisfaction_indicator);

    PRINT 'Conversation intelligence analysis refreshed successfully.';
END;
GO

-- Sample analysis queries (commented for reference)
/*
-- Execute conversation intelligence analysis
EXEC dbo.sp_refresh_conversation_intelligence;

-- View overall conversation statistics
SELECT * FROM dbo.v_conversation_statistics;

-- Store-level conversation analysis
SELECT * FROM dbo.v_store_conversation_analysis
ORDER BY total_conversations DESC;

-- Language preference analysis
SELECT language_detected, conversation_intent, COUNT(*) as frequency,
       AVG(politeness_score) as avg_politeness
FROM dbo.conversation_intelligence_results
WHERE language_detected != 'Silent'
GROUP BY language_detected, conversation_intent
ORDER BY frequency DESC;

-- Product demand analysis from conversations
SELECT StoreID, cigarette_brand_mentioned, beverage_mentioned, digital_product_mentioned,
       COUNT(*) as mention_frequency
FROM dbo.conversation_intelligence_results
WHERE cigarette_brand_mentioned IS NOT NULL
   OR beverage_mentioned IS NOT NULL
   OR digital_product_mentioned IS NOT NULL
GROUP BY StoreID, cigarette_brand_mentioned, beverage_mentioned, digital_product_mentioned
ORDER BY mention_frequency DESC;
*/