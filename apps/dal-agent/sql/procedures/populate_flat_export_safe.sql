-- Safe population of materialized flat export table
-- Uses type-safe approach to avoid conversion errors

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER PROCEDURE dbo.sp_populate_flat_export_safe
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Populating materialized flat export table safely...';

    -- Clear existing data
    TRUNCATE TABLE dbo.FlatExport_CSVSafe;

    -- Populate with safe data selection
    WITH si_join AS (
        SELECT
            pt.canonical_tx_id,
            COALESCE(NULLIF(pt.canonical_tx_id,''), pt.canonical_tx_id) AS canonical_tx_id_norm,
            COALESCE(NULLIF(pt.canonical_tx_id,''), pt.canonical_tx_id) AS canonical_tx_id_payload,
            pt.deviceId, pt.sessionId, pt.payload_json,
            pt.storeId,
            si.InteractionID,
            si.TransactionDate,
            si.FacialID,
            si.EmotionalState,
            si.Barangay,
            f.product_id,
            f.age, f.gender, f.role_id,
            COALESCE(f.transaction_value, 0) AS transaction_value,
            COALESCE(f.basket_size, 1) AS basket_size,
            COALESCE(CAST(f.was_substitution AS int), 0) AS was_substitution,
            f.date_key, f.time_key,
            f.created_date
        FROM PayloadTransactions pt
        LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = pt.canonical_tx_id
        LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = pt.canonical_tx_id
        WHERE pt.canonical_tx_id IS NOT NULL
    )
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
        s.canonical_tx_id,
        s.canonical_tx_id_norm,
        s.canonical_tx_id_payload,

        -- Temporal (8) – keep strings as strings, numbers as numbers
        CASE WHEN s.TransactionDate IS NOT NULL
             THEN CONVERT(varchar(10), s.TransactionDate, 120)
             ELSE 'Unknown' END,
        COALESCE(YEAR(s.TransactionDate), 0),
        COALESCE(MONTH(s.TransactionDate), 0),
        CASE WHEN s.TransactionDate IS NOT NULL
             THEN DATENAME(month, s.TransactionDate) ELSE 'Unknown' END,
        COALESCE(DATEPART(quarter, s.TransactionDate), 0),
        CASE WHEN s.TransactionDate IS NOT NULL
             THEN DATENAME(weekday, s.TransactionDate) ELSE 'Unknown' END,
        CASE
          WHEN s.TransactionDate IS NULL                      THEN 'Unknown'
          WHEN DATEPART(weekday, s.TransactionDate) IN (1,7)  THEN 'Weekend'
          ELSE 'Weekday'
        END,
        COALESCE(DATEPART(ISO_WEEK, s.TransactionDate), 0),

        -- Transaction Facts (4)
        s.transaction_value, -- amount
        s.transaction_value,
        s.basket_size,
        s.was_substitution,

        -- Location (3)
        CAST(s.storeId AS varchar(50)),
        COALESCE(CAST(s.product_id AS varchar(50)),'Unknown'),
        COALESCE(s.Barangay,'Unknown'),

        -- Demographics (5)
        COALESCE(s.age, 0),
        COALESCE(NULLIF(s.gender,''),'Unknown'),
        COALESCE(s.EmotionalState,'Unknown'),
        COALESCE(CAST(s.FacialID AS varchar(100)),'Unknown'),
        COALESCE(CAST(s.role_id AS varchar(50)),'Unknown'),

        -- Persona (4) - default values for now
        'Unknown',
        0.000,
        'Unknown',
        'Unknown',

        -- Brand Analytics (7) - simplified for now
        'Unknown',
        'Unknown',
        0.000,
        '',
        'Single-Brand',
        '',
        CASE WHEN s.basket_size > 1 THEN 'Multi-Item' ELSE 'Single-Item' END,

        -- Technical Metadata (8)
        s.deviceId,
        s.sessionId,
        COALESCE(CAST(s.InteractionID AS varchar(60)),'Unknown'),
        CASE WHEN s.transaction_value IS NOT NULL THEN 'Enhanced-Analytics' ELSE 'Payload-Only' END,
        'No-JSON',
        '',
        s.TransactionDate,
        COALESCE(s.created_date, GETUTCDATE()),

        -- Derived Analytics (3)
        CASE WHEN s.basket_size > 1 THEN 'Multi-Item' ELSE 'Single-Item' END,
        CASE
          WHEN s.TransactionDate IS NULL THEN 'Unknown'
          WHEN DATEPART(HOUR, s.TransactionDate) BETWEEN 6  AND 11 THEN 'Morning'
          WHEN DATEPART(HOUR, s.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
          WHEN DATEPART(HOUR, s.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
          ELSE 'Night'
        END,
        CASE
          WHEN COALESCE(s.age,0) BETWEEN 18 AND 24 THEN 'Young-Adult'
          WHEN COALESCE(s.age,0) BETWEEN 25 AND 34 THEN 'Adult'
          WHEN COALESCE(s.age,0) BETWEEN 35 AND 54 THEN 'Middle-Age'
          WHEN COALESCE(s.age,0) >= 55 THEN 'Senior'
          ELSE 'Unknown-Age'
        END
    FROM si_join s;

    DECLARE @row_count INT = @@ROWCOUNT;
    PRINT CONCAT('✅ Populated ', @row_count, ' rows successfully');

    -- Update statistics
    UPDATE STATISTICS dbo.FlatExport_CSVSafe;

    PRINT 'Materialized table ready for export';
END;
GO

PRINT 'Safe population procedure created: dbo.sp_populate_flat_export_safe';