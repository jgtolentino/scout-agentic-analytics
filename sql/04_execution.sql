-- File: sql/04_execution.sql
-- One-shot execution commands for ADS/SSMS
-- Run these in Azure Data Studio/SSMS in two batches

-- Batch A
:r ./sql/02_views.sql
GO

-- Batch B
:r ./sql/03_health.sql
GO

-- Sanity check
EXEC dbo.sp_scout_health_check;
SELECT TOP (20) * FROM dbo.v_transactions_flat_production ORDER BY txn_ts DESC;
SELECT TOP (20) * FROM dbo.v_transactions_crosstab_production ORDER BY [date] DESC, store_id, daypart, brand;