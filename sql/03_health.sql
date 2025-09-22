-- File: sql/03_health.sql
-- Batch 2/2 ---------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_scout_health_check
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    rows_flat = COUNT(*),
    rows_flat_with_ts = SUM(CASE WHEN txn_ts IS NOT NULL THEN 1 ELSE 0 END),
    pct_with_ts = AVG(CASE WHEN txn_ts IS NOT NULL THEN 1.0 ELSE 0.0 END),
    min_ts = MIN(txn_ts),
    max_ts = MAX(txn_ts)
  FROM dbo.v_transactions_flat_production;

  ;WITH f AS (
    SELECT COUNT(*) AS n
    FROM dbo.v_transactions_flat_production
    WHERE txn_ts >= DATEADD(day,-30,SYSUTCDATETIME())
  ),
  c AS (
    SELECT SUM(txn_count) AS n
    FROM dbo.v_transactions_crosstab_production
    WHERE [date] >= CAST(DATEADD(day,-30,SYSUTCDATETIME()) AS date)
  )
  SELECT f.n AS flat_30d, c.n AS xtab_30d,
         diff_ratio = CASE WHEN f.n=0 THEN NULL ELSE ABS(1.0 - 1.0*c.n/f.n) END
  FROM f CROSS JOIN c;
END;
GO