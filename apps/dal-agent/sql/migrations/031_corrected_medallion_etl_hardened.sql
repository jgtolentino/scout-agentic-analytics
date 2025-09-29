-- =====================================================
-- CORRECTED MEDALLION ETL: Production-Ready with Guardrails
-- Applies best practices from discovered schema analysis + critical patches
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRAN;

-- Ensure schemas exist (idempotent)
IF SCHEMA_ID('bronze') IS NULL EXEC('CREATE SCHEMA bronze');
IF SCHEMA_ID('silver') IS NULL EXEC('CREATE SCHEMA silver');
IF SCHEMA_ID('gold') IS NULL EXEC('CREATE SCHEMA gold');
IF SCHEMA_ID('platinum') IS NULL EXEC('CREATE SCHEMA platinum');

-- ETL governance tables
IF OBJECT_ID('dbo.etl_execution_log','U') IS NULL
CREATE TABLE dbo.etl_execution_log (
    etl_run_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    etl_name SYSNAME NOT NULL,
    started_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    finished_at DATETIME2(3) NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'RUNNING',
    rows_read BIGINT NULL,
    rows_written BIGINT NULL,
    notes NVARCHAR(2000) NULL
);

IF OBJECT_ID('dbo.data_quality_metrics','U') IS NULL
CREATE TABLE dbo.data_quality_metrics(
    metric_date DATE NOT NULL DEFAULT CAST(SYSUTCDATETIME() AS DATE),
    metric_name SYSNAME NOT NULL,
    metric_value DECIMAL(38,6) NULL,
    layer VARCHAR(16) NOT NULL,   -- bronze|silver|gold
    detail NVARCHAR(1000) NULL,
    CONSTRAINT PK_dqm PRIMARY KEY(metric_date, metric_name, layer)
);

-- Record ETL start
DECLARE @run UNIQUEIDENTIFIER = NEWID();
INSERT dbo.etl_execution_log(etl_run_id, etl_name) VALUES(@run, N'031_corrected_medallion_etl_hardened');

-- =====================================================
-- BRONZE LAYER: Raw data with canonical_tx_id tracking
-- =====================================================

IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('bronze') AND name = 'raw_transactions')
    DROP TABLE bronze.raw_transactions;

CREATE TABLE bronze.raw_transactions (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    canonical_tx_id NVARCHAR(64) NOT NULL,           -- Key linking field discovered
    source_system NVARCHAR(100) DEFAULT 'legacy_dbo',
    source_table NVARCHAR(100),                      -- Track origin table
    raw_json NVARCHAR(MAX),                          -- PayloadTransactions.payload_json
    interaction_data NVARCHAR(MAX),                  -- SalesInteractions data as JSON
    ingestion_timestamp DATETIME2 DEFAULT GETUTCDATE(),
    is_processed BIT DEFAULT 0,
    processing_timestamp DATETIME2 NULL,
    error_message NVARCHAR(MAX) NULL,

    INDEX idx_bronze_canonical_tx (canonical_tx_id),
    INDEX idx_bronze_processed (is_processed, ingestion_timestamp),
    INDEX idx_bronze_source (source_system, source_table)
);

-- =====================================================
-- SILVER LAYER: Typed, conformed data with single date source
-- =====================================================

IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'transactions')
    DROP TABLE silver.transactions;

