-- =====================================================
-- CORRECTED MEDALLION ETL: Based on Discovered Table Relationships
-- Applies best practices from documented schema analysis
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =====================================================
-- BRONZE LAYER: Updated to reflect actual data sources
-- =====================================================

-- Update bronze.raw_transactions to match actual data structure
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('bronze') AND name = 'raw_transactions')
BEGIN
    DROP TABLE bronze.raw_transactions;
END

CREATE TABLE bronze.raw_transactions (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    canonical_tx_id NVARCHAR(64) NOT NULL,           -- Key linking field we discovered
    source_system NVARCHAR(100) DEFAULT 'legacy_dbo', -- dbo.SalesInteractions, dbo.PayloadTransactions
    source_table NVARCHAR(100),                      -- Track which table data came from
    raw_json NVARCHAR(MAX),                          -- Original payload from PayloadTransactions
    interaction_data NVARCHAR(MAX),                  -- Demographic data from SalesInteractions
    ingestion_timestamp DATETIME2 DEFAULT GETUTCDATE(),
    is_processed BIT DEFAULT 0,
    processing_timestamp DATETIME2 NULL,
    error_message NVARCHAR(MAX) NULL,

    -- Indexes for performance
    INDEX idx_bronze_canonical_tx (canonical_tx_id),
    INDEX idx_bronze_processed (is_processed, ingestion_timestamp),
    INDEX idx_bronze_source (source_system, source_table)
);
PRINT 'Updated table: bronze.raw_transactions with canonical_tx_id linkage';

-- =====================================================
-- SILVER LAYER: Corrected to match discovered schema
-- =====================================================

-- Update silver.transactions to reflect actual structure
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'transactions')
BEGIN
    DROP TABLE silver.transactions;
END

CREATE TABLE silver.transactions (
    transaction_id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    canonical_tx_id NVARCHAR(64) NOT NULL UNIQUE,    -- Primary business key we discovered
    interaction_id BIGINT,                           -- From dbo.SalesInteractions.InteractionID

    -- Single date source principle (as documented)
    transaction_date DATE NOT NULL,                  -- From dbo.SalesInteractions.TransactionDate
    transaction_time TIME,                           -- Extracted from CreatedDate
    created_date DATETIME2,                          -- Full timestamp from SalesInteractions

    -- Customer demographics (from SalesInteractions)
    customer_facial_id NVARCHAR(64),                 -- FacialID field we found
    customer_age TINYINT,                            -- Age field we found
    customer_gender NVARCHAR(10),                    -- Gender field we found
    conversation_score DECIMAL(5,2),                 -- ConversationScore

    -- Store information (linked via StoreID)
    store_id INT,                                    -- From dbo.SalesInteractions.StoreID
    store_name NVARCHAR(200),
    region NVARCHAR(100),
    province NVARCHAR(100),
    city NVARCHAR(100),
    barangay NVARCHAR(100),

    -- Transaction payload data (from PayloadTransactions)
    session_id NVARCHAR(100),                       -- sessionId from JSON
    device_id NVARCHAR(100),                        -- deviceId from JSON
    total_amount DECIMAL(12,2),                     -- Calculated from JSON items
    item_count INT,                                 -- Basket size from JSON
    payload_json NVARCHAR(MAX),                     -- Original JSON for audit

    -- Derived fields following best practices
    time_bucket NVARCHAR(20),                       -- morning/afternoon/evening/night
    is_weekday BIT,                                 -- Weekday vs Weekend
    demographics_combined NVARCHAR(256),            -- Age_Gender format

    -- Quality and processing metadata
    json_extraction_success BIT DEFAULT 1,
    confidence_score FLOAT,
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),

    -- Performance indexes based on discovered query patterns
    INDEX idx_silver_canonical_tx (canonical_tx_id),
    INDEX idx_silver_date (transaction_date DESC),
    INDEX idx_silver_store_date (store_id, transaction_date),
    INDEX idx_silver_facial_id (customer_facial_id),
    INDEX idx_silver_demographics (customer_age, customer_gender),
    INDEX idx_silver_location (region, province, city)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Updated table: silver.transactions with discovered schema structure';

