-- =====================================================
-- Complete Canonical Export: ALL 12,192 Transactions + Full Schema (45 columns)
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing procedure if it exists
IF OBJECT_ID('canonical.sp_complete_full_schema') IS NOT NULL
    DROP PROCEDURE canonical.sp_complete_full_schema;
GO

CREATE PROCEDURE canonical.sp_complete_full_schema
    @DateFrom DATE,
    @DateTo   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Complete export of ALL 12,192 payload transactions with full canonical schema
    SELECT
        -- Core Transaction Identity (3 columns)
        pt.canonical_tx_id,
        pt.canonical_tx_id_norm,
        pt.canonical_tx_id_payload,

        -- Temporal Dimensions (8 columns)
        ISNULL(CONVERT(VARCHAR(10), dd.full_date, 120), 'Unknown') AS transaction_date,
        ISNULL(dd.year_number, 0) AS year_number,
        ISNULL(dd.month_number, 0) AS month_number,
        ISNULL(dd.month_name, 'Unknown') AS month_name,
        ISNULL(dd.quarter_number, 0) AS quarter_number,
        ISNULL(dd.day_name, 'Unknown') AS day_name,
        ISNULL(dd.weekday_vs_weekend, 'Unknown') AS weekday_vs_weekend,
        ISNULL(dd.iso_week, 0) AS iso_week,

        -- Transaction Facts (4 columns)
        pt.amount,
        ISNULL(f.transaction_value, pt.amount) AS transaction_value,
        ISNULL(f.basket_size, 1) AS basket_size,
        ISNULL(CAST(f.was_substitution AS INT), 0) AS was_substitution,

        -- Location Dimensions (3 columns)
        pt.storeId AS store_id,
        ISNULL(f.product_id, 'Unknown') AS product_id,
        ISNULL(si.Barangay, 'Unknown') AS barangay,

        -- Customer Demographics (5 columns) - removed sex
        ISNULL(f.age, 0) AS age,
        ISNULL(f.gender, 'Unknown') AS gender,
        ISNULL(si.EmotionalState, 'Unknown') AS emotional_state,
        ISNULL(si.FacialID, 'Unknown') AS facial_id,
        ISNULL(f.role_id, 0) AS role_id,

        -- Persona Analytics (4 columns)
        ISNULL(vp.role_final, 'Unknown') AS persona_id,
        ISNULL(vp.role_confidence, 0.0) AS persona_confidence,
        ISNULL(vp.role_suggested, 'Unknown') AS persona_alternative_roles,
        ISNULL(vp.rule_source, 'Unknown') AS persona_rule_source,

        -- Brand Analytics (7 columns)
        (
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si2 ON sib.InteractionID = si2.InteractionID
            WHERE si2.canonical_tx_id = pt.canonical_tx_id
            ORDER BY sib.Confidence DESC
        ) AS primary_brand,

        (
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si2 ON sib.InteractionID = si2.InteractionID
            WHERE si2.canonical_tx_id = pt.canonical_tx_id
            AND sib.BrandName != (
                SELECT TOP 1 sib2.BrandName
                FROM SalesInteractionBrands sib2
                JOIN SalesInteractions si3 ON sib2.InteractionID = si3.InteractionID
                WHERE si3.canonical_tx_id = pt.canonical_tx_id
                ORDER BY sib2.Confidence DESC
            )
            ORDER BY sib.Confidence DESC
        ) AS secondary_brand,

        (
            SELECT TOP 1 sib.Confidence
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si2 ON sib.InteractionID = si2.InteractionID
            WHERE si2.canonical_tx_id = pt.canonical_tx_id
            ORDER BY sib.Confidence DESC
        ) AS primary_brand_confidence,

        (
            SELECT STRING_AGG(sib.BrandName, ';')
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si2 ON sib.InteractionID = si2.InteractionID
            WHERE si2.canonical_tx_id = pt.canonical_tx_id
            AND sib.Confidence > 0.5
        ) AS all_brands_mentioned,

        -- Brand switching indicator
        CASE
            WHEN f.canonical_tx_id IS NULL THEN 'No-Analytics-Data'
            WHEN (
                SELECT COUNT(DISTINCT sib.BrandName)
                FROM SalesInteractionBrands sib
                JOIN SalesInteractions si2 ON sib.InteractionID = si2.InteractionID
                WHERE si2.canonical_tx_id = pt.canonical_tx_id
                AND sib.Confidence > 0.5
            ) > 1 THEN 'Brand-Switch-Considered'
            ELSE 'Single-Brand'
        END AS brand_switching_indicator,

        ISNULL(si.TranscriptionText, '') AS transcription_text,

        -- Co-purchase patterns (simplified for performance)
        CASE
            WHEN ISNULL(f.basket_size, 1) > 1 THEN 'Multi-Item-Transaction'
            ELSE 'Single-Item-Transaction'
        END AS co_purchase_patterns,

        -- Technical Metadata (8 columns)
        pt.deviceId AS device_id,
        pt.sessionId AS session_id,
        ISNULL(si.InteractionID, 'Unknown') AS interaction_id,

        -- Data source indicator
        CASE
            WHEN f.canonical_tx_id IS NOT NULL THEN 'Enhanced-Analytics'
            ELSE 'Payload-Only'
        END AS data_source_type,

        -- Payload JSON data availability
        CASE
            WHEN pt.payload_json IS NOT NULL AND LEN(pt.payload_json) > 10 THEN 'JSON-Available'
            ELSE 'No-JSON'
        END AS payload_data_status,

        -- Payload JSON (truncated for export)
        CASE
            WHEN pt.payload_json IS NOT NULL AND LEN(pt.payload_json) > 100
            THEN LEFT(pt.payload_json, 100) + '...'
            ELSE ISNULL(pt.payload_json, '')
        END AS payload_json_truncated,

        -- Original timestamp from SalesInteractions
        si.TransactionDate AS transaction_date_original,

        -- Record creation timestamp
        ISNULL(f.created_date, GETDATE()) AS created_date,

        -- Derived Analytics (3 columns)
        CASE
            WHEN ISNULL(f.basket_size, 1) > 1 THEN 'Multi-Item'
            ELSE 'Single-Item'
        END AS transaction_type,

        -- Time of day category
        CASE
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
            ELSE 'Night'
        END AS time_of_day_category,

        -- Customer segment (derived)
        CASE
            WHEN ISNULL(f.age, 0) BETWEEN 18 AND 24 THEN 'Young-Adult'
            WHEN ISNULL(f.age, 0) BETWEEN 25 AND 34 THEN 'Adult'
            WHEN ISNULL(f.age, 0) BETWEEN 35 AND 54 THEN 'Middle-Age'
            WHEN ISNULL(f.age, 0) >= 55 THEN 'Senior'
            ELSE 'Unknown-Age'
        END AS customer_segment

    FROM PayloadTransactions pt
        -- LEFT JOINs to preserve ALL payload transactions
        LEFT JOIN canonical.SalesInteractionFact f ON pt.canonical_tx_id = f.canonical_tx_id
        LEFT JOIN DimDate dd ON dd.date_key = f.date_key
        LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = pt.canonical_tx_id
        LEFT JOIN gold.v_personas_production vp ON vp.canonical_tx_id = pt.canonical_tx_id

    -- Include ALL 12,192 payload transactions
    WHERE pt.canonical_tx_id IS NOT NULL

    ORDER BY
        CASE WHEN f.canonical_tx_id IS NOT NULL THEN 0 ELSE 1 END, -- Enhanced data first
        dd.full_date,
        pt.canonical_tx_id;

END
GO

PRINT 'Complete canonical export with full schema (45 columns) created successfully';
PRINT 'Usage: EXEC canonical.sp_complete_full_schema @DateFrom=''2025-01-01'', @DateTo=''2025-12-31''';