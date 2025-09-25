-- ========================================================================
-- Scout Analytics Platform - Flat Export Codebook
-- Purpose: Machine-readable codebook for the 12 columns in v_flat_export_sheet
-- Usage: Generate CSV metadata for data dictionary and API documentation
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '📚 Generating machine-readable codebook for flat export view...';

-- ========================================================================
-- COLUMN SPECIFICATIONS WITH DETAILED METADATA
-- ========================================================================

WITH column_specs AS (
  SELECT
    c.column_id,
    c.name AS column_name,
    t.name AS type_name,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    CASE
      WHEN t.name IN ('varchar', 'nvarchar', 'char', 'nchar')
      THEN CONCAT(t.name, '(', CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length as varchar) END, ')')
      WHEN t.name IN ('decimal', 'numeric')
      THEN CONCAT(t.name, '(', c.precision, ',', c.scale, ')')
      ELSE t.name
    END AS full_type
  FROM sys.columns c
  JOIN sys.types t ON c.user_type_id = t.user_type_id
  WHERE c.object_id = OBJECT_ID('dbo.v_flat_export_sheet')
),
column_details AS (
  SELECT
    cs.*,
    CASE cs.column_name
      WHEN 'Transaction_ID' THEN 'Canonical transaction identifier'
      WHEN 'Transaction_Value' THEN 'Total amount for transaction (currency)'
      WHEN 'Basket_Size' THEN 'Item count in transaction'
      WHEN 'Category' THEN 'Primary product category'
      WHEN 'Brand' THEN 'Primary product brand'
      WHEN 'Daypart' THEN 'Derived from txn_ts (Morning/Afternoon/Evening/Night)'
      WHEN 'Demographics (Age/Gender/Role)' THEN 'Concatenated demo: age bracket + gender + customer type'
      WHEN 'Weekday_vs_Weekend' THEN 'Derived from txn_ts'
      WHEN 'Time of transaction' THEN 'Formatted hour (htt, en-US)'
      WHEN 'Location' THEN 'Store/site name or municipality'
      WHEN 'Other_Products' THEN 'Co-purchases excluding primary brand/category'
      WHEN 'Was_Substitution' THEN 'true/false/empty from v_insight_base'
      ELSE ''
    END AS description,
    CASE cs.column_name
      WHEN 'Transaction_ID' THEN 'dbo.v_transactions_flat_production.canonical_tx_id'
      WHEN 'Transaction_Value' THEN 'dbo.v_transactions_flat_production.total_amount'
      WHEN 'Basket_Size' THEN 'dbo.v_transactions_flat_production.total_items'
      WHEN 'Category' THEN 'dbo.v_transactions_flat_production.category'
      WHEN 'Brand' THEN 'dbo.v_transactions_flat_production.brand'
      WHEN 'Daypart' THEN 'dbo.v_transactions_flat_production.daypart'
      WHEN 'Demographics (Age/Gender/Role)' THEN 'dbo.SalesInteractions: age_bracket + gender + customer_type'
      WHEN 'Weekday_vs_Weekend' THEN 'dbo.v_transactions_flat_production.weekday_weekend'
      WHEN 'Time of transaction' THEN 'FORMAT(dbo.v_transactions_flat_production.txn_ts, ''htt'', ''en-US'')'
      WHEN 'Location' THEN 'dbo.v_transactions_flat_production.store_name'
      WHEN 'Other_Products' THEN 'STRING_AGG from dbo.TransactionItems excluding primary brand/category'
      WHEN 'Was_Substitution' THEN 'dbo.v_insight_base.substitution_event mapped to true/false/empty'
      ELSE ''
    END AS source_derivation,
    CASE cs.column_name
      WHEN 'Transaction_ID' THEN 'Not null, unique identifier'
      WHEN 'Transaction_Value' THEN 'Positive decimal values (currency)'
      WHEN 'Basket_Size' THEN 'Positive integer values'
      WHEN 'Category' THEN 'Text values, may be empty for unclassified items'
      WHEN 'Brand' THEN 'Text values, may be empty for unrecognized brands'
      WHEN 'Daypart' THEN 'Morning|Afternoon|Evening|Night or empty'
      WHEN 'Demographics (Age/Gender/Role)' THEN 'Space-separated concatenation, may be empty'
      WHEN 'Weekday_vs_Weekend' THEN 'Weekday|Weekend or empty'
      WHEN 'Time of transaction' THEN '12-hour format with AM/PM (e.g., 2PM, 8AM)'
      WHEN 'Location' THEN 'Store names or geographic locations'
      WHEN 'Other_Products' THEN 'Comma-separated list of co-purchased items, empty if none'
      WHEN 'Was_Substitution' THEN 'true|false|empty (empty when substitution data unavailable)'
      ELSE ''
    END AS allowed_values_notes,
    CASE cs.column_name
      WHEN 'Transaction_ID' THEN 'Primary key for joining with other Scout tables'
      WHEN 'Transaction_Value' THEN 'Use for revenue analysis and transaction size segmentation'
      WHEN 'Basket_Size' THEN 'Use for market basket analysis and customer behavior insights'
      WHEN 'Category' THEN 'Use for product category performance analysis'
      WHEN 'Brand' THEN 'Use for brand performance and competitive analysis'
      WHEN 'Daypart' THEN 'Use for temporal analysis and peak hour identification'
      WHEN 'Demographics (Age/Gender/Role)' THEN 'Use for customer segmentation and demographic analysis'
      WHEN 'Weekday_vs_Weekend' THEN 'Use for temporal patterns and day-of-week analysis'
      WHEN 'Time of transaction' THEN 'Use for hourly traffic analysis and peak hour identification'
      WHEN 'Location' THEN 'Use for geographic analysis and store performance comparison'
      WHEN 'Other_Products' THEN 'Use for market basket analysis and cross-selling opportunities'
      WHEN 'Was_Substitution' THEN 'Use for substitution analysis and brand switching behavior'
      ELSE ''
    END AS usage_notes
  FROM column_specs cs
)
-- ========================================================================
-- FINAL CODEBOOK OUTPUT
-- ========================================================================
SELECT
  column_id AS [Column_Order],
  column_name AS [Column_Name],
  full_type AS [Data_Type],
  CASE WHEN is_nullable = 1 THEN 'Yes' ELSE 'No' END AS [Nullable],
  description AS [Description],
  source_derivation AS [Source_Derivation],
  allowed_values_notes AS [Allowed_Values_Notes],
  usage_notes AS [Usage_Notes],
  -- Additional metadata
  CASE column_name
    WHEN 'Transaction_ID' THEN 'HIGH'
    WHEN 'Transaction_Value' THEN 'HIGH'
    WHEN 'Basket_Size' THEN 'MEDIUM'
    WHEN 'Category' THEN 'HIGH'
    WHEN 'Brand' THEN 'HIGH'
    WHEN 'Daypart' THEN 'MEDIUM'
    WHEN 'Demographics (Age/Gender/Role)' THEN 'MEDIUM'
    WHEN 'Weekday_vs_Weekend' THEN 'MEDIUM'
    WHEN 'Time of transaction' THEN 'MEDIUM'
    WHEN 'Location' THEN 'HIGH'
    WHEN 'Other_Products' THEN 'LOW'
    WHEN 'Was_Substitution' THEN 'LOW'
    ELSE 'UNKNOWN'
  END AS [Data_Quality_Priority],
  CASE column_name
    WHEN 'Transaction_ID' THEN 'Required for all operations'
    WHEN 'Transaction_Value' THEN 'Core business metric'
    WHEN 'Basket_Size' THEN 'Core business metric'
    WHEN 'Category' THEN 'Core business dimension'
    WHEN 'Brand' THEN 'Core business dimension'
    WHEN 'Daypart' THEN 'Temporal analysis dimension'
    WHEN 'Demographics (Age/Gender/Role)' THEN 'Customer segmentation dimension'
    WHEN 'Weekday_vs_Weekend' THEN 'Temporal analysis dimension'
    WHEN 'Time of transaction' THEN 'Temporal analysis metric'
    WHEN 'Location' THEN 'Geographic analysis dimension'
    WHEN 'Other_Products' THEN 'Market basket analysis metric'
    WHEN 'Was_Substitution' THEN 'Advanced analytics metric'
    ELSE 'Unknown'
  END AS [Business_Function],
  -- Performance and indexing recommendations
  CASE column_name
    WHEN 'Transaction_ID' THEN 'Indexed (clustered or primary)'
    WHEN 'Category' THEN 'Consider indexing for filtering'
    WHEN 'Brand' THEN 'Consider indexing for filtering'
    WHEN 'Location' THEN 'Consider indexing for geographic analysis'
    ELSE 'No index needed'
  END AS [Index_Recommendation]
