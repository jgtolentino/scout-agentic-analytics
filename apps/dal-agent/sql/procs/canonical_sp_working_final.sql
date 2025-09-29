-- =====================================================
-- Final Working Canonical Export Stored Procedure
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing procedure if it exists
IF OBJECT_ID('canonical.sp_export_flat') IS NOT NULL
    DROP PROCEDURE canonical.sp_export_flat;
GO

CREATE PROCEDURE canonical.sp_export_flat
    @DateFrom DATE,
    @DateTo   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Export with actual available columns
    SELECT
        f.canonical_tx_id,
        dd.full_date AS transaction_date,
        f.transaction_value AS amount,
        f.basket_size,
        f.store_id,
        f.age,
        f.gender,
        dd.weekday_vs_weekend,
        dd.day_name,
        CAST(f.was_substitution AS INT) AS substitution_flag,
        FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss') AS export_timestamp

    FROM canonical.SalesInteractionFact f
        LEFT JOIN DimDate dd ON dd.date_key = f.date_key

    WHERE dd.full_date BETWEEN @DateFrom AND @DateTo
        AND f.canonical_tx_id IS NOT NULL

    ORDER BY dd.full_date, f.canonical_tx_id;

END
GO

PRINT 'Final working canonical export stored procedure created';
PRINT 'Usage: EXEC canonical.sp_export_flat @DateFrom=''2025-09-01'', @DateTo=''2025-09-23''';