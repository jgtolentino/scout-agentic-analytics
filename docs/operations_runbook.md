# Scout v7 Auto-Sync Operations Runbook

## Quick Status Checks

### Check Auto-Sync Status
```sql
-- Current fleet status
SELECT TOP 1 * FROM system.v_task_status WHERE task_code='AUTO_SYNC_FLAT';

-- Recent runs
SELECT TOP 10
    run_id,
    start_time,
    end_time,
    status,
    DATEDIFF(SECOND, start_time, COALESCE(end_time, SYSUTCDATETIME())) AS duration_seconds,
    version_start,
    version_end,
    rows_read,
    LEFT(artifacts, 100) AS artifacts_preview
FROM system.v_task_run_history
WHERE task_code = 'AUTO_SYNC_FLAT'
ORDER BY start_time DESC;

-- Live events
SELECT TOP 20
    td.task_code,
    te.event_time,
    te.level,
    LEFT(te.message, 150) AS message
FROM system.task_events te
JOIN system.task_runs tr ON te.run_id = tr.run_id
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE te.event_time >= DATEADD(HOUR, -2, SYSUTCDATETIME())
ORDER BY te.event_time DESC;
```

### Check Change Tracking Status
```sql
SELECT
    'Change Tracking' AS component,
    CASE WHEN CHANGE_TRACKING_CURRENT_VERSION() IS NOT NULL
         THEN 'ENABLED' ELSE 'DISABLED' END AS status,
    CHANGE_TRACKING_CURRENT_VERSION() AS current_version,
    CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions')) AS min_valid_version;
```

### Check Export Files
```sql
SELECT
    td.task_code,
    tr.end_time AS last_export_time,
    tr.rows_read AS exported_rows,
    LEFT(tr.artifacts, 200) AS file_paths,
    DATEDIFF(MINUTE, tr.end_time, SYSUTCDATETIME()) AS minutes_since_export
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE td.task_code = 'AUTO_SYNC_FLAT'
  AND tr.status = 'SUCCEEDED'
  AND tr.artifacts IS NOT NULL
  AND tr.end_time = (
    SELECT MAX(end_time)
    FROM system.task_runs tr2
    WHERE tr2.task_id = tr.task_id AND tr2.status = 'SUCCEEDED'
  );
```

## Manual Operations

### Manual Parity Check
```sql
DECLARE @rid BIGINT;
DECLARE @tbl TABLE(run_id BIGINT);

INSERT INTO @tbl
EXEC system.sp_task_start
    @task_code='PARITY_CHECK',
    @pid=CONVERT(nvarchar(100),@@SPID),
    @host=HOST_NAME(),
    @note='Manual parity check';

SELECT @rid=run_id FROM @tbl;

BEGIN TRY
  -- Execute parity check
  EXEC dbo.sp_parity_flat_vs_crosstab_ct @days_back=30;

  -- Mark successful completion
  EXEC system.sp_task_finish
    @run_id=@rid,
    @note='Manual parity check completed successfully';

END TRY
BEGIN CATCH
  -- Handle failure
  EXEC system.sp_task_fail
    @run_id=@rid,
    @error_message=ERROR_MESSAGE(),
    @note='Manual parity check failed';

  -- Re-raise error
  THROW;
END CATCH;
```

### Force Export (Manual Trigger)
```sql
-- Reset last version to force next export
UPDATE system.sync_state
SET last_version = NULL,
    last_export_note = 'Manual reset to force export'
WHERE state_id = (SELECT MAX(state_id) FROM system.sync_state);
```

### Disable/Enable Auto-Sync
```sql
-- Disable auto-sync task
UPDATE system.task_definitions
SET enabled=0, updated_at=SYSUTCDATETIME()
WHERE task_code='AUTO_SYNC_FLAT';

-- Re-enable auto-sync task
UPDATE system.task_definitions
SET enabled=1, updated_at=SYSUTCDATETIME()
WHERE task_code='AUTO_SYNC_FLAT';
```

## Container Operations

### Docker Commands
```bash
# Build image locally
docker build -f etl/agents/Dockerfile -t scout-autosync:local .

# Run locally with environment variables
docker run --rm \
  -e AZURE_SQL_ODBC="DRIVER={ODBC Driver 18 for SQL Server};SERVER=tcp:sqltbwaprojectscoutserver.database.windows.net,1433;DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;UID=TBWA;PWD=R@nd0mPA$$2025!;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;" \
  -e OUTDIR="/app/exports" \
  -e SYNC_INTERVAL="60" \
  -v $(pwd)/exports:/app/exports \
  scout-autosync:local

# Run parity check once
docker run --rm \
  -e AZURE_SQL_ODBC="DRIVER={ODBC Driver 18 for SQL Server};SERVER=tcp:sqltbwaprojectscoutserver.database.windows.net,1433;DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;UID=TBWA;PWD=R@nd0mPA$$2025!;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;" \
  -e TASK_OVERRIDE="PARITY_CHECK" \
  scout-autosync:local
```

### Docker Compose Operations
```bash
# Start auto-sync service
docker-compose up -d autosync

# View logs
docker-compose logs -f autosync

# Stop service
docker-compose down

# Check service status
docker-compose ps
```