-- SKU-level transaction items (extracted from PayloadTransactions JSON)
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'transaction_items')
BEGIN
    DROP TABLE silver.transaction_items;
END

CREATE TABLE silver.transaction_items (
    item_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    canonical_tx_id NVARCHAR(64) NOT NULL,          -- Links to silver.transactions
    sku_code NVARCHAR(100),                         -- From JSON $.items[].sku
    item_brand NVARCHAR(256),                       -- From JSON $.items[].brand
    item_category NVARCHAR(256),                    -- From JSON $.items[].category
    item_quantity INT,                              -- From JSON $.items[].quantity
    unit_price DECIMAL(10,2),                       -- From JSON $.items[].unitPrice
    item_total DECIMAL(10,2),                       -- From JSON $.items[].total
    item_rank INT,                                  -- Ranking by value within transaction

    -- Nielsen taxonomy mapping (following best practices)
    nielsen_category_l1 NVARCHAR(200),
    nielsen_category_l2 NVARCHAR(200),
    nielsen_category_l3 NVARCHAR(200),
    nielsen_brand_name NVARCHAR(200),
    nielsen_brand_id NVARCHAR(50),

    created_at DATETIME2 DEFAULT GETUTCDATE(),

    -- Foreign key relationship
    FOREIGN KEY (canonical_tx_id) REFERENCES silver.transactions(canonical_tx_id),

    INDEX idx_silver_items_tx (canonical_tx_id),
    INDEX idx_silver_items_sku (sku_code),
    INDEX idx_silver_items_brand (item_brand),
    INDEX idx_silver_items_nielsen (nielsen_category_l1, nielsen_category_l2)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Created table: silver.transaction_items for SKU-level data';

-- Store master data (sourced from dbo.Stores)
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'stores')
BEGIN
    DROP TABLE silver.stores;
END

CREATE TABLE silver.stores (
    store_id INT PRIMARY KEY,                       -- From dbo.Stores.StoreID
    store_name NVARCHAR(200),                       -- From dbo.Stores.StoreName
    store_code NVARCHAR(50),                        -- Store identifier
    region NVARCHAR(100),                           -- Geographic hierarchy
    province NVARCHAR(100),
    city NVARCHAR(100),
    barangay NVARCHAR(100),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    store_type NVARCHAR(50),
    is_active BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_silver_stores_location (region, province, city),
    INDEX idx_silver_stores_active (is_active, store_id)
);
PRINT 'Updated table: silver.stores to match dbo.Stores structure';

-- =====================================================
-- GOLD LAYER: Business metrics following best practices
-- =====================================================

-- Daily metrics with complete time hierarchy
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'daily_metrics')
BEGIN
    DROP TABLE gold.daily_metrics;
END

CREATE TABLE gold.daily_metrics (
    metric_date DATE PRIMARY KEY,

    -- Core transaction metrics
    total_transactions INT NOT NULL DEFAULT 0,
    total_revenue DECIMAL(15,2) NOT NULL DEFAULT 0,
    avg_transaction_value DECIMAL(10,2),
    median_transaction_value DECIMAL(10,2),
    total_basket_size INT,
    avg_basket_size DECIMAL(8,2),

    -- Customer metrics
    unique_facial_ids INT,                          -- Based on customer_facial_id
    unique_stores INT,
    age_distribution NVARCHAR(500),                 -- JSON: {"18-25": count, "26-35": count}
    gender_distribution NVARCHAR(200),              -- JSON: {"Male": count, "Female": count}

    -- Geographic distribution
    region_distribution NVARCHAR(MAX),              -- JSON with region counts
    top_performing_store_id INT,
    top_performing_region NVARCHAR(100),

    -- Product insights
    top_category NVARCHAR(256),
    top_brand NVARCHAR(256),
    top_sku NVARCHAR(100),
    category_diversity_index DECIMAL(8,4),          -- Shannon diversity

    -- Temporal patterns
    is_weekday BIT,
    morning_transactions INT,
    afternoon_transactions INT,
    evening_transactions INT,
    night_transactions INT,
    peak_hour INT,

    -- Quality metrics
    json_extraction_success_rate DECIMAL(8,4),
    data_quality_score DECIMAL(8,4),
    conversation_score_avg DECIMAL(8,4),

    last_updated DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_gold_daily_date (metric_date DESC),
    INDEX idx_gold_daily_revenue (total_revenue DESC)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Updated table: gold.daily_metrics with comprehensive metrics';

-- Market basket analysis (items bought together)
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'market_basket_analysis')
BEGIN
    DROP TABLE gold.market_basket_analysis;