CREATE TABLE silver.transactions (
    transaction_id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    canonical_tx_id NVARCHAR(64) NOT NULL,          -- Primary business key
    interaction_id BIGINT,                          -- From SalesInteractions.InteractionID

    -- Single date source principle (authoritative)
    transaction_date DATE NOT NULL,                 -- From SalesInteractions.TransactionDate
    transaction_time TIME,                          -- Extracted from CreatedDate
    created_date DATETIME2,                         -- Full timestamp

    -- Customer demographics (from SalesInteractions)
    customer_facial_id NVARCHAR(64),                -- FacialID
    customer_age TINYINT,                           -- Age
    customer_gender NVARCHAR(10),                   -- Gender
    conversation_score DECIMAL(5,2),                -- ConversationScore

    -- Store linkage
    store_id INT,                                   -- SalesInteractions.StoreID
    store_name NVARCHAR(200),
    region NVARCHAR(100),
    province NVARCHAR(100),
    city NVARCHAR(100),
    barangay NVARCHAR(100),

    -- Transaction payload (from PayloadTransactions)
    session_id NVARCHAR(100),                      -- JSON sessionId
    device_id NVARCHAR(100),                       -- JSON deviceId
    total_amount DECIMAL(12,2),                    -- Calculated from JSON items
    item_count INT,                                -- Basket size
    payload_json NVARCHAR(MAX),                    -- Original JSON for audit

    -- Derived fields
    time_bucket NVARCHAR(20),                      -- morning/afternoon/evening/night
    is_weekday BIT,                                -- Weekday vs Weekend
    demographics_combined NVARCHAR(256),           -- Age_Gender format

    -- Quality metadata
    json_extraction_success BIT DEFAULT 1,
    confidence_score FLOAT DEFAULT 0.95,
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),

    -- Performance indexes
    INDEX idx_silver_canonical_tx (canonical_tx_id),
    INDEX idx_silver_date (transaction_date DESC),
    INDEX idx_silver_store_date (store_id, transaction_date),
    INDEX idx_silver_facial_id (customer_facial_id),
    INDEX idx_silver_demographics (customer_age, customer_gender)
) WITH (DATA_COMPRESSION = PAGE);

-- Enforce canonical_tx_id uniqueness
ALTER TABLE silver.transactions ADD CONSTRAINT UQ_silver_transactions_txid UNIQUE (canonical_tx_id);

-- SKU-level items (from PayloadTransactions JSON)
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'transaction_items')
    DROP TABLE silver.transaction_items;

CREATE TABLE silver.transaction_items (
    item_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    canonical_tx_id NVARCHAR(64) NOT NULL,         -- Links to silver.transactions
    sku_code NVARCHAR(100),                        -- JSON $.items[].sku
    item_brand NVARCHAR(256),                      -- JSON $.items[].brand
    item_category NVARCHAR(256),                   -- JSON $.items[].category
    item_quantity INT,                             -- JSON $.items[].quantity
    unit_price DECIMAL(10,2),                      -- JSON $.items[].unitPrice
    item_total DECIMAL(10,2),                      -- JSON $.items[].total
    item_rank INT,                                 -- Ranking by value within transaction

    -- Nielsen taxonomy (will be populated by 032_nielsen_integration)
    nielsen_category_l1 NVARCHAR(200),
    nielsen_category_l2 NVARCHAR(200),
    nielsen_category_l3 NVARCHAR(200),
    nielsen_brand_name NVARCHAR(200),
    nielsen_brand_id NVARCHAR(50),

    created_at DATETIME2 DEFAULT GETUTCDATE(),

    FOREIGN KEY (canonical_tx_id) REFERENCES silver.transactions(canonical_tx_id),
    INDEX idx_silver_items_tx (canonical_tx_id),
    INDEX idx_silver_items_sku (sku_code),
    INDEX idx_silver_items_brand (item_brand)
) WITH (DATA_COMPRESSION = PAGE);

-- Store master (from dbo.Stores)
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'stores')
    DROP TABLE silver.stores;