### Kubernetes Operations
```bash
# Apply manifests
kubectl apply -f k8s/secret-autosync.yaml
kubectl apply -f k8s/deploy-autosync.yaml
kubectl apply -f k8s/cron-parity.yaml

# Check deployment status
kubectl get deployments scout-autosync
kubectl rollout status deployment/scout-autosync

# View logs
kubectl logs -f deployment/scout-autosync

# Check CronJob
kubectl get cronjobs scout-parity
kubectl get jobs --selector=job-name=scout-parity

# Manual parity check
kubectl create job --from=cronjob/scout-parity manual-parity-$(date +%s)

# Scale deployment
kubectl scale deployment scout-autosync --replicas=0  # Stop
kubectl scale deployment scout-autosync --replicas=1  # Start

# Update image
kubectl set image deployment/scout-autosync autosync=ghcr.io/jgtolentino/scout-agentic-analytics/auto-sync:v1.1.0
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Timeout
```sql
-- Check current connections
SELECT
    session_id,
    login_name,
    host_name,
    program_name,
    login_time,
    last_request_start_time
FROM sys.dm_exec_sessions
WHERE program_name LIKE '%python%' OR host_name LIKE '%scout%';

-- Check blocked processes
SELECT
    blocking_session_id,
    session_id,
    wait_type,
    wait_time,
    wait_resource
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;
```

#### 2. Change Tracking Issues
```sql
-- Check CT version gaps
SELECT
    CHANGE_TRACKING_CURRENT_VERSION() AS current_version,
    CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions')) AS min_valid_version,
    (SELECT MAX(version_end) FROM system.task_runs WHERE task_code='AUTO_SYNC_FLAT') AS last_processed_version;

-- Reset CT if needed (CAUTION: Will lose tracking history)
-- ALTER TABLE silver.Transactions DISABLE CHANGE_TRACKING;
-- ALTER TABLE silver.Transactions ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
```

#### 3. Export File Issues
```bash
# Check export directory permissions
ls -la exports/

# Check disk space
df -h

# View recent export attempts
grep -i "export" /var/log/scout-autosync.log | tail -20
```

#### 4. Task Framework Issues
```sql
-- Check for orphaned running tasks
SELECT
    td.task_code,
    tr.run_id,
    tr.start_time,
    DATEDIFF(MINUTE, tr.start_time, SYSUTCDATETIME()) AS running_minutes,
    tr.pid,
    tr.host
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE tr.status = 'RUNNING'
  AND tr.start_time <= DATEADD(HOUR, -2, SYSUTCDATETIME());

-- Manually fail stuck tasks
UPDATE system.task_runs
SET status = 'FAILED',
    end_time = SYSUTCDATETIME(),
    note = CONCAT(COALESCE(note, ''), ' | Manually failed due to timeout')
WHERE status = 'RUNNING'
  AND start_time <= DATEADD(HOUR, -4, SYSUTCDATETIME());
```

### Performance Monitoring

#### Database Performance
```sql
-- Check query performance
SELECT
    qs.execution_count,
    qs.total_worker_time / qs.execution_count AS avg_cpu_time_ms,
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_time_ms,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2)+1) AS statement_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE qt.text LIKE '%vw_FlatExport%'
   OR qt.text LIKE '%system.task_%'
ORDER BY qs.total_elapsed_time DESC;
```

#### Export Performance
```sql
-- Export timing analysis
SELECT
    DATE(start_time) AS export_date,
    COUNT(*) AS export_count,
    AVG(DATEDIFF(SECOND, start_time, end_time)) AS avg_duration_seconds,
    AVG(rows_read) AS avg_rows_exported,
    SUM(CASE WHEN status = 'SUCCEEDED' THEN 1 ELSE 0 END) AS successful_exports
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE td.task_code = 'AUTO_SYNC_FLAT'
  AND start_time >= DATEADD(DAY, -7, SYSUTCDATETIME())
  AND end_time IS NOT NULL
GROUP BY DATE(start_time)
ORDER BY export_date DESC;
```

## Health Monitoring Setup

### Alerting Queries
```sql
-- Tasks that haven't run in > 2 hours
SELECT task_code, last_run, DATEDIFF(MINUTE, last_run, SYSUTCDATETIME()) AS minutes_overdue
FROM system.v_task_status
WHERE last_run < DATEADD(HOUR, -2, SYSUTCDATETIME())
  AND task_code IN ('AUTO_SYNC_FLAT', 'PARITY_CHECK');

-- Recent failures (last 24 hours)
SELECT task_code, COUNT(*) AS failure_count
FROM system.v_task_run_history
WHERE status = 'FAILED'
  AND start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME())
GROUP BY task_code
HAVING COUNT(*) > 2;  -- Alert if > 2 failures in 24h

-- Long-running tasks (> 10 minutes)
SELECT task_code, run_id, start_time,
       DATEDIFF(MINUTE, start_time, SYSUTCDATETIME()) AS running_minutes
FROM system.v_task_run_history
WHERE status = 'RUNNING'
  AND start_time <= DATEADD(MINUTE, -10, SYSUTCDATETIME());
```

### Prometheus Metrics (Optional)
For Kubernetes deployments, consider adding metric endpoints to the container for Prometheus scraping.