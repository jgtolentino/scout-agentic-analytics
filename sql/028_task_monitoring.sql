-- Scout v7 Task Framework Monitoring Queries
-- Use these queries to monitor ETL task execution and performance

-- 1. Current Task Fleet Status
SELECT
    task_code,
    task_name,
    enabled,
    owner,
    last_run,
    last_status,
    CASE
        WHEN last_status = 'SUCCEEDED' THEN '✅'
        WHEN last_status = 'FAILED' THEN '❌'
        WHEN last_status = 'RUNNING' THEN '🔄'
        ELSE '⚠️'
    END AS status_icon,
    DATEDIFF(MINUTE, last_run, SYSUTCDATETIME()) AS minutes_since_last_run,
    last_version_end,
    LEFT(last_note, 100) AS last_note_preview
FROM system.v_task_status
ORDER BY task_code;

-- 2. Recent Run History (Last 24 hours)
SELECT
    task_code,
    run_id,
    start_time,
    end_time,
    status,
    DATEDIFF(SECOND, start_time, COALESCE(end_time, SYSUTCDATETIME())) AS duration_seconds,
    version_start,
    version_end,
    rows_read,
    rows_written,
    LEFT(artifacts, 200) AS artifacts_preview,
    LEFT(note, 150) AS note_preview
FROM system.v_task_run_history
WHERE start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME())
ORDER BY start_time DESC;

-- 3. Task Performance Summary (Last 7 days)
SELECT
    td.task_code,
    td.task_name,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN tr.status = 'SUCCEEDED' THEN 1 ELSE 0 END) AS successful_runs,
    SUM(CASE WHEN tr.status = 'FAILED' THEN 1 ELSE 0 END) AS failed_runs,
    CAST(SUM(CASE WHEN tr.status = 'SUCCEEDED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS success_rate_pct,
    AVG(DATEDIFF(SECOND, tr.start_time, tr.end_time)) AS avg_duration_seconds,
    MAX(DATEDIFF(SECOND, tr.start_time, tr.end_time)) AS max_duration_seconds,
    SUM(ISNULL(tr.rows_read, 0)) AS total_rows_processed
FROM system.task_definitions td
LEFT JOIN system.task_runs tr ON td.task_id = tr.task_id
    AND tr.start_time >= DATEADD(DAY, -7, SYSUTCDATETIME())
    AND tr.end_time IS NOT NULL
GROUP BY td.task_code, td.task_name
ORDER BY total_runs DESC;

-- 4. Recent Task Events (Last 2 hours)
SELECT
    td.task_code,
    tr.run_id,
    te.event_time,
    te.level,
    te.message,
    te.meta_json
FROM system.task_events te
JOIN system.task_runs tr ON te.run_id = tr.run_id
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE te.event_time >= DATEADD(HOUR, -2, SYSUTCDATETIME())
ORDER BY te.event_time DESC;

-- 5. Failed Tasks Analysis (Last 24 hours)
SELECT
    td.task_code,
    tr.run_id,
    tr.start_time,
    tr.end_time,
    tr.note AS failure_details,
    -- Get the most recent error event
    (SELECT TOP 1 message
     FROM system.task_events te
     WHERE te.run_id = tr.run_id AND te.level = 'ERROR'
     ORDER BY te.event_time DESC) AS last_error_message
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE tr.status = 'FAILED'
  AND tr.start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME())
ORDER BY tr.start_time DESC;

-- 6. Change Tracking Version Analysis
SELECT
    td.task_code,
    tr.run_id,
    tr.start_time,
    tr.version_start,
    tr.version_end,
    tr.min_valid_version,
    CASE
        WHEN tr.version_start IS NULL THEN 'No CT data'
        WHEN tr.version_start < tr.min_valid_version THEN 'Bootstrap needed'
        WHEN tr.version_end > tr.version_start THEN 'Changes processed'
        ELSE 'No changes'
    END AS ct_status,
    (tr.version_end - tr.version_start) AS versions_processed
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE tr.start_time >= DATEADD(HOUR, -6, SYSUTCDATETIME())
ORDER BY tr.start_time DESC;

-- 7. Long Running Tasks (Currently running > 10 minutes)
SELECT
    td.task_code,
    tr.run_id,
    tr.start_time,
    DATEDIFF(MINUTE, tr.start_time, SYSUTCDATETIME()) AS running_minutes,
    tr.pid,
    tr.host,
    tr.note,
    -- Get latest heartbeat
    (SELECT TOP 1 CONCAT(te.level, ': ', te.message)
     FROM system.task_events te
     WHERE te.run_id = tr.run_id
     ORDER BY te.event_time DESC) AS latest_heartbeat
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE tr.status = 'RUNNING'
  AND tr.start_time <= DATEADD(MINUTE, -10, SYSUTCDATETIME())
ORDER BY tr.start_time;

-- 8. Data Quality Dashboard
SELECT
    'Change Tracking Status' AS metric_type,
    CASE
        WHEN CHANGE_TRACKING_CURRENT_VERSION() IS NOT NULL THEN 'Enabled'
        ELSE 'Disabled'
    END AS status,
    CHANGE_TRACKING_CURRENT_VERSION() AS current_value,
    NULL AS threshold
UNION ALL
SELECT
    'Active Tasks',
    CAST(COUNT(*) AS NVARCHAR(50)),
    COUNT(*),
    NULL
FROM system.task_definitions WHERE enabled = 1
UNION ALL
SELECT
    'Running Tasks',
    CAST(COUNT(*) AS NVARCHAR(50)),
    COUNT(*),
    5 -- Alert if more than 5 tasks running
FROM system.task_runs WHERE status = 'RUNNING'
UNION ALL
SELECT
    'Recent Failures (24h)',
    CAST(COUNT(*) AS NVARCHAR(50)),
    COUNT(*),
    3 -- Alert if more than 3 failures in 24h
FROM system.task_runs
WHERE status = 'FAILED' AND start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME());

-- 9. Export Files Health Check
SELECT
    td.task_code,
    tr.run_id,
    tr.end_time AS last_export_time,
    tr.rows_written AS exported_rows,
    tr.artifacts AS file_paths,
    DATEDIFF(MINUTE, tr.end_time, SYSUTCDATETIME()) AS minutes_since_export
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE td.task_code LIKE '%EXPORT%'
  AND tr.status = 'SUCCEEDED'
  AND tr.artifacts IS NOT NULL
  AND tr.end_time = (
    SELECT MAX(end_time)
    FROM system.task_runs tr2
    WHERE tr2.task_id = tr.task_id AND tr2.status = 'SUCCEEDED'
  )
ORDER BY tr.end_time DESC;