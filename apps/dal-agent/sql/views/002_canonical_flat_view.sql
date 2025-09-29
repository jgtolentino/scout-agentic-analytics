-- ========================================================================
-- Canonical Flat Export View - Hardened 13-Column Structure
-- Purpose: Single source of truth for all flat exports with exact schema compliance
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

PRINT 'Creating canonical flat export view...';

-- Create the canonical flat view that EXACTLY matches the 13-column schema
CREATE OR ALTER VIEW gold.v_transactions_flat_canonical AS
WITH base_transactions AS (
    SELECT
        si.canonical_tx_id,
        si.TransactionValue,
        si.TransactionDate,
        si.StoreID,

        -- Enhanced brand extraction (handling JSON truncation)
        CASE
            WHEN ti.brand_name IS NOT NULL AND ti.brand_name != 'unspecified'
                THEN ti.brand_name
            WHEN si.payload_json IS NOT NULL
                THEN COALESCE(
                    -- Extract brand patterns from JSON (first 950 chars)
                    CASE
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%marlboro%' THEN 'Marlboro'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%camel%' THEN 'Camel'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%winston%' THEN 'Winston'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%great%taste%' THEN 'Great Taste'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%nescafe%' THEN 'Nescafé'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%surf%' THEN 'Surf'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%tide%' THEN 'Tide'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%ariel%' THEN 'Ariel'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%downy%' THEN 'Downy'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%colgate%' THEN 'Colgate'
                        ELSE 'Unknown'
                    END,
                    'Unknown'
                )
            ELSE 'Unknown'
        END as brand_name,

        -- Category with fallback chain
        CASE
            WHEN ti.category IS NOT NULL AND ti.category != 'unspecified'
                THEN ti.category
            WHEN nb.category_name IS NOT NULL
                THEN nb.category_name
            ELSE 'unspecified'
        END as category,

        -- Basket size calculation
        COALESCE(
            (SELECT COUNT(DISTINCT item_id)
             FROM dbo.TransactionItems ti2
             WHERE ti2.canonical_tx_id = si.canonical_tx_id),
            1
        ) as basket_size,

        -- Daypart standardization
        CASE
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 5 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
            ELSE 'Night'
        END as daypart,

        -- Demographics parsing (handle various formats)
        COALESCE(
            si.demographics,
            CASE
                WHEN si.estimated_age IS NOT NULL OR si.gender IS NOT NULL
                    THEN CONCAT(
                        COALESCE(CAST(si.estimated_age AS nvarchar), 'Unknown'),
                        ' ',
                        COALESCE(si.gender, 'Unknown'),
                        ' Customer'
                    )
                ELSE 'Unknown Demographics'
            END
        ) as demographics,

        -- Week type classification
        CASE
            WHEN DATEPART(WEEKDAY, si.TransactionDate) IN (1, 7) THEN 'Weekend'
            ELSE 'Weekday'
        END as week_type,

        -- Location hierarchy (prefer more specific)
        COALESCE(
            s.barangay,
            s.city,
            s.region,
            s.StoreName,
            'Unknown Location'
        ) as location,

        ROW_NUMBER() OVER (PARTITION BY si.canonical_tx_id ORDER BY si.TransactionDate) as rn

    FROM dbo.SalesInteractions si
    LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = si.canonical_tx_id
    LEFT JOIN dbo.Stores s ON s.StoreID = si.StoreID
    LEFT JOIN dbo.nielsen_brand_mapping nb ON nb.brand_name = ti.brand_name
    WHERE si.canonical_tx_id IS NOT NULL
),

-- Get co-purchase information
co_purchases AS (
    SELECT
        ti.canonical_tx_id,
        STRING_AGG(
            CASE
                WHEN ti.brand_name IS NOT NULL
                THEN CONCAT(ti.brand_name, ' (', ti.category, ')')
                ELSE ti.category
            END,
            ', '
        ) WITHIN GROUP (ORDER BY ti.brand_name) as other_products
    FROM dbo.TransactionItems ti
    WHERE ti.canonical_tx_id IS NOT NULL
    GROUP BY ti.canonical_tx_id
    HAVING COUNT(*) > 1  -- Only include multi-item transactions
),

-- Get substitution information
substitutions AS (
    SELECT DISTINCT
        se.canonical_tx_id,
        1 as was_substitution
    FROM dbo.substitution_events se
    WHERE se.canonical_tx_id IS NOT NULL
)

SELECT
    /* CANONICAL 13 COLUMNS - EXACT ORDER AND NAMING */

    /* 1 */ bt.canonical_tx_id AS Transaction_ID,

    /* 2 */ CAST(ISNULL(bt.TransactionValue, 0) AS decimal(18,2)) AS Transaction_Value,

    /* 3 */ CAST(bt.basket_size AS int) AS Basket_Size,

    /* 4 */ CAST(bt.category AS nvarchar(256)) AS Category,

    /* 5 */ CAST(bt.brand_name AS nvarchar(256)) AS Brand,

    /* 6 */ CAST(bt.daypart AS nvarchar(32)) AS Daypart,

    /* 7 */ CAST(bt.demographics AS nvarchar(256)) AS Demographics_Age_Gender_Role,

    /* 8 */ CAST(bt.week_type AS nvarchar(32)) AS Weekday_vs_Weekend,

    /* 9 */ CAST(bt.TransactionDate AS time) AS Time_of_Transaction,

    /* 10 */ CAST(bt.location AS nvarchar(256)) AS Location,

    /* 11 */ CAST(cp.other_products AS nvarchar(max)) AS Other_Products,

    /* 12 */ CAST(ISNULL(sub.was_substitution, 0) AS bit) AS Was_Substitution,

    /* 13 */ CAST(SYSUTCDATETIME() AS datetime2) AS Export_Timestamp

FROM base_transactions bt
LEFT JOIN co_purchases cp ON cp.canonical_tx_id = bt.canonical_tx_id
LEFT JOIN substitutions sub ON sub.canonical_tx_id = bt.canonical_tx_id
WHERE bt.rn = 1  -- Ensure 1:1 relationship (no JOIN multiplication)
;
GO

-- Create filtered views for specific categories
CREATE OR ALTER VIEW gold.v_transactions_flat_tobacco AS
SELECT * FROM gold.v_transactions_flat_canonical
WHERE Category LIKE '%Tobacco%'
   OR Brand IN ('Marlboro', 'Camel', 'Winston', 'Philip Morris', 'Chesterfield');
GO

CREATE OR ALTER VIEW gold.v_transactions_flat_laundry AS
SELECT * FROM gold.v_transactions_flat_canonical
WHERE Category LIKE '%Laundry%'
   OR Category LIKE '%Detergent%'
   OR Brand IN ('Surf', 'Tide', 'Ariel', 'Downy');
GO

-- Update the main production view to point to canonical
CREATE OR ALTER VIEW gold.v_transactions_flat_production AS
SELECT * FROM gold.v_transactions_flat_canonical;
GO

PRINT '✅ Canonical flat export view created successfully';
PRINT '✅ Category-specific views created (tobacco, laundry)';
PRINT '✅ Production view updated to use canonical structure';

-- Quick validation check
SELECT
    'Canonical View Validation' as check_type,
    COUNT(*) as total_rows,
    COUNT(DISTINCT Transaction_ID) as unique_transactions,
    COUNT(CASE WHEN Category = 'unspecified' THEN 1 END) as unspecified_category_count,
    COUNT(CASE WHEN Brand = 'Unknown' THEN 1 END) as unknown_brand_count
FROM gold.v_transactions_flat_canonical;

PRINT 'Canonical flat view deployment complete.';