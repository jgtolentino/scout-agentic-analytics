-- ========================================================================
-- Scout Platform Enhanced Schema for Complete Retail Intelligence
-- Supports: Demographics, Substitution, Basket Analysis, Transaction Completion
-- ========================================================================

-- ==========================
-- 1. BRAND SUBSTITUTION TRACKING
-- ==========================

-- Track brand substitutions (FROM brand → TO brand)
CREATE TABLE dbo.BrandSubstitutions (
    substitution_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    interaction_id VARCHAR(50),
    transaction_id VARCHAR(50),

    -- Original Request
    original_brand VARCHAR(100),
    original_product VARCHAR(200),
    original_sku VARCHAR(100),

    -- Substitution Made
    substituted_brand VARCHAR(100),
    substituted_product VARCHAR(200),
    substituted_sku VARCHAR(100),

    -- Reason & Customer Response
    substitution_reason VARCHAR(100), -- 'out_of_stock', 'price', 'customer_preference', 'promotion'
    suggestion_accepted BIT DEFAULT 0,
    customer_requested BIT DEFAULT 0, -- Customer asked for substitution vs store suggested

    -- Financial Impact
    original_price DECIMAL(10,2),
    substituted_price DECIMAL(10,2),
    price_difference AS (substituted_price - original_price),

    -- Detection Confidence
    confidence_score DECIMAL(3,2),
    detection_timestamp DATETIME2 DEFAULT GETDATE(),

    -- Indexes for performance
    INDEX IX_BrandSub_Brands (original_brand, substituted_brand),
    INDEX IX_BrandSub_Acceptance (suggestion_accepted),
    INDEX IX_BrandSub_Transaction (transaction_id),
    INDEX IX_BrandSub_Timestamp (detection_timestamp)
);

-- ==========================
-- 2. MARKET BASKET ANALYSIS
-- ==========================

-- Transaction-level basket analysis
CREATE TABLE dbo.TransactionBaskets (
    basket_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id VARCHAR(50) UNIQUE,
    interaction_id VARCHAR(50),

    -- Basket Composition
    total_items INT,
    unique_products INT,
    unique_brands INT,
    unique_categories INT,

    -- Basket Value
    total_basket_value DECIMAL(12,2),
    avg_item_price DECIMAL(10,2),
    max_item_price DECIMAL(10,2),

    -- Product Mix JSON
    product_list JSON, -- Array of products with quantities
    brand_list JSON,   -- Array of brands in basket
    category_list JSON, -- Array of categories

    -- Basket Intelligence
    has_tobacco BIT DEFAULT 0,
    has_laundry BIT DEFAULT 0,
    has_beverages BIT DEFAULT 0,
    has_snacks BIT DEFAULT 0,

    -- Timing
    basket_timestamp DATETIME2,

    INDEX IX_Basket_Transaction (transaction_id),
    INDEX IX_Basket_Value (total_basket_value),
    INDEX IX_Basket_Size (total_items),
    INDEX IX_Basket_Categories (has_tobacco, has_laundry)
);

-- Product Association Rules (Market Basket Mining Results)
CREATE TABLE dbo.ProductAssociations (
    association_id BIGINT IDENTITY(1,1) PRIMARY KEY,

    -- Product Pair
    product_a VARCHAR(200),
    product_b VARCHAR(200),
    brand_a VARCHAR(100),
    brand_b VARCHAR(100),
    category_a VARCHAR(100),
    category_b VARCHAR(100),

    -- Association Metrics (Apriori Algorithm)
    support DECIMAL(5,4), -- How often both appear together / total transactions
    confidence DECIMAL(5,4), -- P(B|A) = Support(A,B) / Support(A)
    lift DECIMAL(6,2), -- Confidence(A→B) / Support(B)

    -- Transaction Counts
    transactions_together INT,
    transactions_a_only INT,
    transactions_b_only INT,
    total_transactions_analyzed INT,

    -- Time Patterns
    most_common_hour INT,
    most_common_day VARCHAR(20),

    -- Metadata
    last_calculated DATETIME2 DEFAULT GETDATE(),

    INDEX IX_Assoc_Products (product_a, product_b),
    INDEX IX_Assoc_Lift (lift DESC),
    INDEX IX_Assoc_Confidence (confidence DESC),
    INDEX IX_Assoc_Categories (category_a, category_b)
);

-- ==========================
-- 3. TRANSACTION COMPLETION TRACKING
-- ==========================

