-- =====================================================
-- Scout Lakehouse Warehouse DDL (Gold/Platinum)
-- Microsoft Fabric - Medallion Architecture
-- =====================================================

-- Create schemas for Gold and Platinum layers
IF SCHEMA_ID('gold') IS NULL     EXEC('CREATE SCHEMA gold');
IF SCHEMA_ID('platinum') IS NULL EXEC('CREATE SCHEMA platinum');

PRINT 'Created Gold and Platinum schemas';

-- =====================================================
-- PLATINUM LAYER: ML REGISTRY PATTERN
-- =====================================================

-- Model Registry - Central ML model catalog
IF OBJECT_ID('platinum.model_registry','U') IS NULL
CREATE TABLE platinum.model_registry(
    model_id INT IDENTITY(1,1) PRIMARY KEY,
    model_name NVARCHAR(128) NOT NULL,
    task_type NVARCHAR(32) NOT NULL,  -- classification|regression|reco|nlp|clustering
    framework NVARCHAR(64) NULL,      -- sklearn|pytorch|transformers|spark_ml
    owner NVARCHAR(200) NULL,
    description NVARCHAR(1000) NULL,
    tags NVARCHAR(500) NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    is_active BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_model UNIQUE(model_name, task_type)
);

-- Model Versions - Track model iterations
IF OBJECT_ID('platinum.model_version','U') IS NULL
CREATE TABLE platinum.model_version(
    model_version_id INT IDENTITY(1,1) PRIMARY KEY,
    model_id INT NOT NULL REFERENCES platinum.model_registry(model_id),
    version_label NVARCHAR(64) NOT NULL,
    signature_sha256 CHAR(64) NOT NULL,
    train_data_hash CHAR(64) NULL,
    params_json NVARCHAR(MAX) NULL,
    training_duration_minutes INT NULL,
    training_samples BIGINT NULL,
    validation_samples BIGINT NULL,
    model_size_mb DECIMAL(10,2) NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    deployed_at DATETIME2(3) NULL,
    is_production BIT NOT NULL DEFAULT 0,
    CONSTRAINT UQ_model_ver UNIQUE(model_id, version_label)
);

-- Model Metrics - Performance tracking
IF OBJECT_ID('platinum.model_metric','U') IS NULL
CREATE TABLE platinum.model_metric(
    model_version_id INT NOT NULL REFERENCES platinum.model_version(model_version_id),
    metric_name SYSNAME NOT NULL,        -- accuracy|f1_score|precision|recall|auc|rmse
    metric_value DECIMAL(18,6) NULL,
    metric_type NVARCHAR(32) NULL,       -- training|validation|test|production
    measured_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_model_metric PRIMARY KEY(model_version_id, metric_name, metric_type)
);

-- Feature Store - ML features for training and inference
IF OBJECT_ID('platinum.features','U') IS NULL
CREATE TABLE platinum.features(
    subject_type VARCHAR(32) NOT NULL,     -- tx|store|brand|customer|product
    subject_key NVARCHAR(128) NOT NULL,
    feature_date DATE NOT NULL,
    feature_name SYSNAME NOT NULL,
    feature_value_sql_variant SQL_VARIANT NULL,
    feature_value_float DECIMAL(18,6) NULL,
    feature_value_int BIGINT NULL,
    feature_value_text NVARCHAR(500) NULL,
    data_source NVARCHAR(128) NULL,       -- silver_transactions|gold_analytics|external
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_features PRIMARY KEY(subject_type, subject_key, feature_date, feature_name)
);

-- Predictions - Model inference results
IF OBJECT_ID('platinum.predictions','U') IS NULL
CREATE TABLE platinum.predictions(
    prediction_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    model_version_id INT NOT NULL REFERENCES platinum.model_version(model_version_id),
    subject_type VARCHAR(32) NOT NULL,    -- tx|store|customer|brand
    subject_key NVARCHAR(128) NOT NULL,
    pred_date DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    label NVARCHAR(128) NULL,             -- persona:frequent_buyer|churn_risk:high|segment:premium
    score DECIMAL(18,6) NULL,             -- confidence score or numeric prediction
    confidence DECIMAL(9,6) NULL,        -- model confidence 0-1
    explanation NVARCHAR(1000) NULL,     -- model explanation or feature importance
    extra_json NVARCHAR(MAX) NULL,       -- additional metadata
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_pred UNIQUE(model_version_id, subject_type, subject_key, label, pred_date)
);

