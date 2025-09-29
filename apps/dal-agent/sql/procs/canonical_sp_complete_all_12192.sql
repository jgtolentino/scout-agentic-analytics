-- =====================================================
-- Complete Export: ALL 12,192 Payload Transactions
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing procedure if it exists
IF OBJECT_ID('canonical.sp_export_all_12192') IS NOT NULL
    DROP PROCEDURE canonical.sp_export_all_12192;
GO

CREATE PROCEDURE canonical.sp_export_all_12192
    @DateFrom DATE,
    @DateTo   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Export ALL 12,192 payload transactions with enhanced data where available
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

        -- Data source indicator (KEY ADDITION)
        CASE
            WHEN f.canonical_tx_id IS NOT NULL THEN 'Enhanced-Analytics'
            ELSE 'Payload-Only'
        END AS data_source_type,

        -- Brand switching analysis (enhanced data only)
        (
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = pt.canonical_tx_id
            ORDER BY sib.Confidence DESC
        ) AS primary_brand,

        (
            SELECT TOP 1 sib.BrandName
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = pt.canonical_tx_id
            AND sib.BrandName != (
                SELECT TOP 1 sib2.BrandName
                FROM SalesInteractionBrands sib2
                JOIN SalesInteractions si2 ON sib2.InteractionID = si2.InteractionID
                WHERE si2.canonical_tx_id = pt.canonical_tx_id
                ORDER BY sib2.Confidence DESC
            )
            ORDER BY sib.Confidence DESC
        ) AS secondary_brand,

        (
            SELECT TOP 1 sib.Confidence
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = pt.canonical_tx_id
            ORDER BY sib.Confidence DESC
        ) AS primary_brand_confidence,

        (
            SELECT STRING_AGG(sib.BrandName, ';')
            FROM SalesInteractionBrands sib
            JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
            WHERE si.canonical_tx_id = pt.canonical_tx_id
            AND sib.Confidence > 0.5
        ) AS all_brands_mentioned,

        -- Transaction type analysis
        CASE
            WHEN ISNULL(f.basket_size, 1) > 1 THEN 'Multi-Item'
            ELSE 'Single-Item'
        END AS transaction_type,

        -- Brand switching indicator
        CASE
            WHEN f.canonical_tx_id IS NULL THEN 'No-Analytics-Data'
            WHEN (
                SELECT COUNT(DISTINCT sib.BrandName)
                FROM SalesInteractionBrands sib
                JOIN SalesInteractions si ON sib.InteractionID = si.InteractionID
                WHERE si.canonical_tx_id = pt.canonical_tx_id
                AND sib.Confidence > 0.5
            ) > 1 THEN 'Brand-Switch-Considered'
            ELSE 'Single-Brand'
        END AS brand_switching_indicator,

        -- Payload JSON data availability
        CASE
            WHEN pt.payload_json IS NOT NULL AND LEN(pt.payload_json) > 10 THEN 'JSON-Available'
            ELSE 'No-JSON'
        END AS payload_data_status,

        -- Device and session info from payload
        pt.deviceId AS device_id,
        pt.sessionId AS session_id,

        -- Use actual timestamp from SalesInteractions table
        (
            SELECT TOP 1 FORMAT(si.TransactionDate, 'yyyy-MM-ddTHH:mm:ss')
            FROM dbo.SalesInteractions si
            WHERE si.canonical_tx_id = pt.canonical_tx_id
            ORDER BY si.TransactionDate DESC
        ) AS export_timestamp

    FROM PayloadTransactions pt
        -- LEFT JOIN to get enhanced data where available
        LEFT JOIN canonical.SalesInteractionFact f ON pt.canonical_tx_id = f.canonical_tx_id
        LEFT JOIN DimDate dd ON dd.date_key = f.date_key

    -- REMOVED DATE FILTERING - Include ALL 12,192 payload transactions
    WHERE pt.canonical_tx_id IS NOT NULL

    ORDER BY
        CASE WHEN f.canonical_tx_id IS NOT NULL THEN 0 ELSE 1 END, -- Enhanced data first
        dd.full_date,
        pt.canonical_tx_id;

END
GO

PRINT 'Complete export for ALL 12,192 payload transactions created successfully';
PRINT 'Usage: EXEC canonical.sp_export_all_12192 @DateFrom=''2025-09-01'', @DateTo=''2025-09-23''';