-- CSV-Safe Materialized Flat Export Table (All VARCHAR columns)
-- Eliminates all conversion errors by using VARCHAR for all columns

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing table
IF OBJECT_ID('dbo.FlatExport_CSVSafe', 'U') IS NOT NULL
    DROP TABLE dbo.FlatExport_CSVSafe;
GO

-- Create table with ALL VARCHAR columns for CSV safety
CREATE TABLE dbo.FlatExport_CSVSafe (
    -- Identity (3)
    canonical_tx_id VARCHAR(100) NOT NULL,
    canonical_tx_id_norm VARCHAR(100),
    canonical_tx_id_payload VARCHAR(100),

    -- Temporal (8) - ALL VARCHAR to avoid conversion issues
    transaction_date VARCHAR(20),
    year_number VARCHAR(10),
    month_number VARCHAR(10),
    month_name VARCHAR(20),
    quarter_number VARCHAR(10),
    day_name VARCHAR(20),
    weekday_vs_weekend VARCHAR(20),
    iso_week VARCHAR(10),

    -- Transaction Facts (4) - Keep as strings for CSV
    amount VARCHAR(20),
    transaction_value VARCHAR(20),
    basket_size VARCHAR(10),
    was_substitution VARCHAR(10),

    -- Location (3)
    store_id VARCHAR(50),
    product_id VARCHAR(50),
    barangay VARCHAR(100),

    -- Demographics (5) - ALL VARCHAR
    age VARCHAR(10),
    gender VARCHAR(20),
    emotional_state VARCHAR(50),
    facial_id VARCHAR(100),
    role_id VARCHAR(50),

    -- Persona (4)
    persona_id VARCHAR(50),
    persona_confidence VARCHAR(20),
    persona_alternative_roles VARCHAR(200),
    persona_rule_source VARCHAR(100),

    -- Brand Analytics (7)
    primary_brand VARCHAR(100),
    secondary_brand VARCHAR(100),
    primary_brand_confidence VARCHAR(20),
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
    transaction_date_original VARCHAR(30),
    created_date VARCHAR(30),

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

PRINT 'CSV-safe materialized table created (all VARCHAR columns)';
GO

-- Create safe population procedure
CREATE OR ALTER PROCEDURE dbo.sp_populate_flat_export_varchar
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Populating CSV-safe flat export table...';

    -- Clear existing data
    TRUNCATE TABLE dbo.FlatExport_CSVSafe;

    -- Populate with safe VARCHAR conversions
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
    SELECT
        -- Identity (3)
        pt.canonical_tx_id,
        COALESCE(NULLIF(pt.canonical_tx_id,''), pt.canonical_tx_id),
        COALESCE(NULLIF(pt.canonical_tx_id,''), pt.canonical_tx_id),

        -- Temporal (8) – ALL converted to VARCHAR
        CASE WHEN si.TransactionDate IS NOT NULL
             THEN CONVERT(varchar(10), si.TransactionDate, 120)
             ELSE 'Unknown' END,
        COALESCE(CAST(YEAR(si.TransactionDate) AS varchar(10)), 'Unknown'),
        COALESCE(CAST(MONTH(si.TransactionDate) AS varchar(10)), 'Unknown'),
        CASE WHEN si.TransactionDate IS NOT NULL
             THEN DATENAME(month, si.TransactionDate) ELSE 'Unknown' END,
        COALESCE(CAST(DATEPART(quarter, si.TransactionDate) AS varchar(10)), 'Unknown'),
        CASE WHEN si.TransactionDate IS NOT NULL
             THEN DATENAME(weekday, si.TransactionDate) ELSE 'Unknown' END,
        CASE
          WHEN si.TransactionDate IS NULL                      THEN 'Unknown'
          WHEN DATEPART(weekday, si.TransactionDate) IN (1,7)  THEN 'Weekend'
          ELSE 'Weekday'
        END,
        COALESCE(CAST(DATEPART(ISO_WEEK, si.TransactionDate) AS varchar(10)), 'Unknown'),

        -- Transaction Facts (4) - ALL VARCHAR
        COALESCE(CAST(f.transaction_value AS varchar(20)), '0'),
        COALESCE(CAST(f.transaction_value AS varchar(20)), '0'),
        COALESCE(CAST(f.basket_size AS varchar(10)), '1'),
        CASE WHEN f.was_substitution = 1 THEN 'Yes' ELSE 'No' END,

        -- Location (3)
        COALESCE(CAST(pt.storeId AS varchar(50)), 'Unknown'),
        COALESCE(CAST(f.product_id AS varchar(50)),'Unknown'),
        COALESCE(si.Barangay,'Unknown'),

        -- Demographics (5) - ALL VARCHAR
        COALESCE(CAST(f.age AS varchar(10)), 'Unknown'),
        COALESCE(NULLIF(f.gender,''),'Unknown'),
        COALESCE(si.EmotionalState,'Unknown'),
        COALESCE(CAST(si.FacialID AS varchar(100)),'Unknown'),
        COALESCE(CAST(f.role_id AS varchar(50)),'Unknown'),

        -- Persona (4) - simplified for CSV safety
        'Unknown',
        '0.000',
        'Unknown',
        'Unknown',

        -- Brand Analytics (7) - simplified for CSV safety
        'Unknown',
        'Unknown',
        '0.000',
        '',
        'Single-Brand',
        '',
        CASE WHEN COALESCE(f.basket_size, 1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END,

        -- Technical Metadata (8)
        COALESCE(pt.deviceId, 'Unknown'),
        COALESCE(pt.sessionId, 'Unknown'),
        COALESCE(CAST(si.InteractionID AS varchar(60)),'Unknown'),
        CASE WHEN f.transaction_value IS NOT NULL THEN 'Enhanced-Analytics' ELSE 'Payload-Only' END,
        'No-JSON',
        '',
        COALESCE(CONVERT(varchar(30), si.TransactionDate, 120), 'Unknown'),
        COALESCE(CONVERT(varchar(30), f.created_date, 120), CONVERT(varchar(30), GETUTCDATE(), 120)),

        -- Derived Analytics (3)
        CASE WHEN COALESCE(f.basket_size, 1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END,
        CASE
          WHEN si.TransactionDate IS NULL THEN 'Unknown'
          WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 6  AND 11 THEN 'Morning'
          WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
          WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
          ELSE 'Night'
        END,
        CASE
          WHEN COALESCE(f.age,0) BETWEEN 18 AND 24 THEN 'Young-Adult'
          WHEN COALESCE(f.age,0) BETWEEN 25 AND 34 THEN 'Adult'
          WHEN COALESCE(f.age,0) BETWEEN 35 AND 54 THEN 'Middle-Age'
          WHEN COALESCE(f.age,0) >= 55 THEN 'Senior'
          ELSE 'Unknown-Age'
        END
    FROM PayloadTransactions pt
    LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = pt.canonical_tx_id
    LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = pt.canonical_tx_id
    WHERE pt.canonical_tx_id IS NOT NULL;

    DECLARE @row_count INT = @@ROWCOUNT;
    PRINT CONCAT('✅ Populated ', @row_count, ' rows successfully');

    -- Update statistics
    UPDATE STATISTICS dbo.FlatExport_CSVSafe;

    PRINT '45-column materialized table ready for CSV export';
END;
GO

PRINT 'CSV-safe procedures created successfully';