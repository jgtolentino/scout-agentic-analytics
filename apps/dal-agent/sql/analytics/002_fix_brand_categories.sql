-- Fix Brand Categories: No brand should have "unspecified" category
-- Based on analysis of brands_categories_live.csv export

-- This script fixes the critical data quality issue where known brands
-- show as "unspecified" when they should have proper categories.

-- Problem identified:
-- Alaska: 8 transactions correct (Food & Beverages), 277 wrong (unspecified)
-- C2: 16 transactions correct (Beverages), 396 wrong (unspecified)
-- Blend 45: 9 transactions correct, 53 wrong (unspecified)
-- And many others...

-- Strategy: Update transactions to use the correct category for each brand
-- Find the authoritative category for each brand and apply it consistently

BEGIN TRANSACTION;

-- Step 1: Create a temporary table with the authoritative brand-category mapping
-- This uses the non-"unspecified" entries as the source of truth
CREATE TABLE #brand_category_authority (
    brand_name NVARCHAR(255),
    correct_category NVARCHAR(255),
    authoritative_source NVARCHAR(50)
);

-- Step 2: Insert authoritative mappings based on existing correct data
-- Priority: Use most frequent non-"unspecified" category for each brand
INSERT INTO #brand_category_authority (brand_name, correct_category, authoritative_source)
SELECT
    brand_name,
    correct_category,
    'frequency_based'
FROM (
    SELECT
        brand_name,
        category as correct_category,
        COUNT(*) as usage_count,
        ROW_NUMBER() OVER (PARTITION BY brand_name ORDER BY COUNT(*) DESC) as rn
    FROM (
        -- Extract brand-category pairs from all transaction sources
        -- This is a template - actual column names need to be verified
        SELECT DISTINCT
            COALESCE(ti.brand_name, t.Brand) as brand_name,
            COALESCE(ti.category, t.Category) as category
        FROM dbo.v_transactions_flat_production t
        LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id
        WHERE COALESCE(ti.category, t.Category) IS NOT NULL
          AND COALESCE(ti.category, t.Category) != 'unspecified'
          AND COALESCE(ti.category, t.Category) != ''
          AND COALESCE(ti.brand_name, t.Brand) IS NOT NULL
          AND COALESCE(ti.brand_name, t.Brand) != ''
    ) brand_categories
    GROUP BY brand_name, category
) ranked
WHERE rn = 1;

-- Step 3: Add manual overrides for known brands based on export analysis
INSERT INTO #brand_category_authority (brand_name, correct_category, authoritative_source)
VALUES
    ('Alaska', 'Food & Beverages', 'manual_override'),
    ('C2', 'Beverages', 'manual_override'),
    ('Blend 45', 'Food & Beverages', 'manual_override'),
    ('Café Puro', 'Beverages', 'manual_override'),
    ('Cobra', 'Beverages', 'manual_override'),
    ('Extra Joss', 'Beverages', 'manual_override'),
    ('Gatorade', 'Beverages', 'manual_override'),
    ('Great Taste', 'Beverages', 'manual_override'),
    ('Kopiko', 'Beverages', 'manual_override'),
    ('Magnolia', 'Food & Beverages', 'manual_override'),
    ('Nescafé', 'Beverages', 'manual_override'),
    ('Nestea', 'Beverages', 'manual_override'),
    ('Nido', 'Food & Beverages', 'manual_override'),
    ('Ovaltine', 'Beverages', 'manual_override'),
    ('Red Bull', 'Beverages', 'manual_override'),
    ('Royal', 'Beverages', 'manual_override'),
    ('Selecta', 'Food & Beverages', 'manual_override'),
    ('Tang', 'Beverages', 'manual_override'),
    ('Eight O''Clock', 'Pantry Staples & Groceries', 'manual_override'),
    ('Cowhead', 'Food & Beverages', 'manual_override'),
    ('Presto', 'Snacks & Confectionery', 'manual_override')
ON CONFLICT (brand_name) DO UPDATE SET
    correct_category = VALUES(correct_category),
    authoritative_source = VALUES(authoritative_source);

-- Step 4: Show the fix plan before applying
SELECT
    'BEFORE FIX: Brands with unspecified categories' as status,
    brand_name,
    'unspecified' as current_category,
    auth.correct_category as will_become,
    COUNT(*) as affected_transactions
FROM dbo.v_transactions_flat_production t
LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id
JOIN #brand_category_authority auth ON auth.brand_name = COALESCE(ti.brand_name, t.Brand)
WHERE COALESCE(ti.category, t.Category) = 'unspecified'
GROUP BY brand_name, auth.correct_category
ORDER BY affected_transactions DESC;

-- Step 5: Apply the fixes (commented out for safety - uncomment to execute)
/*
-- Update TransactionItems table if it exists and has the columns
UPDATE ti
SET category = auth.correct_category
FROM dbo.TransactionItems ti
JOIN #brand_category_authority auth ON auth.brand_name = ti.brand_name
WHERE ti.category = 'unspecified'
  AND auth.correct_category IS NOT NULL;

-- Update any other source tables that feed the view
-- (Table names and structure need to be verified)
UPDATE source_table
SET Category = auth.correct_category
FROM [actual_source_table_name] source_table
JOIN #brand_category_authority auth ON auth.brand_name = source_table.Brand
WHERE source_table.Category = 'unspecified'
  AND auth.correct_category IS NOT NULL;
*/

-- Step 6: Validation query to confirm the fix
SELECT
    'AFTER FIX VALIDATION' as status,
    brand_name,
    category,
    COUNT(*) as transaction_count,
    CASE
        WHEN category = 'unspecified' THEN '❌ Still broken'
        ELSE '✅ Fixed'
    END as fix_status
FROM (
    SELECT
        COALESCE(ti.brand_name, t.Brand) as brand_name,
        COALESCE(ti.category, t.Category) as category
    FROM dbo.v_transactions_flat_production t
    LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id
    WHERE COALESCE(ti.brand_name, t.Brand) IN (
        SELECT brand_name FROM #brand_category_authority
    )
) fixed_data
GROUP BY brand_name, category
ORDER BY brand_name, category;

-- Cleanup
DROP TABLE #brand_category_authority;

-- COMMIT; -- Uncomment when ready to apply changes
ROLLBACK; -- Safety rollback - remove when ready to commit

/*
EXECUTION INSTRUCTIONS:
1. Review the "BEFORE FIX" results to confirm the scope
2. Verify the table names and column names match your actual schema
3. Uncomment the UPDATE statements in Step 5
4. Change ROLLBACK to COMMIT
5. Run the script
6. Verify using the validation query in Step 6
*/