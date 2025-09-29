-- =====================================================
-- Microsoft Fabric Warehouse DDL for Scout v7
-- Medallion Architecture: Gold and Platinum Schemas
-- =====================================================

-- CONFIGURATION: Replace <LAKEHOUSE_SQL_NAME> with your actual Lakehouse SQL endpoint name
-- Example: MyLakehouse_SQL -> [MyLakehouse_SQL].dbo.silver_transactions

-- =====================================================
-- SCHEMA CREATION
-- =====================================================

IF SCHEMA_ID('gold') IS NULL
    EXEC('CREATE SCHEMA gold');

IF SCHEMA_ID('platinum') IS NULL
    EXEC('CREATE SCHEMA platinum');

PRINT 'Fabric Warehouse schemas created: gold, platinum';

-- =====================================================
-- GOLD LAYER: FACT AND DIMENSION VIEWS
-- =====================================================
-- These views read from Lakehouse Silver tables and provide
-- the canonical data model for analytics and Power BI

-- Gold Dimensions (read from Lakehouse Silver)
CREATE OR ALTER VIEW gold.dim_store AS
SELECT
    store_id,
    store_name,
    region_name,
    province_name,
    municipality_name,
    barangay_name,
    store_type,
    latitude,
    longitude,
    is_active,
    created_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_store
WHERE is_active = 1;

CREATE OR ALTER VIEW gold.dim_brand AS
SELECT
    brand_id,
    brand_name,
    brand_category,
    nielsen_l1_category,
    nielsen_l2_category,
    nielsen_l3_category,
    is_premium,
    market_segment,
    created_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_brand;

CREATE OR ALTER VIEW gold.dim_category AS
SELECT
    category_id,
    category_name,
    parent_category_id,
    category_level,
    nielsen_mapping,
    is_tobacco,
    is_laundry,
    created_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_category;

CREATE OR ALTER VIEW gold.dim_date AS
SELECT
    date_key,
    full_date,
    day_of_week,
    day_name,
    day_of_month,
    day_of_year,
    week_of_year,
    month_number,
    month_name,
    quarter,
    year,
    is_weekend,
    is_payday_period,
    salary_week
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_date;

CREATE OR ALTER VIEW gold.dim_time AS
SELECT
    time_key,
    time_24h,
    hour_24,
    hour_12,
    minute,
    second,
    am_pm,
    daypart,
    business_hours_category
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_time;

-- Gold Fact Tables
CREATE OR ALTER VIEW gold.fact_transactions AS
SELECT
    canonical_tx_id,
    interaction_id,
    store_id,
    customer_id AS facial_id,
    transaction_date,        -- SINGLE authoritative date source
    transaction_time,
    date_key,
    time_key,
    transaction_value,
    basket_size,
    customer_age,
    customer_gender,
    device_id,
    was_substitution,
    conversation_score,
    emotional_state,
    transcript_text,
    hour_24,
    weekday_vs_weekend,
    time_of_day_category,
    business_time_period,
    persona_assigned,
    persona_confidence,
    created_ts
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions;

CREATE OR ALTER VIEW gold.fact_transaction_items AS
SELECT
    canonical_tx_id,
    item_sequence,
    sku,
    item_brand,
    item_category,
    item_qty,
    item_unit_price,
    item_total,
    nielsen_l1,
    nielsen_l2,
    nielsen_l3,
    is_substitution,
    original_sku,
    substitution_reason
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transaction_items;

