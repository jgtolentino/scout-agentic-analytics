-- Scout v7 Production Readiness SQL Schema
-- Tenant isolation, query tracking, comprehensive monitoring, and production safeguards

-- =============================================================================
-- 1. TENANT ISOLATION & ROW LEVEL SECURITY
-- =============================================================================

-- Add tenant isolation columns to existing tables
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('silver.Transactions') AND name = 'tenant_id')
BEGIN
    ALTER TABLE silver.Transactions ADD tenant_id VARCHAR(100) NOT NULL DEFAULT 'tbwa';
    CREATE INDEX IX_Transactions_TenantId ON silver.Transactions(tenant_id, transaction_timestamp);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Stores') AND name = 'tenant_id')
BEGIN
    ALTER TABLE dbo.Stores ADD tenant_id VARCHAR(100) NOT NULL DEFAULT 'tbwa';
    CREATE INDEX IX_Stores_TenantId ON dbo.Stores(tenant_id, store_id);
END
GO

-- Create tenant access function for RLS
CREATE OR ALTER FUNCTION dbo.fn_tenant_access(@tenant_id VARCHAR(100))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS tenant_access_allowed
    WHERE @tenant_id = CAST(SESSION_CONTEXT(N'current_tenant_id') AS VARCHAR(100));
GO

-- Enable RLS on key tables
ALTER TABLE silver.Transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dbo.Stores ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DROP SECURITY POLICY IF EXISTS TenantIsolationPolicy;
CREATE SECURITY POLICY TenantIsolationPolicy
ADD FILTER PREDICATE dbo.fn_tenant_access(tenant_id) ON silver.Transactions,
ADD FILTER PREDICATE dbo.fn_tenant_access(tenant_id) ON dbo.Stores
WITH (STATE = ON);
GO

-- =============================================================================
-- 2. QUERY TRACKING & ANALYTICS
-- =============================================================================

-- Ask Suqi query tracking table
CREATE TABLE system.AskSuqiQueries (
    query_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    session_id VARCHAR(100) NOT NULL,
    trace_id VARCHAR(100) NOT NULL,
    user_message NVARCHAR(MAX) NOT NULL,
    intent VARCHAR(200),
    confidence DECIMAL(3,2),
    plan_json NVARCHAR(MAX),
    execution_success BIT NOT NULL DEFAULT 0,
    execution_time_ms INT,
    artifacts_count INT DEFAULT 0,
    reply_type VARCHAR(50),
    has_errors BIT NOT NULL DEFAULT 0,
    error_message NVARCHAR(MAX),
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    INDEX IX_AskSuqi_Session (session_id, created_at DESC),
    INDEX IX_AskSuqi_User (user_id, created_at DESC),
    INDEX IX_AskSuqi_Tenant (tenant_id, created_at DESC),
    INDEX IX_AskSuqi_Performance (execution_success, execution_time_ms),
    INDEX IX_AskSuqi_Intent (intent, confidence)
);
GO

-- API request tracking table
CREATE TABLE system.ApiRequests (
    request_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    endpoint VARCHAR(200) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INT NOT NULL,
    response_time_ms INT NOT NULL,
    request_size_bytes INT,
    response_size_bytes INT,
    cache_hit BIT NOT NULL DEFAULT 0,
    error_message NVARCHAR(1000),
    trace_id VARCHAR(100),
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    INDEX IX_ApiRequests_Endpoint (endpoint, created_at DESC),
    INDEX IX_ApiRequests_Performance (status_code, response_time_ms),
    INDEX IX_ApiRequests_Tenant (tenant_id, created_at DESC)
);
GO

-- =============================================================================
-- 3. PRODUCTION SMOKE TEST PROCEDURES
-- =============================================================================

