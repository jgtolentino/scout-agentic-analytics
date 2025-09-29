-- =====================================================
-- Payment Method View: Placeholder Until Payment Data Available
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER VIEW gold.v_tx_payments AS
SELECT
  f.canonical_tx_id,
  'Unknown' AS payment_method
FROM canonical.SalesInteractionFact f;
GO

PRINT 'Payment view created successfully';
PRINT 'Usage: SELECT * FROM gold.v_tx_payments';