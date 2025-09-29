-- Enhanced Master Catalog for Scout v7 Full Dataset
-- Handles 1,100 brands, 6,600 SKUs, 70 categories with lexical variations
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: ENHANCED BRAND CATALOG
-- =====================================================

-- Enhanced brand catalog with lexical variation support
CREATE TABLE IF NOT EXISTS dbo.enhanced_brand_catalog (
    brand_id NVARCHAR(20) PRIMARY KEY,
    brand_name NVARCHAR(200) NOT NULL,
    brand_name_normalized NVARCHAR(200), -- For fuzzy matching
    nielsen_category NVARCHAR(50),
    nielsen_prefix NVARCHAR(10),
    tbwa_client_id NVARCHAR(20),
    parent_company NVARCHAR(200),
    brand_tier NVARCHAR(20), -- Premium, Mid-tier, Economy
    origin_country NVARCHAR(50),
    is_active BIT DEFAULT 1,
    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),
    updated_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    INDEX IX_brand_name (brand_name),
    INDEX IX_brand_normalized (brand_name_normalized),
    INDEX IX_nielsen_category (nielsen_category),
    INDEX IX_tbwa_client (tbwa_client_id)
);

-- Lexical variations table for Filipino market brand recognition
CREATE TABLE IF NOT EXISTS dbo.brand_lexical_variations (
    variation_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    brand_id NVARCHAR(20) NOT NULL,
    variation_type NVARCHAR(20) NOT NULL, -- formal, informal, code_switched, abbreviated
    variation_text NVARCHAR(200) NOT NULL,
    confidence_weight DECIMAL(3,2) DEFAULT 1.0, -- Matching confidence multiplier
    language_code NVARCHAR(10) DEFAULT 'fil-PH', -- Filipino-Philippines
    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (brand_id) REFERENCES dbo.enhanced_brand_catalog(brand_id),
    INDEX IX_brand_variation (brand_id, variation_type),
    INDEX IX_variation_text (variation_text),
    INDEX IX_variation_type (variation_type)
);

-- Enhanced SKU catalog with Nielsen classification
CREATE TABLE IF NOT EXISTS dbo.enhanced_sku_catalog (
    sku_id NVARCHAR(20) PRIMARY KEY,
    brand_id NVARCHAR(20) NOT NULL,
    sku_name NVARCHAR(200) NOT NULL,
    sku_variant NVARCHAR(100),
    package_size NVARCHAR(50),
    package_type NVARCHAR(30), -- Sachet, Bottle, Box, etc.
    unit_price DECIMAL(10,2),
    cost_price DECIMAL(10,2),
    weight_grams DECIMAL(10,2),
    volume_ml DECIMAL(10,2),
    barcode NVARCHAR(50),
    nielsen_category NVARCHAR(50),
    is_active BIT DEFAULT 1,
    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),
    updated_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (brand_id) REFERENCES dbo.enhanced_brand_catalog(brand_id),
    INDEX IX_brand_sku (brand_id),
    INDEX IX_sku_name (sku_name),
    INDEX IX_nielsen_category (nielsen_category),
    INDEX IX_barcode (barcode)
);

-- Nielsen category master data
CREATE TABLE IF NOT EXISTS dbo.nielsen_categories (
    nielsen_category NVARCHAR(50) PRIMARY KEY,
    category_name NVARCHAR(200) NOT NULL,
    category_prefix NVARCHAR(10),
    parent_category NVARCHAR(50),
    hierarchy_level TINYINT DEFAULT 1,
    total_brands INT DEFAULT 0,
    is_active BIT DEFAULT 1,
    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    INDEX IX_category_prefix (category_prefix),
    INDEX IX_parent_category (parent_category),
    INDEX IX_hierarchy (hierarchy_level)
);

-- =====================================================
-- SECTION 2: CONVERSATION INTELLIGENCE ENHANCED
-- =====================================================

-- Enhanced conversation segments with Filipino pattern recognition
CREATE TABLE IF NOT EXISTS dbo.enhanced_conversation_segments (
    segment_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id NVARCHAR(64) NOT NULL,
    session_id NVARCHAR(64),
    speaker_type NVARCHAR(20) NOT NULL, -- 'customer', 'store_owner', 'unknown'
    segment_text NVARCHAR(MAX),
    segment_text_cleaned NVARCHAR(MAX), -- Cleaned for analysis
    start_timestamp DECIMAL(10,3),
    end_timestamp DECIMAL(10,3),
    duration_seconds DECIMAL(10,3),
    confidence_score DECIMAL(5,3), -- Speaker identification confidence
    language_detected NVARCHAR(10) DEFAULT 'fil-PH', -- Filipino-Philippines

    -- Enhanced pattern recognition
    pattern_type NVARCHAR(30), -- customer_purchase, owner_response, substitution_offer
    intent_classification NVARCHAR(50),
    intent_confidence DECIMAL(5,3),

    -- Brand/product mentions with lexical matching
    brands_mentioned NVARCHAR(MAX), -- JSON array of mentioned brands with confidence
    brands_matched NVARCHAR(MAX), -- JSON array of successfully matched brand IDs
    products_mentioned NVARCHAR(MAX), -- JSON array of mentioned products
    variation_types_used NVARCHAR(MAX), -- JSON array tracking which lexical types were used

    -- Filipino conversation patterns
    code_switching_detected BIT DEFAULT 0,
    filipino_patterns_found NVARCHAR(MAX), -- JSON array of detected patterns
    conversation_politeness_level TINYINT, -- 1-5 scale based on po/opo usage

    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    INDEX IX_transaction_id (transaction_id),
    INDEX IX_speaker_type (speaker_type),
    INDEX IX_intent (intent_classification),
    INDEX IX_pattern_type (pattern_type),
    INDEX IX_timestamps (start_timestamp, end_timestamp)
);

