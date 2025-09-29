-- =====================================================
-- Working Export: ALL 12,192 Transactions + Persona Data
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing procedure if it exists
IF OBJECT_ID('canonical.sp_working_with_persona') IS NOT NULL
    DROP PROCEDURE canonical.sp_working_with_persona;
GO

CREATE PROCEDURE canonical.sp_working_with_persona
    @DateFrom DATE,
    @DateTo   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Working export based on proven simple export + persona data
    SELECT
        pt.canonical_tx_id,

        -- Date handling (use fact table date if available, otherwise mark as unknown)
        ISNULL(CONVERT(VARCHAR(10), dd.full_date, 120), 'Unknown') AS transaction_date,

        -- Amount from payload (always available)
        pt.amount,

        -- Enhanced fact data (if matched) or dummy values
        ISNULL(f.basket_size, 1) AS basket_size,
        pt.storeId AS store_id,
        ISNULL(f.age, 0) AS age,
        ISNULL(f.gender, 'Unknown') AS gender,
        ISNULL(dd.weekday_vs_weekend, 'Unknown') AS weekday_vs_weekend,
        ISNULL(dd.day_name, 'Unknown') AS day_name,
        ISNULL(CAST(f.was_substitution AS INT), 0) AS substitution_flag,

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

        -- Device and session info from payload
        pt.deviceId AS device_id,
        pt.sessionId AS session_id,

        -- Timestamp from SalesInteractions
        si.TransactionDate AS export_timestamp,

        -- NEW: Persona Analytics (4 columns)
        ISNULL(vp.role_final, 'Unknown') AS persona_id,
        ISNULL(vp.role_confidence, 0.0) AS persona_confidence,
        ISNULL(vp.role_suggested, 'Unknown') AS persona_alternative_roles,
        ISNULL(vp.rule_source, 'Unknown') AS persona_rule_source,

        -- Additional demographics from SalesInteractions
        ISNULL(si.EmotionalState, 'Unknown') AS emotional_state,
        ISNULL(si.Barangay, 'Unknown') AS barangay,
        ISNULL(si.TranscriptionText, '') AS transcription_text

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

PRINT 'Working export with persona data created successfully';
PRINT 'Usage: EXEC canonical.sp_working_with_persona @DateFrom=''2025-01-01'', @DateTo=''2025-12-31''';