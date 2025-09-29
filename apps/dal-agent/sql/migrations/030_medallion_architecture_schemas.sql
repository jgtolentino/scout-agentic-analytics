-- Scout Analytics Medallion Architecture
-- For existing Azure SQL Database: SQL-TBWA-ProjectScout-Reporting-Prod
-- Server: sqltbwaprojectscoutserver.database.windows.net

-- Create schemas for medallion architecture
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze AUTHORIZATION dbo');
    PRINT 'Created schema: bronze';
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA silver AUTHORIZATION dbo');
    PRINT 'Created schema: silver';
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold AUTHORIZATION dbo');
    PRINT 'Created schema: gold';
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'platinum')
BEGIN
    EXEC('CREATE SCHEMA platinum AUTHORIZATION dbo');
    PRINT 'Created schema: platinum';
END

-- BRONZE LAYER: Raw data ingestion
-- =====================================

-- Raw transactions from various sources (JSON format)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('bronze') AND name = 'raw_transactions')
BEGIN
    CREATE TABLE bronze.raw_transactions (
        id BIGINT IDENTITY(1,1) PRIMARY KEY,
        source_file NVARCHAR(500) NULL,
        correlation_id NVARCHAR(100) NULL,
        raw_json NVARCHAR(MAX) NOT NULL,
        ingestion_timestamp DATETIME2 DEFAULT GETUTCDATE(),
        is_processed BIT DEFAULT 0,
        processing_timestamp DATETIME2 NULL,
        error_message NVARCHAR(MAX) NULL,

        -- Indexes for performance
        INDEX idx_bronze_processed (is_processed, ingestion_timestamp),
        INDEX idx_bronze_correlation (correlation_id),
        INDEX idx_bronze_ingestion (ingestion_timestamp DESC)
    );
    PRINT 'Created table: bronze.raw_transactions';
END

-- Raw events and interactions
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('bronze') AND name = 'raw_events')
BEGIN
    CREATE TABLE bronze.raw_events (
        id BIGINT IDENTITY(1,1) PRIMARY KEY,
        event_type NVARCHAR(100),
        event_payload NVARCHAR(MAX),
        event_timestamp DATETIME2 DEFAULT GETUTCDATE(),
        is_processed BIT DEFAULT 0,

        INDEX idx_bronze_events_processed (is_processed, event_timestamp)
    );
    PRINT 'Created table: bronze.raw_events';
END

-- SILVER LAYER: Cleaned and validated data
-- =========================================

-- Cleaned transactions with proper data types
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'transactions')
BEGIN
    CREATE TABLE silver.transactions (
        transaction_id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
        correlation_id NVARCHAR(100),
        store_id INT,
        account_id INT,
        transaction_amount DECIMAL(12,2) NOT NULL,
        confidence_score FLOAT CHECK (confidence_score BETWEEN 0 AND 1),
        transaction_date DATE NOT NULL,
        transaction_hour INT CHECK (transaction_hour BETWEEN 0 AND 23),
        day_of_week NVARCHAR(10),
        time_bucket NVARCHAR(20), -- morning/afternoon/evening/night
        likely_product NVARCHAR(200),
        persona NVARCHAR(100),
        persona_confidence FLOAT CHECK (persona_confidence BETWEEN 0 AND 1),
        recommendation_title NVARCHAR(200),
        revenue_potential DECIMAL(10,2),
        roi DECIMAL(8,4),
        timeline NVARCHAR(50),
        accepted BIT,
        created_at DATETIME2 DEFAULT GETUTCDATE(),
        updated_at DATETIME2 DEFAULT GETUTCDATE(),

        -- Performance indexes
        INDEX idx_silver_date (transaction_date DESC),
        INDEX idx_silver_store_date (store_id, transaction_date),
        INDEX idx_silver_persona (persona, transaction_date),
        INDEX idx_silver_confidence (confidence_score DESC),
        INDEX idx_silver_correlation (correlation_id)
    ) WITH (DATA_COMPRESSION = PAGE);
    PRINT 'Created table: silver.transactions';
