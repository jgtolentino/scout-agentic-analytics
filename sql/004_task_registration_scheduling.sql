-- Task Registration + Scheduled Integrity Jobs (SQL)
-- Register both continuous autosync and daily parity job with SI-timestamp integrity

-- Idempotent register AUTO_SYNC_FLAT task
EXEC system.sp_task_register
  @task_code='AUTO_SYNC_FLAT',
  @task_name='Auto Sync Flat Export (CT-driven)',
  @description='Change Tracking driven export of gold.vw_FlatExport to CSV/XLSX/Parquet with SI-only timestamps',
  @owner='DataOps',
  @enabled=1;

-- Idempotent register PARITY_CHECK task
EXEC system.sp_task_register
  @task_code='PARITY_CHECK',
  @task_name='Flat vs Crosstab Parity (SI timestamp integrity)',
  @description='Validates data consistency between flat export and crosstab views with SI timestamp tracking',
  @owner='QA',
  @enabled=1;

-- Register additional tasks for comprehensive ETL tracking
EXEC system.sp_task_register
  @task_code='MAIN_ETL',
  @task_name='Main Incremental ETL Pipeline',
  @description='Bronze->Silver->Gold medallion pipeline with PayloadTransactions processing',
  @owner='DataOps',
  @enabled=1;

EXEC system.sp_task_register
  @task_code='CANONICAL_ID_SYNC',
  @task_name='Canonical ID Synchronization',
  @description='Normalize canonical transaction IDs and sync with SalesInteractions',
  @owner='DataOps',
  @enabled=1;

-- SQL Agent schedule for parity check daily at 02:15 UTC
-- (Only if SQL Agent is available - Kubernetes CronJob handles this otherwise)
BEGIN TRY
  -- Check if SQL Agent is available
  IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'msdb')
  BEGIN
    -- Remove existing job if present
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name='SCOUT_PARITY_CHECK_JOB')
      EXEC msdb.dbo.sp_delete_job @job_name='SCOUT_PARITY_CHECK_JOB';

    -- Create new job
    DECLARE @job_id UNIQUEIDENTIFIER;
    EXEC msdb.dbo.sp_add_job
      @job_name='SCOUT_PARITY_CHECK_JOB',
      @enabled=1,
      @owner_login_name='sa',
      @job_id=@job_id OUTPUT;

    -- Add job step with task framework integration
    EXEC msdb.dbo.sp_add_jobstep
      @job_id=@job_id,
      @step_name='run_parity_with_tracking',
      @subsystem='TSQL',
      @command=N'
        DECLARE @rid BIGINT;
        DECLARE @tbl TABLE(run_id BIGINT);

        BEGIN TRY
          -- Start task run
          INSERT INTO @tbl
          EXEC system.sp_task_start
            @task_code=''PARITY_CHECK'',
            @pid=CONVERT(nvarchar(100),@@SPID),
            @host=HOST_NAME(),
            @note=''SQL Agent scheduled parity check'';

          SELECT @rid=run_id FROM @tbl;

          -- Log start
          EXEC system.sp_task_heartbeat
            @run_id=@rid,
            @level=''INFO'',
            @message=''Starting scheduled parity check'';

          -- Execute parity check
          EXEC dbo.sp_parity_flat_vs_crosstab_ct @days_back=30;

          -- Log completion
          EXEC system.sp_task_heartbeat
            @run_id=@rid,
            @level=''INFO'',
            @message=''Parity check procedure completed successfully'';

          -- Mark successful finish
          EXEC system.sp_task_finish
            @run_id=@rid,
            @rows_read=1,
            @note=''Nightly parity check completed successfully'';

        END TRY
        BEGIN CATCH
          -- Handle failure
          IF @rid IS NOT NULL
            EXEC system.sp_task_fail
              @run_id=@rid,
              @error_message=ERROR_MESSAGE(),
              @note=''SQL Agent parity check failed'';

          -- Re-raise error for SQL Agent
          THROW;
        END CATCH;',
      @retry_attempts=2,
      @retry_interval=5;

    -- Create schedule (02:15 UTC daily)
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name='SCOUT_PARITY_0215UTC')
      EXEC msdb.dbo.sp_delete_schedule @schedule_name='SCOUT_PARITY_0215UTC';

    EXEC msdb.dbo.sp_add_schedule
      @schedule_name='SCOUT_PARITY_0215UTC',
      @freq_type=4,         -- Daily
      @freq_interval=1,     -- Every day
      @active_start_time=21500; -- 02:15:00

    -- Attach schedule to job
    EXEC msdb.dbo.sp_attach_schedule
      @job_name='SCOUT_PARITY_CHECK_JOB',
      @schedule_name='SCOUT_PARITY_0215UTC';

    -- Add job to server
    EXEC msdb.dbo.sp_add_jobserver
      @job_name='SCOUT_PARITY_CHECK_JOB';

    PRINT 'SQL Agent job SCOUT_PARITY_CHECK_JOB created successfully';
  END
  ELSE
  BEGIN
    PRINT 'SQL Agent (msdb) not available - use Kubernetes CronJob for scheduling';
  END
END TRY
BEGIN CATCH
  PRINT 'SQL Agent job creation failed (likely permissions) - use Kubernetes CronJob for scheduling';
  PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH;

-- Verify task registration
SELECT
  task_code,
  task_name,
  enabled,
  owner,
  created_at
FROM system.task_definitions
WHERE task_code IN ('AUTO_SYNC_FLAT', 'PARITY_CHECK', 'MAIN_ETL', 'CANONICAL_ID_SYNC')
ORDER BY task_code;

-- Show current task status
SELECT * FROM system.v_task_status
WHERE task_code IN ('AUTO_SYNC_FLAT', 'PARITY_CHECK')
ORDER BY task_code;