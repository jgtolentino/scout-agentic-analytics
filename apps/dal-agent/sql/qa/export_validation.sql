-- =====================================================
-- Export Data Quality Validation Queries
-- =====================================================
-- File: sql/qa/export_validation.sql
-- Purpose: Comprehensive QA checks for flat export data integrity
-- Usage: Run after each export to validate data quality

DECLARE @DateFrom DATE = '{{DATE_FROM}}';  -- Default: 2025-09-01
DECLARE @DateTo   DATE = '{{DATE_TO}}';    -- Default: 2025-09-23

PRINT '=== Export Data Quality Validation Report ===';
PRINT 'Date Range: ' + CAST(@DateFrom AS VARCHAR(10)) + ' to ' + CAST(@DateTo AS VARCHAR(10));
PRINT 'Timestamp: ' + FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm:ss');
PRINT '';

-- =====================================================
-- 1. Primary Key Uniqueness Check
-- =====================================================
PRINT '1. PRIMARY KEY UNIQUENESS CHECK';
PRINT '================================';

SELECT
    COUNT(*) AS rows_total,
    COUNT(DISTINCT f.CanonicalTxID) AS rows_distinct,
    COUNT(*) - COUNT(DISTINCT f.CanonicalTxID) AS duplicate_count,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT f.CanonicalTxID) THEN '✅ PASS'
        ELSE '❌ FAIL - Duplicates detected'
    END AS status
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;

PRINT '';

-- =====================================================
-- 2. Amount Sanity Check
-- =====================================================
PRINT '2. AMOUNT SANITY CHECK';
PRINT '=====================';

SELECT
    COUNT(*) AS transaction_count,
    SUM(f.TransactionValue) AS amount_total,
    AVG(f.TransactionValue) AS amount_avg,
    MIN(f.TransactionValue) AS amount_min,
    MAX(f.TransactionValue) AS amount_max,
    COUNT(CASE WHEN f.TransactionValue <= 0 THEN 1 END) AS negative_amounts,
    COUNT(CASE WHEN f.TransactionValue IS NULL THEN 1 END) AS null_amounts,
    CASE
        WHEN COUNT(CASE WHEN f.TransactionValue <= 0 THEN 1 END) = 0
         AND COUNT(CASE WHEN f.TransactionValue IS NULL THEN 1 END) = 0
        THEN '✅ PASS'
        ELSE '❌ FAIL - Invalid amounts detected'
    END AS status
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;

PRINT '';

-- =====================================================
-- 3. Basket Size Validation
-- =====================================================
PRINT '3. BASKET SIZE VALIDATION';
PRINT '========================';

SELECT
    COUNT(*) AS transaction_count,
    AVG(CAST(f.BasketSize AS FLOAT)) AS basket_avg,
    MIN(f.BasketSize) AS basket_min,
    MAX(f.BasketSize) AS basket_max,
    COUNT(CASE WHEN f.BasketSize <= 0 THEN 1 END) AS invalid_basket_size,
    COUNT(CASE WHEN f.BasketSize IS NULL THEN 1 END) AS null_basket_size,
    CASE
        WHEN COUNT(CASE WHEN f.BasketSize <= 0 THEN 1 END) = 0
         AND COUNT(CASE WHEN f.BasketSize IS NULL THEN 1 END) = 0
        THEN '✅ PASS'
        ELSE '❌ FAIL - Invalid basket sizes detected'
    END AS status
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;

PRINT '';

-- =====================================================
-- 4. NCR Region Filter Check (if NCR_ONLY required)
-- =====================================================
PRINT '4. NCR REGION FILTER CHECK';
PRINT '=========================';

SELECT
    COUNT(*) AS total_transactions,
    COUNT(CASE WHEN r.RegionName IN ('NCR', 'Metro Manila') THEN 1 END) AS ncr_transactions,
    COUNT(CASE WHEN r.RegionName NOT IN ('NCR', 'Metro Manila') OR r.RegionName IS NULL THEN 1 END) AS non_ncr_transactions,
    CASE
        WHEN COUNT(CASE WHEN r.RegionName NOT IN ('NCR', 'Metro Manila') OR r.RegionName IS NULL THEN 1 END) = 0
        THEN '✅ PASS - All NCR'
        ELSE '⚠️  WARNING - Non-NCR data present'
    END AS status
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
LEFT JOIN dbo.Stores s ON s.StoreID = f.StoreID
LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;

