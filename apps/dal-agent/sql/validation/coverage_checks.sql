-- ========================================================================
-- Scout Analytics Platform - Coverage & Column Contract Validation
-- Purpose: Post-creation sanity checks (zero row drop; column order)
-- Usage: Run after view creation to ensure data integrity
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '🔍 Starting coverage and column contract validation...';

-- ========================================================================
-- COVERAGE GATE: Ensure zero row drop from base view
-- THROWS on mismatch - this is a HARD GATE
-- ========================================================================

PRINT '📊 Validating coverage (zero row drop requirement)...';

DECLARE @base_count INT = (SELECT COUNT(DISTINCT canonical_tx_id) FROM dbo.v_transactions_flat_production);
DECLARE @flat_count INT = (SELECT COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet);

PRINT CONCAT('Base view rows: ', @base_count);
PRINT CONCAT('Flat export rows: ', @flat_count);

-- HARD GATE: Throw if counts don't match
IF @flat_count <> @base_count
BEGIN
  DECLARE @error_msg NVARCHAR(200) = CONCAT('Coverage mismatch: flat=', @flat_count, ' base=', @base_count);
  PRINT CONCAT('❌ COVERAGE GATE FAILED: ', @error_msg);
  THROW 50020, @error_msg, 1;
END
ELSE
BEGIN
  PRINT '✅ Coverage gate PASSED: No row drop detected';
END;

-- ========================================================================
-- COLUMN CONTRACT GATE: Exact names & order validation
-- THROWS on mismatch - this is a HARD GATE
-- ========================================================================

PRINT '📋 Validating column contract (exact names and order)...';

-- Define the exact specification
WITH spec AS (
  SELECT 1 AS ord, 'Transaction_ID' AS name UNION ALL
  SELECT 2,'Transaction_Value' UNION ALL
  SELECT 3,'Basket_Size' UNION ALL
  SELECT 4,'Category' UNION ALL
  SELECT 5,'Brand' UNION ALL
  SELECT 6,'Daypart' UNION ALL
  SELECT 7,'Demographics (Age/Gender/Role)' UNION ALL
  SELECT 8,'Weekday_vs_Weekend' UNION ALL
  SELECT 9,'Time of transaction' UNION ALL
  SELECT 10,'Location' UNION ALL
  SELECT 11,'Other_Products' UNION ALL
  SELECT 12,'Was_Substitution'
),
-- Get actual columns from the view
actual AS (
  SELECT column_id AS ord, name FROM sys.columns
  WHERE object_id = OBJECT_ID('dbo.v_flat_export_sheet')
),
-- Find mismatches
mismatches AS (
  SELECT
    s.ord as spec_ord,
    s.name as spec_name,
    a.ord as actual_ord,
    a.name as actual_name
  FROM spec s
  FULL JOIN actual a ON a.ord = s.ord AND a.name = s.name
  WHERE a.ord IS NULL OR s.ord IS NULL
)
-- Check for any mismatches
SELECT @flat_count = COUNT(*) FROM mismatches;

-- Show detailed mismatch information if any exist
IF EXISTS (SELECT 1 FROM mismatches)
BEGIN
  PRINT '❌ COLUMN CONTRACT GATE FAILED: Column specification mismatch detected';

  SELECT
    spec_ord as [Expected_Order],
    spec_name as [Expected_Name],
    actual_ord as [Actual_Order],
    actual_name as [Actual_Name],
    CASE
      WHEN spec_ord IS NULL THEN 'Extra column in view'
      WHEN actual_ord IS NULL THEN 'Missing column in view'
      ELSE 'Order/name mismatch'
    END as [Issue]
  FROM (
    SELECT
      s.ord as spec_ord,
      s.name as spec_name,
      a.ord as actual_ord,
      a.name as actual_name
    FROM (
      SELECT 1 AS ord, 'Transaction_ID' AS name UNION ALL
      SELECT 2,'Transaction_Value' UNION ALL
      SELECT 3,'Basket_Size' UNION ALL
      SELECT 4,'Category' UNION ALL
      SELECT 5,'Brand' UNION ALL
      SELECT 6,'Daypart' UNION ALL
      SELECT 7,'Demographics (Age/Gender/Role)' UNION ALL
      SELECT 8,'Weekday_vs_Weekend' UNION ALL
      SELECT 9,'Time of transaction' UNION ALL
      SELECT 10,'Location' UNION ALL
      SELECT 11,'Other_Products' UNION ALL
      SELECT 12,'Was_Substitution'
    ) s
    FULL JOIN (
      SELECT column_id AS ord, name FROM sys.columns
      WHERE object_id = OBJECT_ID('dbo.v_flat_export_sheet')
    ) a ON a.ord = s.ord AND a.name = s.name
    WHERE a.ord IS NULL OR s.ord IS NULL
  ) mismatches
  ORDER BY COALESCE(spec_ord, actual_ord);

  THROW 50021, 'Column contract mismatch in v_flat_export_sheet', 1;
