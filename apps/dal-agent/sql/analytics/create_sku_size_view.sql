-- =====================================================
-- SKU Pack Size View: Safe Join with Pack Size Data
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER VIEW gold.v_tx_sku_size AS
SELECT
  f.interaction_id,
  f.canonical_tx_id,
  COALESCE(s.category, 'Standard') AS pack_size
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.sku_dimensions s
  ON TRY_CAST(s.sku_id AS NVARCHAR(100)) = TRY_CAST(f.product_id AS NVARCHAR(100));
GO

PRINT 'SKU size view created successfully';
PRINT 'Usage: SELECT * FROM gold.v_tx_sku_size';