-- Enhanced ETL Column Mapping with Auto-Sync Infrastructure
-- Includes canonical ID normalization, Change Tracking, and export view

-- 0.1 Ensure system schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='system') EXEC('CREATE SCHEMA system');

-- 0.2 Persisted, normalized canonical id on silver.Transactions
IF COL_LENGTH('silver.Transactions','canonical_tx_id_norm') IS NULL
ALTER TABLE silver.Transactions
ADD canonical_tx_id_norm AS LOWER(REPLACE(canonical_tx_id,'-','')) PERSISTED;

-- Helpful index for joins/exports
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Transactions_CanonNorm' AND object_id=OBJECT_ID('silver.Transactions'))
  CREATE INDEX IX_Transactions_CanonNorm ON silver.Transactions(canonical_tx_id_norm) INCLUDE (transaction_timestamp, amount, basket_count, store_id);

-- 0.3 Change Tracking (database + target tables)
IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
ALTER DATABASE CURRENT SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 7 DAYS, AUTO_CLEANUP = ON);

IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id = OBJECT_ID('silver.Transactions'))
  ALTER TABLE silver.Transactions ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

IF OBJECT_ID('silver.TransactionProducts','U') IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id = OBJECT_ID('silver.TransactionProducts'))
  ALTER TABLE silver.TransactionProducts ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

-- 0.4 Sync state table
IF OBJECT_ID('system.sync_state','U') IS NULL
CREATE TABLE system.sync_state(
  state_id        INT IDENTITY(1,1) PRIMARY KEY,
  last_version    BIGINT NULL,
  last_export_at  DATETIME2 NULL,
  last_export_note NVARCHAR(4000) NULL
);
IF NOT EXISTS (SELECT 1 FROM system.sync_state) INSERT INTO system.sync_state(last_version,last_export_at,last_export_note) VALUES(NULL,NULL,N'bootstrap');

-- 0.5 Canonical export view that NEVER uses payload timestamps
--     (uses silver.Transactions.transaction_timestamp only)
IF OBJECT_ID('gold.vw_FlatExport','V') IS NULL EXEC('CREATE VIEW gold.vw_FlatExport AS SELECT 1 AS x;');
GO
CREATE OR ALTER VIEW gold.vw_FlatExport
AS
SELECT
  -- IDs
  t.canonical_tx_id,
  t.canonical_tx_id_norm,
  t.session_id,
  t.device_id,
  t.store_id,

  -- Store / Geo
  s.store_name,
  g.barangay,
  g.city,
  g.region_name,
  g.latitude,
  g.longitude,

  -- Measures
  t.amount,
  t.basket_count,

  -- Demographics
  t.age,
  t.age_group,
  t.gender,
  t.emotion,
  t.customer_type,

  -- Time (authoritative)
  t.transaction_timestamp                           AS txn_ts,
  CAST(t.transaction_timestamp AS date)             AS transaction_date,
  t.year, t.month, t.day, t.hour, t.daypart, t.weekday, t.is_weekend,

  -- Products (top-level from TP; if multiple lines, this view stays one row per transaction; aggregate examples)
  MAX(tp.brand)                                     AS brand_any,
  MAX(tp.category)                                  AS category_any,

  -- Text
  t.audio_transcript,
  t.products_detected

FROM silver.Transactions t
JOIN dbo.Stores s              ON s.store_id = t.store_id
LEFT JOIN dbo.GeographicHierarchy g ON g.geo_id = s.geo_id
LEFT JOIN silver.TransactionProducts tp ON tp.transaction_id = t.transaction_id
GROUP BY
  t.canonical_tx_id, t.canonical_tx_id_norm, t.session_id, t.device_id, t.store_id,
  s.store_name, g.barangay, g.city, g.region_name, g.latitude, g.longitude,
  t.amount, t.basket_count, t.age, t.age_group, t.gender, t.emotion, t.customer_type,
  t.transaction_timestamp, t.year, t.month, t.day, t.hour, t.daypart, t.weekday, t.is_weekend,
  t.audio_transcript, t.products_detected;
GO

-- 0.6 Narrow read principal (optional)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='scout_reader')
  CREATE USER [scout_reader] WITHOUT LOGIN;
