-- =====================================================
-- Canonical Flat Export Stored Procedure
-- =====================================================
-- File: sql/procs/canonical.sp_export_flat.sql
-- Purpose: One-call CSV export procedure for CI and automation
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

    -- Export with comprehensive joins and proper CSV formatting
    SELECT
        f.CanonicalTxID                           AS canonical_tx_id,
        CONVERT(VARCHAR(10), dd.[Date], 120)      AS transaction_date,
        CAST(f.TransactionValue AS DECIMAL(10,2)) AS amount,
        f.BasketSize                              AS basket_size,
        f.StoreID                                 AS store_id,
        ISNULL(s.StoreName, 'Unknown')            AS store_name,
        ISNULL(r.RegionName, 'Unknown')           AS region,
        ISNULL(s.Province, 'Unknown')             AS province,
        ISNULL(s.City, 'Unknown')                 AS city,
        ISNULL(s.Barangay, 'Unknown')             AS barangay,
        ISNULL(f.PaymentMethod, 'Unknown')        AS payment_method,
        CASE
            WHEN dt.Hour24 BETWEEN 6 AND 11 THEN 'Morning'
            WHEN dt.Hour24 BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN dt.Hour24 BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END                                       AS daypart,
        CASE
            WHEN dd.DayOfWeek IN ('Saturday', 'Sunday') THEN 'Weekend'
            ELSE 'Weekday'
        END                                       AS weekday_weekend,
        ISNULL(f.CustomerAge, 'Unknown')          AS age,
        ISNULL(f.CustomerGender, 'Unknown')       AS gender,
        ISNULL(b.BrandName, 'Unknown')            AS brand_mentioned,
        ISNULL(sb.Confidence, 0)                  AS brand_confidence,
        ISNULL(nh.CategoryName, 'Unknown')        AS category,
        ISNULL(f.SubstitutionFlag, 0)             AS substitution_flag,
        -- Copurchase categories (other categories in same basket)
        ISNULL((
            SELECT STRING_AGG(DISTINCT nh2.CategoryName, ';')
            FROM canonical.SalesInteractionFact f2
            LEFT JOIN dbo.Brands b2 ON f2.BrandID = b2.BrandID
            LEFT JOIN ref.NielsenHierarchy nh2 ON b2.CategoryID = nh2.NielsenCategoryID
            WHERE f2.CanonicalTxID = f.CanonicalTxID
            AND nh2.CategoryName != ISNULL(nh.CategoryName, 'Unknown')
            AND nh2.CategoryName IS NOT NULL
        ), 'None')                                AS copurchase_categories,
        -- Export metadata
        FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss') AS export_timestamp

    FROM canonical.SalesInteractionFact f
        -- Core date join for filtering
        JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey

        -- Store and location dimensions
        LEFT JOIN dbo.Stores s ON s.StoreID = f.StoreID
        LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID

        -- Time dimensions
        LEFT JOIN dbo.DimTime dt ON dt.TimeKey = f.TimeKey

        -- Brand and category dimensions
        LEFT JOIN dbo.Brands b ON f.BrandID = b.BrandID
        LEFT JOIN ref.NielsenHierarchy nh ON b.CategoryID = nh.NielsenCategoryID

        -- Sales interaction brands (text mining results)
        LEFT JOIN dbo.SalesInteractionBrands sb ON sb.InteractionID = f.InteractionID

    WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo
        AND f.CanonicalTxID IS NOT NULL

    ORDER BY dd.[Date], f.CanonicalTxID;

END
GO

-- Grant execute permissions
GRANT EXECUTE ON canonical.sp_export_flat TO [scout-analytics];
GO

PRINT 'Canonical flat export stored procedure created successfully';
PRINT 'Usage: EXEC canonical.sp_export_flat @DateFrom=''2025-09-01'', @DateTo=''2025-09-23''';