-- ============================================================================
-- Production Operations Bundle - Scout Analytics
-- Automated monitoring, credential rotation, and blob exports
-- ============================================================================

-- ===========================================
-- 1) CREDENTIAL ROTATION & SECURITY
-- ===========================================

PRINT '=== Production Security Hardening ===';

-- Update scout_reader password (Bruno will rotate this via vault)
-- ALTER USER [scout_reader] WITH PASSWORD = '{{vault.scout_analytics.sql_reader_password_new}}';

-- Create network security recommendations
PRINT 'SECURITY RECOMMENDATIONS:';
PRINT '1. Block public network access in Azure SQL firewall';
PRINT '2. Allow only specific IP ranges and Azure services';
PRINT '3. Enable Azure AD authentication for admin access';
PRINT '4. Rotate scout_reader password monthly via Bruno vault';
PRINT '';

-- ===========================================
-- 2) AUTOMATED PARITY & FRESHNESS MONITORING
-- ===========================================

PRINT '=== Creating Automated Monitoring ===';

-- Create monitoring log table
IF OBJECT_ID('audit.monitoring_log', 'U') IS NOT NULL
  DROP TABLE audit.monitoring_log;

CREATE TABLE audit.monitoring_log (
    check_id UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
    check_timestamp DATETIME2 DEFAULT GETUTCDATE(),
    check_type NVARCHAR(50) NOT NULL,
    status NVARCHAR(20) NOT NULL,
    metric_value FLOAT,
    threshold_value FLOAT,
    alert_level NVARCHAR(10),
    details NVARCHAR(1000),
    INDEX IX_monitoring_log_timestamp (check_timestamp),
    INDEX IX_monitoring_log_type_status (check_type, status)
);

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

PRINT 'Created audit.sp_daily_parity_check for automated monitoring';

-- ===========================================
-- 3) BLOB EXPORT PROCEDURES
-- ===========================================

PRINT '=== Creating Blob Export Capabilities ===';

-- Weekly full flat export procedure
CREATE OR ALTER PROCEDURE staging.sp_export_to_blob_full_flat
AS
BEGIN
    EXEC staging.sp_export_query_sql
        @report_name = N'scout_full_flat_weekly',
        @sql = N'
            SELECT
                canonical_tx_id, device_id, store_id, brand, product_name, category,
                total_amount, total_items, payment_method, audio_transcript,
                daypart, weekday_weekend, txn_ts, store_name, transaction_date
            FROM gold.v_transactions_flat
            ORDER BY txn_ts DESC;
        ';
END;

-- 14-day crosstab export for blob storage
CREATE OR ALTER PROCEDURE staging.sp_export_to_blob_crosstab_14d
AS
BEGIN
    EXEC staging.sp_export_query_sql
        @report_name = N'scout_crosstab_14d_blob',
        @sql = N'
            SELECT
                [date], store_name,
                Morning_Transactions, Midday_Transactions,
                Afternoon_Transactions, Evening_Transactions,
                txn_count as total_transactions,
                total_amount as total_revenue,
                ROUND(total_amount / txn_count, 2) as avg_transaction_value
            FROM gold.v_transactions_crosstab
            WHERE [date] >= CAST(DATEADD(day, -14, GETUTCDATE()) AS DATE)
            ORDER BY [date], store_name;
        ';
END;

PRINT 'Created blob export procedures for automated archival';

-- ===========================================
-- 4) MONITORING VIEWS & DASHBOARDS
-- ===========================================

PRINT '=== Creating Monitoring Views ===';

-- Monitoring dashboard view
CREATE OR ALTER VIEW audit.v_monitoring_dashboard
AS
SELECT
    check_timestamp,
    check_type,
    status,
    alert_level,
    metric_value,
    threshold_value,
    CASE
        WHEN alert_level = 'CRITICAL' THEN '🔴'
        WHEN alert_level = 'WARNING' THEN '🟡'
        ELSE '🟢'
    END as status_indicator,
    details,

    -- SLA calculations
    CASE check_type
        WHEN 'PARITY_CHECK' THEN
            CASE WHEN metric_value >= 100.0 THEN 'SLA_MET' ELSE 'SLA_BREACH' END
        WHEN 'FRESHNESS_CHECK' THEN
            CASE WHEN metric_value <= 12.0 THEN 'SLA_MET' ELSE 'SLA_BREACH' END
        WHEN 'RECORD_COUNT_CHECK' THEN
            CASE WHEN status = 'PASS' THEN 'SLA_MET' ELSE 'SLA_BREACH' END
        ELSE 'UNKNOWN'
    END as sla_status

FROM audit.monitoring_log
WHERE check_timestamp >= CAST(DATEADD(day, -7, GETUTCDATE()) AS DATE);

