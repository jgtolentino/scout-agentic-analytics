-- ========================================================================
-- Scout Analytics Platform - Production-Safe Flat Export View
-- Migration: 2025-09-25_v_flat_export_sheet.sql
-- Purpose: Create flattened, merged, enriched dataframe view
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- CREATE OR ALTER VIEW: dbo.v_flat_export_sheet
-- Exact 12 columns in specified order, LEFT JOINs only, zero row drop
-- ========================================================================

CREATE OR ALTER VIEW dbo.v_flat_export_sheet AS
WITH base AS (
  SELECT
    CAST(p.canonical_tx_id AS varchar(64))   AS Transaction_ID,
    CAST(p.total_amount AS decimal(18,2))    AS Transaction_Value,
    CAST(p.total_items  AS int)              AS Basket_Size,
    p.category                               AS Category,
    p.brand                                  AS Brand,
    p.txn_ts,
    p.daypart                                AS Daypart,
    p.weekday_weekend                        AS Weekday_vs_Weekend,
    p.store_name                             AS Location
  FROM dbo.v_transactions_flat_production p
  -- Optional: uncomment only if you intentionally want "completed-only"
  -- WHERE p.transaction_status = 'completed'
),
demo AS (
  SELECT
    si.canonical_tx_id,
    CASE
      WHEN MAX(si.Age) BETWEEN 18 AND 24 THEN '18-24'
      WHEN MAX(si.Age) BETWEEN 25 AND 34 THEN '25-34'
      WHEN MAX(si.Age) BETWEEN 35 AND 44 THEN '35-44'
      WHEN MAX(si.Age) BETWEEN 45 AND 54 THEN '45-54'
      WHEN MAX(si.Age) BETWEEN 55 AND 64 THEN '55-64'
      WHEN MAX(si.Age) >= 65 THEN '65+'
      ELSE ''
    END AS age_bracket,
    MAX(si.Gender) AS gender,
    'Regular' AS customer_type  -- Default since this column doesn't exist in current schema
  FROM dbo.SalesInteractions si
  GROUP BY si.canonical_tx_id
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
  b.Daypart,
  LTRIM(RTRIM(
    CONCAT(
      COALESCE(d.age_bracket,''),
      CASE WHEN COALESCE(d.gender,'')='' THEN '' ELSE ' ' + d.gender END,
      CASE WHEN COALESCE(d.customer_type,'')='' THEN '' ELSE ' ' + d.customer_type END
    )
  ))                                   AS [Demographics (Age/Gender/Role)],
  b.Weekday_vs_Weekend,
  FORMAT(b.txn_ts, 'htt', 'en-US')     AS [Time of transaction],
  b.Location,
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
  )                                     AS Other_Products,
  CASE
    WHEN s.was_substitution = 1 THEN 'true'
    WHEN s.was_substitution = 0 THEN 'false'
    ELSE ''
  END                                    AS Was_Substitution
FROM base b
LEFT JOIN demo d ON d.canonical_tx_id = b.Transaction_ID
LEFT JOIN subs s ON s.canonical_tx_id  = b.Transaction_ID;
GO

-- ========================================================================
-- PERMISSIONS: Grant read access to reporting role
-- ========================================================================

-- Permissions (adjust role/user as needed)
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rpt_reader')
  GRANT SELECT ON dbo.v_flat_export_sheet TO rpt_reader;

-- Additional common reporting roles
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'scout_reader')
  GRANT SELECT ON dbo.v_flat_export_sheet TO scout_reader;

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'analytics_reader')
  GRANT SELECT ON dbo.v_flat_export_sheet TO analytics_reader;

-- ========================================================================
-- PERFORMANCE RECOMMENDATIONS
-- Create recommended indexes if they don't exist
-- ========================================================================

-- Index on SalesInteractions for faster demographic lookups
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_SalesInteractions_canon'
               AND object_id = OBJECT_ID('dbo.SalesInteractions'))
BEGIN
    CREATE INDEX IX_SalesInteractions_canon ON dbo.SalesInteractions(canonical_tx_id);
    PRINT '✅ Created index IX_SalesInteractions_canon';
END;

-- Index on TransactionItems for faster co-purchase analysis
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_TransactionItems_canon'
               AND object_id = OBJECT_ID('dbo.TransactionItems'))
BEGIN
    CREATE INDEX IX_TransactionItems_canon ON dbo.TransactionItems(canonical_tx_id);
    PRINT '✅ Created index IX_TransactionItems_canon';
END;

-- Index on v_insight_base (if it's a table, not just a view)
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'v_insight_base' AND type = 'U')
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = 'IX_v_insight_base_canon'
                   AND object_id = OBJECT_ID('dbo.v_insight_base'))
BEGIN
    CREATE INDEX IX_v_insight_base_canon ON dbo.v_insight_base(canonical_tx_id);
    PRINT '✅ Created index IX_v_insight_base_canon';
END;

-- ========================================================================
-- VALIDATION: Basic smoke test
-- ========================================================================

DECLARE @row_count INT;
SELECT @row_count = COUNT(*) FROM dbo.v_flat_export_sheet;

IF @row_count > 0
    PRINT CONCAT('✅ View created successfully with ', @row_count, ' rows');
ELSE
    PRINT '⚠️ Warning: View created but returned 0 rows';

-- Show sample of output
PRINT '📊 Sample output (first 3 rows):';
SELECT TOP (3)
    Transaction_ID,
    Transaction_Value,
    Basket_Size,
    Category,
    Brand,
    [Demographics (Age/Gender/Role)],
    [Time of transaction],
    Location
FROM dbo.v_flat_export_sheet;

PRINT '🎯 Flat export view migration completed successfully!';
PRINT '📋 Next steps: Run validation scripts to verify coverage and column contract';