CREATE TABLE silver.stores (
    store_id INT PRIMARY KEY,                      -- dbo.Stores.StoreID
    store_name NVARCHAR(200),                      -- dbo.Stores.StoreName
    store_code NVARCHAR(50),
    region NVARCHAR(100),                          -- Geographic hierarchy
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

-- =====================================================
-- GOLD LAYER: Analytics-ready views and marts
-- =====================================================

-- Fact transactions view (authoritative date source)
CREATE OR ALTER VIEW gold.fact_transactions AS
SELECT
    st.canonical_tx_id,
    st.transaction_date,                            -- Authoritative from SalesInteractions
    st.created_date AS transaction_ts,
    DATEPART(HOUR, st.created_date) AS txn_hour,
    st.time_bucket AS daypart,
    st.total_amount,
    st.item_count AS basket_size,
    st.store_id,
    st.customer_facial_id,
    st.customer_age,
    st.customer_gender,
    st.conversation_score,
    st.region,
    st.province,
    st.city,
    st.is_weekday,
    st.json_extraction_success,
    st.confidence_score
FROM silver.transactions st
WHERE st.json_extraction_success = 1;

-- Mart transactions (denormalized for API)
CREATE OR ALTER VIEW gold.mart_transactions AS
SELECT
    ft.canonical_tx_id,
    ft.transaction_date,
    ft.transaction_ts,
    ft.txn_hour,
    ft.daypart,
    ft.total_amount,
    ft.basket_size,
    ft.store_id,
    ft.customer_facial_id,
    ft.customer_age,
    ft.customer_gender,
    ft.conversation_score,
    ft.region,
    ft.province,
    ft.city,
    ft.is_weekday,

    -- Top item details
    sti.sku_code AS primary_sku,
    sti.item_brand AS primary_brand,
    sti.item_category AS primary_category,
    sti.item_total AS primary_item_value,

    -- Nielsen taxonomy
    sti.nielsen_category_l1,
    sti.nielsen_category_l2,
    sti.nielsen_category_l3,
    sti.nielsen_brand_name,

    ft.confidence_score
FROM gold.fact_transactions ft
LEFT JOIN silver.transaction_items sti ON ft.canonical_tx_id = sti.canonical_tx_id AND sti.item_rank = 1;

-- Daily metrics
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'daily_metrics')
    DROP TABLE gold.daily_metrics;

CREATE TABLE gold.daily_metrics (
    metric_date DATE PRIMARY KEY,
    total_transactions INT NOT NULL DEFAULT 0,
    total_revenue DECIMAL(15,2) NOT NULL DEFAULT 0,
    avg_transaction_value DECIMAL(10,2),
    median_transaction_value DECIMAL(10,2),
    total_basket_size INT,
    avg_basket_size DECIMAL(8,2),
    unique_facial_ids INT,
    unique_stores INT,
    top_performing_store_id INT,
    top_performing_region NVARCHAR(100),
    top_category NVARCHAR(256),
    top_brand NVARCHAR(256),
    json_extraction_success_rate DECIMAL(8,4),
    data_quality_score DECIMAL(8,4),
    conversation_score_avg DECIMAL(8,4),
    last_updated DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_gold_daily_date (metric_date DESC)
) WITH (DATA_COMPRESSION = PAGE);

-- =====================================================
-- MIGRATION PROCEDURES
-- =====================================================

-- Migrate from dbo.SalesInteractions
CREATE OR ALTER PROCEDURE dbo.sp_MigrateSalesInteractions
    @SinceDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @SinceDate IS NULL
        SET @SinceDate = DATEADD(DAY, -30, CAST(GETUTCDATE() AS DATE));

    INSERT INTO silver.transactions (
        canonical_tx_id, interaction_id, transaction_date, transaction_time,
        created_date, customer_facial_id, customer_age, customer_gender,
        conversation_score, store_id, demographics_combined,
        time_bucket, is_weekday, confidence_score
    )
    SELECT
        si.canonical_tx_id,
        si.InteractionID,
        CAST(si.TransactionDate AS DATE),               -- Single authoritative date
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
        0.95 as confidence_score
    FROM dbo.SalesInteractions si
    WHERE CAST(si.TransactionDate AS DATE) >= @SinceDate
    AND NOT EXISTS (
        SELECT 1 FROM silver.transactions st
        WHERE st.canonical_tx_id = si.canonical_tx_id
    );

    SELECT @@ROWCOUNT AS rows_migrated;
