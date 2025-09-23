-- Scout v7 Task Framework Monitoring Dashboard
-- Quick status checks for the auto-sync system

-- 1. Fleet Status Overview
PRINT '=== SCOUT V7 TASK FLEET STATUS ==='
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
    last_version_end
FROM system.v_task_status
ORDER BY task_code;

-- 2. Recent AUTO_SYNC_FLAT Activity
PRINT '=== AUTO_SYNC_FLAT RECENT RUNS ==='
SELECT TOP 10
    run_id,
    start_time,
    end_time,
    status,
    DATEDIFF(SECOND, start_time, COALESCE(end_time, SYSUTCDATETIME())) AS duration_seconds,
    version_start,
    version_end,
    rows_read,
    LEFT(artifacts, 100) AS artifacts_preview,
    LEFT(note, 100) AS note_preview
FROM system.v_task_run_history
WHERE task_code = 'AUTO_SYNC_FLAT'
ORDER BY start_time DESC;

-- 3. Change Tracking Status
PRINT '=== CHANGE TRACKING STATUS ==='
SELECT
    'Change Tracking' AS component,
    CASE WHEN CHANGE_TRACKING_CURRENT_VERSION() IS NOT NULL
         THEN 'ENABLED' ELSE 'DISABLED' END AS status,
    CHANGE_TRACKING_CURRENT_VERSION() AS current_version,
    CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions')) AS min_valid_version;

-- 4. Recent Task Events (Live Log)
PRINT '=== RECENT TASK EVENTS (Last 2 hours) ==='
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

-- 5. Export Health Check
PRINT '=== EXPORT FILES HEALTH ==='
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

-- 6. Data Quality Indicators
PRINT '=== DATA QUALITY INDICATORS ==='
SELECT
    'Canonical ID Normalization' AS quality_check,
    COUNT(*) AS total_records,
    SUM(CASE WHEN canonical_tx_id LIKE '%-%' OR canonical_tx_id COLLATE Latin1_General_CS_AS LIKE '%[A-Z]%'
             THEN 1 ELSE 0 END) AS issues_found,
    CASE WHEN SUM(CASE WHEN canonical_tx_id LIKE '%-%' OR canonical_tx_id COLLATE Latin1_General_CS_AS LIKE '%[A-Z]%'
                       THEN 1 ELSE 0 END) = 0
         THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM silver.Transactions
UNION ALL
SELECT
    'SI Timestamp Coverage',
    COUNT(*),
    SUM(CASE WHEN timestamp_source = 'PayloadTransactions' THEN 1 ELSE 0 END),
    CASE WHEN SUM(CASE WHEN timestamp_source = 'PayloadTransactions' THEN 1 ELSE 0 END) = 0
         THEN '✅ SI-ONLY' ELSE '⚠️ MIXED' END
FROM gold.vw_FlatExport;

-- 7. System Health Summary
PRINT '=== SYSTEM HEALTH SUMMARY ==='
SELECT
    'Active Tasks' AS metric,
    CAST(COUNT(*) AS NVARCHAR(50)) AS value,
    CASE WHEN COUNT(*) > 0 THEN '✅' ELSE '⚠️' END AS status
FROM system.task_definitions WHERE enabled = 1
UNION ALL
SELECT
    'Running Tasks',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) BETWEEN 0 AND 3 THEN '✅' ELSE '⚠️' END
FROM system.task_runs WHERE status = 'RUNNING'
UNION ALL
SELECT
    'Recent Failures (24h)',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) <= 2 THEN '✅' ELSE '❌' END
FROM system.task_runs
WHERE status = 'FAILED' AND start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME());

PRINT '=== MONITORING COMPLETE ==='