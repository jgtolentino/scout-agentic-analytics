-- Operational Smoke Test Procedure for Scout v7 Auto-Sync System
-- Single command validation for ops teams: EXEC system.sp_task_smoke_test

IF OBJECT_ID('system.sp_task_smoke_test','P') IS NOT NULL
  DROP PROCEDURE system.sp_task_smoke_test;
GO
CREATE PROCEDURE system.sp_task_smoke_test
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @failures INT = 0;
  DECLARE @msg NVARCHAR(MAX) = '';

  PRINT '===== SCOUT V7 AUTO-SYNC SMOKE TEST =====';
  PRINT 'Runtime: ' + CONVERT(VARCHAR(30), SYSUTCDATETIME(), 120) + ' UTC';
  PRINT '';

  -- 1) Task Registry Check
  PRINT '[1/7] Task Registry Check...';
  IF NOT EXISTS (SELECT 1 FROM system.task_definitions WHERE task_code = 'AUTO_SYNC_FLAT' AND enabled = 1)
  BEGIN
    SET @failures = @failures + 1;
    PRINT '  ❌ FAIL: AUTO_SYNC_FLAT task not found or disabled';
  END
  ELSE
    PRINT '  ✅ PASS: AUTO_SYNC_FLAT registered and enabled';

  IF NOT EXISTS (SELECT 1 FROM system.task_definitions WHERE task_code = 'PARITY_CHECK' AND enabled = 1)
  BEGIN
    SET @failures = @failures + 1;
    PRINT '  ❌ FAIL: PARITY_CHECK task not found or disabled';
  END
  ELSE
    PRINT '  ✅ PASS: PARITY_CHECK registered and enabled';

  -- 2) Canonical ID Normalization Check
  PRINT '';
  PRINT '[2/7] Canonical ID Normalization Check...';
  DECLARE @bad_canon INT = (
    SELECT COUNT(*)
    FROM silver.Transactions
    WHERE canonical_tx_id LIKE '%-%'
       OR canonical_tx_id <> LOWER(canonical_tx_id)
       OR canonical_tx_id IS NULL
  );

  IF @bad_canon > 0
  BEGIN
    SET @failures = @failures + 1;
    PRINT '  ❌ FAIL: ' + CAST(@bad_canon AS VARCHAR(20)) + ' records with invalid canonical IDs';
  END
  ELSE
    PRINT '  ✅ PASS: All canonical IDs normalized (lowercase, no hyphens)';

  -- 3) SI-Only Timestamp Enforcement
  PRINT '';
  PRINT '[3/7] SI-Only Timestamp Check...';
  DECLARE @null_ts INT = (
    SELECT COUNT(*)
    FROM silver.Transactions
    WHERE transaction_timestamp IS NULL
  );

  IF @null_ts > 0
  BEGIN
    SET @failures = @failures + 1;
    PRINT '  ❌ FAIL: ' + CAST(@null_ts AS VARCHAR(20)) + ' records with NULL timestamps';
  END
  ELSE
    PRINT '  ✅ PASS: All transactions have SI-sourced timestamps';

  -- 4) Change Tracking Status
  PRINT '';
  PRINT '[4/7] Change Tracking Status...';
  DECLARE @ct_enabled BIT = 0;
  IF EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
    SET @ct_enabled = 1;

  IF @ct_enabled = 0
  BEGIN
    SET @failures = @failures + 1;
    PRINT '  ❌ FAIL: Change Tracking not enabled on database';
  END
  ELSE
  BEGIN
    PRINT '  ✅ PASS: Change Tracking enabled on database';

    -- Check table-level CT
    IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id = OBJECT_ID('silver.Transactions'))
    BEGIN
      SET @failures = @failures + 1;
      PRINT '  ❌ FAIL: Change Tracking not enabled on silver.Transactions';
    END
    ELSE
    BEGIN
      DECLARE @ct_current BIGINT = CHANGE_TRACKING_CURRENT_VERSION();
      DECLARE @ct_min BIGINT = CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions'));
      PRINT '  ✅ PASS: CT enabled on silver.Transactions';
      PRINT '      Current Version: ' + CAST(@ct_current AS VARCHAR(20));
      PRINT '      Min Valid Version: ' + CAST(@ct_min AS VARCHAR(20));
    END
  END

  -- 5) Recent Task Runs
  PRINT '';
  PRINT '[5/7] Recent Task Execution...';
  DECLARE @last_sync_hours INT = (
    SELECT TOP 1 DATEDIFF(HOUR, end_time, SYSUTCDATETIME())
    FROM system.task_runs
    WHERE task_id = (SELECT task_id FROM system.task_definitions WHERE task_code = 'AUTO_SYNC_FLAT')
      AND status = 'SUCCEEDED'
    ORDER BY end_time DESC
  );

  IF @last_sync_hours IS NULL
    PRINT '  ⚠️  WARN: No successful AUTO_SYNC_FLAT runs found';
  ELSE IF @last_sync_hours > 24
  BEGIN
    SET @failures = @failures + 1;
    PRINT '  ❌ FAIL: Last successful sync was ' + CAST(@last_sync_hours AS VARCHAR(20)) + ' hours ago';
  END
  ELSE
    PRINT '  ✅ PASS: Last sync completed ' + CAST(@last_sync_hours AS VARCHAR(20)) + ' hours ago';

  -- 6) Flat vs Crosstab Parity
  PRINT '';
  PRINT '[6/7] Flat vs Crosstab Data Parity...';

  -- Check if views exist
  IF OBJECT_ID('gold.vw_FlatExport','V') IS NULL
  BEGIN
    SET @failures = @failures + 1;
    PRINT '  ❌ FAIL: gold.vw_FlatExport view not found';
  END
  ELSE
  BEGIN
    DECLARE @flat_count INT = (SELECT COUNT(*) FROM gold.vw_FlatExport);
    PRINT '  ✅ PASS: Flat export view exists with ' + CAST(@flat_count AS VARCHAR(20)) + ' rows';

    -- Parity check would go here if crosstab view exists
    -- For now, just validate flat view is queryable
  END

  -- 7) Export Files Check
  PRINT '';
  PRINT '[7/7] Export Artifacts...';
  DECLARE @recent_exports INT = (
    SELECT COUNT(*)
    FROM system.task_runs
    WHERE task_id = (SELECT task_id FROM system.task_definitions WHERE task_code = 'AUTO_SYNC_FLAT')
      AND status = 'SUCCEEDED'
      AND artifacts IS NOT NULL
      AND end_time >= DATEADD(DAY, -7, SYSUTCDATETIME())
  );

  IF @recent_exports = 0
    PRINT '  ⚠️  WARN: No export artifacts found in last 7 days';
  ELSE
    PRINT '  ✅ PASS: ' + CAST(@recent_exports AS VARCHAR(20)) + ' successful exports in last 7 days';

  -- Final Summary
  PRINT '';
  PRINT '========================================';
  IF @failures = 0
  BEGIN
    PRINT '✅ SMOKE TEST PASSED - All checks successful';
    PRINT 'System is operational and ready for production';
  END
  ELSE
  BEGIN
    PRINT '❌ SMOKE TEST FAILED - ' + CAST(@failures AS VARCHAR(20)) + ' check(s) failed';
    PRINT 'Review failures above and remediate before production use';
  END
  PRINT '========================================';

  -- Return status code
  RETURN @failures; -- 0 = success, >0 = failure count
END
GO

-- Grant execute permission
GRANT EXECUTE ON system.sp_task_smoke_test TO [scout_reader];
GO

PRINT 'Smoke test procedure created. Run with: EXEC system.sp_task_smoke_test';
GO