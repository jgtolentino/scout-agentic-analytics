-- =====================================================
-- Working Canonical Flat Export Stored Procedure
-- =====================================================
-- File: sql/procs/canonical_sp_export_working.sql
-- Purpose: One-call CSV export using actual column names
-- Usage: EXEC canonical.sp_export_flat @DateFrom='2025-09-01', @DateTo='2025-09-23'

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

    -- Validate date parameters
    IF @DateFrom IS NULL OR @DateTo IS NULL
    BEGIN
        RAISERROR('Date parameters cannot be NULL', 16, 1);
        RETURN;
    END

    IF @DateFrom > @DateTo
    BEGIN
        RAISERROR('DateFrom cannot be greater than DateTo', 16, 1);
        RETURN;
    END

    -- Export with available columns and joins
    SELECT
        f.canonical_tx_id,
        CONVERT(VARCHAR(10), dd.[Date], 120) AS transaction_date,
        f.transaction_value AS amount,
        f.basket_size,
        f.store_id,
        ISNULL(s.StoreName, 'Unknown') AS store_name,
        ISNULL(r.RegionName, 'Unknown') AS region,
        CASE
            WHEN dt.Hour24 BETWEEN 6 AND 11 THEN 'Morning'
            WHEN dt.Hour24 BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN dt.Hour24 BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS daypart,
        CASE
            WHEN dd.DayOfWeek IN ('Saturday', 'Sunday') THEN 'Weekend'
            ELSE 'Weekday'
        END AS weekday_weekend,
        f.age,
        f.gender,
        CAST(f.was_substitution AS INT) AS substitution_flag,
        FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss') AS export_timestamp

    FROM canonical.SalesInteractionFact f
        -- Core date join for filtering
        LEFT JOIN dbo.DimDate dd ON dd.DateKey = f.date_key

        -- Store and location dimensions
        LEFT JOIN dbo.Stores s ON s.StoreID = f.store_id
        LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID

        -- Time dimensions
        LEFT JOIN dbo.DimTime dt ON dt.TimeKey = f.time_key

    WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo
        AND f.canonical_tx_id IS NOT NULL

    ORDER BY dd.[Date], f.canonical_tx_id;

END
GO

-- Grant execute permissions
GRANT EXECUTE ON canonical.sp_export_flat TO [scout-analytics];
GO

PRINT 'Working canonical flat export stored procedure created successfully';
PRINT 'Usage: EXEC canonical.sp_export_flat @DateFrom=''2025-09-01'', @DateTo=''2025-09-23''';