END

-- Store master data
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'stores')
BEGIN
    CREATE TABLE silver.stores (
        store_id INT PRIMARY KEY,
        store_name NVARCHAR(200),
        region NVARCHAR(100),
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
    PRINT 'Created table: silver.stores';
END

-- Product master data
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('silver') AND name = 'products')
BEGIN
    CREATE TABLE silver.products (
        product_id INT IDENTITY(1,1) PRIMARY KEY,
        product_name NVARCHAR(200) NOT NULL,
        category NVARCHAR(100),
        brand NVARCHAR(100),
        price_range NVARCHAR(50),
        is_active BIT DEFAULT 1,
        created_at DATETIME2 DEFAULT GETUTCDATE(),

        INDEX idx_silver_products_category (category, brand),
        INDEX idx_silver_products_name (product_name)
    );
    PRINT 'Created table: silver.products';
END

-- GOLD LAYER: Business metrics and aggregations
-- ==============================================

-- Daily aggregated metrics
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'daily_metrics')
BEGIN
    CREATE TABLE gold.daily_metrics (
        metric_date DATE PRIMARY KEY,
        total_transactions INT NOT NULL DEFAULT 0,
        total_revenue DECIMAL(15,2) NOT NULL DEFAULT 0,
        avg_transaction_value DECIMAL(10,2),
        median_transaction_value DECIMAL(10,2),
        unique_stores INT,
        unique_accounts INT,
        top_product NVARCHAR(200),
        top_persona NVARCHAR(100),
        avg_confidence_score FLOAT,
        acceptance_rate FLOAT,
        total_revenue_potential DECIMAL(15,2),
        last_updated DATETIME2 DEFAULT GETUTCDATE(),

        INDEX idx_gold_daily_date (metric_date DESC)
    ) WITH (DATA_COMPRESSION = PAGE);
    PRINT 'Created table: gold.daily_metrics';
END

-- Hourly metrics for time-of-day analysis
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'hourly_metrics')
BEGIN
    CREATE TABLE gold.hourly_metrics (
        metric_date DATE,
        metric_hour INT,
        time_bucket NVARCHAR(20),
        transactions_count INT,
        revenue DECIMAL(12,2),
        avg_confidence FLOAT,
        top_persona NVARCHAR(100),

        PRIMARY KEY (metric_date, metric_hour),
        INDEX idx_gold_hourly_time (metric_date DESC, metric_hour)
    ) WITH (DATA_COMPRESSION = PAGE);
    PRINT 'Created table: gold.hourly_metrics';
END

-- Geographic performance metrics
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'geographic_metrics')
BEGIN
    CREATE TABLE gold.geographic_metrics (
        region NVARCHAR(100),
        province NVARCHAR(100),
        city NVARCHAR(100),
        barangay NVARCHAR(100),
        metric_date DATE,
        transaction_count INT,
        total_revenue DECIMAL(12,2),
        avg_transaction DECIMAL(10,2),
        unique_stores INT,
        top_product NVARCHAR(200),
        market_share DECIMAL(8,4), -- % of total regional revenue

        PRIMARY KEY (region, province, city, barangay, metric_date),
        INDEX idx_gold_geo_region (region, metric_date DESC),
        INDEX idx_gold_geo_revenue (total_revenue DESC)
    ) WITH (DATA_COMPRESSION = PAGE);
    PRINT 'Created table: gold.geographic_metrics';
END

-- Product performance metrics
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'product_metrics')
BEGIN
    CREATE TABLE gold.product_metrics (
        product_name NVARCHAR(200),
        category NVARCHAR(100),
        brand NVARCHAR(100),
        metric_date DATE,
        transaction_count INT,
        total_revenue DECIMAL(12,2),
        avg_price DECIMAL(10,2),
        market_share DECIMAL(8,4),

        PRIMARY KEY (product_name, metric_date),
        INDEX idx_gold_product_category (category, metric_date DESC),
        INDEX idx_gold_product_brand (brand, metric_date DESC)
    ) WITH (DATA_COMPRESSION = PAGE);
    PRINT 'Created table: gold.product_metrics';
