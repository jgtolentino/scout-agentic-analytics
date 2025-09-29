-- Master Data Catalog Schema
-- Enhanced brand/SKU catalog with conversation intelligence support
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: MASTER DATA CATALOG
-- =====================================================

-- Brand master catalog with TBWA client tracking
CREATE TABLE IF NOT EXISTS dbo.brand_catalog (
    brand_id INT IDENTITY(1,1) PRIMARY KEY,
    brand_name NVARCHAR(200) NOT NULL,
    brand_name_normalized NVARCHAR(200), -- For fuzzy matching
    parent_company NVARCHAR(200),
    tbwa_client BIT DEFAULT 0,
    category_primary NVARCHAR(100),
    category_secondary NVARCHAR(100),
    brand_tier NVARCHAR(20), -- Premium, Mid-tier, Economy
    origin_country NVARCHAR(50),
    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),
    updated_date DATETIME2 DEFAULT SYSUTCDATETIME(),
    is_active BIT DEFAULT 1,

    INDEX IX_brand_name (brand_name),
    INDEX IX_brand_normalized (brand_name_normalized),
    INDEX IX_category_primary (category_primary),
    INDEX IX_tbwa_client (tbwa_client)
);

-- SKU catalog with detailed product information
CREATE TABLE IF NOT EXISTS dbo.sku_catalog (
    sku_id INT IDENTITY(1,1) PRIMARY KEY,
    brand_id INT NOT NULL,
    sku_code NVARCHAR(50),
    sku_name NVARCHAR(200) NOT NULL,
    sku_variant NVARCHAR(100),
    package_size NVARCHAR(50),
    unit_price DECIMAL(10,2),
    cost_price DECIMAL(10,2),
    package_type NVARCHAR(30), -- Sachet, Bottle, Box, etc.
    weight_grams DECIMAL(10,2),
    volume_ml DECIMAL(10,2),
    barcode NVARCHAR(50),
    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),
    updated_date DATETIME2 DEFAULT SYSUTCDATETIME(),
    is_active BIT DEFAULT 1,

    FOREIGN KEY (brand_id) REFERENCES dbo.brand_catalog(brand_id),
    INDEX IX_brand_id (brand_id),
    INDEX IX_sku_code (sku_code),
    INDEX IX_sku_name (sku_name),
    INDEX IX_barcode (barcode)
);

-- =====================================================
-- SECTION 2: CONVERSATION INTELLIGENCE TABLES
-- =====================================================

-- Enhanced conversation segments with speaker separation
CREATE TABLE IF NOT EXISTS dbo.conversation_segments (
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
    language_detected NVARCHAR(10) DEFAULT 'fil', -- Filipino/Tagalog

    -- Intent classification
    intent_classification NVARCHAR(50),
    intent_confidence DECIMAL(5,3),

    -- Brand/product mentions
    brands_mentioned NVARCHAR(MAX), -- JSON array of mentioned brands
    products_mentioned NVARCHAR(MAX), -- JSON array of mentioned products

    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    INDEX IX_transaction_id (transaction_id),
    INDEX IX_speaker_type (speaker_type),
    INDEX IX_intent (intent_classification),
    INDEX IX_timestamps (start_timestamp, end_timestamp)
);

-- Purchase funnel tracking (5-stage enhanced)
CREATE TABLE IF NOT EXISTS dbo.purchase_funnel_tracking (
    funnel_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id NVARCHAR(64) NOT NULL,
    session_id NVARCHAR(64),

    -- 5-stage funnel
    stage_1_store_visit BIT DEFAULT 0,
    stage_1_timestamp DATETIME2,

    stage_2_browse BIT DEFAULT 0,
    stage_2_timestamp DATETIME2,

    stage_3_brand_request BIT DEFAULT 0,
    stage_3_timestamp DATETIME2,
    stage_3_brands_requested NVARCHAR(MAX), -- JSON array

    stage_4_suggestion_accepted BIT DEFAULT 0,
    stage_4_timestamp DATETIME2,
    stage_4_suggestions_made NVARCHAR(MAX), -- JSON array

    stage_5_purchase_completed BIT DEFAULT 0,
    stage_5_timestamp DATETIME2,
    stage_5_final_brands NVARCHAR(MAX), -- JSON array

    -- Funnel metrics
    total_duration_seconds INT,
    stages_completed TINYINT,
    conversion_rate DECIMAL(5,3),

    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    INDEX IX_transaction_id (transaction_id),
    INDEX IX_stages_completed (stages_completed),
    INDEX IX_conversion_rate (conversion_rate)
);

-- Market basket analysis (combo_basket support)
CREATE TABLE IF NOT EXISTS dbo.market_basket_analysis (
    basket_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id NVARCHAR(64) NOT NULL,

    -- Basket composition
    item_count INT,
    unique_categories INT,
    unique_brands INT,
    total_value DECIMAL(12,2),

    -- Combo basket (JSON array of items usually bought together)
    combo_basket NVARCHAR(MAX),
    combo_confidence DECIMAL(5,3),

    -- Substitution tracking
    substitutions_made BIT DEFAULT 0,
    original_requests NVARCHAR(MAX), -- JSON array
    final_purchases NVARCHAR(MAX), -- JSON array
    substitution_reasons NVARCHAR(MAX), -- JSON array

    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    INDEX IX_transaction_id (transaction_id),
    INDEX IX_item_count (item_count),
    INDEX IX_substitutions (substitutions_made)
);