FROM column_details
ORDER BY column_id;

-- ========================================================================
-- DATA QUALITY METRICS
-- ========================================================================

PRINT '📊 Generating data quality metrics...';

WITH quality_metrics AS (
  SELECT
    COUNT(*) as total_rows,
    -- Core fields completeness
    SUM(CASE WHEN Transaction_ID IS NOT NULL THEN 1 ELSE 0 END) as complete_transaction_id,
    SUM(CASE WHEN Transaction_Value IS NOT NULL AND Transaction_Value > 0 THEN 1 ELSE 0 END) as valid_transaction_value,
    SUM(CASE WHEN Basket_Size IS NOT NULL AND Basket_Size > 0 THEN 1 ELSE 0 END) as valid_basket_size,
    SUM(CASE WHEN Category IS NOT NULL AND Category != '' THEN 1 ELSE 0 END) as complete_category,
    SUM(CASE WHEN Brand IS NOT NULL AND Brand != '' THEN 1 ELSE 0 END) as complete_brand,
    -- Dimensional completeness
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] IS NOT NULL AND [Demographics (Age/Gender/Role)] != '' THEN 1 ELSE 0 END) as complete_demographics,
    SUM(CASE WHEN [Time of transaction] IS NOT NULL AND [Time of transaction] != '' THEN 1 ELSE 0 END) as complete_time,
    SUM(CASE WHEN Location IS NOT NULL AND Location != '' THEN 1 ELSE 0 END) as complete_location,
    -- Advanced metrics completeness
    SUM(CASE WHEN Other_Products IS NOT NULL THEN 1 ELSE 0 END) as complete_other_products,
    SUM(CASE WHEN Was_Substitution IN ('true', 'false') THEN 1 ELSE 0 END) as complete_substitution
  FROM dbo.v_flat_export_sheet
)
SELECT
  'Data Quality Summary' as Metric_Category,
  'Total Records' as Metric_Name,
  total_rows as Record_Count,
  100.0 as Completeness_Percentage