CREATE OR ALTER PROCEDURE system.sp_production_smoke_test
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @failures INT = 0;
    DECLARE @message NVARCHAR(MAX) = '';

    -- Test 1: Change Tracking enabled on database
    IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: Change Tracking not enabled on database. ';
    END

    -- Test 2: Change Tracking enabled on key tables
    IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id = OBJECT_ID('silver.Transactions'))
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: Change Tracking not enabled on silver.Transactions. ';
    END

    -- Test 3: Canonical ID normalization working
    IF EXISTS (SELECT 1 FROM silver.Transactions WHERE canonical_tx_id_norm IS NULL AND canonical_tx_id IS NOT NULL)
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: Canonical ID normalization incomplete. ';
    END

    -- Test 4: SI-only timestamps enforced
    IF EXISTS (SELECT 1 FROM gold.vw_FlatExport WHERE txn_ts IS NULL)
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: SI-only timestamp enforcement failed. ';
    END

    -- Test 5: Task framework health
    IF NOT EXISTS (SELECT 1 FROM system.v_task_status
                   WHERE last_heartbeat > DATEADD(MINUTE, -30, SYSUTCDATETIME()))
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: No recent task heartbeats detected. ';
    END

    -- Test 6: Data freshness check
    DECLARE @last_sync DATETIME2 = (
        SELECT MAX(last_heartbeat) FROM system.v_task_status
        WHERE task_name LIKE '%SYNC%' OR task_name LIKE '%EXPORT%'
    );
    IF @last_sync < DATEADD(HOUR, -2, SYSUTCDATETIME())
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: Data sync not running within expected window. ';
    END

    -- Test 7: RLS policies active
    IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'TenantIsolationPolicy' AND is_enabled = 1)
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: Row Level Security policies not active. ';
    END

    -- Test 8: Core views accessible
    BEGIN TRY
        DECLARE @test_count INT;
        SELECT @test_count = COUNT(*) FROM gold.vw_FlatExport WHERE 1=0; -- Syntax/permission check
    END TRY
    BEGIN CATCH
        SET @failures += 1;
        SET @message += 'FAIL: Core gold views not accessible. ';
    END CATCH

    -- Test 9: Indexes present for performance
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('silver.Transactions') AND name = 'IX_Transactions_TenantId')
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: Critical performance indexes missing. ';
    END

    -- Test 10: System procedures accessible
    IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_parity_flat_vs_crosstab')
    BEGIN
        SET @failures += 1;
        SET @message += 'FAIL: Critical system procedures missing. ';
    END

    -- Log the smoke test result
    INSERT INTO system.TaskEvents (task_name, event_type, message, created_at)
    VALUES ('SMOKE_TEST',
            CASE WHEN @failures = 0 THEN 'SUCCESS' ELSE 'ERROR' END,
            CASE WHEN @failures = 0 THEN 'All smoke tests passed' ELSE @message END,
            SYSUTCDATETIME());

    -- Return failure count (0 = success)
    RETURN @failures;
END
GO

-- =============================================================================
-- 4. ENHANCED PARITY CHECK
-- =============================================================================

CREATE OR ALTER PROCEDURE system.sp_enhanced_parity_check
    @days_back INT = 30,
    @threshold_percent DECIMAL(5,2) = 1.0,
    @diff_percent DECIMAL(5,2) OUTPUT,
    @is_within_threshold BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @flat_count BIGINT;
    DECLARE @crosstab_count BIGINT;
    DECLARE @difference BIGINT;
    DECLARE @start_date DATETIME2 = DATEADD(DAY, -@days_back, SYSUTCDATETIME());

    -- Count from flat export
    SELECT @flat_count = COUNT_BIG(*)
    FROM gold.vw_FlatExport
    WHERE txn_ts >= @start_date;

    -- Count from crosstab (sum of all product counts)
    SELECT @crosstab_count = SUM(CAST(transaction_count AS BIGINT))
    FROM gold.vw_CrossTabExport
    WHERE transaction_date >= CAST(@start_date AS DATE);

    -- Calculate difference
    SET @difference = ABS(@flat_count - @crosstab_count);
    SET @diff_percent = CASE
        WHEN @flat_count > 0 THEN (CAST(@difference AS DECIMAL(18,2)) / @flat_count) * 100
        ELSE 0
    END;

    SET @is_within_threshold = CASE WHEN @diff_percent <= @threshold_percent THEN 1 ELSE 0 END;

    -- Log the parity check result
    INSERT INTO system.TaskEvents (task_name, event_type, message, metadata_json, created_at)
    VALUES ('PARITY_CHECK',
            CASE WHEN @is_within_threshold = 1 THEN 'SUCCESS' ELSE 'WARNING' END,
            CONCAT('Parity check: ', @diff_percent, '% difference over ', @days_back, ' days'),
            JSON_OBJECT(
                'days_back', @days_back,
                'flat_count', @flat_count,
                'crosstab_count', @crosstab_count,
                'difference', @difference,
                'diff_percent', @diff_percent,
                'threshold_percent', @threshold_percent,
                'within_threshold', @is_within_threshold
            ),
            SYSUTCDATETIME());

    -- Return summary
    SELECT
        @days_back AS days_checked,
        @flat_count AS flat_count,
        @crosstab_count AS crosstab_count,
        @difference AS difference,
        @diff_percent AS difference_percent,
        @threshold_percent AS threshold_percent,
        @is_within_threshold AS within_threshold,
        CASE
            WHEN @is_within_threshold = 1 THEN 'PASS'
            ELSE 'FAIL'
        END AS result;
END
GO

-- =============================================================================
-- 5. PERFORMANCE MONITORING VIEWS
-- =============================================================================