-- Gold Analytics Mart
CREATE OR ALTER VIEW gold.mart_transactions AS
SELECT
    t.canonical_tx_id,
    t.interaction_id,
    t.store_id,
    t.facial_id,
    t.transaction_date,               -- SINGLE authoritative date
    t.transaction_value,
    t.basket_size,
    t.customer_age,
    t.customer_gender,
    t.hour_24,
    t.weekday_vs_weekend,
    t.time_of_day_category,
    t.business_time_period,
    t.persona_assigned,
    t.persona_confidence,
    s.region_name,
    s.province_name,
    s.municipality_name,
    s.barangay_name,
    s.store_type,
    d.is_weekend,
    d.is_payday_period,
    d.month_name,
    d.quarter,
    d.year,
    tm.daypart
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_transactions t
LEFT JOIN [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_store s
    ON t.store_id = s.store_id
LEFT JOIN [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_date d
    ON t.date_key = d.date_key
LEFT JOIN [<LAKEHOUSE_SQL_NAME>].dbo.silver_dim_time tm
    ON t.time_key = tm.time_key;

-- Gold Market Basket Analysis
CREATE OR ALTER VIEW gold.market_basket_analysis AS
SELECT
    product_a,
    product_b,
    brand_a,
    brand_b,
    category_a,
    category_b,
    transactions_together,
    total_transactions_a,
    total_transactions_b,
    confidence,
    lift,
    support,
    analysis_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_market_basket_analysis
WHERE confidence >= 0.1 AND lift >= 1.0;

-- Gold Nielsen Analytics
CREATE OR ALTER VIEW gold.nielsen_category_metrics AS
SELECT
    nielsen_l1_category,
    nielsen_l2_category,
    nielsen_l3_category,
    analysis_period,
    total_transactions,
    total_revenue,
    unique_customers,
    avg_basket_size,
    market_share_pct,
    growth_rate_pct,
    created_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_nielsen_category_metrics;

CREATE OR ALTER VIEW gold.nielsen_brand_metrics AS
SELECT
    brand_name,
    nielsen_l1_category,
    nielsen_l2_category,
    nielsen_l3_category,
    analysis_period,
    total_transactions,
    total_revenue,
    unique_customers,
    brand_penetration_pct,
    category_share_pct,
    substitution_rate_pct,
    created_date
FROM [<LAKEHOUSE_SQL_NAME>].dbo.silver_nielsen_brand_metrics;

PRINT 'Gold layer views created successfully';

-- =====================================================
-- PLATINUM LAYER: ML REGISTRY AND PREDICTIONS
-- =====================================================
-- Physical tables for ML models, predictions, and insights

-- Model Registry
IF OBJECT_ID('platinum.model_registry','U') IS NULL
CREATE TABLE platinum.model_registry(
    model_id INT IDENTITY(1,1) PRIMARY KEY,
    model_name NVARCHAR(128) NOT NULL,
    task_type NVARCHAR(32) NOT NULL,        -- 'classification', 'regression', 'clustering', 'forecasting'
    framework NVARCHAR(64) NULL,            -- 'sklearn', 'pytorch', 'tensorflow', 'lightgbm'
    owner NVARCHAR(200) NULL,
    description NVARCHAR(1000) NULL,
    tags NVARCHAR(MAX) NULL,                 -- JSON array of tags
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    is_active BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_model UNIQUE(model_name, task_type)
);

-- Model Versions
IF OBJECT_ID('platinum.model_version','U') IS NULL
CREATE TABLE platinum.model_version(
    model_version_id INT IDENTITY(1,1) PRIMARY KEY,
    model_id INT NOT NULL REFERENCES platinum.model_registry(model_id),
    version_label NVARCHAR(64) NOT NULL,
    signature_sha256 CHAR(64) NOT NULL,
    train_data_hash CHAR(64) NULL,
    hyperparams_json NVARCHAR(MAX) NULL,
    feature_columns NVARCHAR(MAX) NULL,      -- JSON array of feature column names
    target_column NVARCHAR(128) NULL,
    model_artifact_path NVARCHAR(500) NULL,
    deployment_status NVARCHAR(32) DEFAULT 'development', -- 'development', 'staging', 'production', 'retired'
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    is_active BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_model_ver UNIQUE(model_id, version_label)
);

-- Model Performance Metrics
IF OBJECT_ID('platinum.model_metric','U') IS NULL
CREATE TABLE platinum.model_metric(
    model_version_id INT NOT NULL REFERENCES platinum.model_version(model_version_id),
    metric_name SYSNAME NOT NULL,           -- 'accuracy', 'precision', 'recall', 'f1', 'auc', 'rmse', 'mae'
    metric_value DECIMAL(18,6) NULL,
    dataset_type NVARCHAR(32) NOT NULL,     -- 'train', 'validation', 'test'
    measured_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_model_metric PRIMARY KEY(model_version_id, metric_name, dataset_type)
);

-- Feature Store
IF OBJECT_ID('platinum.features','U') IS NULL
CREATE TABLE platinum.features(
    feature_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    subject_type VARCHAR(32) NOT NULL,      -- 'customer', 'store', 'product', 'transaction'
    subject_key NVARCHAR(128) NOT NULL,
    feature_date DATE NOT NULL,
    feature_name SYSNAME NOT NULL,
    feature_value_num DECIMAL(18,6) NULL,
    feature_value_str NVARCHAR(500) NULL,
    feature_value_json NVARCHAR(MAX) NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    INDEX IX_features_subject (subject_type, subject_key, feature_date),
    INDEX IX_features_name (feature_name, feature_date),
    CONSTRAINT UQ_features UNIQUE(subject_type, subject_key, feature_date, feature_name)
);

-- Model Predictions
IF OBJECT_ID('platinum.predictions','U') IS NULL
CREATE TABLE platinum.predictions(
    prediction_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    model_version_id INT NOT NULL REFERENCES platinum.model_version(model_version_id),
    subject_type VARCHAR(32) NOT NULL,      -- 'transaction', 'store', 'customer', 'brand'
    subject_key NVARCHAR(128) NOT NULL,
    prediction_date DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    label NVARCHAR(128) NULL,               -- Predicted class/category
    score DECIMAL(18,6) NULL,               -- Prediction score/probability
    confidence DECIMAL(9,6) NULL,           -- Model confidence (0-1)
    prediction_json NVARCHAR(MAX) NULL,     -- Full prediction details
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    INDEX IX_pred_subject (subject_type, subject_key, prediction_date),
    INDEX IX_pred_model (model_version_id, prediction_date),
    CONSTRAINT UQ_pred UNIQUE(model_version_id, subject_type, subject_key, label, prediction_date)
);

-- Business Insights
IF OBJECT_ID('platinum.insights','U') IS NULL
CREATE TABLE platinum.insights(
    insight_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    source NVARCHAR(64) NOT NULL,           -- 'persona', 'market_basket', 'substitution', 'nielsen', 'ml_model'
    entity_type VARCHAR(32) NOT NULL,       -- 'store', 'brand', 'category', 'customer_segment'
    entity_key NVARCHAR(128) NOT NULL,
    insight_date DATE NOT NULL,
    title NVARCHAR(256) NOT NULL,
    summary NVARCHAR(2000) NOT NULL,
    impact_score DECIMAL(9,6) NULL,         -- Business impact score (0-1)
    confidence DECIMAL(9,6) NULL,           -- Insight confidence (0-1)
    evidence_json NVARCHAR(MAX) NULL,       -- Supporting data and metrics
    action_recommended NVARCHAR(1000) NULL,
    status NVARCHAR(32) DEFAULT 'new',      -- 'new', 'reviewed', 'actioned', 'dismissed'
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    reviewed_at DATETIME2(3) NULL,
    reviewed_by NVARCHAR(200) NULL,
    INDEX IX_insight_entity (entity_type, entity_key, insight_date),
    INDEX IX_insight_source (source, insight_date),
    INDEX IX_insight_status (status, created_at),
    CONSTRAINT UQ_ins UNIQUE(source, entity_type, entity_key, insight_date, title)
);

-- Model Experiment Tracking
IF OBJECT_ID('platinum.experiments','U') IS NULL
CREATE TABLE platinum.experiments(
    experiment_id INT IDENTITY(1,1) PRIMARY KEY,
    experiment_name NVARCHAR(128) NOT NULL,
    model_id INT NOT NULL REFERENCES platinum.model_registry(model_id),
    hypothesis NVARCHAR(1000) NULL,
    dataset_config NVARCHAR(MAX) NULL,      -- JSON config for data preparation
    feature_config NVARCHAR(MAX) NULL,      -- JSON config for feature engineering
    training_config NVARCHAR(MAX) NULL,     -- JSON config for model training
    evaluation_config NVARCHAR(MAX) NULL,   -- JSON config for evaluation
    results_json NVARCHAR(MAX) NULL,        -- Experiment results
    status NVARCHAR(32) DEFAULT 'running',  -- 'running', 'completed', 'failed', 'cancelled'
    started_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    completed_at DATETIME2(3) NULL,
    created_by NVARCHAR(200) NULL,
    CONSTRAINT UQ_experiment UNIQUE(experiment_name, model_id)
);

PRINT 'Platinum layer ML registry tables created successfully';

-- =====================================================
-- PERFORMANCE INDEXES
-- =====================================================

-- Additional indexes for performance optimization
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_pred_subject_date' AND object_id=OBJECT_ID('platinum.predictions'))
    CREATE INDEX IX_pred_subject_date ON platinum.predictions(subject_type, subject_key, prediction_date DESC);

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_features_subject_date' AND object_id=OBJECT_ID('platinum.features'))
    CREATE INDEX IX_features_subject_date ON platinum.features(subject_type, subject_key, feature_date DESC);

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_insights_impact' AND object_id=OBJECT_ID('platinum.insights'))
    CREATE INDEX IX_insights_impact ON platinum.insights(impact_score DESC, confidence DESC)
    WHERE impact_score IS NOT NULL AND confidence IS NOT NULL;

PRINT 'Performance indexes created successfully';

-- =====================================================
-- VALIDATION VIEWS
-- =====================================================

-- System health and data quality views
CREATE OR ALTER VIEW gold.data_quality_summary AS
SELECT
    'transactions' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT canonical_tx_id) AS unique_transactions,
    MIN(transaction_date) AS earliest_date,
    MAX(transaction_date) AS latest_date,
    SUM(CASE WHEN transaction_value IS NULL OR transaction_value <= 0 THEN 1 ELSE 0 END) AS invalid_amounts,
    SUM(CASE WHEN customer_age IS NULL OR customer_age < 13 OR customer_age > 100 THEN 1 ELSE 0 END) AS invalid_ages,
    SUM(CASE WHEN customer_gender NOT IN ('Male', 'Female') THEN 1 ELSE 0 END) AS invalid_genders
FROM gold.fact_transactions
UNION ALL
SELECT
    'transaction_items' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT canonical_tx_id) AS unique_transactions,
    NULL AS earliest_date,
    NULL AS latest_date,
    SUM(CASE WHEN item_total IS NULL OR item_total <= 0 THEN 1 ELSE 0 END) AS invalid_amounts,
    SUM(CASE WHEN item_qty IS NULL OR item_qty <= 0 THEN 1 ELSE 0 END) AS invalid_quantities,
    SUM(CASE WHEN sku IS NULL OR LEN(sku) = 0 THEN 1 ELSE 0 END) AS missing_skus;

