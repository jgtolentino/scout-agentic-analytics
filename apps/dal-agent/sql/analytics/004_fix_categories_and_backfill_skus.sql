-- IMMEDIATE FIX: Category Correction + SKU Backfill
-- Fixes both category misclassification AND populates missing sku_id values

BEGIN TRANSACTION;

-- Step 1: Create temporary mapping table for category fixes
CREATE TABLE #brand_category_authority (
    brand_name NVARCHAR(255) PRIMARY KEY,
    correct_category NVARCHAR(255),
    source_type NVARCHAR(50)
);

-- Step 2: Manual category mappings based on analysis
INSERT INTO #brand_category_authority (brand_name, correct_category, source_type)
VALUES
    ('Alaska', 'Food & Beverages', 'manual_fix'),
    ('C2', 'Beverages', 'manual_fix'),
    ('Kopiko', 'Beverages', 'manual_fix'),
    ('Nido', 'Food & Beverages', 'manual_fix'),
    ('Royal', 'Beverages', 'manual_fix'),
    ('Blend 45', 'Food & Beverages', 'manual_fix'),
    ('Gatorade', 'Beverages', 'manual_fix'),
    ('Great Taste', 'Beverages', 'manual_fix'),
    ('Selecta', 'Food & Beverages', 'manual_fix'),
    ('Cobra', 'Beverages', 'manual_fix'),
    ('Cowhead', 'Food & Beverages', 'manual_fix'),
    ('Ovaltine', 'Beverages', 'manual_fix'),
    ('Red Bull', 'Beverages', 'manual_fix'),
    ('Extra Joss', 'Beverages', 'manual_fix'),
    ('Magnolia', 'Food & Beverages', 'manual_fix'),
    ('Eight O''Clock', 'Pantry Staples & Groceries', 'manual_fix'),
    ('Nestea', 'Beverages', 'manual_fix'),
    ('Café Puro', 'Beverages', 'manual_fix'),
    ('Tang', 'Beverages', 'manual_fix'),
    ('Nescafé', 'Beverages', 'manual_fix'),
    ('Presto', 'Snacks & Confectionery', 'manual_fix');

-- Step 3: Show what will be fixed (VALIDATION)
SELECT
    'CATEGORIES TO BE FIXED' as action_type,
    ti.brand_name,
    ti.category as current_category,
    auth.correct_category as new_category,
    COUNT(*) as affected_rows
FROM dbo.TransactionItems ti
JOIN #brand_category_authority auth ON auth.brand_name = ti.brand_name
WHERE ti.category = 'unspecified'
GROUP BY ti.brand_name, ti.category, auth.correct_category
ORDER BY affected_rows DESC;

-- Step 4: Fix categories immediately
UPDATE ti
SET category = auth.correct_category
FROM dbo.TransactionItems ti
JOIN #brand_category_authority auth ON auth.brand_name = ti.brand_name
WHERE ti.category = 'unspecified'
  AND auth.correct_category IS NOT NULL;

SELECT @@ROWCOUNT as categories_fixed;

-- Step 5: SKU Backfill from JSON payload data
-- First, let's check if we have access to the original JSON payload
DECLARE @has_payload_table BIT = 0;
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PayloadTransactions')
BEGIN
    SET @has_payload_table = 1;
    PRINT 'PayloadTransactions table found - will attempt SKU backfill';
END
ELSE
BEGIN
    PRINT 'PayloadTransactions table not found - skipping SKU backfill';
END

-- SKU backfill logic (only if PayloadTransactions exists)
IF @has_payload_table = 1
BEGIN
    -- Create temporary SKU mapping from JSON payload
    WITH payload_items AS (
        SELECT
            pt.canonical_tx_id,
            item_data.brandName,
            item_data.productName,
            item_data.sku,
            item_data.category
        FROM dbo.PayloadTransactions pt
        CROSS APPLY OPENJSON(pt.transaction_payload, '$.items')
        WITH (
            brandName NVARCHAR(255) '$.brandName',
            productName NVARCHAR(255) '$.productName',
            sku NVARCHAR(255) '$.sku',
            category NVARCHAR(255) '$.category'
        ) as item_data
        WHERE item_data.sku IS NOT NULL
          AND item_data.sku != ''
    ),
    sku_mapping AS (
        SELECT DISTINCT
            pi.brandName as brand_name,
            pi.productName as product_name,
            pi.sku,
            pi.category,
            -- Generate deterministic sku_id from the SKU string
            'SKU_' + UPPER(REPLACE(REPLACE(REPLACE(pi.sku, '-', '_'), ' ', '_'), '.', '_')) as generated_sku_id
        FROM payload_items pi
    )

    -- Update TransactionItems with SKU information
    UPDATE ti
    SET
        sku_id = sm.generated_sku_id,
        -- Also fix category if it's still wrong
        category = CASE
            WHEN ti.category = 'unspecified' AND sm.category IS NOT NULL
            THEN sm.category
            ELSE ti.category
        END
    FROM dbo.TransactionItems ti
    JOIN sku_mapping sm ON sm.brand_name = ti.brand_name
        AND (sm.product_name = ti.item_desc OR ti.item_desc IS NULL)
    WHERE ti.sku_id IS NULL;

    SELECT @@ROWCOUNT as skus_backfilled;
