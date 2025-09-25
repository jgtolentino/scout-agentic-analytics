SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ========================================================================
 * Scout Analytics - Item-Level Helper Views
 * Migration: 20250926_21_itemlevel_helpers.sql
 * Purpose: Create item-level analysis views for detailed product insights
 * ======================================================================== */

-- Tobacco sticks per transaction analysis (transaction-level estimation)
CREATE OR ALTER VIEW gold.v_tobacco_sticks_per_tx AS
SELECT
    canonical_tx_id AS Transaction_ID,
    product_name,
    brand,
    total_items,
    CASE
        -- Extract pack size from product name patterns
        WHEN product_name LIKE '%20s%' OR product_name LIKE '%20 stick%' THEN 20
        WHEN product_name LIKE '%10s%' OR product_name LIKE '%10 stick%' THEN 10
        WHEN product_name LIKE '%5s%' OR product_name LIKE '%5 stick%' THEN 5
        WHEN product_name LIKE '%stick%' AND product_name LIKE '%tingi%' THEN 1
        -- Brand-specific pack sizes (heuristics)
        WHEN brand IN ('Marlboro','Philip Morris') THEN 20
        WHEN product_name LIKE '%pack%' THEN 20
        ELSE 20  -- Default assumption for tobacco products
    END AS Sticks_Per_Pack,
    total_items *
    CASE
        WHEN product_name LIKE '%20s%' OR product_name LIKE '%20 stick%' THEN 20
        WHEN product_name LIKE '%10s%' OR product_name LIKE '%10 stick%' THEN 10
        WHEN product_name LIKE '%5s%' OR product_name LIKE '%5 stick%' THEN 5
        WHEN product_name LIKE '%stick%' AND product_name LIKE '%tingi%' THEN 1
        WHEN brand IN ('Marlboro','Philip Morris') THEN 20
        WHEN product_name LIKE '%pack%' THEN 20
        ELSE 20
    END AS Estimated_Sticks
FROM dbo.v_transactions_flat_production
WHERE category LIKE '%Tobacco%'
   OR brand IN ('Marlboro','Philip Morris','Fortune','Hope','Champion')
   OR product_name LIKE '%cigarette%'
   OR product_name LIKE '%yosi%';
GO

-- Product form analysis (bar vs powder for detergents)
CREATE OR ALTER VIEW gold.v_product_form_analysis AS
SELECT
    canonical_tx_id AS Transaction_ID,
    product_name,
    brand,
    category,
    CASE
        WHEN product_name LIKE '%bar%' OR product_name LIKE '%sabon%' THEN 'Bar'
        WHEN product_name LIKE '%powder%' OR product_name LIKE '%pulbos%' THEN 'Powder'
        WHEN product_name LIKE '%liquid%' OR product_name LIKE '%tubig%' THEN 'Liquid'
        WHEN product_name LIKE '%capsule%' OR product_name LIKE '%pod%' THEN 'Capsule'
        ELSE 'Other/Unknown'
    END AS Product_Form,
    total_items,
    total_amount
FROM dbo.v_transactions_flat_production
WHERE category LIKE '%Laundry%'
   OR category LIKE '%Detergent%'
   OR category LIKE '%Personal Care%';
GO

-- Package size extraction helper
CREATE OR ALTER VIEW gold.v_package_size_analysis AS
WITH size_patterns AS (
    SELECT
        canonical_tx_id AS Transaction_ID,
        product_name,
        brand,
        category,
        -- Extract numeric values from product names
        CASE
            WHEN product_name LIKE '%[0-9][0-9][0-9]ml%' THEN
                TRY_CAST(SUBSTRING(product_name, PATINDEX('%[0-9][0-9][0-9]ml%', product_name), 3) AS int)
            WHEN product_name LIKE '%[0-9][0-9]ml%' THEN
                TRY_CAST(SUBSTRING(product_name, PATINDEX('%[0-9][0-9]ml%', product_name), 2) AS int)
            WHEN product_name LIKE '%[0-9]L%' THEN
                TRY_CAST(SUBSTRING(product_name, PATINDEX('%[0-9]L%', product_name), 1) AS int) * 1000
            WHEN product_name LIKE '%[0-9][0-9]g%' THEN
                TRY_CAST(SUBSTRING(product_name, PATINDEX('%[0-9][0-9]g%', product_name), 2) AS int)
            WHEN product_name LIKE '%sachet%' THEN 10  -- Common sachet size
            ELSE NULL
        END AS Package_Size_ML,
        CASE
            WHEN product_name LIKE '%small%' OR product_name LIKE '%maliit%' THEN 'Small'
            WHEN product_name LIKE '%large%' OR product_name LIKE '%malaki%' THEN 'Large'
            WHEN product_name LIKE '%family%' OR product_name LIKE '%pamilya%' THEN 'Family'
            WHEN product_name LIKE '%sachet%' THEN 'Sachet'
            ELSE 'Standard'
        END AS Size_Category,
        total_items,
        total_amount
    FROM dbo.v_transactions_flat_production
)
SELECT
    *,
    CASE
        WHEN Package_Size_ML IS NULL THEN Size_Category
        WHEN Package_Size_ML <= 50 THEN 'Sachet'
        WHEN Package_Size_ML <= 250 THEN 'Small'
        WHEN Package_Size_ML <= 1000 THEN 'Standard'
        ELSE 'Large'
    END AS Inferred_Size_Category
FROM size_patterns;
GO

-- Fabric conditioner co-purchase analysis
CREATE OR ALTER VIEW gold.v_fabcon_copurchase AS
WITH laundry_baskets AS (
    SELECT DISTINCT canonical_tx_id AS Transaction_ID
    FROM dbo.v_transactions_flat_production
    WHERE category LIKE '%Laundry%' OR category LIKE '%Detergent%'
),
basket_analysis AS (
    SELECT
        lb.Transaction_ID,
        MAX(CASE WHEN f.category LIKE '%Fabric%' OR f.product_name LIKE '%fabcon%' THEN 1 ELSE 0 END) AS Has_Fabcon,
        MAX(CASE WHEN f.category LIKE '%Laundry%' OR f.category LIKE '%Detergent%' THEN 1 ELSE 0 END) AS Has_Detergent,
        AVG(CAST(f.total_items AS float)) AS Total_Items,
        AVG(f.total_amount) AS Basket_Value
    FROM laundry_baskets lb
    JOIN dbo.v_transactions_flat_production f ON f.canonical_tx_id = lb.Transaction_ID
    GROUP BY lb.Transaction_ID
)
SELECT
    Transaction_ID,
    Has_Fabcon,
    Has_Detergent,
    Total_Items,
    Basket_Value,
    CASE
        WHEN Has_Fabcon = 1 AND Has_Detergent = 1 THEN 'Co-Purchase'
        WHEN Has_Detergent = 1 THEN 'Detergent Only'
        ELSE 'Other'
    END AS Purchase_Pattern
FROM basket_analysis;
GO

PRINT '✅ Item-level helper views created successfully';
PRINT '🔍 Available views:';
PRINT '   - gold.v_tobacco_sticks_per_tx (cigarette stick estimation)';
PRINT '   - gold.v_product_form_analysis (bar/powder/liquid classification)';
PRINT '   - gold.v_package_size_analysis (ML/size extraction)';
PRINT '   - gold.v_fabcon_copurchase (fabric conditioner co-purchase patterns)';
GO