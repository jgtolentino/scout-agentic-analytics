-- Parity Check between Flat Export and Crosstab Views
-- SI-timestamp integrity validation

-- Create/refresh parity proc if not present
CREATE OR ALTER PROCEDURE dbo.sp_parity_flat_vs_crosstab_ct
  @days_back int = 30
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @start_date date = CONVERT(date, DATEADD(day, -@days_back, SYSUTCDATETIME()));

  -- Flat export counts
  WITH f AS (
    SELECT
      COUNT(*) as record_count,
      SUM(COALESCE(amount,0)) as total_amount,
      COUNT(DISTINCT canonical_tx_id) as unique_transactions,
      COUNT(CASE WHEN timestamp_source = 'SalesInteractions' THEN 1 END) as si_sourced,
      COUNT(CASE WHEN timestamp_source = 'PayloadTransactions' THEN 1 END) as payload_sourced
    FROM gold.vw_FlatExport
    WHERE transaction_date >= @start_date
  ),
  -- Crosstab counts (if available)
  c AS (
    SELECT
      COALESCE(SUM(txn_count), 0) as record_count,
      COALESCE(SUM(total_amount), 0) as total_amount
    FROM dbo.v_transactions_crosstab_production
    WHERE [date] >= @start_date
  )
  SELECT
    -- Record counts
    f.record_count AS flat_records,
    c.record_count AS crosstab_records,
    CASE WHEN f.record_count > 0
         THEN CAST(ABS(1.0 - 1.0*c.record_count / f.record_count) AS decimal(18,6))
         ELSE NULL END AS record_diff_ratio,

    -- Amount totals
    f.total_amount AS flat_amount,
    c.total_amount AS crosstab_amount,
    CASE WHEN f.total_amount > 0
         THEN CAST(ABS(1.0 - 1.0*c.total_amount / f.total_amount) AS decimal(18,6))
         ELSE NULL END AS amount_diff_ratio,

    -- Timestamp source breakdown
    f.si_sourced AS si_timestamp_count,
    f.payload_sourced AS payload_timestamp_count,
    CASE WHEN f.record_count > 0
         THEN CAST(f.si_sourced * 100.0 / f.record_count AS decimal(5,2))
         ELSE 0 END AS si_timestamp_pct,

    -- Quality indicators
    f.unique_transactions,
    CASE WHEN f.record_count = f.unique_transactions THEN 'PASS' ELSE 'WARN' END AS uniqueness_check,

    -- Metadata
    @days_back AS days_analyzed,
    @start_date AS analysis_start_date,
    SYSUTCDATETIME() AS analysis_timestamp;

  FROM f CROSS JOIN c;
END
GO

-- Register parity check task if not already
IF NOT EXISTS (SELECT 1 FROM system.task_definitions WHERE task_code = 'PARITY_CHECK')
BEGIN
  EXEC system.sp_task_register
    @task_code='PARITY_CHECK',
    @task_name='Flat vs Crosstab Parity',
    @description='Validates data consistency between flat export and crosstab views with SI timestamp tracking',
    @owner='QA';
END

-- Sample parity check execution with task tracking
/*
-- Run this manually or schedule it:

DECLARE @rid BIGINT;
DECLARE @tbl TABLE(run_id BIGINT);

INSERT INTO @tbl
EXEC system.sp_task_start
  @task_code='PARITY_CHECK',
  @pid=CONVERT(nvarchar(100),@@SPID),
  @host=HOST_NAME(),
  @note='Scheduled parity validation';

SELECT @rid = run_id FROM @tbl;

BEGIN TRY
  -- Run parity check
  EXEC dbo.sp_parity_flat_vs_crosstab_ct @days_back=30;

  -- Log completion
  EXEC system.sp_task_finish
    @run_id=@rid,
    @rows_read=NULL,
    @artifacts=NULL,
    @note='Parity check completed successfully';

END TRY
BEGIN CATCH
  -- Handle failure
  EXEC system.sp_task_fail
    @run_id=@rid,
    @error_message=ERROR_MESSAGE(),
    @note='Parity check failed';

  -- Re-raise error
  THROW;
END CATCH;
*/