-- Track transaction completion and abandonment patterns
CREATE TABLE dbo.TransactionCompletionStatus (
    status_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    interaction_id VARCHAR(50),
    transaction_id VARCHAR(50),

    -- Completion Status
    interaction_started BIT DEFAULT 1,
    selection_made BIT DEFAULT 0,
    payment_initiated BIT DEFAULT 0,
    transaction_completed BIT DEFAULT 0,
    transaction_abandoned BIT DEFAULT 0,

    -- Abandonment Details
    abandonment_stage VARCHAR(50), -- 'browsing', 'selection', 'payment', 'confirmation'
    abandonment_reason VARCHAR(200), -- 'payment_failed', 'customer_left', 'out_of_stock', 'price_dispute'
    time_to_abandonment_seconds INT,

    -- Recovery & Alternatives
    recovery_attempted BIT DEFAULT 0,
    recovery_successful BIT DEFAULT 0,
    alternative_product_offered BIT DEFAULT 0,
    alternative_accepted BIT DEFAULT 0,

    -- Financial Impact
    potential_revenue_lost DECIMAL(10,2),
    items_in_abandoned_basket INT,
    completed_transaction_value DECIMAL(10,2),

    -- Timestamps
    interaction_timestamp DATETIME2,
    completion_timestamp DATETIME2,
    abandonment_timestamp DATETIME2,

    INDEX IX_Completion_Status (transaction_completed, transaction_abandoned),
    INDEX IX_Completion_Interaction (interaction_id),
    INDEX IX_Completion_Revenue (potential_revenue_lost),
    INDEX IX_Completion_Timestamp (interaction_timestamp)
);

-- ==========================
-- 4. ENHANCED SALES INTERACTIONS (Customer Demographics)
-- ==========================

-- Extend existing SalesInteractions or create enhanced version
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'SalesInteractions')
BEGIN
    CREATE TABLE dbo.SalesInteractions (
        interaction_id VARCHAR(50) PRIMARY KEY,
        device_id VARCHAR(50),
        store_id VARCHAR(50),

        -- Timing
        interaction_timestamp DATETIME2,
        interaction_duration_seconds INT,

        -- Customer Demographics (Vision Analysis)
        customer_age INT,
        customer_gender VARCHAR(20), -- M, F, U (Unknown)
        customer_emotion VARCHAR(50), -- happy, neutral, serious, etc.
        age_confidence DECIMAL(3,2),
        gender_confidence DECIMAL(3,2),

        -- Transaction Context
        payment_method VARCHAR(50), -- cash, gcash, maya, credit_card, debit_card
        transaction_type VARCHAR(50), -- purchase, inquiry, browsing

        -- Privacy & Compliance
        facial_data_stored BIT DEFAULT 0, -- Should always be 0 for privacy
        demographic_consent BIT DEFAULT 1,
        data_retention_days INT DEFAULT 30,

        INDEX IX_SalesInt_Store_Time (store_id, interaction_timestamp),
        INDEX IX_SalesInt_Demographics (customer_age, customer_gender),
        INDEX IX_SalesInt_Device (device_id),
        INDEX IX_SalesInt_Payment (payment_method),

        FOREIGN KEY (store_id) REFERENCES dbo.Stores(store_id)
    );
END;

-- ==========================
-- 5. ENHANCED TRANSACTION ITEMS
-- ==========================

-- Extend TransactionItems with additional intelligence
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TransactionItems')
BEGIN
    CREATE TABLE dbo.TransactionItems (
        item_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        transaction_id VARCHAR(50),
        interaction_id VARCHAR(50),

        -- Product Details
        product_name VARCHAR(200),
        brand_name VARCHAR(100),
        generic_name VARCHAR(200),
        local_name VARCHAR(100), -- Local/Filipino name
        category VARCHAR(100),
        subcategory VARCHAR(100),
        sku VARCHAR(100),
        barcode VARCHAR(50),

        -- Quantity & Pricing
        quantity INT,
        unit VARCHAR(20), -- pc, pack, sachet, bottle, etc.
        unit_price DECIMAL(10,2),
        total_price DECIMAL(10,2),

        -- Product Characteristics
        weight_grams INT,
        volume_ml INT,
        pack_size VARCHAR(50),

        -- Substitution Tracking
        is_substitution BIT DEFAULT 0,
        original_product_requested VARCHAR(200),
        original_brand_requested VARCHAR(100),
        substitution_reason VARCHAR(100),
        customer_accepted_substitution BIT,
        suggested_alternatives JSON, -- Array of alternative products offered

        -- Detection & AI
        detection_method VARCHAR(50), -- 'stt_brand_only', 'vision', 'manual', 'barcode'
        brand_confidence DECIMAL(3,2),
        product_confidence DECIMAL(3,2),

        -- Purchase Context
        is_impulse_buy BIT DEFAULT 0,
        is_promoted_item BIT DEFAULT 0,
        customer_request_type VARCHAR(50), -- 'branded', 'generic', 'specific_product'

        -- Audio Context
        audio_context TEXT, -- What customer said about this product

        created_at DATETIME2 DEFAULT GETDATE(),

        INDEX IX_TransItems_Transaction (transaction_id),
        INDEX IX_TransItems_Brand (brand_name),
        INDEX IX_TransItems_Category (category),
        INDEX IX_TransItems_Substitution (is_substitution),
        INDEX IX_TransItems_Detection (detection_method)
    );
END;

-- ==========================
-- 6. CATEGORY-SPECIFIC ANALYSIS TABLES
-- ==========================