EXEC sp_addrolemember 'db_datareader', 'scout_reader';
GRANT SELECT ON OBJECT::gold.vw_FlatExport TO [scout_reader];

-- Enhanced Column Mapping Tables (from original etl_unified_column_mapper.py)

-- Column mapping history table
IF OBJECT_ID('scout.column_mappings','U') IS NULL
CREATE TABLE scout.column_mappings (
    mapping_id INT IDENTITY(1,1) PRIMARY KEY,
    source_file_pattern NVARCHAR(500) NOT NULL,
    source_column NVARCHAR(255) NOT NULL,
    target_column NVARCHAR(255) NOT NULL,
    confidence_score DECIMAL(5,3) NOT NULL,
    mapping_method NVARCHAR(50) NOT NULL, -- 'exact', 'fuzzy', 'ml', 'manual'
    validated_by NVARCHAR(100) NULL,
    created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
    last_used_at DATETIME2 NULL,
    usage_count INT DEFAULT 0
);

-- ETL job queue
IF OBJECT_ID('scout.etl_queue','U') IS NULL
CREATE TABLE scout.etl_queue (
    job_id INT IDENTITY(1,1) PRIMARY KEY,
    job_type NVARCHAR(50) NOT NULL, -- 'drive_sync', 'excel_import', 'json_parse'
    source_path NVARCHAR(1000) NOT NULL,
    status NVARCHAR(20) DEFAULT 'pending', -- 'pending', 'running', 'completed', 'failed'
    priority INT DEFAULT 5,
    scheduled_at DATETIME2 DEFAULT SYSUTCDATETIME(),
    started_at DATETIME2 NULL,
    completed_at DATETIME2 NULL,
    error_message NVARCHAR(MAX) NULL,
    rows_processed INT NULL,
    metadata NVARCHAR(MAX) NULL -- JSON metadata
);

-- ETL sync log
IF OBJECT_ID('scout.etl_sync_log','U') IS NULL
CREATE TABLE scout.etl_sync_log (
    sync_id INT IDENTITY(1,1) PRIMARY KEY,
    sync_type NVARCHAR(50) NOT NULL,
    source_identifier NVARCHAR(500) NOT NULL,
    sync_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
    records_processed INT NOT NULL,
    records_inserted INT NOT NULL,
    records_updated INT NOT NULL,
    records_failed INT NOT NULL,
    execution_time_ms INT NULL,
    quality_score DECIMAL(5,2) NULL,
    notes NVARCHAR(MAX) NULL
);

-- Data quality metrics
IF OBJECT_ID('scout.data_quality_metrics','U') IS NULL
CREATE TABLE scout.data_quality_metrics (
    metric_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(255) NOT NULL,
    column_name NVARCHAR(255) NULL,
    metric_type NVARCHAR(50) NOT NULL, -- 'completeness', 'uniqueness', 'validity', 'consistency'
    metric_value DECIMAL(10,4) NOT NULL,
    threshold_min DECIMAL(10,4) NULL,
    threshold_max DECIMAL(10,4) NULL,
    status NVARCHAR(20) NOT NULL, -- 'pass', 'warn', 'fail'
    measured_at DATETIME2 DEFAULT SYSUTCDATETIME(),
    measurement_context NVARCHAR(MAX) NULL
);

-- Create indexes for performance
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_column_mappings_pattern' AND object_id=OBJECT_ID('scout.column_mappings'))
  CREATE INDEX IX_column_mappings_pattern ON scout.column_mappings(source_file_pattern, target_column);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_etl_queue_status' AND object_id=OBJECT_ID('scout.etl_queue'))
  CREATE INDEX IX_etl_queue_status ON scout.etl_queue(status, priority, scheduled_at);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_sync_log_type_time' AND object_id=OBJECT_ID('scout.etl_sync_log'))
  CREATE INDEX IX_sync_log_type_time ON scout.etl_sync_log(sync_type, sync_timestamp DESC);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_quality_metrics_table_time' AND object_id=OBJECT_ID('scout.data_quality_metrics'))
  CREATE INDEX IX_quality_metrics_table_time ON scout.data_quality_metrics(table_name, measured_at DESC);