FROM quality_metrics
UNION ALL
SELECT
  'Core Business Fields',
  'Transaction_ID Completeness',
  complete_transaction_id,
  CASE WHEN total_rows > 0 THEN CAST((complete_transaction_id * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM quality_metrics
UNION ALL
SELECT
  'Core Business Fields',
  'Valid Transaction_Value',
  valid_transaction_value,
  CASE WHEN total_rows > 0 THEN CAST((valid_transaction_value * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM quality_metrics
UNION ALL
SELECT
  'Core Business Fields',
  'Category Completeness',
  complete_category,
  CASE WHEN total_rows > 0 THEN CAST((complete_category * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM quality_metrics
UNION ALL
SELECT
  'Core Business Fields',
  'Brand Completeness',
  complete_brand,
  CASE WHEN total_rows > 0 THEN CAST((complete_brand * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM quality_metrics
UNION ALL
SELECT
  'Dimensional Fields',
  'Demographics Completeness',
  complete_demographics,
  CASE WHEN total_rows > 0 THEN CAST((complete_demographics * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM quality_metrics
UNION ALL
SELECT
  'Advanced Analytics',
  'Substitution Data Availability',
  complete_substitution,
  CASE WHEN total_rows > 0 THEN CAST((complete_substitution * 100.0 / total_rows) as decimal(5,2)) ELSE 0 END
FROM quality_metrics;

-- ========================================================================
-- EXPORT METADATA
-- ========================================================================

SELECT
  'Export Metadata' as Info_Type,
  'View Name' as Info_Key,
  'dbo.v_flat_export_sheet' as Info_Value
UNION ALL
SELECT
  'Export Metadata',
  'Column Count',
  '12'
UNION ALL
SELECT
  'Export Metadata',
  'Generated Date',
  CONVERT(varchar(20), GETDATE(), 120)
UNION ALL
SELECT
  'Export Metadata',
  'Database',
  DB_NAME()
UNION ALL
SELECT
  'Export Metadata',
  'Server Version',
  LEFT(@@VERSION, 50) + '...'
UNION ALL
SELECT
  'Export Metadata',
  'Join Strategy',
  'LEFT JOIN only (zero row drop)'
UNION ALL
SELECT
  'Export Metadata',
  'Primary Key',
  'canonical_tx_id'
UNION ALL
SELECT
  'Export Metadata',
  'Time Format',
  'FORMAT(txn_ts, ''htt'', ''en-US'')'
UNION ALL
SELECT
  'Export Metadata',
  'Locale',
  'en-US';

PRINT '✅ Machine-readable codebook generated successfully';
PRINT '📋 Ready for CSV export via Bruno workflow';