END
ELSE
BEGIN
  PRINT '✅ Column contract gate PASSED: All 12 columns in correct order';
END;

-- ========================================================================
-- DATA TYPE VALIDATION
-- ========================================================================

PRINT '📝 Validating column data types...';

SELECT
  c.column_id as [Order],
  c.name as [Column_Name],
  t.name as [Data_Type],
  CASE
    WHEN t.name IN ('varchar', 'nvarchar', 'char', 'nchar')
    THEN CONCAT(t.name, '(', CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length as varchar) END, ')')
    WHEN t.name IN ('decimal', 'numeric')
    THEN CONCAT(t.name, '(', c.precision, ',', c.scale, ')')
    ELSE t.name
  END as [Full_Type],
  c.is_nullable as [Nullable]
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.v_flat_export_sheet')
ORDER BY c.column_id;

-- ========================================================================
-- NULL VALUE ANALYSIS
-- ========================================================================

PRINT '📊 Analyzing NULL values in key columns...';

WITH null_analysis AS (
  SELECT
    COUNT(*) as total_rows,
    SUM(CASE WHEN Transaction_ID IS NULL THEN 1 ELSE 0 END) as null_transaction_id,
    SUM(CASE WHEN Category IS NULL OR Category = '' THEN 1 ELSE 0 END) as null_category,
    SUM(CASE WHEN Brand IS NULL OR Brand = '' THEN 1 ELSE 0 END) as null_brand,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] IS NULL OR [Demographics (Age/Gender/Role)] = '' THEN 1 ELSE 0 END) as null_demographics,
    SUM(CASE WHEN Other_Products IS NULL THEN 1 ELSE 0 END) as null_other_products,
    SUM(CASE WHEN Was_Substitution IS NULL OR Was_Substitution = '' THEN 1 ELSE 0 END) as null_substitution
  FROM dbo.v_flat_export_sheet
)
SELECT
  'Total Rows' as Metric, total_rows as Count,
  CAST(100.0 as decimal(5,2)) as Percentage
FROM null_analysis
UNION ALL
SELECT
  'NULL Transaction_ID', null_transaction_id,
  CASE WHEN total_rows > 0 THEN CAST((null_transaction_id * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM null_analysis
UNION ALL
SELECT
  'Empty Category', null_category,
  CASE WHEN total_rows > 0 THEN CAST((null_category * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM null_analysis
UNION ALL
SELECT
  'Empty Brand', null_brand,
  CASE WHEN total_rows > 0 THEN CAST((null_brand * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM null_analysis
UNION ALL
SELECT
  'Empty Demographics', null_demographics,
  CASE WHEN total_rows > 0 THEN CAST((null_demographics * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM null_analysis
UNION ALL
SELECT
  'NULL Other_Products', null_other_products,
  CASE WHEN total_rows > 0 THEN CAST((null_other_products * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM null_analysis
UNION ALL
SELECT
  'Empty Substitution', null_substitution,
  CASE WHEN total_rows > 0 THEN CAST((null_substitution * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM null_analysis;

-- ========================================================================
-- SAMPLE OUTPUT VALIDATION
-- ========================================================================

PRINT '📋 Sample output (first 5 rows for manual inspection):';

SELECT TOP (5)
  Transaction_ID,
  Transaction_Value,
  Basket_Size,
  Category,
  Brand,
  Daypart,
  [Demographics (Age/Gender/Role)],
  Weekday_vs_Weekend,
  [Time of transaction],
  Location,
  LEFT(Other_Products, 100) + CASE WHEN LEN(Other_Products) > 100 THEN '...' ELSE '' END as Other_Products_Sample,
  Was_Substitution
FROM dbo.v_flat_export_sheet
ORDER BY Transaction_ID;

-- ========================================================================
-- PERFORMANCE CHECK
-- ========================================================================

PRINT '⚡ Performance validation...';

DECLARE @start_time DATETIME2 = GETDATE();

-- Test query performance
SELECT COUNT(*) as total_exported_rows
FROM dbo.v_flat_export_sheet;

DECLARE @duration_ms INT = DATEDIFF(MILLISECOND, @start_time, GETDATE());

PRINT CONCAT('Query execution time: ', @duration_ms, 'ms');

IF @duration_ms > 5000
  PRINT '⚠️ Warning: Query took longer than 5 seconds - consider index optimization';
ELSE
  PRINT '✅ Query performance acceptable';

-- ========================================================================
-- FINAL VALIDATION SUMMARY
-- ========================================================================

PRINT '📊 Validation Summary:';
PRINT '✅ Coverage gate: PASSED (zero row drop)';
PRINT '✅ Column contract gate: PASSED (exact specification match)';
PRINT CONCAT('✅ Total rows exported: ', @base_count);
PRINT '🎯 All validation checks completed successfully!';
PRINT '';
PRINT '🚀 Ready for data export and Bruno workflow execution';