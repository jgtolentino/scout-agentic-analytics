-- ========================================================================
-- Scout Analytics Platform - Production-Safe Flat Export View (WORKING)
-- Migration: 2025-09-25_v_flat_export_sheet_WORKING.sql
-- Purpose: Create flattened, merged, enriched dataframe view with actual schema
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- CREATE OR ALTER VIEW: dbo.v_flat_export_sheet
-- Exact 12 columns in specified order, LEFT JOINs only, zero row drop
-- ========================================================================

CREATE OR ALTER VIEW dbo.v_flat_export_sheet AS
SELECT
  CAST(p.canonical_tx_id AS varchar(64)) AS Transaction_ID,
  CAST(p.total_amount AS decimal(18,2)) AS Transaction_Value,
  CAST(p.total_items AS int) AS Basket_Size,
  p.category AS Category,
  p.brand AS Brand,
  p.daypart AS Daypart,
  -- Demographics: Create age bracket from SalesInteractions.Age and Gender
  LTRIM(RTRIM(CONCAT(
    CASE
      WHEN si.Age BETWEEN 18 AND 24 THEN '18-24'
      WHEN si.Age BETWEEN 25 AND 34 THEN '25-34'
      WHEN si.Age BETWEEN 35 AND 44 THEN '35-44'
      WHEN si.Age BETWEEN 45 AND 54 THEN '45-54'
      WHEN si.Age BETWEEN 55 AND 64 THEN '55-64'
      WHEN si.Age >= 65 THEN '65+'
      ELSE ''
    END, ' ',
    COALESCE(si.Gender, ''), ' ',
    'Regular' -- Default customer type since not in schema
  ))) AS [Demographics (Age/Gender/Role)],
  p.weekday_weekend AS Weekday_vs_Weekend,
  FORMAT(p.txn_ts, 'htt', 'en-US') AS [Time of transaction],
  p.store_name AS Location,
  -- Other_Products: Since TransactionItems doesn't have canonical_tx_id, use InteractionID join
  COALESCE((
    SELECT TOP 1 STRING_AGG(
      CASE
        WHEN pr.ProductName IS NOT NULL THEN CONCAT(pr.Brand, ' - ', pr.ProductName)
        ELSE 'Unknown Product'
      END,
      ', '
    )
    FROM dbo.TransactionItems ti
    LEFT JOIN dbo.Products pr ON ti.ProductID = pr.ProductID
    WHERE ti.InteractionID = si.InteractionID
      AND ti.ProductID != si.ProductID -- Exclude primary product
  ), '') AS Other_Products,
  -- Was_Substitution: Map from v_insight_base using sessionId
  CASE
    WHEN vib.substitution_event = '1' THEN 'true'
    WHEN vib.substitution_event = '0' THEN 'false'
    ELSE ''
  END AS Was_Substitution
FROM dbo.v_transactions_flat_production p
LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = p.canonical_tx_id
LEFT JOIN dbo.v_insight_base vib ON vib.sessionId = p.canonical_tx_id
-- Optional: uncomment only if you intentionally want "completed-only"
-- WHERE p.transaction_status = 'completed'
;
GO

-- ========================================================================
-- GRANT PERMISSIONS
-- ========================================================================

GRANT SELECT ON dbo.v_flat_export_sheet TO [rpt_reader];
GRANT SELECT ON dbo.v_flat_export_sheet TO [scout_reader];
GRANT SELECT ON dbo.v_flat_export_sheet TO [analytics_reader];

PRINT '✅ Flat export view created with permissions granted';
PRINT 'Migration completed successfully';
GO