END

-- Persona analysis metrics
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'persona_metrics')
BEGIN
    CREATE TABLE gold.persona_metrics (
        persona NVARCHAR(100),
        metric_date DATE,
        transaction_count INT,
        total_revenue DECIMAL(12,2),
        avg_confidence FLOAT,
        acceptance_rate FLOAT,
        avg_revenue_potential DECIMAL(10,2),

        PRIMARY KEY (persona, metric_date),
        INDEX idx_gold_persona_date (metric_date DESC, persona)
    ) WITH (DATA_COMPRESSION = PAGE);
    PRINT 'Created table: gold.persona_metrics';
END

-- Substitution flow analysis
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'substitution_flows')
BEGIN
    CREATE TABLE gold.substitution_flows (
        from_product NVARCHAR(200),
        to_product NVARCHAR(200),
        category NVARCHAR(100),
        frequency INT,
        confidence_score FLOAT,
        period_start DATE,
        period_end DATE,

        PRIMARY KEY (from_product, to_product, period_start),
        INDEX idx_gold_substitution_category (category, frequency DESC)
    );
    PRINT 'Created table: gold.substitution_flows';
END

-- PLATINUM LAYER: AI-enriched insights
-- ====================================

-- AI-generated insights and recommendations
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('platinum') AND name = 'insights')
BEGIN
    CREATE TABLE platinum.insights (
        insight_id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
        insight_type NVARCHAR(50) NOT NULL, -- 'trend', 'anomaly', 'pattern', 'prediction', 'recommendation'
        insight_category NVARCHAR(50), -- 'revenue', 'geographic', 'product', 'persona', 'temporal'
        insight_title NVARCHAR(200),
        insight_text NVARCHAR(MAX),
        confidence_score FLOAT CHECK (confidence_score BETWEEN 0 AND 1),
        action_recommendation NVARCHAR(MAX),
        impact_level NVARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
        generated_by NVARCHAR(50), -- 'adf_pipeline', 'ml_model', 'custom_engine'
        source_data NVARCHAR(MAX), -- JSON with source metrics
        validation_status NVARCHAR(20) DEFAULT 'pending', -- 'pending', 'validated', 'rejected'
        created_at DATETIME2 DEFAULT GETUTCDATE(),
        valid_until DATETIME2,

        INDEX idx_platinum_insights_created (created_at DESC),
        INDEX idx_platinum_insights_type (insight_type, confidence_score DESC),
        INDEX idx_platinum_insights_valid (validation_status, valid_until)
    );
    PRINT 'Created table: platinum.insights';
END

-- Predictive models and their outputs
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('platinum') AND name = 'predictions')
BEGIN
    CREATE TABLE platinum.predictions (
        prediction_id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
        model_name NVARCHAR(100),
        prediction_type NVARCHAR(50), -- 'demand_forecast', 'revenue_prediction', 'customer_behavior'
        target_entity NVARCHAR(100), -- store_id, product_name, region, etc.
        prediction_date DATE,
        predicted_value DECIMAL(15,4),
        confidence_interval_lower DECIMAL(15,4),
        confidence_interval_upper DECIMAL(15,4),
        model_accuracy FLOAT,
        created_at DATETIME2 DEFAULT GETUTCDATE(),

        INDEX idx_platinum_predictions_type (prediction_type, prediction_date DESC),
        INDEX idx_platinum_predictions_entity (target_entity, prediction_date DESC)
    );
    PRINT 'Created table: platinum.predictions';
END

-- PERFORMANCE VIEWS AND INDEXES
-- ==============================