-- Enhanced purchase funnel with Filipino conversation context
CREATE TABLE IF NOT EXISTS dbo.enhanced_purchase_funnel (
    funnel_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id NVARCHAR(64) NOT NULL,
    session_id NVARCHAR(64),

    -- Enhanced 5-stage funnel with conversation intelligence
    stage_1_store_visit BIT DEFAULT 0,
    stage_1_timestamp DATETIME2,
    stage_1_greeting_type NVARCHAR(30), -- formal, informal, none

    stage_2_browse BIT DEFAULT 0,
    stage_2_timestamp DATETIME2,
    stage_2_browse_patterns NVARCHAR(MAX), -- JSON array of browsing behaviors

    stage_3_brand_request BIT DEFAULT 0,
    stage_3_timestamp DATETIME2,
    stage_3_brands_requested NVARCHAR(MAX), -- JSON array with lexical variations
    stage_3_request_style NVARCHAR(20), -- direct, polite, hesitant

    stage_4_suggestion_accepted BIT DEFAULT 0,
    stage_4_timestamp DATETIME2,
    stage_4_suggestions_made NVARCHAR(MAX), -- JSON array
    stage_4_substitution_reason NVARCHAR(100), -- out_of_stock, price_conscious, upgrade

    stage_5_purchase_completed BIT DEFAULT 0,
    stage_5_timestamp DATETIME2,
    stage_5_final_brands NVARCHAR(MAX), -- JSON array
    stage_5_payment_interaction NVARCHAR(MAX), -- JSON conversation during payment

    -- Enhanced funnel metrics
    total_duration_seconds INT,
    conversation_turns_total INT,
    code_switching_events INT,
    politeness_consistency_score DECIMAL(3,2), -- 0-1 scale
    stages_completed TINYINT,
    overall_satisfaction_inferred NVARCHAR(20), -- high, medium, low

    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    INDEX IX_transaction_id (transaction_id),
    INDEX IX_stages_completed (stages_completed),
    INDEX IX_substitution_reason (stage_4_substitution_reason)
);

-- =====================================================
-- SECTION 3: FILIPINO CONVERSATION PATTERNS
-- =====================================================

-- Filipino conversation pattern library
CREATE TABLE IF NOT EXISTS dbo.filipino_conversation_patterns (
    pattern_id INT IDENTITY(1,1) PRIMARY KEY,
    pattern_category NVARCHAR(30) NOT NULL, -- customer_purchase, owner_response, greeting, etc.
    pattern_text NVARCHAR(500) NOT NULL,
    pattern_regex NVARCHAR(500), -- Regex pattern for matching
    language_mix NVARCHAR(20), -- filipino, english, code_switched
    politeness_level TINYINT, -- 1-5 scale
    frequency_weight DECIMAL(5,3) DEFAULT 1.0,
    cultural_context NVARCHAR(200),
    example_usage NVARCHAR(500),
    is_active BIT DEFAULT 1,

    INDEX IX_pattern_category (pattern_category),
    INDEX IX_language_mix (language_mix),
    INDEX IX_politeness (politeness_level)
);

-- =====================================================
-- SECTION 4: ENHANCED ANALYTICS VIEWS
-- =====================================================

-- Master analytics view combining all enhanced data
CREATE OR ALTER VIEW dbo.v_enhanced_master_analytics AS
SELECT
    t.enhanced_transaction_id,
    t.canonical_tx_id,
    t.transaction_datetime,
    t.transaction_date,
    t.transaction_value,
    t.item_count,

    -- Enhanced brand and product information
    bc.brand_id,
    bc.brand_name,
    bc.nielsen_category,
    bc.nielsen_prefix,
    bc.tbwa_client_id,
    bc.brand_tier,
    nc.category_name AS nielsen_category_name,
    nc.parent_category AS nielsen_parent,

    sc.sku_id,
    sc.sku_name,
    sc.package_size,
    sc.package_type,

    -- Customer demographics
    t.customer_age_estimated,
    t.customer_gender,

    -- Enhanced conversation intelligence
    t.conversation_duration_seconds,
    t.speaker_turns_customer,
    t.speaker_turns_owner,
    t.brands_discussed,
    t.suggestion_acceptance_rate,

    -- Funnel completion with Filipino context
    t.funnel_stage_reached,
    t.conversion_completed,
    pf.greeting_type AS funnel_greeting_type,
    pf.request_style AS funnel_request_style,
    pf.substitution_reason AS funnel_substitution_reason,
    pf.code_switching_events,
    pf.politeness_consistency_score,

    -- Conversation segments aggregation
    cs_agg.total_segments,
    cs_agg.filipino_patterns_count,
    cs_agg.code_switching_detected,
    cs_agg.average_confidence,
    cs_agg.brands_mentioned_count,
    cs_agg.brands_matched_count