-- Insights - Business insights from analysis
IF OBJECT_ID('platinum.insights','U') IS NULL
CREATE TABLE platinum.insights(
    insight_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    source NVARCHAR(64) NOT NULL,        -- persona|conv_intel|basket|substitution|anomaly
    entity_type VARCHAR(32) NOT NULL,    -- store|brand|category|customer_segment|region
    entity_key NVARCHAR(128) NOT NULL,
    insight_date DATE NOT NULL,
    title NVARCHAR(256) NOT NULL,
    summary NVARCHAR(2000) NOT NULL,
    recommendation NVARCHAR(1000) NULL,
    impact_score DECIMAL(9,6) NULL,      -- business impact 0-1
    confidence DECIMAL(9,6) NULL,        -- insight confidence 0-1
    priority NVARCHAR(16) NULL,          -- critical|high|medium|low
    status NVARCHAR(16) NULL,            -- new|acknowledged|acted_upon|dismissed
    evidence_json NVARCHAR(MAX) NULL,    -- supporting data and metrics
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    acknowledged_at DATETIME2(3) NULL,
    acknowledged_by NVARCHAR(200) NULL,
    CONSTRAINT UQ_ins UNIQUE(source, entity_type, entity_key, insight_date, title)
);

-- Experiments - A/B testing and experimentation
IF OBJECT_ID('platinum.experiments','U') IS NULL
CREATE TABLE platinum.experiments(
    experiment_id INT IDENTITY(1,1) PRIMARY KEY,
    experiment_name NVARCHAR(128) NOT NULL,
    description NVARCHAR(1000) NULL,
    hypothesis NVARCHAR(500) NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    status NVARCHAR(32) NOT NULL DEFAULT 'planning',  -- planning|running|completed|paused|cancelled
    owner NVARCHAR(200) NULL,
    success_metric NVARCHAR(128) NULL,
    target_lift_percent DECIMAL(9,2) NULL,
    actual_lift_percent DECIMAL(9,2) NULL,
    statistical_significance DECIMAL(9,6) NULL,
    sample_size BIGINT NULL,
    control_group_size BIGINT NULL,
    treatment_group_size BIGINT NULL,
    config_json NVARCHAR(MAX) NULL,
    results_json NVARCHAR(MAX) NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_experiment UNIQUE(experiment_name, start_date)
);

-- =====================================================
-- PERFORMANCE INDEXES
-- =====================================================

-- Predictions indexes for fast lookup
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_pred_subject' AND object_id=OBJECT_ID('platinum.predictions'))
    CREATE INDEX IX_pred_subject ON platinum.predictions(subject_type, subject_key, pred_date);

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_pred_model' AND object_id=OBJECT_ID('platinum.predictions'))
    CREATE INDEX IX_pred_model ON platinum.predictions(model_version_id, pred_date);

-- Insights indexes for business intelligence
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_insight_entity' AND object_id=OBJECT_ID('platinum.insights'))
    CREATE INDEX IX_insight_entity ON platinum.insights(entity_type, entity_key, insight_date);

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_insight_source' AND object_id=OBJECT_ID('platinum.insights'))
    CREATE INDEX IX_insight_source ON platinum.insights(source, insight_date, priority);

-- Features indexes for ML workflows
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_features_subject' AND object_id=OBJECT_ID('platinum.features'))
    CREATE INDEX IX_features_subject ON platinum.features(subject_type, subject_key, feature_date);

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_features_name' AND object_id=OBJECT_ID('platinum.features'))
    CREATE INDEX IX_features_name ON platinum.features(feature_name, feature_date);

-- =====================================================
-- INITIAL DATA SEEDING
-- =====================================================

-- Seed model registry with common Scout models
IF NOT EXISTS(SELECT 1 FROM platinum.model_registry WHERE model_name = 'customer_persona_classifier')
INSERT INTO platinum.model_registry (model_name, task_type, framework, description, owner)
VALUES
    ('customer_persona_classifier', 'classification', 'sklearn', 'Classifies customers into personas based on transaction behavior', 'Data Science Team'),
    ('churn_predictor', 'classification', 'sklearn', 'Predicts customer churn probability', 'Data Science Team'),
    ('basket_recommender', 'recommendation', 'spark_ml', 'Recommends products for market basket optimization', 'Data Science Team'),
    ('demand_forecaster', 'regression', 'pytorch', 'Forecasts product demand by store and time', 'Data Science Team'),
    ('price_optimizer', 'regression', 'sklearn', 'Optimizes pricing based on demand and competition', 'Data Science Team'),
    ('anomaly_detector', 'classification', 'sklearn', 'Detects anomalous transaction patterns', 'Data Science Team');

PRINT 'Created Platinum layer ML registry tables with sample models';

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

PRINT '========================================';
PRINT 'Warehouse DDL Deployment Complete';
PRINT '========================================';
PRINT 'Schemas created:';
PRINT '  - gold (for analytics views)';
PRINT '  - platinum (for ML registry)';
PRINT '';
PRINT 'Platinum tables created:';
PRINT '  - model_registry (6 sample models)';
PRINT '  - model_version (version tracking)';
PRINT '  - model_metric (performance metrics)';
PRINT '  - features (ML feature store)';
PRINT '  - predictions (inference results)';
PRINT '  - insights (business intelligence)';
PRINT '  - experiments (A/B testing)';
PRINT '';
PRINT 'Indexes created for performance optimization';
PRINT '';
PRINT 'Next step: Execute 02_warehouse_views.sql';
PRINT '========================================';