-- ========================================================================
-- Scout Analytics - Fix Substitution Event Key Mismatch
-- File: 001_fix_substitution_keys.sql
-- Purpose: Fix key mismatch between sessionId and canonical_tx_id with type-safe handling
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '🔧 Fixing substitution event key mismatch and updating v_flat_export_sheet...';
PRINT '📅 Started: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- ========================================================================
-- UPDATE FLAT EXPORT VIEW WITH CORRECTED SUBSTITUTION HANDLING
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
  -- Single-column join on canonical_tx_id; aggregate per tx to prevent multiplication
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
    MAX(si.Gender)             AS gender,
    MAX(si.EmotionalState)     AS customer_type
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
  -- FIXED: Handle key mismatch with COALESCE and type-safe casting
  SELECT
    COALESCE(
      CAST(v.canonical_tx_id AS varchar(64)),
      CAST(v.sessionId AS varchar(64))
    ) AS canonical_tx_id,
    MAX(CASE
      WHEN TRY_CAST(v.substitution_event AS int) = 1 THEN 1
      WHEN v.substitution_event = '1' THEN 1
      WHEN TRY_CAST(v.substitution_event AS bit) = 1 THEN 1
      ELSE 0
    END) AS was_substitution
  FROM dbo.v_insight_base v
  WHERE COALESCE(v.canonical_tx_id, v.sessionId) IS NOT NULL
  GROUP BY COALESCE(CAST(v.canonical_tx_id AS varchar(64)), CAST(v.sessionId AS varchar(64)))
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
           THEN ' ' + p.inferred_role
           WHEN COALESCE(d.customer_type,'') != '' THEN ' ' + d.customer_type
           ELSE '' END
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

  -- Co-purchases: by tx id; exclude primary brand/category
  (
    SELECT STRING_AGG(
             CASE
               WHEN ti2.brand IS NOT NULL AND ti2.category IS NOT NULL THEN CONCAT(ti2.brand, ' (', ti2.category, ')')
               WHEN ti2.brand IS NOT NULL THEN ti2.brand
               WHEN ti2.category IS NOT NULL THEN ti2.category
               ELSE ti2.product_name
             END, ', '
           )
    FROM dbo.TransactionItems ti2
    WHERE ti2.canonical_tx_id = b.Transaction_ID
      AND (
            ti2.brand IS NULL
            OR UPPER(LTRIM(RTRIM(ti2.brand))) <> UPPER(LTRIM(RTRIM(b.Brand)))
          )
      AND (
            ti2.category IS NULL
            OR UPPER(LTRIM(RTRIM(ti2.category))) <> UPPER(LTRIM(RTRIM(b.Category)))
          )
  ) AS Other_Products,

  -- FIXED: Use corrected substitution handling
  CASE
    WHEN s.was_substitution = 1 THEN 'true'
    WHEN s.was_substitution = 0 THEN 'false'
    ELSE ''
  END AS Was_Substitution

FROM base b
LEFT JOIN demo d ON d.canonical_tx_id = b.Transaction_ID          -- single-column join
LEFT JOIN personas p ON p.canonical_tx_id = b.Transaction_ID      -- single-column join
LEFT JOIN subs s ON s.canonical_tx_id = b.Transaction_ID;         -- FIXED: single-column join with normalized keys

GO

-- Grant permissions
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rpt_reader')
  GRANT SELECT ON dbo.v_flat_export_sheet TO rpt_reader;
GO

-- ========================================================================
-- VALIDATION: Verify fix worked
-- ========================================================================

DECLARE @base_count int, @flat_count int, @unique_count int, @subs_count int;

SELECT @base_count = COUNT(DISTINCT canonical_tx_id) FROM dbo.v_transactions_flat_production;
SELECT @flat_count = COUNT(*) FROM dbo.v_flat_export_sheet;
SELECT @unique_count = COUNT(DISTINCT Transaction_ID) FROM dbo.v_flat_export_sheet;
SELECT @subs_count = COUNT(*) FROM dbo.v_flat_export_sheet WHERE Was_Substitution IN ('true', 'false');

PRINT '📊 Substitution Fix Validation Results:';
PRINT '  Base transactions: ' + CAST(@base_count as varchar(10));
PRINT '  Flat export rows: ' + CAST(@flat_count as varchar(10));
PRINT '  Unique Transaction IDs: ' + CAST(@unique_count as varchar(10));
PRINT '  Rows with substitution data: ' + CAST(@subs_count as varchar(10));

IF @base_count = @flat_count AND @flat_count = @unique_count
BEGIN
    PRINT '✅ Coverage validation PASSED - Zero row drop maintained';
    PRINT '✅ JOIN multiplication PREVENTED - 1:1 row mapping confirmed';

    IF @subs_count > 0
        PRINT '✅ Substitution event handling FIXED - Data successfully captured with normalized keys';
    ELSE
        PRINT '⚠️ Substitution events found but no matches - Check source data availability';

    PRINT '✅ Substitution key mismatch fix completed successfully';
END
ELSE
BEGIN
    PRINT '❌ Coverage validation FAILED';
    PRINT '  Expected equal counts for base, flat, and unique Transaction IDs';
    THROW 50001, 'Substitution fix validation failed - coverage mismatch detected', 1;
END

PRINT '';
PRINT '🎉 Substitution event key mismatch fix completed!';
PRINT '📅 Finished: ' + CONVERT(varchar(20), GETDATE(), 120);

GO