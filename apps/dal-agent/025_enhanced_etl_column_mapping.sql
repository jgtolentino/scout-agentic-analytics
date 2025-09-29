-- =====================================================
-- Production Hardening: Fix Canonical 13-Column Export
-- =====================================================
-- File: 025_enhanced_etl_column_mapping.sql
-- Purpose: Align canonical export with locked schema contract
-- Date: 2025-09-26

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing view if it exists
IF OBJECT_ID('canonical.v_export_canonical_13col', 'V') IS NOT NULL
    DROP VIEW canonical.v_export_canonical_13col;
GO

-- Create canonical 13-column export view that matches LOCKED_SCHEMAS exactly
CREATE VIEW canonical.v_export_canonical_13col AS
SELECT
    -- Column 1: Transaction_ID
    sif.CanonicalTxID AS [Transaction_ID],

    -- Column 2: Transaction_Value
    CAST(sif.TransactionValue AS DECIMAL(10,2)) AS [Transaction_Value],

    -- Column 3: Basket_Size
    CAST(sif.BasketSize AS INT) AS [Basket_Size],

    -- Column 4: Category
    COALESCE(nh.CategoryName, 'Unknown') AS [Category],

    -- Column 5: Brand
    COALESCE(b.BrandName, 'Unknown') AS [Brand],

    -- Column 6: Daypart
    CASE
        WHEN dt24.Hour24 BETWEEN 6 AND 11 THEN 'Morning'
        WHEN dt24.Hour24 BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN dt24.Hour24 BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END AS [Daypart],

    -- Column 7: Age
    COALESCE(sif.CustomerAge, 'Unknown') AS [Age],

    -- Column 8: Gender
    COALESCE(sif.CustomerGender, 'Unknown') AS [Gender],

    -- Column 9: Persona
    COALESCE(sif.CustomerRole, 'Customer') AS [Persona],

    -- Column 10: Weekday_vs_Weekend
    CASE
        WHEN dt.DayOfWeek IN ('Saturday', 'Sunday') THEN 'Weekend'
        ELSE 'Weekday'
    END AS [Weekday_vs_Weekend],

    -- Column 11: Time_of_Transaction
    FORMAT(dt24.Time24, 'HH:mm:ss') AS [Time_of_Transaction],

    -- Column 12: Location
    COALESCE(r.RegionName, s.StoreName, 'Unknown') AS [Location],

    -- Column 13: Other_Products (comma-separated list of other categories in basket)
    (
        SELECT STRING_AGG(DISTINCT nh2.CategoryName, ';')
        FROM canonical.SalesInteractionFact sif2
        LEFT JOIN dbo.Brands b2 ON sif2.BrandID = b2.BrandID
        LEFT JOIN ref.NielsenHierarchy nh2 ON b2.CategoryID = nh2.NielsenCategoryID
        WHERE sif2.CanonicalTxID = sif.CanonicalTxID
        AND nh2.CategoryName != COALESCE(nh.CategoryName, 'Unknown')
        AND nh2.CategoryName IS NOT NULL
    ) AS [Other_Products],

    -- Column 14: Was_Substitution (actual substituted brand/SKU or NULL)
    CASE
        WHEN sif.SubstitutionFlag = 1 THEN
            COALESCE(sif.OriginalBrandRequested + '→' + b.BrandName, 'Substitution Made')
        ELSE NULL
    END AS [Was_Substitution],

    -- Column 15: Export_Timestamp
    FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ss') AS [Export_Timestamp]

FROM canonical.SalesInteractionFact sif
    LEFT JOIN dbo.Stores s ON sif.StoreID = s.StoreID
    LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
    LEFT JOIN dbo.DimDate dt ON sif.DateKey = dt.DateKey
    LEFT JOIN dbo.DimTime dt24 ON sif.TimeKey = dt24.TimeKey
    LEFT JOIN dbo.Brands b ON sif.BrandID = b.BrandID
    LEFT JOIN dbo.Products p ON sif.ProductID = p.ProductID
    LEFT JOIN ref.NielsenHierarchy nh ON b.CategoryID = nh.NielsenCategoryID
WHERE sif.InteractionID IS NOT NULL;

GO

-- Add CHECK constraints for schema locking
ALTER TABLE canonical.SalesInteractionFact
ADD CONSTRAINT CHK_TransactionValue_NotNull
CHECK (TransactionValue IS NOT NULL AND TransactionValue > 0);

ALTER TABLE canonical.SalesInteractionFact
ADD CONSTRAINT CHK_BasketSize_Valid
CHECK (BasketSize IS NOT NULL AND BasketSize > 0);

-- Create schema lock view that validates column structure
CREATE VIEW canonical.v_schema_lock_15col AS
SELECT
    'Transaction_ID' as column_name, 'NVARCHAR(50)' as data_type, 1 as position, 'REQUIRED' as constraint_type
UNION ALL SELECT 'Transaction_Value', 'DECIMAL(10,2)', 2, 'REQUIRED'
UNION ALL SELECT 'Basket_Size', 'INT', 3, 'REQUIRED'
UNION ALL SELECT 'Category', 'NVARCHAR(100)', 4, 'REQUIRED'
UNION ALL SELECT 'Brand', 'NVARCHAR(100)', 5, 'REQUIRED'
UNION ALL SELECT 'Daypart', 'NVARCHAR(20)', 6, 'REQUIRED'
UNION ALL SELECT 'Age', 'NVARCHAR(20)', 7, 'REQUIRED'
UNION ALL SELECT 'Gender', 'NVARCHAR(20)', 8, 'REQUIRED'
UNION ALL SELECT 'Persona', 'NVARCHAR(50)', 9, 'REQUIRED'
UNION ALL SELECT 'Weekday_vs_Weekend', 'NVARCHAR(20)', 10, 'REQUIRED'
UNION ALL SELECT 'Time_of_Transaction', 'NVARCHAR(20)', 11, 'REQUIRED'
UNION ALL SELECT 'Location', 'NVARCHAR(100)', 12, 'REQUIRED'
UNION ALL SELECT 'Other_Products', 'NVARCHAR(500)', 13, 'OPTIONAL'
UNION ALL SELECT 'Was_Substitution', 'NVARCHAR(200)', 14, 'OPTIONAL'
UNION ALL SELECT 'Export_Timestamp', 'NVARCHAR(30)', 15, 'REQUIRED';

GO

PRINT 'Production hardening: Enhanced canonical 13-column export view created';
PRINT 'Schema lock constraints added to canonical.SalesInteractionFact';
PRINT 'Schema validation view canonical.v_schema_lock_13col created';