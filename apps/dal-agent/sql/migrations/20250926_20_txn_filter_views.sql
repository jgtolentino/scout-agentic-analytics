SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ========================================================================
 * Scout Analytics - Taxonomy Filter Views
 * Migration: 20250926_20_txn_filter_views.sql
 * Purpose: Create category-specific filter views for precise analytics
 * ======================================================================== */

-- Tobacco transaction filter view
CREATE OR ALTER VIEW gold.v_txn_filter_tobacco AS
SELECT
    *,
    CASE
        WHEN Category LIKE '%Tobacco%'
          OR Brand IN ('Marlboro','Philip Morris','Fortune','Hope','Champion')
          OR Product_Name LIKE '%cigarette%'
          OR Product_Name LIKE '%yosi%'
          OR Product_Name LIKE '%stick%'
        THEN 1
        ELSE 0
    END AS IsTobacco
FROM dbo.v_transactions_flat_production;
GO

-- Laundry/Detergent transaction filter view
CREATE OR ALTER VIEW gold.v_txn_filter_laundry AS
SELECT
    *,
    CASE
        WHEN Category LIKE '%Laundry%'
          OR Category LIKE '%Detergent%'
          OR Brand IN ('Tide','Surf','Ariel','Breeze','Pride')
          OR Product_Name LIKE '%detergent%'
          OR Product_Name LIKE '%soap%'
          OR Product_Name LIKE '%sabon%'
          OR Product_Name LIKE '%fabcon%'
        THEN 1
        ELSE 0
    END AS IsLaundry
FROM dbo.v_transactions_flat_production;
GO

-- Co-purchase analysis matrix
CREATE OR ALTER VIEW gold.v_copurchase_matrix AS
WITH basket_categories AS (
    SELECT
        Transaction_ID,
        Category,
        COUNT(*) as Lines_In_Category
    FROM dbo.v_transactions_flat_production
    GROUP BY Transaction_ID, Category
),
category_pairs AS (
    SELECT
        a.Category AS Category_A,
        b.Category AS Category_B,
        a.Transaction_ID,
        1 AS Co_Occurrence
    FROM basket_categories a
    JOIN basket_categories b ON a.Transaction_ID = b.Transaction_ID
    WHERE a.Category < b.Category  -- Avoid duplicates (A,B) = (B,A)
)
SELECT
    Category_A,
    Category_B,
    COUNT(*) AS Txn_CoCount,
    COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT Transaction_ID) FROM dbo.v_transactions_flat_production) AS CoOccurrence_Pct
FROM category_pairs
GROUP BY Category_A, Category_B
HAVING COUNT(*) >= 5  -- Only show meaningful co-occurrences
GO

PRINT '✅ Taxonomy filter views created successfully';
PRINT '🔍 Available views:';
PRINT '   - gold.v_txn_filter_tobacco (IsTobacco flag)';
PRINT '   - gold.v_txn_filter_laundry (IsLaundry flag)';
PRINT '   - gold.v_copurchase_matrix (category co-occurrence analysis)';
GO