PRINT '';

-- =====================================================
-- 5. Date Range Validation
-- =====================================================
PRINT '5. DATE RANGE VALIDATION';
PRINT '=======================';

SELECT
    MIN(dd.[Date]) AS actual_date_min,
    MAX(dd.[Date]) AS actual_date_max,
    @DateFrom AS requested_date_min,
    @DateTo AS requested_date_max,
    CASE
        WHEN MIN(dd.[Date]) >= @DateFrom AND MAX(dd.[Date]) <= @DateTo
        THEN '✅ PASS'
        ELSE '❌ FAIL - Dates outside requested range'
    END AS status
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;

PRINT '';

-- =====================================================
-- 6. Join Integrity Check
-- =====================================================
PRINT '6. JOIN INTEGRITY CHECK';
PRINT '======================';

SELECT
    COUNT(*) AS total_transactions,
    COUNT(s.StoreID) AS stores_matched,
    COUNT(r.RegionID) AS regions_matched,
    COUNT(b.BrandID) AS brands_matched,
    COUNT(nh.NielsenCategoryID) AS categories_matched,
    CASE
        WHEN COUNT(s.StoreID) > COUNT(*) * 0.8 THEN '✅ PASS'
        ELSE '⚠️  WARNING - Low join match rate'
    END AS store_status,
    CASE
        WHEN COUNT(b.BrandID) > COUNT(*) * 0.5 THEN '✅ PASS'
        ELSE '⚠️  WARNING - Low brand match rate'
    END AS brand_status
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
LEFT JOIN dbo.Stores s ON s.StoreID = f.StoreID
LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
LEFT JOIN dbo.Brands b ON f.BrandID = b.BrandID
LEFT JOIN ref.NielsenHierarchy nh ON b.CategoryID = nh.NielsenCategoryID
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;

PRINT '';

-- =====================================================
-- 7. Export Completeness Summary
-- =====================================================
PRINT '7. EXPORT COMPLETENESS SUMMARY';
PRINT '==============================';

SELECT
    COUNT(*) AS total_exported_rows,
    COUNT(DISTINCT f.CanonicalTxID) AS unique_transactions,
    COUNT(DISTINCT dd.[Date]) AS date_span_days,
    COUNT(DISTINCT s.StoreID) AS unique_stores,
    COUNT(DISTINCT r.RegionName) AS unique_regions,
    COUNT(DISTINCT b.BrandName) AS unique_brands,
    COUNT(DISTINCT nh.CategoryName) AS unique_categories,
    FORMAT(SUM(f.TransactionValue), 'C') AS total_revenue,
    FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm:ss') AS validation_timestamp
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
LEFT JOIN dbo.Stores s ON s.StoreID = f.StoreID
LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
LEFT JOIN dbo.Brands b ON f.BrandID = b.BrandID
LEFT JOIN ref.NielsenHierarchy nh ON b.CategoryID = nh.NielsenCategoryID
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;

PRINT '';
PRINT '=== End of Validation Report ===';

-- =====================================================
-- 8. Quick Error Detection (for CI automation)
-- =====================================================
-- Return error code if critical issues found
DECLARE @ErrorCount INT = 0;

-- Check for duplicates
IF (SELECT COUNT(*) - COUNT(DISTINCT f.CanonicalTxID)
    FROM canonical.SalesInteractionFact f
    JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
    WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo) > 0
    SET @ErrorCount = @ErrorCount + 1;

-- Check for negative amounts
IF (SELECT COUNT(CASE WHEN f.TransactionValue <= 0 THEN 1 END)
    FROM canonical.SalesInteractionFact f
    JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
    WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo) > 0
    SET @ErrorCount = @ErrorCount + 1;

-- Check for invalid basket sizes
IF (SELECT COUNT(CASE WHEN f.BasketSize <= 0 THEN 1 END)
    FROM canonical.SalesInteractionFact f
    JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
    WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo) > 0
    SET @ErrorCount = @ErrorCount + 1;

IF @ErrorCount > 0
BEGIN
    PRINT 'CRITICAL ERRORS DETECTED: ' + CAST(@ErrorCount AS VARCHAR(10));
    RAISERROR('Export validation failed with critical errors', 16, 1);
END
ELSE
BEGIN
    PRINT 'VALIDATION PASSED: No critical errors detected';
END