-- =====================================================
-- Complete Canonical Export: ALL 12,192 Transactions (Simplified Start)
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing procedure if it exists
IF OBJECT_ID('canonical.sp_complete_simple') IS NOT NULL
    DROP PROCEDURE canonical.sp_complete_simple;
GO

CREATE PROCEDURE canonical.sp_complete_simple
    @DateFrom DATE,
    @DateTo   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Complete export of ALL 12,192 payload transactions with key columns
    SELECT
        -- Core Transaction Identity (3 columns)
        pt.canonical_tx_id,
        ISNULL(pt.canonical_tx_id_norm, pt.canonical_tx_id) AS canonical_tx_id_norm,
        ISNULL(pt.canonical_tx_id_payload, pt.canonical_tx_id) AS canonical_tx_id_payload,

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
        ISNULL(CAST(f.product_id AS VARCHAR(50)), 'Unknown') AS product_id,
        ISNULL(si.Barangay, 'Unknown') AS barangay,

        -- Customer Demographics (5 columns)
        ISNULL(f.age, 0) AS age,
        ISNULL(f.gender, 'Unknown') AS gender,
        ISNULL(si.EmotionalState, 'Unknown') AS emotional_state,
        ISNULL(CAST(si.FacialID AS VARCHAR(50)), 'Unknown') AS facial_id,
        ISNULL(f.role_id, 0) AS role_id,

        -- Persona Analytics (4 columns)
        ISNULL(vp.role_final, 'Unknown') AS persona_id,
        ISNULL(vp.role_confidence, 0.0) AS persona_confidence,
        ISNULL(vp.role_suggested, 'Unknown') AS persona_alternative_roles,
        ISNULL(vp.rule_source, 'Unknown') AS persona_rule_source,

        -- Technical Metadata (5 columns)
        pt.deviceId AS device_id,
        pt.sessionId AS session_id,
        ISNULL(CAST(si.InteractionID AS VARCHAR(50)), 'Unknown') AS interaction_id,

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

        -- Original timestamp from SalesInteractions
        si.TransactionDate AS transaction_date_original

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
        pt.canonical_tx_id;

END
GO

PRINT 'Complete canonical export (simplified) created successfully';
PRINT 'Usage: EXEC canonical.sp_complete_simple @DateFrom=''2025-01-01'', @DateTo=''2025-12-31''';