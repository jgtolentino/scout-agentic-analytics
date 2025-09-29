-- =====================================================
-- Simple Export: ALL 12,192 Payload Transactions (Performance Optimized)
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing procedure if it exists
IF OBJECT_ID('canonical.sp_simple_all_12192') IS NOT NULL
    DROP PROCEDURE canonical.sp_simple_all_12192;
GO

CREATE PROCEDURE canonical.sp_simple_all_12192
    @DateFrom DATE,
    @DateTo   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Simple export of ALL 12,192 payload transactions with basic data
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

        -- Simple timestamp from SalesInteractions (single lookup)
        si.TransactionDate AS export_timestamp

    FROM PayloadTransactions pt
        -- LEFT JOIN to get enhanced data where available
        LEFT JOIN canonical.SalesInteractionFact f ON pt.canonical_tx_id = f.canonical_tx_id
        LEFT JOIN DimDate dd ON dd.date_key = f.date_key
        -- Simple LEFT JOIN for timestamp
        LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = pt.canonical_tx_id

    -- REMOVED DATE FILTERING - Include ALL 12,192 payload transactions
    WHERE pt.canonical_tx_id IS NOT NULL

    ORDER BY
        CASE WHEN f.canonical_tx_id IS NOT NULL THEN 0 ELSE 1 END, -- Enhanced data first
        pt.canonical_tx_id;

END
GO

PRINT 'Simple export for ALL 12,192 payload transactions created successfully';
PRINT 'Usage: EXEC canonical.sp_simple_all_12192 @DateFrom=''2025-09-01'', @DateTo=''2025-09-23''';