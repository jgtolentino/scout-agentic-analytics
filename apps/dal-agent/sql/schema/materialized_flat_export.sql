-- Materialized Flat Export Table for High-Performance CSV Exports
-- Materializes the 45-column canonical export for reliable, fast CSV generation
-- Avoids re-computing the view on every export and eliminates JSON parsing issues

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing table if it exists
IF OBJECT_ID('dbo.FlatExport_CSVSafe', 'U') IS NOT NULL
    DROP TABLE dbo.FlatExport_CSVSafe;
GO

-- Create materialized table with proper data types
CREATE TABLE dbo.FlatExport_CSVSafe (
    -- Identity (3)
    canonical_tx_id VARCHAR(100) NOT NULL,
    canonical_tx_id_norm VARCHAR(100),
    canonical_tx_id_payload VARCHAR(100),

    -- Temporal (8)
    transaction_date VARCHAR(20),
    year_number INT,
    month_number INT,
    month_name VARCHAR(20),
    quarter_number INT,
    day_name VARCHAR(20),
    weekday_vs_weekend VARCHAR(20),
    iso_week INT,

    -- Transaction Facts (4)
    amount DECIMAL(18,2),
    transaction_value DECIMAL(18,2),
    basket_size INT,
    was_substitution BIT,

    -- Location (3)
    store_id VARCHAR(50),
    product_id VARCHAR(50),
    barangay VARCHAR(100),

    -- Demographics (5)
    age INT,
    gender VARCHAR(20),
    emotional_state VARCHAR(50),
    facial_id VARCHAR(100),
    role_id VARCHAR(50),

    -- Persona (4)
    persona_id VARCHAR(50),
    persona_confidence DECIMAL(9,3),
    persona_alternative_roles VARCHAR(200),
    persona_rule_source VARCHAR(100),

    -- Brand Analytics (7)
    primary_brand VARCHAR(100),
    secondary_brand VARCHAR(100),
    primary_brand_confidence DECIMAL(9,3),
    all_brands_mentioned VARCHAR(MAX),
    brand_switching_indicator VARCHAR(50),
    transcription_text VARCHAR(MAX),
    co_purchase_patterns VARCHAR(50),

    -- Technical Metadata (8)
    device_id VARCHAR(100),
    session_id VARCHAR(100),
    interaction_id VARCHAR(60),
    data_source_type VARCHAR(50),
    payload_data_status VARCHAR(50),
    payload_json_truncated VARCHAR(200),
    transaction_date_original DATETIME2,
    created_date DATETIME2,

    -- Derived Analytics (3)
    transaction_type VARCHAR(50),
    time_of_day_category VARCHAR(20),
    customer_segment VARCHAR(20),

    -- Metadata
    materialized_date DATETIME2 DEFAULT GETUTCDATE(),

    PRIMARY KEY (canonical_tx_id)
);
GO

-- Create index for fast ordering
CREATE INDEX IX_FlatExport_CSVSafe_TransactionID ON dbo.FlatExport_CSVSafe (canonical_tx_id);
GO

PRINT 'Materialized flat export table created successfully';
PRINT 'Use: EXEC dbo.sp_refresh_flat_export_csvsafe to populate with latest data';
GO

-- Create refresh procedure
CREATE OR ALTER PROCEDURE dbo.sp_refresh_flat_export_csvsafe
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Refreshing materialized flat export table...';

    -- Clear existing data
    TRUNCATE TABLE dbo.FlatExport_CSVSafe;

    -- Populate with fresh data from canonical procedure
    INSERT INTO dbo.FlatExport_CSVSafe (
        canonical_tx_id, canonical_tx_id_norm, canonical_tx_id_payload,
        transaction_date, year_number, month_number, month_name, quarter_number, day_name, weekday_vs_weekend, iso_week,
        amount, transaction_value, basket_size, was_substitution,
        store_id, product_id, barangay,
        age, gender, emotional_state, facial_id, role_id,
        persona_id, persona_confidence, persona_alternative_roles, persona_rule_source,
        primary_brand, secondary_brand, primary_brand_confidence, all_brands_mentioned, brand_switching_indicator, transcription_text, co_purchase_patterns,
        device_id, session_id, interaction_id, data_source_type, payload_data_status, payload_json_truncated, transaction_date_original, created_date,
        transaction_type, time_of_day_category, customer_segment
    )
    EXEC canonical.sp_complete_canonical_45_safe;

    DECLARE @row_count INT = @@ROWCOUNT;
    PRINT CONCAT('✅ Materialized ', @row_count, ' rows successfully');

    -- Update statistics for optimal query performance
    UPDATE STATISTICS dbo.FlatExport_CSVSafe;

    PRINT 'Table ready for high-performance CSV exports';
END;
GO

PRINT 'Refresh procedure created: dbo.sp_refresh_flat_export_csvsafe';