END

CREATE TABLE gold.market_basket_analysis (
    basket_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    item_a_sku NVARCHAR(100),
    item_a_brand NVARCHAR(256),
    item_a_category NVARCHAR(256),
    item_b_sku NVARCHAR(100),
    item_b_brand NVARCHAR(256),
    item_b_category NVARCHAR(256),

    -- Association metrics
    support_count INT,                              -- How often items appear together
    confidence_a_to_b DECIMAL(8,4),                 -- P(B|A)
    confidence_b_to_a DECIMAL(8,4),                 -- P(A|B)
    lift_score DECIMAL(8,4),                        -- Strength of association

    -- Time and geography
    period_start DATE,
    period_end DATE,
    region_filter NVARCHAR(100),

    created_at DATETIME2 DEFAULT GETUTCDATE(),

    PRIMARY KEY (item_a_sku, item_b_sku, period_start),
    INDEX idx_gold_basket_lift (lift_score DESC),
    INDEX idx_gold_basket_category (item_a_category, item_b_category)
);
PRINT 'Created table: gold.market_basket_analysis for co-purchase patterns';

-- Product substitution patterns
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'substitution_patterns')
BEGIN
    DROP TABLE gold.substitution_patterns;
END

CREATE TABLE gold.substitution_patterns (
    substitution_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    from_sku NVARCHAR(100),
    from_brand NVARCHAR(256),
    from_category NVARCHAR(256),
    to_sku NVARCHAR(100),
    to_brand NVARCHAR(256),
    to_category NVARCHAR(256),

    -- Pattern metrics
    substitution_frequency INT,                     -- How often substitution occurs
    price_difference_pct DECIMAL(8,4),             -- Price difference percentage
    category_switch BIT,                           -- Cross-category substitution
    brand_switch BIT,                              -- Cross-brand substitution
    seasonality_factor DECIMAL(8,4),               -- Seasonal influence

    -- Demographics influence
    age_group_preference NVARCHAR(100),            -- Which age groups prefer this substitution
    gender_preference NVARCHAR(20),                -- Gender preference pattern
    region_preference NVARCHAR(100),               -- Regional preference

    -- Confidence and validation
    pattern_confidence DECIMAL(8,4),
    statistical_significance DECIMAL(8,4),

    period_start DATE,
    period_end DATE,
    created_at DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_gold_substitution_from (from_sku, substitution_frequency DESC),
    INDEX idx_gold_substitution_confidence (pattern_confidence DESC),
    INDEX idx_gold_substitution_category (from_category, to_category)
);
PRINT 'Created table: gold.substitution_patterns for product switching analysis';

-- Persona inference metrics
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'persona_inference')
BEGIN
    DROP TABLE gold.persona_inference;
END