END

-- Step 6: Create/Update reference table for SKU dimensions
IF @has_payload_table = 1
BEGIN
    -- Create or update product dimensions table
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'ref' AND TABLE_NAME = 'sari_sari_product_dimensions')
    BEGIN
        CREATE SCHEMA ref;

        CREATE TABLE ref.sari_sari_product_dimensions (
            sku_id NVARCHAR(255) PRIMARY KEY,
            brand_name NVARCHAR(255),
            sku_name NVARCHAR(255),
            product_name NVARCHAR(255),
            nielsen_category NVARCHAR(255),
            created_date DATETIME2 DEFAULT GETUTCDATE()
        );
    END

    -- Populate reference table from corrected data
    MERGE ref.sari_sari_product_dimensions AS target
    USING (
        SELECT DISTINCT
            ti.sku_id,
            ti.brand_name,
            ti.sku_id as sku_name, -- Use sku_id as sku_name for now
            ti.item_desc as product_name,
            ti.category as nielsen_category
        FROM dbo.TransactionItems ti
        WHERE ti.sku_id IS NOT NULL
          AND ti.brand_name IS NOT NULL
    ) AS source ON target.sku_id = source.sku_id
    WHEN NOT MATCHED THEN
        INSERT (sku_id, brand_name, sku_name, product_name, nielsen_category)
        VALUES (source.sku_id, source.brand_name, source.sku_name, source.product_name, source.nielsen_category)
    WHEN MATCHED THEN
        UPDATE SET
            nielsen_category = source.nielsen_category,
            product_name = COALESCE(source.product_name, target.product_name);

    SELECT @@ROWCOUNT as reference_records_upserted;
END

-- Step 7: Final validation
SELECT
    'FINAL VALIDATION' as status,
    COUNT(*) as total_items,
    SUM(CASE WHEN category = 'unspecified' THEN 1 ELSE 0 END) as still_unspecified,
    SUM(CASE WHEN sku_id IS NOT NULL THEN 1 ELSE 0 END) as items_with_sku,
    SUM(CASE WHEN sku_id IS NULL THEN 1 ELSE 0 END) as items_without_sku,
    CAST(100.0 * SUM(CASE WHEN sku_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) as pct_with_sku
FROM dbo.TransactionItems;

-- Step 8: Show brands that still have unspecified (should be zero for our target brands)
SELECT
    'REMAINING UNSPECIFIED BRANDS' as check_type,
    brand_name,
    COUNT(*) as unspecified_count
FROM dbo.TransactionItems
WHERE category = 'unspecified'
  AND brand_name IN (
    SELECT brand_name FROM #brand_category_authority
  )
GROUP BY brand_name;

-- Step 9: Show new SKU-level data sample
SELECT TOP 10
    'SKU LEVEL SAMPLE' as data_type,
    ti.brand_name,
    ti.sku_id,
    ti.item_desc as product_name,
    ti.category,
    COUNT(*) as transaction_count
FROM dbo.TransactionItems ti
WHERE ti.sku_id IS NOT NULL
GROUP BY ti.brand_name, ti.sku_id, ti.item_desc, ti.category
ORDER BY transaction_count DESC;

-- Cleanup
DROP TABLE #brand_category_authority;

-- COMMIT the transaction (comment out ROLLBACK to apply changes)
PRINT 'Transaction ready to commit. Change ROLLBACK to COMMIT to apply fixes.';
ROLLBACK; -- Change to COMMIT when ready to apply

/*
EXECUTION CHECKLIST:
☐ 1. Review validation results above
☐ 2. Verify the "CATEGORIES TO BE FIXED" output looks correct
☐ 3. Check "REMAINING UNSPECIFIED BRANDS" shows zero
☐ 4. Verify SKU backfill percentage is reasonable
☐ 5. Change ROLLBACK to COMMIT
☐ 6. Re-run your brand mapping export to see clean results
*/