CREATE OR ALTER VIEW platinum.model_performance_summary AS
SELECT
    r.model_name,
    r.task_type,
    v.version_label,
    v.deployment_status,
    MAX(CASE WHEN m.metric_name = 'accuracy' AND m.dataset_type = 'test' THEN m.metric_value END) AS test_accuracy,
    MAX(CASE WHEN m.metric_name = 'precision' AND m.dataset_type = 'test' THEN m.metric_value END) AS test_precision,
    MAX(CASE WHEN m.metric_name = 'recall' AND m.dataset_type = 'test' THEN m.metric_value END) AS test_recall,
    MAX(CASE WHEN m.metric_name = 'f1' AND m.dataset_type = 'test' THEN m.metric_value END) AS test_f1,
    v.created_at AS version_created,
    COUNT(p.prediction_id) AS prediction_count_7d
FROM platinum.model_registry r
JOIN platinum.model_version v ON r.model_id = v.model_id
LEFT JOIN platinum.model_metric m ON v.model_version_id = m.model_version_id
LEFT JOIN platinum.predictions p ON v.model_version_id = p.model_version_id
    AND p.prediction_date >= DATEADD(day, -7, GETDATE())
WHERE r.is_active = 1 AND v.is_active = 1
GROUP BY r.model_name, r.task_type, v.version_label, v.deployment_status, v.created_at;

PRINT 'Validation views created successfully';

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

PRINT '========================================';
PRINT 'Microsoft Fabric Warehouse DDL Complete';
PRINT '========================================';
PRINT 'Schemas created: gold, platinum';
PRINT 'Gold views: 8 fact/dimension views';
PRINT 'Platinum tables: 7 ML registry tables';
PRINT 'Performance indexes: Optimized for analytics';
PRINT 'Validation views: Data quality monitoring';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Replace <LAKEHOUSE_SQL_NAME> with your Lakehouse SQL endpoint';
PRINT '2. Run Silver ETL notebooks to populate Lakehouse tables';
PRINT '3. Verify all views resolve correctly';
PRINT '4. Connect Power BI to gold schema views';
PRINT '========================================';