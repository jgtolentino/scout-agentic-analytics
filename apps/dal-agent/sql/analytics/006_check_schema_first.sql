-- Check actual column names in TransactionItems table
SELECT TOP 5 COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TransactionItems'
ORDER BY ORDINAL_POSITION;

-- Show sample data to understand structure
SELECT TOP 5 *
FROM dbo.TransactionItems;

-- Check if brand and category data is in a different table
SELECT TOP 5 COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%transaction%'
  AND (COLUMN_NAME LIKE '%brand%' OR COLUMN_NAME LIKE '%category%')
ORDER BY TABLE_NAME, ORDINAL_POSITION;