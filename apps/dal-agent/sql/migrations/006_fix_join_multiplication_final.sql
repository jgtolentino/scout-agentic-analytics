-- ========================================================================
-- Scout Analytics - Final JOIN Multiplication Fix
-- Migration: 006_fix_join_multiplication_final.sql
-- Purpose: Single-key join strategy with SalesInteractions timestamp
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- CREATE CORRECTED FLAT EXPORT VIEW WITH SINGLE-KEY JOINS
-- ========================================================================

CREATE OR ALTER VIEW dbo.v_flat_export_sheet AS
WITH base AS (
  SELECT
    CAST(p.canonical_tx_id AS varchar(64))   AS Transaction_ID,
    CAST(p.total_amount AS decimal(18,2))    AS Transaction_Value,
    CAST(p.total_items  AS int)              AS Basket_Size,
    p.category                                AS Category,
    p.brand                                   AS Brand,
    p.txn_ts                                  AS base_txn_ts,      -- fallback only
    p.daypart                                 AS base_daypart,     -- fallback only
    p.weekday_weekend                         AS base_weektype,    -- fallback only
    p.store_name                               AS Location
  FROM dbo.v_transactions_flat_production p
),
demo AS (
  -- Single-column join on canonical_tx_id; aggregate per tx
  SELECT
    si.canonical_tx_id,
    MAX(si.TransactionDate)    AS si_txn_ts,          -- use SI timestamp
    MAX(CASE
      WHEN si.Age BETWEEN 18 AND 24 THEN '18-24'
      WHEN si.Age BETWEEN 25 AND 34 THEN '25-34'
      WHEN si.Age BETWEEN 35 AND 44 THEN '35-44'
      WHEN si.Age BETWEEN 45 AND 54 THEN '45-54'
      WHEN si.Age BETWEEN 55 AND 64 THEN '55-64'
      WHEN si.Age >= 65 THEN '65+'
      ELSE ''
    END) AS age_bracket,
    MAX(si.Gender)             AS gender
  FROM dbo.SalesInteractions si
  WHERE si.canonical_tx_id IS NOT NULL
  GROUP BY si.canonical_tx_id
),
personas AS (
  SELECT
    pr.canonical_tx_id,
    MAX(pr.role) AS inferred_role
  FROM ref.v_persona_inference pr
  WHERE pr.canonical_tx_id IS NOT NULL
  GROUP BY pr.canonical_tx_id
),
subs AS (
  SELECT
    v.sessionId AS canonical_tx_id,
    MAX(CASE WHEN v.substitution_event = '1' THEN 1 ELSE 0 END) AS was_substitution
  FROM dbo.v_insight_base v
  WHERE v.sessionId IS NOT NULL
  GROUP BY v.sessionId
)
SELECT
  b.Transaction_ID,
  b.Transaction_Value,
  b.Basket_Size,
  b.Category,
  b.Brand,

  -- Derive Daypart from SI timestamp when present, else fallback to base
  COALESCE(
    CASE
      WHEN d.si_txn_ts IS NULL THEN NULL
      WHEN DATEPART(HOUR, d.si_txn_ts) BETWEEN 5 AND 11 THEN 'Morning'
      WHEN DATEPART(HOUR, d.si_txn_ts) BETWEEN 12 AND 17 THEN 'Afternoon'
      WHEN DATEPART(HOUR, d.si_txn_ts) BETWEEN 18 AND 22 THEN 'Evening'
      ELSE 'Night'
    END,
    b.base_daypart
  ) AS Daypart,

  -- Demographics with inferred persona role: "Age Gender Role"
  LTRIM(RTRIM(
    CONCAT(
      COALESCE(d.age_bracket,''),
      CASE WHEN COALESCE(d.gender,'') != '' THEN ' ' + d.gender ELSE '' END,
      CASE WHEN COALESCE(p.inferred_role,'') != '' AND COALESCE(p.inferred_role,'') != 'Regular'
           THEN ' ' + p.inferred_role ELSE '' END
    )
  )) AS [Demographics (Age/Gender/Role)],

  -- Weekday/Weekend from SI timestamp when present
  COALESCE(
    CASE WHEN d.si_txn_ts IS NULL THEN NULL
         WHEN DATENAME(WEEKDAY, d.si_txn_ts) IN ('Saturday','Sunday') THEN 'Weekend'
         ELSE 'Weekday'
    END,
    b.base_weektype
  ) AS Weekday_vs_Weekend,

  -- Time of transaction strictly from SI timestamp; fallback to base if SI missing
  FORMAT(COALESCE(d.si_txn_ts, b.base_txn_ts), 'htt', 'en-US') AS [Time of transaction],

  b.Location,

  -- Other_Products: Simplified empty for now
  '' AS Other_Products,

  CASE
    WHEN s.was_substitution = 1 THEN 'true'
    WHEN s.was_substitution = 0 THEN 'false'
    ELSE ''
  END AS Was_Substitution

FROM base b
LEFT JOIN demo d ON d.canonical_tx_id = b.Transaction_ID          -- single-column join
LEFT JOIN personas p ON p.canonical_tx_id = b.Transaction_ID      -- single-column join
LEFT JOIN subs s ON s.canonical_tx_id = b.Transaction_ID;         -- single-column join

GO

-- Grant permissions
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rpt_reader')
  GRANT SELECT ON dbo.v_flat_export_sheet TO rpt_reader;
GO

-- ========================================================================
-- VALIDATION
-- ========================================================================

DECLARE @base_count int, @flat_count int, @unique_count int;

SELECT @base_count = COUNT(DISTINCT canonical_tx_id) FROM dbo.v_transactions_flat_production;
SELECT @flat_count = COUNT(*) FROM dbo.v_flat_export_sheet;
SELECT @unique_count = COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet;

PRINT '📊 Final Validation Results:';
PRINT '  Base transactions: ' + CAST(@base_count as varchar(10));
PRINT '  Flat export rows: ' + CAST(@flat_count as varchar(10));
PRINT '  Unique Transaction IDs: ' + CAST(@unique_count as varchar(10));

IF @base_count = @flat_count AND @flat_count = @unique_count
BEGIN
    PRINT '✅ Coverage validation PASSED - Zero row drop achieved';
    PRINT '✅ JOIN multiplication FIXED - 1:1 row mapping confirmed';

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
        Brand,
        [Time of transaction]
    FROM dbo.v_flat_export_sheet
    WHERE [Demographics (Age/Gender/Role)] IS NOT NULL
      AND [Demographics (Age/Gender/Role)] != ''
    ORDER BY Transaction_ID;

    PRINT '✅ Migration 006 completed successfully - JOIN multiplications eliminated';
END
ELSE
BEGIN
    PRINT '❌ Coverage validation FAILED';
    PRINT '  Expected equal counts for all three metrics';
    PRINT '  Check for remaining JOIN multiplication issues';
END

GO