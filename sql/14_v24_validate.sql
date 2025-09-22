SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* v24 contract validator
   - Verifies column ORDER, NAMES, and TYPES of dbo.v_transactions_flat_v24
   - Parity: row count equals dbo.v_transactions_flat
   - Null ratios reported (warn threshold 0.10)
   - TimeOfDay format check: exactly 4 chars, ends with AM/PM
   - Hard FAIL (RAISERROR) if: missing/misordered columns OR type mismatch OR parity !=
*/
CREATE OR ALTER PROCEDURE dbo.sp_validate_v24
AS
BEGIN
  SET NOCOUNT ON;

  ----------------------------------------------------------------------
  -- 1) Expected contract (24 columns, order-sensitive)
  ----------------------------------------------------------------------
  DECLARE @expect TABLE(ordinal int, name sysname, system_type_id int, user_type sysname);
  INSERT INTO @expect (ordinal, name, system_type_id, user_type)
  VALUES
  ( 1, N'CanonicalTxID',         167, N'varchar'),
  ( 2, N'TransactionID',         167, N'varchar'),
  ( 3, N'DeviceID',              167, N'varchar'),
  ( 4, N'StoreID',                56, N'int'),
  ( 5, N'StoreName',             231, N'nvarchar'),
  ( 6, N'Region',                167, N'varchar'),
  ( 7, N'ProvinceName',          231, N'nvarchar'),
  ( 8, N'MunicipalityName',      231, N'nvarchar'),
  ( 9, N'BarangayName',          231, N'nvarchar'),
  (10, N'psgc_region',           175, N'char'),
  (11, N'psgc_citymun',          175, N'char'),
  (12, N'psgc_barangay',         175, N'char'),
  (13, N'GeoLatitude',           62 , N'float'),
  (14, N'GeoLongitude',          62 , N'float'),
  (15, N'StorePolygon',          231, N'nvarchar'),
  (16, N'Amount',                106, N'decimal'),
  (17, N'Basket_Item_Count',     56 , N'int'),
  (18, N'WeekdayOrWeekend',      167, N'varchar'),
  (19, N'TimeOfDay',             175, N'char'),
  (20, N'AgeBracket',            231, N'nvarchar'),
  (21, N'Gender',                231, N'nvarchar'),
  (22, N'Role',                  231, N'nvarchar'),
  (23, N'Substitution_Flag',     104, N'bit'),
  (24, N'Txn_TS',                61 , N'datetime2');  -- stored as datetime2 in adapter

  ----------------------------------------------------------------------
  -- 2) Actual columns of view
  ----------------------------------------------------------------------
  IF OBJECT_ID(N'dbo.v_transactions_flat_v24','V') IS NULL
  BEGIN
    RAISERROR('View dbo.v_transactions_flat_v24 is missing', 16, 1);
    RETURN;
  END

  ;WITH cols AS (
    SELECT
      c.column_id AS ordinal,
      c.name,
      c.system_type_id,
      st.name AS user_type
    FROM sys.columns c
    JOIN sys.objects o ON o.object_id = c.object_id AND o.type='V' AND o.name='v_transactions_flat_v24'
    JOIN sys.types st ON st.user_type_id = c.user_type_id
  )
  SELECT e.ordinal, e.name AS expected, c.name AS actual, e.user_type AS expected_type, c.user_type AS actual_type,
         CASE WHEN e.name=c.name AND e.user_type=c.user_type THEN 'OK' ELSE 'MISMATCH' END AS status
  INTO #col_check
  FROM @expect e
  FULL OUTER JOIN cols c ON c.ordinal = e.ordinal;

  DECLARE @col_errors int = (SELECT COUNT(*) FROM #col_check WHERE status='MISMATCH' OR expected IS NULL OR actual IS NULL);
  IF (@col_errors > 0)
  BEGIN
    SELECT * FROM #col_check ORDER BY ordinal;
    RAISERROR('v24 column contract FAIL: %d mismatches', 16, 1, @col_errors);
    RETURN;
  END

  ----------------------------------------------------------------------
  -- 3) Parity: row counts
  ----------------------------------------------------------------------
  DECLARE @n_flat bigint, @n_v24 bigint;
  SELECT @n_flat = COUNT(*) FROM dbo.v_transactions_flat WITH (NOEXPAND);
  SELECT @n_v24  = COUNT(*) FROM dbo.v_transactions_flat_v24 WITH (NOEXPAND);

  SELECT @n_flat AS rows_flat, @n_v24 AS rows_v24,
         CASE WHEN @n_flat=@n_v24 THEN 'OK' ELSE 'MISMATCH' END AS parity_status;

  IF (@n_flat <> @n_v24)
  BEGIN
    RAISERROR('v24 parity FAIL: v24 rows (%d) != flat rows (%d)', 16, 1, @n_v24, @n_flat);
    RETURN;
  END

  ----------------------------------------------------------------------
  -- 4) Null ratios (report only; warn if >10%)
  ----------------------------------------------------------------------
  DECLARE @sql nvarchar(max) = N'';
  ;WITH names AS (
    SELECT name FROM @expect
  )
  SELECT @sql = STRING_AGG(CONCAT(
    'SELECT ', QUOTENAME(name), ' AS column_name, ',
    'CAST(SUM(CASE WHEN ', QUOTENAME(name), ' IS NULL THEN 1 ELSE 0 END) AS float)/NULLIF(COUNT(*),0) AS null_ratio ',
    'FROM dbo.v_transactions_flat_v24 WITH (NOEXPAND)'
  ), ' UNION ALL ')
  FROM names;

  EXEC sp_executesql @sql;

  ----------------------------------------------------------------------
  -- 5) TimeOfDay format check (4 chars, ends with AM/PM)
  ----------------------------------------------------------------------
  SELECT TOP 10 TimeOfDay AS bad_TimeOfDay
  FROM dbo.v_transactions_flat_v24 WITH (NOEXPAND)
  WHERE (TimeOfDay IS NOT NULL AND (LEN(TimeOfDay)<>4 OR RIGHT(TimeOfDay,2) NOT IN ('AM','PM')));

  -- soft warnings only; no RAISERROR unless you want to enforce:
  -- IF EXISTS(SELECT 1 FROM dbo.v_transactions_flat_v24 WHERE TimeOfDay IS NOT NULL AND (LEN(TimeOfDay)<>4 OR RIGHT(TimeOfDay,2) NOT IN ('AM','PM')))
  --   RAISERROR('v24 TimeOfDay format WARN: some rows are not HHAM/HHPM', 10, 1);

END
GO
GRANT EXECUTE ON dbo.sp_validate_v24 TO [scout_reader];
GO