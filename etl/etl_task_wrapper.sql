-- ETL Task Wrapper Template for Scout v7 Task Framework
-- Use this template to wrap existing stored procedures with task tracking

-- Example: Wrapping Main ETL Process
-- Replace 'MAIN_ETL' with appropriate task code and customize for your specific ETL

DECLARE @run_id BIGINT;
DECLARE @task_code SYSNAME = 'MAIN_ETL';

BEGIN TRY
    -- Start task run
    DECLARE @run_table TABLE(run_id BIGINT);
    INSERT INTO @run_table
    EXEC system.sp_task_start
        @task_code = @task_code,
        @pid = @@SPID,
        @host = HOST_NAME(),
        @note = 'Scheduled incremental ETL process';

    SELECT @run_id = run_id FROM @run_table;

    -- Log start of process
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = 'Starting main ETL process';

    -- ========================================
    -- Stage 1: Bronze Layer Processing
    -- ========================================
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = 'Stage 1: Processing bronze layer (PayloadTransactions)';

    -- Your bronze layer ETL code here
    -- Example: EXEC dbo.sp_process_payload_transactions;

    DECLARE @bronze_rows INT = @@ROWCOUNT;
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = CONCAT('Bronze layer complete: ', @bronze_rows, ' rows processed');

    -- ========================================
    -- Stage 2: Silver Layer Processing
    -- ========================================
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = 'Stage 2: Processing silver layer (Transactions enrichment)';

    -- Your silver layer ETL code here
    -- Example: EXEC dbo.sp_enrich_transactions;

    DECLARE @silver_rows INT = @@ROWCOUNT;
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = CONCAT('Silver layer complete: ', @silver_rows, ' rows processed');

    -- ========================================
    -- Stage 3: Gold Layer Processing
    -- ========================================
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = 'Stage 3: Processing gold layer (Analytics aggregations)';

    -- Your gold layer ETL code here
    -- Example: EXEC dbo.sp_build_analytics_tables;

    DECLARE @gold_rows INT = @@ROWCOUNT;
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = CONCAT('Gold layer complete: ', @gold_rows, ' rows processed');

    -- ========================================
    -- Data Quality Validation
    -- ========================================
    EXEC system.sp_task_heartbeat
        @run_id = @run_id,
        @level = 'INFO',
        @message = 'Stage 4: Data quality validation';

    -- Your data quality checks here
    DECLARE @quality_score DECIMAL(5,2);
    -- Example: SELECT @quality_score = dbo.fn_calculate_data_quality();

    IF @quality_score < 95.0
    BEGIN
        EXEC system.sp_task_heartbeat
            @run_id = @run_id,
            @level = 'WARN',
            @message = CONCAT('Data quality below threshold: ', @quality_score, '%');
    END
    ELSE
    BEGIN
        EXEC system.sp_task_heartbeat
            @run_id = @run_id,
            @level = 'INFO',
            @message = CONCAT('Data quality check passed: ', @quality_score, '%');
    END

    -- ========================================
    -- Success Completion
    -- ========================================
    DECLARE @total_rows INT = @bronze_rows + @silver_rows + @gold_rows;
    DECLARE @completion_note NVARCHAR(MAX) = CONCAT(
        'ETL completed successfully. ',
        'Bronze: ', @bronze_rows, ' rows, ',
        'Silver: ', @silver_rows, ' rows, ',
        'Gold: ', @gold_rows, ' rows. ',
        'Quality score: ', @quality_score, '%'
    );

    EXEC system.sp_task_finish
        @run_id = @run_id,
        @rows_read = @total_rows,
        @rows_written = @total_rows,
        @artifacts = NULL,
        @note = @completion_note;

    PRINT 'ETL process completed successfully';

END TRY
BEGIN CATCH
    -- Handle any errors
    DECLARE @error_msg NVARCHAR(MAX) = CONCAT(
        'Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE(),
        ' at line ', ERROR_LINE(),
        ' in procedure ', ISNULL(ERROR_PROCEDURE(), 'ad-hoc')
    );

    -- Log the failure
    IF @run_id IS NOT NULL
    BEGIN
        EXEC system.sp_task_fail
            @run_id = @run_id,
            @error_message = @error_msg,
            @note = 'ETL process failed during execution';
    END

    -- Re-raise the error
    THROW;
END CATCH;

-- ========================================
-- Alternative: Simple Wrapper for Existing SP
-- ========================================

/*
-- If you have an existing stored procedure, wrap it like this:

DECLARE @run_id BIGINT;
BEGIN TRY
    -- Start run
    DECLARE @run_table TABLE(run_id BIGINT);
    INSERT INTO @run_table
    EXEC system.sp_task_start @task_code='YOUR_TASK_CODE', @pid=@@SPID, @host=HOST_NAME();
    SELECT @run_id = run_id FROM @run_table;

    -- Execute existing procedure
    EXEC dbo.your_existing_stored_procedure;

    -- Finish successfully
    EXEC system.sp_task_finish @run_id=@run_id, @rows_read=@@ROWCOUNT, @note='Procedure completed';

END TRY
BEGIN CATCH
    -- Handle failure
    IF @run_id IS NOT NULL
        EXEC system.sp_task_fail @run_id=@run_id, @error_message=ERROR_MESSAGE();
    THROW;
END CATCH;
*/

-- ========================================
-- Python/PowerShell Integration Example
-- ========================================

/*
-- For external scripts, use similar pattern in your programming language:

import pyodbc

def run_with_task_tracking(task_code, operation_func):
    cn = pyodbc.connect(CONNECTION_STRING)
    cur = cn.cursor()
    run_id = None

    try:
        # Start task
        cur.execute("EXEC system.sp_task_start @task_code=?, @pid=?, @host=?",
                   (task_code, os.getpid(), socket.gethostname()))
        run_id = cur.fetchone()[0]

        # Heartbeat
        cur.execute("EXEC system.sp_task_heartbeat @run_id=?, @level='INFO', @message=?",
                   (run_id, "Starting operation"))

        # Your operation
        result = operation_func()

        # Finish
        cur.execute("EXEC system.sp_task_finish @run_id=?, @rows_read=?, @note=?",
                   (run_id, result.get('rows', 0), 'Operation completed'))

    except Exception as e:
        if run_id:
            cur.execute("EXEC system.sp_task_fail @run_id=?, @error_message=?",
                       (run_id, str(e)))
        raise
*/