-- API performance view
CREATE OR ALTER VIEW system.v_api_performance AS
SELECT
    endpoint,
    COUNT(*) AS request_count,
    AVG(CAST(response_time_ms AS FLOAT)) AS avg_response_time_ms,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY response_time_ms) AS p50_response_time_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS p95_response_time_ms,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms) AS p99_response_time_ms,
    SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) AS error_count,
    (SUM(CASE WHEN status_code >= 400 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS error_rate_percent,
    SUM(CASE WHEN cache_hit = 1 THEN 1 ELSE 0 END) AS cache_hits,
    (SUM(CASE WHEN cache_hit = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS cache_hit_rate_percent,
    MIN(created_at) AS first_request,
    MAX(created_at) AS last_request
FROM system.ApiRequests
WHERE created_at >= DATEADD(HOUR, -24, SYSUTCDATETIME())
GROUP BY endpoint;
GO

-- Ask Suqi analytics view
CREATE OR ALTER VIEW system.v_ask_suqi_analytics AS
SELECT
    intent,
    COUNT(*) AS query_count,
    AVG(confidence) AS avg_confidence,
    SUM(CASE WHEN execution_success = 1 THEN 1 ELSE 0 END) AS success_count,
    (SUM(CASE WHEN execution_success = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS success_rate_percent,
    AVG(CAST(execution_time_ms AS FLOAT)) AS avg_execution_time_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms) AS p95_execution_time_ms,
    reply_type,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(DISTINCT session_id) AS unique_sessions,
    MIN(created_at) AS first_query,
    MAX(created_at) AS last_query
FROM system.AskSuqiQueries
WHERE created_at >= DATEADD(HOUR, -24, SYSUTCDATETIME())
GROUP BY intent, reply_type;
GO

-- =============================================================================
-- 6. TENANT MANAGEMENT PROCEDURES
-- =============================================================================

CREATE OR ALTER PROCEDURE system.sp_set_tenant_context
    @tenant_id VARCHAR(100)
AS
BEGIN
    EXEC sp_set_session_context @key = N'current_tenant_id', @value = @tenant_id;
END
GO

CREATE OR ALTER PROCEDURE system.sp_create_tenant
    @tenant_id VARCHAR(100),
    @tenant_name NVARCHAR(200),
    @created_by VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- Create tenant record if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM system.Tenants WHERE tenant_id = @tenant_id)
    BEGIN
        INSERT INTO system.Tenants (tenant_id, tenant_name, created_by, created_at, is_active)
        VALUES (@tenant_id, @tenant_name, @created_by, SYSUTCDATETIME(), 1);

        -- Log tenant creation
        INSERT INTO system.TaskEvents (task_name, event_type, message, created_at)
        VALUES ('TENANT_MANAGEMENT', 'INFO',
                CONCAT('Tenant created: ', @tenant_id, ' (', @tenant_name, ')'),
                SYSUTCDATETIME());
    END
    ELSE
    BEGIN
        RAISERROR('Tenant already exists: %s', 16, 1, @tenant_id);
    END
END
GO

-- Create tenants table if not exists
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Tenants' AND schema_id = SCHEMA_ID('system'))
BEGIN
    CREATE TABLE system.Tenants (
        tenant_id VARCHAR(100) NOT NULL PRIMARY KEY,
        tenant_name NVARCHAR(200) NOT NULL,
        created_by VARCHAR(100) NOT NULL,
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        is_active BIT NOT NULL DEFAULT 1,
        metadata_json NVARCHAR(MAX)
    );

    -- Create default tenant
    INSERT INTO system.Tenants (tenant_id, tenant_name, created_by)
    VALUES ('tbwa', 'TBWA Philippines', 'system');
END
GO

-- =============================================================================
-- 7. CLEANUP AND ARCHIVAL PROCEDURES
-- =============================================================================

CREATE OR ALTER PROCEDURE system.sp_cleanup_old_logs
    @retention_days INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cutoff_date DATETIME2 = DATEADD(DAY, -@retention_days, SYSUTCDATETIME());
    DECLARE @deleted_count INT;

    -- Clean up old API requests
    DELETE FROM system.ApiRequests WHERE created_at < @cutoff_date;
    SET @deleted_count = @@ROWCOUNT;

    -- Clean up old Ask Suqi queries
    DELETE FROM system.AskSuqiQueries WHERE created_at < @cutoff_date;
    SET @deleted_count += @@ROWCOUNT;

    -- Clean up old task events (keep last 30 days)
    DELETE FROM system.TaskEvents
    WHERE created_at < DATEADD(DAY, -30, SYSUTCDATETIME())
    AND event_type NOT IN ('ERROR', 'CRITICAL');
    SET @deleted_count += @@ROWCOUNT;

    -- Log cleanup activity
    INSERT INTO system.TaskEvents (task_name, event_type, message, created_at)
    VALUES ('LOG_CLEANUP', 'INFO',
            CONCAT('Cleaned up ', @deleted_count, ' old log records (retention: ', @retention_days, ' days)'),
            SYSUTCDATETIME());
END
GO

PRINT 'Production readiness schema created successfully.';
PRINT 'Next steps:';
PRINT '1. Execute: EXEC system.sp_production_smoke_test -- Should return 0';
PRINT '2. Execute: EXEC system.sp_enhanced_parity_check @days_back=30';
PRINT '3. Set tenant context: EXEC system.sp_set_tenant_context @tenant_id=''tbwa''';
PRINT '4. Verify RLS: SELECT * FROM silver.Transactions -- Should be filtered by tenant';
GO