END;
GO

-- Migrate PayloadTransactions with JSON extraction
CREATE OR ALTER PROCEDURE dbo.sp_MigratePayloadTransactions
    @SinceDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @SinceDate IS NULL
        SET @SinceDate = DATEADD(DAY, -30, CAST(GETUTCDATE() AS DATE));

    -- Extract SKU items from JSON
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
        INNER JOIN silver.transactions st ON st.canonical_tx_id = pt.canonical_tx_id
        CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS item
        WHERE pt.payload_json IS NOT NULL
          AND ISJSON(pt.payload_json) = 1
          AND st.transaction_date >= @SinceDate
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

    SELECT @@ROWCOUNT AS items_migrated;
END;
GO

-- Migrate stores
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

    SELECT @@ROWCOUNT AS stores_migrated;
END;
GO

-- Master migration with error handling
CREATE OR ALTER PROCEDURE dbo.sp_MigrateLegacyToMedallion
    @SinceDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @run_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @rows_processed INT = 0;

    BEGIN TRY
        INSERT dbo.etl_execution_log(etl_run_id, etl_name, started_at)
        VALUES(@run_id, 'sp_MigrateLegacyToMedallion', SYSUTCDATETIME());

        PRINT 'Starting medallion migration...';

        -- Step 1: Migrate stores
        EXEC dbo.sp_MigrateStores;

        -- Step 2: Migrate sales interactions
        EXEC dbo.sp_MigrateSalesInteractions @SinceDate;

        -- Step 3: Migrate payload transactions
        EXEC dbo.sp_MigratePayloadTransactions @SinceDate;

        -- Step 4: Update transaction totals
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
        ) item_totals ON st.canonical_tx_id = item_totals.canonical_tx_id
        WHERE st.total_amount IS NULL;

        SET @rows_processed = @@ROWCOUNT;

        UPDATE dbo.etl_execution_log
        SET finished_at = SYSUTCDATETIME(),
            status = 'SUCCESS',
            rows_written = @rows_processed
        WHERE etl_run_id = @run_id;

        PRINT 'Migration completed successfully.';
    END TRY
    BEGIN CATCH
        DECLARE @error_msg NVARCHAR(2048) = ERROR_MESSAGE();

        UPDATE dbo.etl_execution_log
        SET finished_at = SYSUTCDATETIME(),
            status = 'FAILED',
            notes = @error_msg
        WHERE etl_run_id = @run_id;

        THROW;
    END CATCH
END;
GO

-- Record completion metrics
MERGE dbo.data_quality_metrics AS tgt
USING (
    SELECT
        'silver.transactions.count' AS metric_name,
        COUNT(*)*1.0 AS metric_value,
        'silver' AS layer
    FROM silver.transactions
) s ON (
    tgt.metric_date = CAST(SYSUTCDATETIME() AS DATE)
    AND tgt.metric_name = s.metric_name
    AND tgt.layer = s.layer
)
WHEN MATCHED THEN
    UPDATE SET metric_value = s.metric_value
WHEN NOT MATCHED THEN
    INSERT(metric_date, metric_name, metric_value, layer)
    VALUES(CAST(SYSUTCDATETIME() AS DATE), s.metric_name, s.metric_value, s.layer);

UPDATE dbo.etl_execution_log
SET finished_at = SYSUTCDATETIME(),
    status = 'SUCCESS',
    notes = 'Corrected medallion ETL with canonical_tx_id linking and single date source'
WHERE etl_run_id = @run;

COMMIT;
PRINT '✅ Corrected medallion ETL deployment complete with production guardrails.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE();
    INSERT dbo.etl_execution_log(etl_run_id, etl_name, finished_at, status, notes)
    VALUES(NEWID(), N'031_corrected_medallion_etl_hardened', SYSUTCDATETIME(), 'FAILED', @msg);
    THROW;
END CATCH