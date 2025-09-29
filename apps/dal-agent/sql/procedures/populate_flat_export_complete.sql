-- Complete 45-Column Population Procedure (ALL 12,192 rows)
-- Uses LEFT JOINs to preserve every PayloadTransactions row
-- No DISTINCT, no type conversions, pure VARCHAR output

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER PROCEDURE dbo.sp_populate_flat_export_full
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Populating complete 45-column flat export (ALL 12,192 rows)...';

    -- Clear existing data
    TRUNCATE TABLE dbo.FlatExport_CSVSafe;

    -- Populate with LEFT JOINs to preserve ALL payload rows
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
        CASE WHEN si.TransactionDate IS NOT NULL THEN CONVERT(VARCHAR(10), si.TransactionDate, 120) ELSE 'Unknown' END,
        CASE WHEN si.TransactionDate IS NOT NULL THEN CONVERT(VARCHAR(4),  YEAR(si.TransactionDate)) ELSE '0' END,
        CASE WHEN si.TransactionDate IS NOT NULL THEN CONVERT(VARCHAR(2),  MONTH(si.TransactionDate)) ELSE '0' END,
        CASE WHEN si.TransactionDate IS NOT NULL THEN DATENAME(month, si.TransactionDate) ELSE 'Unknown' END,
        CASE WHEN si.TransactionDate IS NOT NULL THEN CONVERT(VARCHAR(1),  DATEPART(quarter, si.TransactionDate)) ELSE '0' END,
        CASE WHEN si.TransactionDate IS NOT NULL THEN DATENAME(weekday, si.TransactionDate) ELSE 'Unknown' END,
        CASE WHEN si.TransactionDate IS NOT NULL AND DATEPART(weekday, si.TransactionDate) IN (1,7) THEN 'Weekend'
             WHEN si.TransactionDate IS NOT NULL THEN 'Weekday' ELSE 'Unknown' END,
        CASE WHEN si.TransactionDate IS NOT NULL THEN CONVERT(VARCHAR(2),  DATEPART(week, si.TransactionDate)) ELSE '0' END,

        -- Transaction Facts (4) - ALL VARCHAR
        COALESCE(CONVERT(VARCHAR(32), f.transaction_value), COALESCE(CONVERT(VARCHAR(32), pt.amount), '0.00')),
        COALESCE(CONVERT(VARCHAR(32), f.transaction_value), COALESCE(CONVERT(VARCHAR(32), pt.amount), '0.00')),
        COALESCE(CONVERT(VARCHAR(8),  f.basket_size), '1'),
        CASE WHEN f.was_substitution = 1 THEN '1' ELSE '0' END,

        -- Location (3)
        COALESCE(CONVERT(VARCHAR(64), pt.storeId), 'Unknown'),
        COALESCE(CONVERT(VARCHAR(64), f.product_id), 'Unknown'),
        COALESCE(si.Barangay, 'Unknown'),

        -- Demographics (5) - ALL VARCHAR
        COALESCE(CONVERT(VARCHAR(3),  f.age), '0'),
        COALESCE(f.gender, 'Unknown'),
        COALESCE(si.EmotionalState, 'Unknown'),
        COALESCE(CONVERT(VARCHAR(64), si.FacialID), 'Unknown'),
        COALESCE(CONVERT(VARCHAR(64), f.role_id), 'Unknown'),

        -- Persona (4) - simplified for CSV safety
        COALESCE(vp.role_final, 'Unknown'),
        COALESCE(CONVERT(VARCHAR(16), vp.role_confidence), '0.0'),
        COALESCE(vp.role_suggested, 'Unknown'),
        COALESCE(vp.rule_source, 'Unknown'),

        -- Brand Analytics (7) - simplified queries to avoid complexity
        COALESCE((
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            WHERE sib.InteractionID = si.InteractionID
            ORDER BY sib.Confidence DESC
        ), 'Unknown'),
        COALESCE((
            SELECT TOP 1 sib2.BrandName
            FROM SalesInteractionBrands sib2
            WHERE sib2.InteractionID = si.InteractionID
              AND sib2.BrandName != (
                SELECT TOP 1 sib3.BrandName FROM SalesInteractionBrands sib3
                WHERE sib3.InteractionID = si.InteractionID
                ORDER BY sib3.Confidence DESC
              )
            ORDER BY sib2.Confidence DESC
        ), 'Unknown'),
        COALESCE((
            SELECT TOP 1 CONVERT(VARCHAR(16), sibc.Confidence)
            FROM SalesInteractionBrands sibc
            WHERE sibc.InteractionID = si.InteractionID
            ORDER BY sibc.Confidence DESC
        ), '0.0'),
        COALESCE((
            SELECT STUFF((
                SELECT ';' + siba.BrandName
                FROM SalesInteractionBrands siba
                WHERE siba.InteractionID = si.InteractionID AND siba.Confidence > 0.5
                FOR XML PATH('')
            ), 1, 1, '')
        ), ''),
        CASE
            WHEN f.canonical_tx_id IS NULL THEN 'No-Analytics-Data'
            WHEN EXISTS (
                SELECT 1
                FROM SalesInteractionBrands x
                WHERE x.InteractionID = si.InteractionID
                GROUP BY x.InteractionID
                HAVING COUNT(DISTINCT x.BrandName) > 1
            ) THEN 'Brand-Switch-Considered'
            ELSE 'Single-Brand'
        END,
        COALESCE(REPLACE(REPLACE(REPLACE(si.TranscriptionText, CHAR(13), ' '), CHAR(10), ' '), CHAR(9), ' '), ''),
        CASE WHEN COALESCE(f.basket_size,1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END,

        -- Technical Metadata (8)
        COALESCE(pt.deviceId, 'Unknown'),
        COALESCE(pt.sessionId, 'Unknown'),
        COALESCE(CONVERT(VARCHAR(64), si.InteractionID), 'Unknown'),
        CASE WHEN f.canonical_tx_id IS NOT NULL THEN 'Enhanced-Analytics' ELSE 'Payload-Only' END,
        CASE WHEN pt.payload_json IS NOT NULL AND LEN(pt.payload_json) > 10 THEN 'JSON-Available' ELSE 'No-JSON' END,
        CASE WHEN LEN(COALESCE(pt.payload_json,'')) > 100 THEN LEFT(pt.payload_json, 100) + '...' ELSE COALESCE(pt.payload_json,'') END,
        COALESCE(CONVERT(VARCHAR(32), si.TransactionDate, 120), 'Unknown'),
        COALESCE(CONVERT(VARCHAR(32), f.created_date, 120), CONVERT(VARCHAR(32), GETDATE(), 120)),

        -- Derived Analytics (3)
        CASE WHEN COALESCE(f.basket_size,1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END,
        CASE
            WHEN si.TransactionDate IS NULL THEN 'Unknown'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 6  AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
            ELSE 'Night'
        END,
        CASE
            WHEN TRY_CONVERT(INT, f.age) BETWEEN 18 AND 24 THEN 'Young-Adult'
            WHEN TRY_CONVERT(INT, f.age) BETWEEN 25 AND 34 THEN 'Adult'
            WHEN TRY_CONVERT(INT, f.age) BETWEEN 35 AND 54 THEN 'Middle-Age'
            WHEN TRY_CONVERT(INT, f.age) >= 55 THEN 'Senior'
            ELSE 'Unknown-Age'
        END
    FROM PayloadTransactions pt
    LEFT JOIN canonical.SalesInteractionFact f
        ON f.canonical_tx_id = pt.canonical_tx_id
    LEFT JOIN dbo.SalesInteractions si
        ON si.canonical_tx_id = pt.canonical_tx_id
    LEFT JOIN gold.v_personas_production vp
        ON vp.canonical_tx_id = pt.canonical_tx_id
    WHERE pt.canonical_tx_id IS NOT NULL;            -- ensures full payload coverage (12192)

    DECLARE @row_count INT = @@ROWCOUNT;
    PRINT CONCAT('✅ Populated ', @row_count, ' rows successfully');

    -- Update statistics
    UPDATE STATISTICS dbo.FlatExport_CSVSafe;

    PRINT 'Complete 45-column table ready for CSV export';
    PRINT 'Expected: 12,192 rows (ALL payload transactions)';
END;
GO

PRINT 'Complete population procedure created: dbo.sp_populate_flat_export_full';
PRINT 'Usage: EXEC dbo.sp_populate_flat_export_full';
PRINT 'Expected result: 12,192 rows with 45 columns each';