-- Real-time KPI view with indexed computation
IF NOT EXISTS (SELECT * FROM sys.views WHERE schema_id = SCHEMA_ID('gold') AND name = 'v_realtime_kpis')
BEGIN
    EXEC('
    CREATE VIEW gold.v_realtime_kpis
    WITH SCHEMABINDING
    AS
    SELECT
        COUNT_BIG(*) as total_transactions,
        SUM(CAST(transaction_amount AS DECIMAL(20,2))) as total_revenue,
        COUNT_BIG(DISTINCT store_id) as unique_stores,
        COUNT_BIG(DISTINCT account_id) as unique_accounts,
        AVG(CAST(confidence_score AS FLOAT)) as avg_confidence,
        MAX(transaction_date) as latest_transaction_date,
        SUM(CASE WHEN accepted = 1 THEN 1 ELSE 0 END) as accepted_recommendations,
        SUM(CAST(revenue_potential AS DECIMAL(20,2))) as total_revenue_potential
    FROM silver.transactions
    WHERE transaction_date >= DATEADD(day, -30, CAST(GETUTCDATE() AS DATE))
    ');

    -- Create unique clustered index for the indexed view
    CREATE UNIQUE CLUSTERED INDEX idx_v_realtime_kpis
    ON gold.v_realtime_kpis(total_transactions);

    PRINT 'Created indexed view: gold.v_realtime_kpis';
END

-- Columnstore indexes for analytics performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('silver.transactions') AND name = 'cci_silver_transactions')
BEGIN
    CREATE COLUMNSTORE INDEX cci_silver_transactions
    ON silver.transactions (
        transaction_date,
        store_id,
        transaction_amount,
        confidence_score,
        persona,
        time_bucket
    );
    PRINT 'Created columnstore index on silver.transactions';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('gold.daily_metrics') AND name = 'cci_gold_daily')
BEGIN
    CREATE COLUMNSTORE INDEX cci_gold_daily
    ON gold.daily_metrics;
    PRINT 'Created columnstore index on gold.daily_metrics';
END

-- ETL MONITORING AND LOGGING
-- ===========================

-- ETL execution log table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'etl_execution_log')
BEGIN
    CREATE TABLE dbo.etl_execution_log (
        log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        pipeline_name NVARCHAR(200),
        run_id NVARCHAR(100),
        execution_start DATETIME2,
        execution_end DATETIME2,
        duration_seconds AS DATEDIFF(SECOND, execution_start, execution_end),
        status NVARCHAR(20), -- 'success', 'failed', 'running'
        rows_processed INT,
        error_message NVARCHAR(MAX),
        created_at DATETIME2 DEFAULT GETUTCDATE(),

        INDEX idx_etl_log_pipeline (pipeline_name, execution_start DESC),
        INDEX idx_etl_log_status (status, created_at DESC)
    );
    PRINT 'Created table: dbo.etl_execution_log';
END

-- Data quality metrics table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'data_quality_metrics')
BEGIN
    CREATE TABLE dbo.data_quality_metrics (
        metric_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        table_name NVARCHAR(200),
        metric_name NVARCHAR(100),
        metric_value DECIMAL(15,4),
        threshold_value DECIMAL(15,4),
        status NVARCHAR(20), -- 'pass', 'fail', 'warning'
        measured_at DATETIME2 DEFAULT GETUTCDATE(),

        INDEX idx_quality_table (table_name, measured_at DESC),
        INDEX idx_quality_status (status, measured_at DESC)
    );
    PRINT 'Created table: dbo.data_quality_metrics';
END

-- STORED PROCEDURES FOR OPERATIONS
-- =================================