FROM dbo.enhanced_transactions t
    LEFT JOIN dbo.enhanced_brand_catalog bc ON t.primary_brand_id = bc.brand_id
    LEFT JOIN dbo.enhanced_sku_catalog sc ON t.primary_sku_id = sc.sku_id
    LEFT JOIN dbo.nielsen_categories nc ON bc.nielsen_category = nc.nielsen_category
    LEFT JOIN dbo.enhanced_purchase_funnel pf ON t.canonical_tx_id = pf.transaction_id
    LEFT JOIN (
        SELECT
            transaction_id,
            COUNT(*) AS total_segments,
            SUM(CASE WHEN filipino_patterns_found IS NOT NULL THEN 1 ELSE 0 END) AS filipino_patterns_count,
            MAX(CASE WHEN code_switching_detected = 1 THEN 1 ELSE 0 END) AS code_switching_detected,
            AVG(confidence_score) AS average_confidence,
            SUM(JSON_ARRAY_LENGTH(ISNULL(brands_mentioned, '[]'))) AS brands_mentioned_count,
            SUM(JSON_ARRAY_LENGTH(ISNULL(brands_matched, '[]'))) AS brands_matched_count
        FROM dbo.enhanced_conversation_segments
        GROUP BY transaction_id
    ) cs_agg ON t.canonical_tx_id = cs_agg.transaction_id
WHERE t.conversion_completed = 1;

-- =====================================================
-- SECTION 5: DATA POPULATION TEMPLATES
-- =====================================================

-- Template for populating Nielsen categories
INSERT INTO dbo.nielsen_categories (nielsen_category, category_name, category_prefix, total_brands)
VALUES
    ('0101_CARBONATED_SOFT_DRINKS', 'Carbonated Soft Drinks', 'CSD', 45),
    ('0102_FRUIT_JUICES', 'Fruit Juices', 'FJC', 35),
    ('0103_BOTTLED_WATER', 'Bottled Water', 'BWR', 25),
    ('0301_INSTANT_NOODLES', 'Instant Noodles', 'NUD', 30),
    ('0302_INSTANT_COFFEE', 'Instant Coffee', 'ICF', 25),
    ('0401_POTATO_CHIPS', 'Potato Chips', 'PCH', 25),
    ('0404_COOKIES', 'Cookies', 'COK', 35),
    ('0901_BAR_SOAP', 'Bar Soap', 'BSP', 20),
    ('1201_PREMIUM_CIGARETTES', 'Premium Cigarettes', 'PCG', 15);

-- Template for populating Filipino conversation patterns
INSERT INTO dbo.filipino_conversation_patterns (pattern_category, pattern_text, language_mix, politeness_level, cultural_context)
VALUES
    ('customer_purchase', 'pabili ng [brand]', 'filipino', 3, 'Standard purchase request in Filipino'),
    ('customer_purchase', 'may [brand] ka ba', 'filipino', 3, 'Availability inquiry in Filipino'),
    ('customer_purchase', 'magkano [brand]', 'filipino', 2, 'Price inquiry in Filipino'),
    ('customer_purchase', 'isa [brand]', 'filipino', 2, 'Quantity specification in Filipino'),
    ('owner_response', 'meron po', 'filipino', 4, 'Polite availability confirmation'),
    ('owner_response', '[amount] po', 'filipino', 4, 'Polite price response'),
    ('owner_response', 'available', 'english', 3, 'English availability confirmation'),
    ('owner_response', 'ubos na po', 'filipino', 4, 'Polite out-of-stock response');

-- =====================================================
-- SECTION 6: LEXICAL VARIATION FUNCTIONS
-- =====================================================

-- Function to match brand variations (stored procedure template)
/*
CREATE OR ALTER PROCEDURE dbo.sp_match_brand_variation
    @input_text NVARCHAR(200),
    @confidence_threshold DECIMAL(3,2) = 0.7
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 5
        blv.brand_id,
        bc.brand_name,
        blv.variation_text,
        blv.variation_type,
        blv.confidence_weight,
        CASE
            WHEN @input_text = blv.variation_text THEN 1.0
            WHEN @input_text LIKE '%' + blv.variation_text + '%' THEN 0.8
            ELSE 0.6
        END AS match_confidence
    FROM dbo.brand_lexical_variations blv
        INNER JOIN dbo.enhanced_brand_catalog bc ON blv.brand_id = bc.brand_id
    WHERE blv.variation_text LIKE '%' + @input_text + '%'
        OR @input_text LIKE '%' + blv.variation_text + '%'
    ORDER BY match_confidence DESC, blv.confidence_weight DESC;
END;
*/

PRINT 'Enhanced master catalog schema created successfully for 1,100+ brands';
PRINT 'Ready for Filipino conversation intelligence and lexical variation matching';