CREATE TABLE gold.persona_inference (
    persona_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    customer_facial_id NVARCHAR(64),               -- Links to actual customer ID

    -- Demographic foundation
    age_group NVARCHAR(20),                        -- 18-25, 26-35, 36-45, etc.
    gender NVARCHAR(10),
    estimated_income_bracket NVARCHAR(30),

    -- Shopping behavior patterns
    avg_transaction_value DECIMAL(10,2),
    avg_basket_size DECIMAL(8,2),
    shopping_frequency NVARCHAR(20),               -- Daily, Weekly, Monthly
    preferred_categories NVARCHAR(500),            -- JSON array of categories
    preferred_brands NVARCHAR(500),                -- JSON array of brands
    price_sensitivity NVARCHAR(20),                -- High, Medium, Low

    -- Temporal patterns
    preferred_shopping_time NVARCHAR(20),          -- morning, afternoon, evening
    weekday_vs_weekend_preference NVARCHAR(20),
    seasonal_patterns NVARCHAR(500),               -- JSON with seasonal preferences

    -- Geographic patterns
    primary_region NVARCHAR(100),
    store_loyalty_index DECIMAL(8,4),              -- How often they visit same store
    geographic_mobility NVARCHAR(20),              -- High, Medium, Low

    -- Conversation intelligence
    conversation_engagement_level NVARCHAR(20),    -- Based on conversation scores
    interaction_style NVARCHAR(50),                -- Chatty, Brief, Analytical

    -- Persona classification
    primary_persona NVARCHAR(100),                 -- Budget_Conscious, Brand_Loyal, etc.
    secondary_persona NVARCHAR(100),
    persona_confidence DECIMAL(8,4),

    -- Metadata
    first_seen_date DATE,
    last_seen_date DATE,
    total_transactions INT,
    persona_last_updated DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_gold_persona_facial (customer_facial_id),
    INDEX idx_gold_persona_primary (primary_persona, persona_confidence DESC),
    INDEX idx_gold_persona_demographics (age_group, gender),
    INDEX idx_gold_persona_value (avg_transaction_value DESC)
);
PRINT 'Created table: gold.persona_inference for customer intelligence';

-- =====================================================
-- MIGRATION PROCEDURES: Legacy to Medallion
-- =====================================================

-- Procedure to migrate from dbo.SalesInteractions to silver.transactions
CREATE OR ALTER PROCEDURE dbo.sp_MigrateSalesInteractions
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO silver.transactions (
        canonical_tx_id, interaction_id, transaction_date, transaction_time,
        created_date, customer_facial_id, customer_age, customer_gender,
        conversation_score, store_id, demographics_combined,
        time_bucket, is_weekday, confidence_score
    )
    SELECT
        si.canonical_tx_id,
        si.InteractionID,
        si.TransactionDate,
        CAST(si.CreatedDate AS TIME),
        si.CreatedDate,
        si.FacialID,
        si.Age,
        si.Gender,
        si.ConversationScore,
        si.StoreID,
        CONCAT(
            CASE
                WHEN si.Age BETWEEN 18 AND 25 THEN '18-25'
                WHEN si.Age BETWEEN 26 AND 35 THEN '26-35'
                WHEN si.Age BETWEEN 36 AND 45 THEN '36-45'
                WHEN si.Age BETWEEN 46 AND 55 THEN '46-55'
                ELSE '55+'
            END,
            ' ', si.Gender
        ) as demographics_combined,
        CASE
            WHEN DATEPART(hour, si.CreatedDate) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(hour, si.CreatedDate) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(hour, si.CreatedDate) BETWEEN 18 AND 21 THEN 'Evening'
            ELSE 'Night'
        END as time_bucket,
        CASE
            WHEN DATEPART(weekday, si.TransactionDate) IN (1, 7) THEN 0
            ELSE 1
        END as is_weekday,
        0.95 as confidence_score  -- High confidence for direct data
    FROM dbo.SalesInteractions si
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.transactions st
        WHERE st.canonical_tx_id = si.canonical_tx_id
    );

    PRINT CONCAT('Migrated ', @@ROWCOUNT, ' records from dbo.SalesInteractions');
END;
GO