-- Update processing flags in bronze layer
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo') AND name = 'sp_UpdateBronzeProcessed')
BEGIN
    EXEC('
    CREATE PROCEDURE dbo.sp_UpdateBronzeProcessed
        @ProcessingTimestamp DATETIME2 = NULL
    AS
    BEGIN
        SET NOCOUNT ON;

        IF @ProcessingTimestamp IS NULL
            SET @ProcessingTimestamp = GETUTCDATE();

        UPDATE bronze.raw_transactions
        SET is_processed = 1,
            processing_timestamp = @ProcessingTimestamp
        WHERE is_processed = 0
        AND raw_json IS NOT NULL
        AND ISJSON(raw_json) = 1;

        SELECT @@ROWCOUNT as rows_updated;
    END
    ');
    PRINT 'Created procedure: dbo.sp_UpdateBronzeProcessed';
END

-- Log ETL execution
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo') AND name = 'sp_LogETLExecution')
BEGIN
    EXEC('
    CREATE PROCEDURE dbo.sp_LogETLExecution
        @PipelineName NVARCHAR(200),
        @RunId NVARCHAR(100),
        @Status NVARCHAR(20),
        @RowsProcessed INT = NULL,
        @ErrorMessage NVARCHAR(MAX) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;

        -- Try to update existing log entry first
        UPDATE dbo.etl_execution_log
        SET execution_end = GETUTCDATE(),
            status = @Status,
            rows_processed = ISNULL(@RowsProcessed, rows_processed),
            error_message = @ErrorMessage
        WHERE pipeline_name = @PipelineName
        AND run_id = @RunId;

        -- If no existing entry, create new one
        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO dbo.etl_execution_log (
                pipeline_name, run_id, execution_start, execution_end,
                status, rows_processed, error_message
            )
            VALUES (
                @PipelineName, @RunId, GETUTCDATE(), GETUTCDATE(),
                @Status, @RowsProcessed, @ErrorMessage
            );
        END
    END
    ');
    PRINT 'Created procedure: dbo.sp_LogETLExecution';
END

-- Get ETL status
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo') AND name = 'sp_GetETLStatus')
BEGIN
    EXEC('
    CREATE PROCEDURE dbo.sp_GetETLStatus
        @HoursBack INT = 24
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT
            pipeline_name,
            run_id,
            execution_start,
            execution_end,
            duration_seconds,
            status,
            rows_processed,
            error_message,
            created_at
        FROM dbo.etl_execution_log
        WHERE execution_start >= DATEADD(hour, -@HoursBack, GETUTCDATE())
        ORDER BY execution_start DESC;
    END
    ');
    PRINT 'Created procedure: dbo.sp_GetETLStatus';
END

-- Get data quality metrics
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo') AND name = 'sp_GetDataQualityMetrics')
BEGIN
    EXEC('
    CREATE PROCEDURE dbo.sp_GetDataQualityMetrics
    AS
    BEGIN
        SET NOCOUNT ON;

        -- Bronze layer stats
        SELECT
            ''Bronze'' as layer,
            ''raw_transactions'' as table_name,
            COUNT(*) as total_records,
            SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END) as processed_records,
            MAX(ingestion_timestamp) as last_ingestion,
            COUNT(CASE WHEN ISJSON(raw_json) = 0 THEN 1 END) as invalid_json_count
        FROM bronze.raw_transactions

        UNION ALL

        -- Silver layer stats
        SELECT
            ''Silver'' as layer,
            ''transactions'' as table_name,
            COUNT(*) as total_records,
            COUNT(DISTINCT transaction_date) as unique_dates,
            MAX(created_at) as last_update,
            AVG(confidence_score) as avg_confidence
        FROM silver.transactions

        UNION ALL

        -- Gold layer stats
        SELECT
            ''Gold'' as layer,
            ''daily_metrics'' as table_name,
            COUNT(*) as total_records,
            NULL as processed_records,
            MAX(last_updated) as last_update,
            SUM(total_revenue) as total_revenue
        FROM gold.daily_metrics;
    END
    ');
    PRINT 'Created procedure: dbo.sp_GetDataQualityMetrics';
END

PRINT '======================================';
PRINT 'Medallion Architecture Setup Complete!';
PRINT '======================================';
PRINT 'Schemas Created: bronze, silver, gold, platinum';
PRINT 'Tables Created: 15 tables across all layers';
PRINT 'Indexes Created: Clustered, non-clustered, and columnstore indexes';
PRINT 'Views Created: Real-time KPI indexed view';
PRINT 'Procedures Created: ETL operations and monitoring';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Set up Azure Data Factory linked services';
PRINT '2. Create data flows for Bronze → Silver → Gold';
PRINT '3. Configure ETL pipelines and triggers';
PRINT '4. Deploy API endpoints via Azure Functions';
PRINT '======================================';