-- System health summary view
CREATE OR ALTER VIEW audit.v_system_health_summary
AS
WITH latest_checks AS (
    SELECT
        check_type,
        status,
        alert_level,
        metric_value,
        details,
        ROW_NUMBER() OVER (PARTITION BY check_type ORDER BY check_timestamp DESC) as rn
    FROM audit.monitoring_log
    WHERE check_timestamp >= CAST(DATEADD(day, -1, GETUTCDATE()) AS DATE)
)
SELECT
    check_type,
    status,
    alert_level,
    metric_value,
    details,
    CASE
        WHEN alert_level = 'CRITICAL' THEN 1
        WHEN alert_level = 'WARNING' THEN 2
        WHEN alert_level = 'INFO' THEN 3
        ELSE 4
    END as priority_order
FROM latest_checks
WHERE rn = 1;

PRINT 'Created monitoring dashboard views';

-- ===========================================
-- 5) ELASTIC JOBS AUTOMATION TEMPLATE
-- ===========================================

PRINT '=== Elastic Jobs Template ===';

-- Template for daily monitoring job (to be created in Elastic Jobs)
PRINT 'ELASTIC JOBS SQL TEMPLATE:';
PRINT '-- Create this job in Azure SQL Elastic Jobs:';
PRINT 'EXEC audit.sp_daily_parity_check;';
PRINT '';
PRINT 'Schedule: Daily at 06:00 UTC';
PRINT 'Target: flat_scratch database';
PRINT 'Credentials: scout_analytics_job_credential';
PRINT '';

-- ===========================================
-- 6) POWER BI DATASET TEMPLATE
-- ===========================================

PRINT '=== Power BI Dataset Preparation ===';

-- Create optimized views for Power BI
CREATE OR ALTER VIEW gold.v_pbi_transactions_summary
AS
SELECT
    CAST(txn_ts AS DATE) as transaction_date,
    DATEPART(YEAR, txn_ts) as year,
    DATEPART(MONTH, txn_ts) as month,
    DATEPART(DAY, txn_ts) as day,
    DATENAME(WEEKDAY, txn_ts) as weekday_name,
    daypart,
    weekday_weekend,

    store_id,
    store_name,

    brand,
    category,

    COUNT(*) as transaction_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    SUM(total_items) as total_items_sold,

    -- Additional metrics for dashboards
    COUNT(DISTINCT canonical_tx_id) as unique_transactions,
    COUNT(DISTINCT device_id) as unique_devices

FROM gold.v_transactions_flat
GROUP BY
    CAST(txn_ts AS DATE),
    DATEPART(YEAR, txn_ts),
    DATEPART(MONTH, txn_ts),
    DATEPART(DAY, txn_ts),
    DATENAME(WEEKDAY, txn_ts),
    daypart,
    weekday_weekend,
    store_id,
    store_name,
    brand,
    category;

-- Power BI brand performance view
CREATE OR ALTER VIEW gold.v_pbi_brand_performance
AS
SELECT
    brand,
    category,
    COUNT(*) as total_transactions,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    MIN(txn_ts) as first_transaction,
    MAX(txn_ts) as latest_transaction,
    COUNT(DISTINCT store_id) as stores_present,
    COUNT(DISTINCT CAST(txn_ts AS DATE)) as active_days,

    -- Performance metrics
    ROUND(SUM(total_amount) / COUNT(*), 2) as revenue_per_transaction,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as market_share_transactions,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER(), 2) as market_share_revenue

FROM gold.v_transactions_flat
GROUP BY brand, category;

PRINT 'Created optimized Power BI views';

-- ===========================================
-- 7) DEPLOYMENT VALIDATION
-- ===========================================

PRINT '=== Running Deployment Validation ===';

-- Run initial monitoring check
EXEC audit.sp_daily_parity_check;

-- Validate system health
SELECT 'System Health Check' as validation_type, * FROM audit.v_system_health_summary;

-- Check Power BI views
SELECT 'PBI Transactions Summary' as view_name, COUNT(*) as record_count FROM gold.v_pbi_transactions_summary
UNION ALL
SELECT 'PBI Brand Performance' as view_name, COUNT(*) as record_count FROM gold.v_pbi_brand_performance;

-- ===========================================
-- DEPLOYMENT COMPLETE
-- ===========================================

PRINT '';
PRINT '=== PRODUCTION OPS BUNDLE DEPLOYED ===';
PRINT '';
PRINT 'Monitoring:';
PRINT '• audit.sp_daily_parity_check - Automated daily health checks';
PRINT '• audit.v_monitoring_dashboard - Real-time monitoring view';
PRINT '• audit.v_system_health_summary - Current system status';
PRINT '';
PRINT 'Blob Exports:';
PRINT '• staging.sp_export_to_blob_full_flat - Weekly full export';
PRINT '• staging.sp_export_to_blob_crosstab_14d - 14-day dimensional export';
PRINT '';
PRINT 'Power BI:';
PRINT '• gold.v_pbi_transactions_summary - Optimized transaction analytics';
PRINT '• gold.v_pbi_brand_performance - Brand performance metrics';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Set up Elastic Jobs for audit.sp_daily_parity_check (daily 06:00 UTC)';
PRINT '2. Configure Azure SQL firewall to block public access';
PRINT '3. Rotate scout_reader password via Bruno vault';
PRINT '4. Create Power BI dataset using optimized views';
PRINT '5. Set up blob storage exports for weekly archival';
PRINT '';