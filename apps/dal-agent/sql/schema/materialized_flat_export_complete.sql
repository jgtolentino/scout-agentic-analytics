-- Complete 45-Column Materialized Flat Export Table (Fixed for ALL 12,192 rows)
-- Eliminates PRIMARY KEY constraint to prevent row loss
-- Uses surrogate key and all VARCHAR columns for CSV safety

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing table
IF OBJECT_ID('dbo.FlatExport_CSVSafe', 'U') IS NOT NULL
    DROP TABLE dbo.FlatExport_CSVSafe;
GO

-- Create table with surrogate key (no PK on canonical_tx_id)
CREATE TABLE dbo.FlatExport_CSVSafe (
    export_row_id           BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- Surrogate key
    canonical_tx_id         VARCHAR(64)  NULL,
    canonical_tx_id_norm    VARCHAR(64)  NULL,
    canonical_tx_id_payload VARCHAR(64)  NULL,

    -- Temporal (8) - ALL VARCHAR
    transaction_date        VARCHAR(10)  NULL,
    year_number             VARCHAR(4)   NULL,
    month_number            VARCHAR(2)   NULL,
    month_name              VARCHAR(12)  NULL,
    quarter_number          VARCHAR(1)   NULL,
    day_name                VARCHAR(12)  NULL,
    weekday_vs_weekend      VARCHAR(8)   NULL,
    iso_week                VARCHAR(2)   NULL,

    -- Transaction Facts (4) - VARCHAR for CSV safety
    amount                  VARCHAR(32)  NULL,
    transaction_value       VARCHAR(32)  NULL,
    basket_size             VARCHAR(8)   NULL,
    was_substitution        VARCHAR(1)   NULL,

    -- Location (3)
    store_id                VARCHAR(64)  NULL,
    product_id              VARCHAR(64)  NULL,
    barangay                VARCHAR(128) NULL,

    -- Demographics (5) - ALL VARCHAR
    age                     VARCHAR(3)   NULL,
    gender                  VARCHAR(32)  NULL,
    emotional_state         VARCHAR(64)  NULL,
    facial_id               VARCHAR(64)  NULL,
    role_id                 VARCHAR(64)  NULL,

    -- Persona (4)
    persona_id              VARCHAR(64)  NULL,
    persona_confidence      VARCHAR(16)  NULL,
    persona_alternative_roles VARCHAR(128) NULL,
    persona_rule_source     VARCHAR(64)  NULL,

    -- Brand Analytics (7)
    primary_brand           VARCHAR(128) NULL,
    secondary_brand         VARCHAR(128) NULL,
    primary_brand_confidence VARCHAR(16) NULL,
    all_brands_mentioned    VARCHAR(8000) NULL,
    brand_switching_indicator VARCHAR(32) NULL,
    transcription_text      VARCHAR(8000) NULL,
    co_purchase_patterns    VARCHAR(128) NULL,

    -- Technical Metadata (8)
    device_id               VARCHAR(64)  NULL,
    session_id              VARCHAR(64)  NULL,
    interaction_id          VARCHAR(64)  NULL,
    data_source_type        VARCHAR(32)  NULL,
    payload_data_status     VARCHAR(16)  NULL,
    payload_json_truncated  VARCHAR(8000) NULL,
    transaction_date_original VARCHAR(32) NULL,
    created_date            VARCHAR(32)  NULL,

    -- Derived Analytics (3)
    transaction_type        VARCHAR(16)  NULL,
    time_of_day_category    VARCHAR(16)  NULL,
    customer_segment        VARCHAR(32)  NULL,

    -- Metadata
    materialized_date       DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- Create index for ordering (not unique)
CREATE INDEX IX_FlatExport_CSVSafe_CanonicalTxId ON dbo.FlatExport_CSVSafe (canonical_tx_id);
CREATE INDEX IX_FlatExport_CSVSafe_ExportRowId ON dbo.FlatExport_CSVSafe (export_row_id);
GO

PRINT 'Complete 45-column materialized table created with surrogate key';
PRINT 'No PRIMARY KEY on canonical_tx_id to prevent row loss';
PRINT 'Ready for population with ALL 12,192 payload rows';