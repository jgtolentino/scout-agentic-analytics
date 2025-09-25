-- Extract Transaction Items from PayloadTransactions JSON
-- This extracts item-level data from the loaded transaction payloads

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create procedure to extract items from JSON payloads
CREATE OR ALTER PROCEDURE sp_ExtractTransactionItems
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Starting transaction items extraction...';

    -- Clear existing items (in case we're re-running)
    DELETE FROM dbo.TransactionItems;
    PRINT 'Cleared existing TransactionItems';

    -- Extract items from JSON payloads
    INSERT INTO dbo.TransactionItems (
        transaction_id,
        item_name,
        brand_name,
        category,
        subcategory,
        price,
        quantity,
        unit,
        total_amount,
        ai_confidence,
        created_date,
        updated_date
    )
    SELECT
        pt.transaction_id,
        -- Extract item details from JSON array
        JSON_VALUE(item.value, '$.name') as item_name,
        JSON_VALUE(item.value, '$.brand') as brand_name,
        COALESCE(JSON_VALUE(item.value, '$.category'), 'unspecified') as category,
        JSON_VALUE(item.value, '$.subcategory') as subcategory,
        TRY_CAST(JSON_VALUE(item.value, '$.price') as DECIMAL(10,2)) as price,
        TRY_CAST(JSON_VALUE(item.value, '$.quantity') as INT) as quantity,
        JSON_VALUE(item.value, '$.unit') as unit,
        TRY_CAST(JSON_VALUE(item.value, '$.total') as DECIMAL(10,2)) as total_amount,
        TRY_CAST(JSON_VALUE(item.value, '$.confidence') as DECIMAL(5,2)) as ai_confidence,
        GETDATE() as created_date,
        GETDATE() as updated_date
    FROM dbo.PayloadTransactions pt
    CROSS APPLY OPENJSON(pt.payload_json, '$.items') item
    WHERE JSON_VALUE(item.value, '$.name') IS NOT NULL;

    DECLARE @ItemCount INT = @@ROWCOUNT;
    PRINT 'Extracted ' + CAST(@ItemCount AS NVARCHAR(20)) + ' transaction items';

    -- Show summary statistics
    SELECT
        'Transaction Items Extracted' as Metric,
        COUNT(*) as Count
    FROM dbo.TransactionItems

    UNION ALL

    SELECT
        'Unique Brands',
        COUNT(DISTINCT brand_name)
    FROM dbo.TransactionItems
    WHERE brand_name IS NOT NULL

    UNION ALL

    SELECT
        'Unspecified Categories',
        COUNT(*)
    FROM dbo.TransactionItems
    WHERE category = 'unspecified'

    UNION ALL

    SELECT
        'Category Coverage',
        COUNT(DISTINCT category)
    FROM dbo.TransactionItems
    WHERE category != 'unspecified';

    PRINT 'Transaction items extraction completed successfully';
END
GO

PRINT 'sp_ExtractTransactionItems procedure created successfully';