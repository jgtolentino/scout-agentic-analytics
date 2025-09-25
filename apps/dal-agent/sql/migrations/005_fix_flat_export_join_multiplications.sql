-- ========================================================================
-- Scout Analytics - Fix Flat Export JOIN Multiplications
-- Migration: 005_fix_flat_export_join_multiplications.sql
-- Purpose: Correct row multiplication issues in v_flat_export_sheet
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- CREATE CORRECTED FLAT EXPORT VIEW
-- ========================================================================

CREATE OR ALTER VIEW dbo.v_flat_export_sheet AS
WITH demo_agg AS (
  -- Aggregate SalesInteractions to prevent row multiplication
  SELECT
    canonical_tx_id,
    -- Use MAX to get one value per transaction
    MAX(CASE
      WHEN Age BETWEEN 18 AND 24 THEN '18-24'
      WHEN Age BETWEEN 25 AND 34 THEN '25-34'
      WHEN Age BETWEEN 35 AND 44 THEN '35-44'
      WHEN Age BETWEEN 45 AND 54 THEN '45-54'
      WHEN Age BETWEEN 55 AND 64 THEN '55-64'
      WHEN Age >= 65 THEN '65+'
      ELSE ''
    END) AS age_bracket,
    MAX(Gender) AS gender
  FROM dbo.SalesInteractions
  WHERE canonical_tx_id IS NOT NULL
  GROUP BY canonical_tx_id
),
vib_agg AS (
  -- Aggregate v_insight_base to prevent row multiplication
  SELECT
    sessionId AS canonical_tx_id,
    MAX(CASE
      WHEN substitution_event = '1' THEN 'true'
      WHEN substitution_event = '0' THEN 'false'
      ELSE ''
    END) AS substitution_flag
  FROM dbo.v_insight_base
  WHERE sessionId IS NOT NULL
  GROUP BY sessionId
)
SELECT
  CAST(p.canonical_tx_id AS varchar(64)) AS Transaction_ID,
  CAST(p.total_amount AS decimal(18,2)) AS Transaction_Value,
  CAST(p.total_items AS int) AS Basket_Size,
  p.category AS Category,
  p.brand AS Brand,
  p.daypart AS Daypart,
  -- Demographics with inferred persona role: "Age Gender Role"
  LTRIM(RTRIM(CONCAT(
    COALESCE(d.age_bracket, ''),
    CASE WHEN COALESCE(d.gender, '') != '' THEN ' ' + d.gender ELSE '' END,
    CASE WHEN COALESCE(pr.role, '') != '' AND COALESCE(pr.role, '') != 'Regular'
         THEN ' ' + pr.role ELSE '' END
  ))) AS [Demographics (Age/Gender/Role)],
  p.weekday_weekend AS Weekday_vs_Weekend,
  FORMAT(p.txn_ts, 'htt', 'en-US') AS [Time of transaction],
  p.store_name AS Location,
  -- Other_Products: Simplified empty for now
  '' AS Other_Products,
  COALESCE(v.substitution_flag, '') AS Was_Substitution
FROM dbo.v_transactions_flat_production p
LEFT JOIN demo_agg d ON d.canonical_tx_id = p.canonical_tx_id
LEFT JOIN vib_agg v ON v.canonical_tx_id = p.canonical_tx_id
LEFT JOIN ref.v_persona_inference pr ON pr.canonical_tx_id = p.canonical_tx_id;

GO

-- ========================================================================
-- VALIDATION
-- ========================================================================

DECLARE @base_count int, @flat_count int, @unique_count int;

SELECT @base_count = COUNT(DISTINCT canonical_tx_id) FROM dbo.v_transactions_flat_production;
SELECT @flat_count = COUNT(*) FROM dbo.v_flat_export_sheet;
SELECT @unique_count = COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet;

PRINT '📊 Coverage Validation Results:';
PRINT '  Base transactions: ' + CAST(@base_count as varchar(10));
PRINT '  Flat export rows: ' + CAST(@flat_count as varchar(10));
PRINT '  Unique Transaction IDs: ' + CAST(@unique_count as varchar(10));

IF @base_count = @flat_count AND @flat_count = @unique_count
BEGIN
    PRINT '✅ Coverage validation PASSED - Zero row drop achieved';

    -- Test persona integration
    DECLARE @persona_count int;
    SELECT @persona_count = COUNT(*)
    FROM dbo.v_flat_export_sheet
    WHERE [Demographics (Age/Gender/Role)] LIKE '%Student%'
       OR [Demographics (Age/Gender/Role)] LIKE '%Office%'
       OR [Demographics (Age/Gender/Role)] LIKE '%Delivery%'
       OR [Demographics (Age/Gender/Role)] LIKE '%Parent%'
       OR [Demographics (Age/Gender/Role)] LIKE '%Senior%';

    PRINT '📈 Transactions with persona inference: ' + CAST(@persona_count as varchar(10));

    -- Sample data
    SELECT TOP 5
        Transaction_ID,
        [Demographics (Age/Gender/Role)],
        Category,
        Brand
    FROM dbo.v_flat_export_sheet
    WHERE [Demographics (Age/Gender/Role)] IS NOT NULL
      AND [Demographics (Age/Gender/Role)] != '';

    PRINT '✅ Migration 005 completed successfully - JOIN multiplications fixed';
END
ELSE
BEGIN
    PRINT '❌ Coverage validation FAILED';
    PRINT '  Expected equal counts for all three metrics';
END

GO