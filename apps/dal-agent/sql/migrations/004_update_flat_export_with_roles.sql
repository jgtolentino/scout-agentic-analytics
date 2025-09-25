-- ========================================================================
-- Scout Analytics - Persona Role Integration
-- Migration: 004_update_flat_export_with_roles.sql
-- Purpose: Update v_flat_export_sheet to include persona roles in Demographics
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- UPDATE FLAT EXPORT VIEW WITH PERSONA ROLES
-- ========================================================================

CREATE OR ALTER VIEW dbo.v_flat_export_sheet AS
SELECT
  CAST(p.canonical_tx_id AS varchar(64)) AS Transaction_ID,
  CAST(p.total_amount AS decimal(18,2)) AS Transaction_Value,
  CAST(p.total_items AS int) AS Basket_Size,
  p.category AS Category,
  p.brand AS Brand,
  p.daypart AS Daypart,
  -- Demographics with inferred persona role: "Age Gender Role"
  LTRIM(RTRIM(CONCAT(
    -- Age bracket from SalesInteractions.Age
    CASE
      WHEN si.Age BETWEEN 18 AND 24 THEN '18-24'
      WHEN si.Age BETWEEN 25 AND 34 THEN '25-34'
      WHEN si.Age BETWEEN 35 AND 44 THEN '35-44'
      WHEN si.Age BETWEEN 45 AND 54 THEN '45-54'
      WHEN si.Age BETWEEN 55 AND 64 THEN '55-64'
      WHEN si.Age >= 65 THEN '65+'
      ELSE ''
    END,
    -- Gender with proper spacing
    CASE WHEN COALESCE(si.Gender, '') != '' THEN ' ' + si.Gender ELSE '' END,
    -- Persona role with proper spacing
    CASE WHEN COALESCE(pr.role, '') != '' AND COALESCE(pr.role, '') != 'Regular'
         THEN ' ' + pr.role ELSE '' END
  ))) AS [Demographics (Age/Gender/Role)],
  p.weekday_weekend AS Weekday_vs_Weekend,
  FORMAT(p.txn_ts, 'htt', 'en-US') AS [Time of transaction],
  p.store_name AS Location,
  -- Other_Products: Simplified - empty for now (schema complexity)
  '' AS Other_Products,
  -- Was_Substitution: Map from v_insight_base using sessionId
  CASE
    WHEN vib.substitution_event = '1' THEN 'true'
    WHEN vib.substitution_event = '0' THEN 'false'
    ELSE ''
  END AS Was_Substitution
FROM dbo.v_transactions_flat_production p
LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
LEFT JOIN dbo.v_insight_base vib ON vib.sessionId = p.canonical_tx_id
LEFT JOIN ref.v_persona_inference pr ON pr.canonical_tx_id = p.canonical_tx_id
-- Optional: uncomment only if you intentionally want "completed-only"
-- WHERE p.transaction_status = 'completed'
;
GO

-- ========================================================================
-- VERIFICATION AND VALIDATION
-- ========================================================================

-- Test 1: Coverage validation (zero row drop)
DECLARE @base_count int, @flat_count int;
SELECT @base_count = COUNT(*) FROM dbo.v_transactions_flat_production;
SELECT @flat_count = COUNT(*) FROM dbo.v_flat_export_sheet;

IF @base_count = @flat_count
BEGIN
    PRINT '✅ Coverage validation passed: ' + CAST(@flat_count as varchar(10)) + ' rows (zero row drop)';
END
ELSE
BEGIN
    PRINT '❌ Coverage mismatch: base=' + CAST(@base_count as varchar(10)) + ', flat=' + CAST(@flat_count as varchar(10));
END

-- Test 2: Column contract validation (exact 12 columns)
DECLARE @col_count int;
SELECT @col_count = COUNT(*)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'v_flat_export_sheet' AND TABLE_SCHEMA = 'dbo';

IF @col_count = 12
BEGIN
    PRINT '✅ Column contract validation passed: 12 columns confirmed';
END
ELSE
BEGIN
    PRINT '❌ Column contract failed: expected 12, got ' + CAST(@col_count as varchar(10));
END

-- Test 3: Persona role distribution
SELECT
    'Persona Distribution' as metric,
    COUNT(*) as total_rows,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] LIKE '%Student%' THEN 1 ELSE 0 END) AS student_count,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] LIKE '%Office Worker%' THEN 1 ELSE 0 END) AS office_worker_count,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] LIKE '%Delivery Rider%' THEN 1 ELSE 0 END) AS rider_count,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] LIKE '%Parent%' THEN 1 ELSE 0 END) AS parent_count,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] LIKE '%Senior%' THEN 1 ELSE 0 END) AS senior_count,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] LIKE '%Reseller%' THEN 1 ELSE 0 END) AS reseller_count
FROM dbo.v_flat_export_sheet;

-- Test 4: Sample data verification
SELECT TOP 5
    Transaction_ID,
    Category,
    Brand,
    [Demographics (Age/Gender/Role)],
    [Time of transaction],
    Was_Substitution
FROM dbo.v_flat_export_sheet
WHERE [Demographics (Age/Gender/Role)] IS NOT NULL AND [Demographics (Age/Gender/Role)] != ''
ORDER BY Transaction_ID;

-- Test 5: Data quality check
SELECT
    'Data Quality Metrics' as metric,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN Transaction_ID IS NOT NULL THEN 1 ELSE 0 END) as valid_tx_ids,
    SUM(CASE WHEN Category IS NOT NULL AND Category != '' THEN 1 ELSE 0 END) as valid_categories,
    SUM(CASE WHEN Brand IS NOT NULL AND Brand != '' THEN 1 ELSE 0 END) as valid_brands,
    SUM(CASE WHEN [Demographics (Age/Gender/Role)] IS NOT NULL AND [Demographics (Age/Gender/Role)] != ''
         THEN 1 ELSE 0 END) as with_demographics,
    SUM(CASE WHEN [Time of transaction] IS NOT NULL AND [Time of transaction] != ''
         THEN 1 ELSE 0 END) as with_time_data
FROM dbo.v_flat_export_sheet;

PRINT '✅ Migration 004_update_flat_export_with_roles completed successfully';
PRINT '🎯 Flat export view now includes persona role inference in Demographics column';
GO