-- Simple test to isolate conversion errors
USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER PROCEDURE canonical.sp_simple_test
AS
BEGIN
  SET NOCOUNT ON;

  SELECT TOP 5
    pt.canonical_tx_id,
    COALESCE(NULLIF(pt.canonical_tx_id_norm,''), pt.canonical_tx_id) AS canonical_tx_id_norm,
    COALESCE(NULLIF(pt.canonical_tx_id_payload,''), pt.canonical_tx_id) AS canonical_tx_id_payload,
    CASE WHEN si.TransactionDate IS NOT NULL
         THEN CONVERT(varchar(10), si.TransactionDate, 120)
         ELSE 'Unknown' END AS transaction_date,
    COALESCE(YEAR(si.TransactionDate), 0) AS year_number,
    COALESCE(MONTH(si.TransactionDate), 0) AS month_number,
    COALESCE(f.age, 0) AS age,
    COALESCE(NULLIF(f.gender,''),'Unknown') AS gender
  FROM PayloadTransactions pt
  LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = pt.canonical_tx_id
  LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = pt.canonical_tx_id
  WHERE pt.canonical_tx_id IS NOT NULL
  ORDER BY pt.canonical_tx_id;
END;
GO