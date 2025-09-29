-- Sanity checks for flat export system
-- Validates data quality and consistency

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Check 1: Row count comparison
SELECT
    'Row Count Validation' as check_name,
    (SELECT COUNT(*) FROM PayloadTransactions WHERE canonical_tx_id IS NOT NULL) AS source_payload_rows,
    (SELECT COUNT(*) FROM dbo.v_flat_export_sheet) AS view_rows,
    (SELECT COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet) AS unique_transactions,
    CASE
        WHEN (SELECT COUNT(*) FROM PayloadTransactions WHERE canonical_tx_id IS NOT NULL) =
             (SELECT COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet)
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status;

-- Check 2: Data quality scan
SELECT
    'Data Quality Scan' as check_name,
    SUM(CASE WHEN Transaction_ID IS NULL THEN 1 ELSE 0 END) AS null_transaction_ids,
    SUM(CASE WHEN Transaction_Value IS NULL THEN 1 ELSE 0 END) AS null_values,
    SUM(CASE WHEN Brand IS NULL OR Brand = '' THEN 1 ELSE 0 END) AS null_brands,
    SUM(CASE WHEN Category IS NULL OR Category = '' THEN 1 ELSE 0 END) AS null_categories,
    COUNT(*) as total_rows
FROM dbo.v_flat_export_sheet;

-- Check 3: Basket size distribution
SELECT
    'Basket Size Distribution' as check_name,
    Basket_Size,
    COUNT(*) as transaction_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS decimal(5,2)) as percentage
FROM dbo.v_flat_export_sheet
WHERE Basket_Size IS NOT NULL
GROUP BY Basket_Size
ORDER BY Basket_Size;

-- Check 4: Category distribution (top 10)
SELECT TOP 10
    'Top Categories' as check_name,
    Category,
    COUNT(*) as transaction_count,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.v_flat_export_sheet) AS decimal(5,2)) as percentage
FROM dbo.v_flat_export_sheet
WHERE Category IS NOT NULL AND Category != ''
GROUP BY Category
ORDER BY COUNT(*) DESC;

-- Check 5: Export file validation
IF OBJECT_ID('dbo.FlatExport_CSVSafe', 'U') IS NOT NULL
BEGIN
    SELECT
        'Materialized Table Status' as check_name,
        COUNT(*) as materialized_rows,
        MAX(materialized_date) as last_refreshed,
        CASE
            WHEN COUNT(*) = (SELECT COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet)
            THEN '✅ SYNCHRONIZED'
            ELSE '⚠️ NEEDS REFRESH'
        END as sync_status
    FROM dbo.FlatExport_CSVSafe;
END
ELSE
BEGIN
    SELECT 'Materialized Table Status' as check_name, 'NOT CREATED' as sync_status;
END

PRINT '📊 Sanity checks completed';
PRINT '📁 Expected export: 12,000+ rows, 45 columns';