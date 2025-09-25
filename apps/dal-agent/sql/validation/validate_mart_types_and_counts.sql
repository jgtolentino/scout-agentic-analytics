SET NOCOUNT ON;
/* ---- Config (parameterizable) ---- */
:setvar EXPECTED_ROWS 12192
DECLARE @EXPECTED_ROWS bigint = $(EXPECTED_ROWS);

PRINT '== Expect mart rows ==';
SELECT 'dbo.v_transactions_flat_production' AS obj, COUNT_BIG(*) AS rows
INTO #mart_rows
FROM dbo.v_transactions_flat_production;

PRINT '== CSV-safe must match ==';
SELECT 'dbo.v_flat_export_csvsafe' AS obj, COUNT_BIG(*) AS rows
INTO #csv_rows
FROM dbo.v_flat_export_csvsafe;

/* Report + pass/fail for row parity */
SELECT m.rows AS mart_rows, c.rows AS csv_rows, @EXPECTED_ROWS AS expected_rows,
       CASE WHEN m.rows = @EXPECTED_ROWS THEN 'PASS' ELSE 'FAIL' END AS mart_matches_expected,
       CASE WHEN c.rows = @EXPECTED_ROWS THEN 'PASS' ELSE 'FAIL' END AS csv_matches_expected,
       CASE WHEN m.rows = c.rows THEN 'PASS' ELSE 'FAIL' END AS mart_vs_csv
FROM #mart_rows m CROSS JOIN #csv_rows c;

PRINT '== Types/nullability for mart ==';
EXEC sys.sp_describe_first_result_set @tsql=N'SELECT * FROM dbo.v_transactions_flat_production';

PRINT '== Types/nullability for CSV-safe ==';
EXEC sys.sp_describe_first_result_set @tsql=N'SELECT * FROM dbo.v_flat_export_csvsafe';

PRINT '== Null/type sanity on key columns ==';
SELECT
  SUM(CASE WHEN TRY_CONVERT(decimal(18,2), total_amount) IS NULL AND total_amount IS NOT NULL THEN 1 ELSE 0 END) AS bad_money,
  SUM(CASE WHEN TRY_CONVERT(int,            total_items ) IS NULL AND total_items  IS NOT NULL THEN 1 ELSE 0 END) AS bad_int,
  SUM(CASE WHEN TRY_CONVERT(datetime2,      txn_ts      ) IS NULL AND txn_ts       IS NOT NULL THEN 1 ELSE 0 END) AS bad_ts
FROM dbo.v_transactions_flat_production;

/* ---------- Crosstab parity (dynamic count column detection) ---------- */
DECLARE @v1 sysname = N'dbo.v_xtab_time_category_abs';
DECLARE @v2 sysname = N'dbo.v_xtab_daypart_weektype_abs';
DECLARE @v3 sysname = N'dbo.v_xtab_basketsize_payment_abs';

DECLARE @countCol1 sysname, @countCol2 sysname, @countCol3 sysname;
SELECT @countCol1 = c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID(@v1) AND c.name IN ('Count','LineCount','TxnCount','TotalCount','RowCount','Qty');
SELECT @countCol2 = c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID(@v2) AND c.name IN ('Count','LineCount','TxnCount','TotalCount','RowCount','Qty');
SELECT @countCol3 = c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID(@v3) AND c.name IN ('Count','LineCount','TxnCount','TotalCount','RowCount','Qty');

DECLARE @mart_total_lines bigint;
SELECT @mart_total_lines = COUNT_BIG(*) FROM dbo.v_transactions_flat_production;

DECLARE @sql nvarchar(max);

PRINT '== Crosstab parity: Daypart×Category (abs) ==';
IF @countCol1 IS NOT NULL
BEGIN
  SET @sql = N'SELECT CAST(SUM(CAST(' + QUOTENAME(@countCol1) + N' AS bigint)) AS bigint) AS xtab_sum FROM ' + @v1 + N';';
  DECLARE @xt1 TABLE(xtab_sum bigint);
  INSERT @xt1 EXEC sp_executesql @sql;
  SELECT @mart_total_lines AS mart_lines, xtab_sum, (xtab_sum - @mart_total_lines) AS delta,
         CASE WHEN xtab_sum = @mart_total_lines THEN 'PASS' ELSE 'FAIL' END AS parity
  FROM @xt1;
END
ELSE
  PRINT 'WARN: Could not detect count column in ' + @v1;

PRINT '== Crosstab parity: WeekType×Daypart (abs) ==';
IF @countCol2 IS NOT NULL
BEGIN
  SET @sql = N'SELECT CAST(SUM(CAST(' + QUOTENAME(@countCol2) + N' AS bigint)) AS bigint) AS xtab_sum FROM ' + @v2 + N';';
  DECLARE @xt2 TABLE(xtab_sum bigint);
  INSERT @xt2 EXEC sp_executesql @sql;
  SELECT @mart_total_lines AS mart_lines, xtab_sum, (xtab_sum - @mart_total_lines) AS delta,
         CASE WHEN xtab_sum = @mart_total_lines THEN 'PASS' ELSE 'FAIL' END AS parity
  FROM @xt2;
END
ELSE
  PRINT 'WARN: Could not detect count column in ' + @v2;

PRINT '== Crosstab parity: BasketSize×Payment (abs) ==';
IF @countCol3 IS NOT NULL
BEGIN
  SET @sql = N'SELECT CAST(SUM(CAST(' + QUOTENAME(@countCol3) + N' AS bigint)) AS bigint) AS xtab_sum FROM ' + @v3 + N';';
  DECLARE @xt3 TABLE(xtab_sum bigint);
  INSERT @xt3 EXEC sp_executesql @sql;
  SELECT @mart_total_lines AS mart_lines, xtab_sum, (xtab_sum - @mart_total_lines) AS delta,
         CASE WHEN xtab_sum = @mart_total_lines THEN 'PASS' ELSE 'FAIL' END AS parity
  FROM @xt3;
END
ELSE
  PRINT 'WARN: Could not detect count column in ' + @v3;

/* ---------- Taxonomy slices (if present) ---------- */
PRINT '== Taxonomy slices (existence-safe) ==';
IF OBJECT_ID('gold.v_txn_filter_tobacco','V') IS NOT NULL
  SELECT (SELECT COUNT(*) FROM gold.v_txn_filter_tobacco WHERE IsTobacco=1) AS tobacco_txns;
ELSE
  PRINT 'INFO: gold.v_txn_filter_tobacco not present.';
IF OBJECT_ID('gold.v_txn_filter_laundry','V') IS NOT NULL
  SELECT (SELECT COUNT(*) FROM gold.v_txn_filter_laundry WHERE IsLaundry=1) AS laundry_txns;
ELSE
  PRINT 'INFO: gold.v_txn_filter_laundry not present.';