-- =====================================================
-- SECTION 3: ENHANCED TRANSACTION PAYLOAD STRUCTURE
-- =====================================================

-- Enhanced transaction fact table with conversation intelligence
CREATE TABLE IF NOT EXISTS dbo.enhanced_transactions (
    enhanced_transaction_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    canonical_tx_id NVARCHAR(64) NOT NULL,
    original_transaction_id NVARCHAR(64),

    -- Master data references
    store_id INT,
    primary_brand_id INT,
    primary_sku_id INT,

    -- Enhanced financial tracking
    transaction_value DECIMAL(12,2),
    item_count INT,
    peso_value_accurate BIT DEFAULT 1,

    -- Temporal dimensions
    transaction_datetime DATETIME2,
    transaction_date DATE,
    transaction_time TIME,
    hour_of_day TINYINT,
    day_of_week TINYINT,
    day_of_month TINYINT,
    month_of_year TINYINT,
    quarter TINYINT,
    year SMALLINT,

    -- Customer demographics (from facial recognition)
    customer_age_estimated TINYINT,
    customer_gender NVARCHAR(10),
    customer_facial_id NVARCHAR(64),

    -- Conversation metrics
    conversation_duration_seconds INT,
    speaker_turns_customer INT,
    speaker_turns_owner INT,
    brands_discussed INT,
    suggestion_acceptance_rate DECIMAL(5,3),

    -- Funnel completion
    funnel_stage_reached TINYINT, -- 1-5
    conversion_completed BIT DEFAULT 0,

    created_date DATETIME2 DEFAULT SYSUTCDATETIME(),
    updated_date DATETIME2 DEFAULT SYSUTCDATETIME(),

    FOREIGN KEY (primary_brand_id) REFERENCES dbo.brand_catalog(brand_id),
    FOREIGN KEY (primary_sku_id) REFERENCES dbo.sku_catalog(sku_id),

    INDEX IX_canonical_tx_id (canonical_tx_id),
    INDEX IX_transaction_datetime (transaction_datetime),
    INDEX IX_store_brand (store_id, primary_brand_id),
    INDEX IX_funnel_stage (funnel_stage_reached),
    INDEX IX_conversion (conversion_completed)
);

-- =====================================================
-- SECTION 4: VIEWS FOR ANALYTICS
-- =====================================================

-- Comprehensive analytics view combining all enhanced data
CREATE OR ALTER VIEW dbo.v_enhanced_analytics AS
SELECT
    et.enhanced_transaction_id,
    et.canonical_tx_id,
    et.store_id,
    et.transaction_datetime,
    et.transaction_date,
    et.transaction_value,
    et.item_count,

    -- Brand and product information
    bc.brand_name,
    bc.category_primary,
    bc.category_secondary,
    bc.tbwa_client,
    bc.brand_tier,

    sc.sku_name,
    sc.package_size,
    sc.package_type,

    -- Customer demographics
    et.customer_age_estimated,
    et.customer_gender,

    -- Temporal dimensions
    et.hour_of_day,
    et.day_of_week,
    et.day_of_month,
    CASE
        WHEN et.day_of_month BETWEEN 23 AND 30 THEN 'Pecha de Peligro'
        WHEN et.day_of_month BETWEEN 1 AND 7 THEN 'Start of Month'
        ELSE 'Mid Month'
    END AS salary_period,

    CASE
        WHEN et.hour_of_day BETWEEN 6 AND 11 THEN 'Morning'
        WHEN et.hour_of_day BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN et.hour_of_day BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END AS daypart,

    -- Conversation intelligence
    et.conversation_duration_seconds,
    et.speaker_turns_customer,
    et.speaker_turns_owner,
    et.brands_discussed,
    et.suggestion_acceptance_rate,

    -- Funnel metrics
    et.funnel_stage_reached,
    et.conversion_completed,

    -- Purchase funnel details
    pft.stages_completed,
    pft.total_duration_seconds AS funnel_duration,

    -- Market basket details
    mba.combo_basket,
    mba.substitutions_made

FROM dbo.enhanced_transactions et
    LEFT JOIN dbo.brand_catalog bc ON et.primary_brand_id = bc.brand_id
    LEFT JOIN dbo.sku_catalog sc ON et.primary_sku_id = sc.sku_id
    LEFT JOIN dbo.purchase_funnel_tracking pft ON et.canonical_tx_id = pft.transaction_id
    LEFT JOIN dbo.market_basket_analysis mba ON et.canonical_tx_id = mba.transaction_id
WHERE et.conversion_completed = 1; -- Only completed transactions

PRINT 'Master data catalog schema created successfully';