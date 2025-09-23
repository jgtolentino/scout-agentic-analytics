-- Daily parity check procedure
CREATE OR ALTER PROCEDURE audit.sp_daily_parity_check
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2 = GETUTCDATE();
    DECLARE @check_date DATE = CAST(@start_time AS DATE);

    -- Check parity for last 7 days
    DECLARE @parity_failures INT = (
        SELECT COUNT(*)
        FROM audit.v_flat_vs_crosstab_parity
        WHERE [date] >= DATEADD(day, -7, @check_date)
          AND parity_status = 'FAIL ❌'
    );

    DECLARE @total_dates INT = (
        SELECT COUNT(*)
        FROM audit.v_flat_vs_crosstab_parity
        WHERE [date] >= DATEADD(day, -7, @check_date)
    );

    DECLARE @parity_percentage FLOAT = CASE
        WHEN @total_dates = 0 THEN 100.0
        ELSE ((@total_dates - @parity_failures) * 100.0 / @total_dates)
    END;

    -- Log parity check
    INSERT INTO audit.monitoring_log (check_type, status, metric_value, threshold_value, alert_level, details)
    VALUES (
        'PARITY_CHECK',
        CASE WHEN @parity_failures = 0 THEN 'PASS' ELSE 'FAIL' END,
        @parity_percentage,
        100.0,
        CASE WHEN @parity_failures = 0 THEN 'INFO' ELSE 'CRITICAL' END,
        'Parity failures: ' + CAST(@parity_failures AS NVARCHAR(10)) +
        ' out of ' + CAST(@total_dates AS NVARCHAR(10)) + ' dates'
    );

    -- Check data freshness
    DECLARE @latest_transaction DATETIME2 = (
        SELECT MAX(txn_ts) FROM gold.v_transactions_flat
    );

    DECLARE @hours_old FLOAT = DATEDIFF_BIG(MINUTE, @latest_transaction, @start_time) / 60.0;

    -- Log freshness check
    INSERT INTO audit.monitoring_log (check_type, status, metric_value, threshold_value, alert_level, details)
    VALUES (
        'FRESHNESS_CHECK',
        CASE WHEN @hours_old <= 12 THEN 'PASS' ELSE 'FAIL' END,
        @hours_old,
        12.0,
        CASE WHEN @hours_old <= 12 THEN 'INFO' WHEN @hours_old <= 24 THEN 'WARNING' ELSE 'CRITICAL' END,
        'Latest transaction: ' + CAST(@latest_transaction AS NVARCHAR(30)) +
        ', Age: ' + CAST(@hours_old AS NVARCHAR(10)) + ' hours'
    );

    -- Check record counts
    DECLARE @staging_count INT = (SELECT COUNT(*) FROM staging.transactions);
    DECLARE @gold_count INT = (SELECT COUNT(*) FROM gold.v_transactions_flat);

    INSERT INTO audit.monitoring_log (check_type, status, metric_value, threshold_value, alert_level, details)
    VALUES (
        'RECORD_COUNT_CHECK',
        CASE WHEN @staging_count = @gold_count AND @gold_count > 0 THEN 'PASS' ELSE 'FAIL' END,
        @gold_count,
        1.0,
        CASE WHEN @staging_count = @gold_count AND @gold_count > 0 THEN 'INFO' ELSE 'WARNING' END,
        'Staging: ' + CAST(@staging_count AS NVARCHAR(10)) +
        ', Gold: ' + CAST(@gold_count AS NVARCHAR(10)) + ' records'
    );

    -- Return summary for automation
    SELECT
        check_type,
        status,
        alert_level,
        metric_value,
        threshold_value,
        details
    FROM audit.monitoring_log
    WHERE check_timestamp >= @start_time
    ORDER BY alert_level DESC, check_type;

END;