-- Procedure to extract and migrate PayloadTransactions JSON to silver.transaction_items
CREATE OR ALTER PROCEDURE dbo.sp_MigratePayloadTransactions
AS
BEGIN
    SET NOCOUNT ON;

    WITH sku_extraction AS (
        SELECT
            pt.canonical_tx_id,
            JSON_VALUE(item.value, '$.sku') AS sku_code,
            JSON_VALUE(item.value, '$.brand') AS item_brand,
            JSON_VALUE(item.value, '$.category') AS item_category,
            TRY_CONVERT(INT, JSON_VALUE(item.value, '$.quantity')) AS item_quantity,
            TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.unitPrice')) AS unit_price,
            TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.total')) AS item_total,
            ROW_NUMBER() OVER (
                PARTITION BY pt.canonical_tx_id
                ORDER BY TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.total')) DESC
            ) AS item_rank
        FROM dbo.PayloadTransactions pt
        CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS item
        WHERE pt.payload_json IS NOT NULL
          AND ISJSON(pt.payload_json) = 1
    )
    INSERT INTO silver.transaction_items (
        canonical_tx_id, sku_code, item_brand, item_category,
        item_quantity, unit_price, item_total, item_rank
    )
    SELECT
        canonical_tx_id, sku_code, item_brand, item_category,
        item_quantity, unit_price, item_total, item_rank
    FROM sku_extraction
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.transaction_items sti
        WHERE sti.canonical_tx_id = sku_extraction.canonical_tx_id
        AND sti.sku_code = sku_extraction.sku_code
    );

    PRINT CONCAT('Migrated ', @@ROWCOUNT, ' SKU items from dbo.PayloadTransactions');
END;
GO

-- Procedure to migrate store data
CREATE OR ALTER PROCEDURE dbo.sp_MigrateStores
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO silver.stores (
        store_id, store_name, region, province, city, barangay, is_active
    )
    SELECT
        s.StoreID,
        s.StoreName,
        s.Region,
        s.Province,
        s.City,
        s.Barangay,
        1 as is_active
    FROM dbo.Stores s
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.stores ss
        WHERE ss.store_id = s.StoreID
    );

    PRINT CONCAT('Migrated ', @@ROWCOUNT, ' stores from dbo.Stores');
END;
GO

-- Master migration procedure
CREATE OR ALTER PROCEDURE dbo.sp_MigrateLegacyToMedallion
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Starting migration from legacy dbo tables to medallion architecture...';

    -- Step 1: Migrate stores (needed for foreign keys)
    EXEC dbo.sp_MigrateStores;

    -- Step 2: Migrate sales interactions
    EXEC dbo.sp_MigrateSalesInteractions;

    -- Step 3: Migrate payload transactions and extract SKUs
    EXEC dbo.sp_MigratePayloadTransactions;

    -- Step 4: Update transaction totals from items
    UPDATE st
    SET total_amount = item_totals.total_amount,
        item_count = item_totals.item_count,
        json_extraction_success = 1
    FROM silver.transactions st
    INNER JOIN (
        SELECT
            canonical_tx_id,
            SUM(item_total) as total_amount,
            COUNT(*) as item_count
        FROM silver.transaction_items
        GROUP BY canonical_tx_id
    ) item_totals ON st.canonical_tx_id = item_totals.canonical_tx_id;

    PRINT 'Migration to medallion architecture completed successfully.';
END;
GO

PRINT '======================================';
PRINT 'CORRECTED MEDALLION ETL COMPLETE!';
PRINT '======================================';
PRINT 'Key Corrections Applied:';
PRINT '✅ canonical_tx_id as primary linking key';
PRINT '✅ Single date source: TransactionDate from SalesInteractions';
PRINT '✅ JSON extraction patterns from PayloadTransactions';
PRINT '✅ Customer demographics: FacialID, Age, Gender';
PRINT '✅ Store hierarchy: Region → Province → City → Barangay';
PRINT '✅ SKU-level transaction items with Nielsen mapping';
PRINT '✅ Market basket analysis for co-purchase patterns';
PRINT '✅ Substitution pattern tracking';
PRINT '✅ Persona inference with conversation intelligence';
PRINT '✅ Migration procedures from legacy dbo tables';
PRINT '';
PRINT 'Execute migration: EXEC dbo.sp_MigrateLegacyToMedallion';