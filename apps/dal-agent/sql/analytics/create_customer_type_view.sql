-- =====================================================
-- Customer Type View: New vs Returning Customers
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER VIEW gold.v_customer_type AS
SELECT
  f.interaction_id,
  COUNT_BIG(*) AS tx_count,
  CASE WHEN COUNT_BIG(*) > 1 THEN 'Returning' ELSE 'New' END AS customer_type
FROM canonical.SalesInteractionFact f
WHERE f.interaction_id IS NOT NULL
GROUP BY f.interaction_id;
GO

PRINT 'Customer type view created successfully';
PRINT 'Usage: SELECT * FROM gold.v_customer_type';