-- Tobacco-specific analytics
CREATE TABLE dbo.TobaccoAnalytics (
    tobacco_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id VARCHAR(50),
    interaction_id VARCHAR(50),

    -- Product Details
    brand_name VARCHAR(100), -- Marlboro, Fortune, Hope, Philip Morris, etc.
    product_type VARCHAR(50), -- cigarettes, tobacco_roll, etc.
    stick_count INT, -- How many cigarettes
    pack_type VARCHAR(50), -- single, pack_of_20, etc.

    -- Customer Demographics
    customer_age INT,
    customer_gender VARCHAR(20),

    -- Purchase Patterns
    purchase_time DATETIME2,
    day_of_month INT,
    is_payday_period BIT, -- Near 15th or 30th
    hour_of_day INT,

    -- Co-purchases
    purchased_with_alcohol BIT DEFAULT 0,
    purchased_with_snacks BIT DEFAULT 0,
    purchased_with_beverages BIT DEFAULT 0,

    -- Terms Used (from STT)
    spoken_terms JSON, -- ["yosi", "stick", "kaha", "reds", etc.]

    INDEX IX_Tobacco_Brand (brand_name),
    INDEX IX_Tobacco_Demographics (customer_age, customer_gender),
    INDEX IX_Tobacco_Timing (purchase_time, is_payday_period)
);

-- Laundry/Soap-specific analytics
CREATE TABLE dbo.LaundryAnalytics (
    laundry_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id VARCHAR(50),
    interaction_id VARCHAR(50),

    -- Product Details
    brand_name VARCHAR(100), -- Tide, Ariel, Surf, Champion, etc.
    product_type VARCHAR(50), -- bar_soap, powder_detergent, liquid_detergent, fabric_softener
    size_description VARCHAR(50), -- small, medium, large, sachet

    -- Customer Demographics
    customer_age INT,
    customer_gender VARCHAR(20),

    -- Purchase Context
    purchase_time DATETIME2,
    day_of_month INT,
    is_payday_period BIT,

    -- Co-purchase Patterns
    has_detergent BIT DEFAULT 0,
    has_bar_soap BIT DEFAULT 0,
    has_fabric_softener BIT DEFAULT 0,
    has_bleach BIT DEFAULT 0,

    -- Terms Used (from STT)
    spoken_terms JSON, -- ["sabon", "labada", "panlaba", "bars", "pulbos", "fabcon", etc.]

    INDEX IX_Laundry_Brand (brand_name),
    INDEX IX_Laundry_Type (product_type),
    INDEX IX_Laundry_Demographics (customer_age, customer_gender),
    INDEX IX_Laundry_Timing (purchase_time, is_payday_period)
);

-- ==========================
-- 7. AUDIT & COMPLIANCE TABLES
-- ==========================

-- Vision analysis audit (for privacy compliance)
CREATE TABLE dbo.VisionAnalysisAudit (
    audit_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    interaction_id VARCHAR(50),
    device_id VARCHAR(50),

    -- Processing Details
    vision_model_version VARCHAR(50),
    processing_timestamp DATETIME2 DEFAULT GETDATE(),
    processing_duration_ms INT,

    -- Confidence Scores
    age_confidence DECIMAL(3,2),
    gender_confidence DECIMAL(3,2),
    emotion_confidence DECIMAL(3,2),

    -- Privacy Compliance
    facial_image_stored BIT DEFAULT 0, -- Must be 0
    biometric_data_extracted BIT DEFAULT 0, -- Must be 0
    demographic_only BIT DEFAULT 1, -- Must be 1

    -- Data Retention
    data_retention_days INT DEFAULT 30,
    deletion_scheduled_date DATE,
    consent_recorded BIT DEFAULT 1,

    INDEX IX_VisionAudit_Interaction (interaction_id),
    INDEX IX_VisionAudit_Timestamp (processing_timestamp),
    INDEX IX_VisionAudit_Privacy (facial_image_stored, biometric_data_extracted)
);

-- ETL processing log
CREATE TABLE dbo.ETLProcessingLog (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    process_name VARCHAR(100),
    execution_timestamp DATETIME2 DEFAULT GETDATE(),

    -- Processing Stats
    files_processed INT,
    transactions_extracted INT,
    items_extracted INT,
    brands_detected INT,
    errors_encountered INT,

    -- Status
    status VARCHAR(50), -- 'success', 'partial', 'failed'
    error_details TEXT,

    -- Performance
    processing_duration_seconds INT,

    INDEX IX_ETL_Process (process_name),
    INDEX IX_ETL_Timestamp (execution_timestamp),
    INDEX IX_ETL_Status (status)
);

PRINT 'Enhanced Scout schema created successfully!';
PRINT 'Tables created: BrandSubstitutions, TransactionBaskets, ProductAssociations, TransactionCompletionStatus, TobaccoAnalytics, LaundryAnalytics, VisionAnalysisAudit, ETLProcessingLog';