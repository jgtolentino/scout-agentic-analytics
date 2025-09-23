IF OBJECT_ID('system.sp_task_export_flat_delta','P') IS NOT NULL
  DROP PROCEDURE system.sp_task_export_flat_delta;
GO
CREATE PROCEDURE system.sp_task_export_flat_delta
  @task_run_id BIGINT
AS
BEGIN
  SET NOCOUNT ON;

  -- 1) CT window compute (uses your 026_task_framework run checkpoints)
  DECLARE @ct_from BIGINT = NULL, @ct_to BIGINT = CHANGE_TRACKING_CURRENT_VERSION();

  SELECT TOP 1 @ct_from = last_ct_version
  FROM system.task_runs WITH (READPAST)
  WHERE task_run_id = @task_run_id;

  -- default first run: export all validated
  IF @ct_from IS NULL SET @ct_from = 0;

  -- 2) Materialize deltas (must use SI timestamp, normalized canonical)
  ;WITH delta AS (
    SELECT t.*
    FROM CHANGETABLE (CHANGES silver.Transactions, @ct_from) AS CT
    JOIN silver.Transactions t ON t.transaction_id = CT.transaction_id
    WHERE CT.SYS_CHANGE_VERSION <= @ct_to
  ),
  shaped AS (
    SELECT
      LOWER(REPLACE(t.canonical_tx_id,'-',''))        AS canonical_tx_id,
      t.session_id, t.device_id, t.store_id,
      t.amount, t.payment_method, t.basket_count,
      t.age, t.age_group, t.gender, t.emotion, t.customer_type,
      -- authoritative timestamp ONLY from silver.Transactions (already SI-sourced)
      CAST(t.transaction_timestamp AS datetime2(0))    AS txn_ts,
      CONVERT(date, t.transaction_timestamp)           AS transaction_date,
      t.daypart, t.weekday, t.is_weekend,
      t.audio_transcript, t.products_detected,
      t.substitution_occurred, t.substitution_accepted
    FROM delta t
    WHERE t.is_validated = 1
  )
  SELECT COUNT(*) AS rows_to_export
  INTO #export_count
  FROM shaped;

  DECLARE @rows INT = (SELECT rows_to_export FROM #export_count);

  -- 3) Short-circuit if no changes
  IF @rows = 0
  BEGIN
    EXEC system.sp_task_event @task_run_id=@task_run_id, @level='INFO', @message='no changes';
    -- still persist CT ceiling
    UPDATE system.task_runs SET last_ct_version=@ct_to WHERE task_run_id=@task_run_id;
    SELECT @rows AS exported_rows; RETURN;
  END

  -- 4) Persist artifacts (CSV/Parquet paths are written by app or xp_cmdshell-less external proc)
  -- For DB-only flow, we just stage to an export table; app will pick it and write files.
  IF OBJECT_ID('tempdb..#payload') IS NOT NULL DROP TABLE #payload;
  SELECT * INTO #payload FROM shaped;

  -- 5) Update run with summary + advance CT
  DECLARE @artifacts nvarchar(max) = N'{"rows": ' + CAST(@rows as nvarchar(20)) + N'}';
  EXEC system.sp_task_event @task_run_id=@task_run_id, @level='INFO', @message='delta materialized', @payload=@artifacts;
  UPDATE system.task_runs SET last_ct_version=@ct_to WHERE task_run_id=@task_run_id;

  -- 6) Return count to caller (worker logs + writes files)
  SELECT @rows AS exported_rows;
END
GO