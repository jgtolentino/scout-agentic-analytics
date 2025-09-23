# Scout v7 Task Framework Deployment Guide

## Overview

The Scout v7 Task Framework provides comprehensive tracking and monitoring for all ETL operations using:

- **Task Registration**: Central registry of all logical tasks
- **Execution Tracking**: Every run recorded with start/end times and Change Tracking versions
- **Event Logging**: Detailed breadcrumb trail for debugging and monitoring
- **Performance Metrics**: Row counts, durations, artifacts, and success rates

## Prerequisites

- Azure SQL Database with appropriate permissions
- Python 3.8+ with `pyodbc`, `pandas`, `openpyxl`, `pyarrow`
- ODBC Driver 18 for SQL Server

## Installation Steps

### 1. Deploy Database Schema

Execute the following SQL files in order:

```bash
# Apply the auto-sync infrastructure
sqlcmd -S $AZURE_SQL_SERVER -d $AZURE_SQL_DATABASE -U $AZURE_SQL_USER -P $AZURE_SQL_PASSWORD -i sql/025_enhanced_etl_column_mapping.sql

# Deploy task framework
sqlcmd -S $AZURE_SQL_SERVER -d $AZURE_SQL_DATABASE -U $AZURE_SQL_USER -P $AZURE_SQL_PASSWORD -i sql/026_task_framework.sql

# Register tasks
sqlcmd -S $AZURE_SQL_SERVER -d $AZURE_SQL_DATABASE -U $AZURE_SQL_USER -P $AZURE_SQL_PASSWORD -i sql/027_register_tasks.sql
```

### 2. Verify Installation

```sql
-- Check task registration
SELECT * FROM system.v_task_status ORDER BY task_code;

-- Verify Change Tracking
SELECT
    CHANGE_TRACKING_CURRENT_VERSION() AS current_version,
    CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions')) AS min_valid_version;

-- Test export view
SELECT TOP 5 * FROM gold.vw_FlatExport;
```

### 3. Configure Auto-Sync Worker

Set environment variables:

```bash
export AZURE_SQL_ODBC="DRIVER={ODBC Driver 18 for SQL Server};SERVER=tcp:$AZURE_SQL_SERVER,1433;DATABASE=$AZURE_SQL_DATABASE;UID=$AZURE_SQL_USER;PWD=$AZURE_SQL_PASSWORD;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
export OUTDIR=exports
export SYNC_INTERVAL=60
```

Install Python dependencies:

```bash
python3 -m pip install pyodbc pandas openpyxl pyarrow
```

### 4. Start Auto-Sync Worker

```bash
python3 etl/agents/auto_sync_tracked.py
```

## Monitoring

### Current Task Status

```sql
-- Fleet overview
SELECT * FROM system.v_task_status ORDER BY task_code;

-- Recent activity
SELECT TOP 20 * FROM system.v_task_run_history ORDER BY start_time DESC;

-- Live events
SELECT TOP 50
    td.task_code,
    te.event_time,
    te.level,
    te.message
FROM system.task_events te
JOIN system.task_runs tr ON te.run_id = tr.run_id
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE te.event_time >= DATEADD(HOUR, -2, SYSUTCDATETIME())
ORDER BY te.event_time DESC;
```

### Performance Analysis

```sql
-- Success rates (last 7 days)
SELECT
    td.task_code,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN tr.status = 'SUCCEEDED' THEN 1 ELSE 0 END) AS successful_runs,
    CAST(SUM(CASE WHEN tr.status = 'SUCCEEDED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS success_rate_pct,
    AVG(DATEDIFF(SECOND, tr.start_time, tr.end_time)) AS avg_duration_seconds
FROM system.task_definitions td
LEFT JOIN system.task_runs tr ON td.task_id = tr.task_id
    AND tr.start_time >= DATEADD(DAY, -7, SYSUTCDATETIME())
    AND tr.end_time IS NOT NULL
GROUP BY td.task_code
ORDER BY total_runs DESC;
```

### Failure Analysis

```sql
-- Recent failures
SELECT
    td.task_code,
    tr.start_time,
    tr.note AS failure_details,
    (SELECT TOP 1 message
     FROM system.task_events te
     WHERE te.run_id = tr.run_id AND te.level = 'ERROR'
     ORDER BY te.event_time DESC) AS error_message
FROM system.task_runs tr
JOIN system.task_definitions td ON tr.task_id = td.task_id
WHERE tr.status = 'FAILED'
  AND tr.start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME())
ORDER BY tr.start_time DESC;
```

## Integrating Existing ETL

### Wrapping Stored Procedures

Use the template in `etl/etl_task_wrapper.sql`:

```sql
DECLARE @run_id BIGINT;
BEGIN TRY
    -- Start task
    DECLARE @run_table TABLE(run_id BIGINT);
    INSERT INTO @run_table
    EXEC system.sp_task_start @task_code='YOUR_TASK', @pid=@@SPID, @host=HOST_NAME();
    SELECT @run_id = run_id FROM @run_table;

    -- Your ETL logic here
    EXEC dbo.your_existing_procedure;

    -- Mark success
    EXEC system.sp_task_finish @run_id=@run_id, @rows_read=@@ROWCOUNT;

END TRY
BEGIN CATCH
    IF @run_id IS NOT NULL
        EXEC system.sp_task_fail @run_id=@run_id, @error_message=ERROR_MESSAGE();
    THROW;
END CATCH;
```

### Python Integration

```python
import pyodbc
import os
import socket

def run_with_tracking(task_code, operation_func):
    cn = pyodbc.connect(os.getenv('AZURE_SQL_ODBC'))
    cur = cn.cursor()
    run_id = None

    try:
        # Start task
        cur.execute("""
            EXEC system.sp_task_start
            @task_code=?, @pid=?, @host=?, @note=?
        """, (task_code, os.getpid(), socket.gethostname(), "Python ETL"))
        run_id = cur.fetchone()[0]

        # Heartbeat
        cur.execute("""
            EXEC system.sp_task_heartbeat
            @run_id=?, @level='INFO', @message=?
        """, (run_id, "Starting operation"))

        # Your operation
        result = operation_func()

        # Finish
        cur.execute("""
            EXEC system.sp_task_finish
            @run_id=?, @rows_read=?, @note=?
        """, (run_id, result.get('rows', 0), 'Operation completed'))

    except Exception as e:
        if run_id:
            cur.execute("""
                EXEC system.sp_task_fail
                @run_id=?, @error_message=?
            """, (run_id, str(e)))
        raise

# Usage
def my_etl_process():
    # Your ETL logic here
    return {'rows': 1000}

run_with_tracking('MY_ETL_TASK', my_etl_process)
```

## Systemd Service Setup (Optional)

Create `/etc/systemd/system/scout-auto-sync.service`:

```ini
[Unit]
Description=Scout v7 Auto Sync Worker
After=network-online.target

[Service]
Environment=AZURE_SQL_ODBC=DRIVER={ODBC Driver 18 for SQL Server};SERVER=tcp:${AZURE_SQL_SERVER},1433;DATABASE=${AZURE_SQL_DATABASE};UID=${AZURE_SQL_USER};PWD=${AZURE_SQL_PASSWORD};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;
Environment=OUTDIR=/opt/scout-exports
Environment=SYNC_INTERVAL=60
WorkingDirectory=/opt/scout-v7
ExecStart=/usr/bin/python3 /opt/scout-v7/etl/agents/auto_sync_tracked.py
Restart=always
RestartSec=5
User=scout
Group=scout

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now scout-auto-sync.service
sudo systemctl status scout-auto-sync.service
```

## Troubleshooting

### Common Issues

1. **Change Tracking Not Enabled**
   ```sql
   -- Check if enabled
   SELECT * FROM sys.change_tracking_databases WHERE database_id = DB_ID();

   -- Enable if needed
   ALTER DATABASE CURRENT SET CHANGE_TRACKING = ON;
   ```

2. **Task Not Found Error**
   ```sql
   -- Re-register task
   EXEC system.sp_task_register
       @task_code='YOUR_TASK',
       @task_name='Your Task Name',
       @enabled=1;
   ```

3. **Connection Timeout**
   - Increase connection timeout in ODBC string
   - Check network connectivity
   - Verify Azure SQL firewall rules

4. **Export Files Missing**
   ```bash
   # Check OUTDIR permissions
   ls -la $OUTDIR

   # Check worker logs
   journalctl -u scout-auto-sync.service -f
   ```

### Health Checks

```sql
-- System health dashboard
SELECT
    'Tasks Registered' AS metric,
    COUNT(*) AS value
FROM system.task_definitions WHERE enabled = 1
UNION ALL
SELECT
    'Tasks Running',
    COUNT(*)
FROM system.task_runs WHERE status = 'RUNNING'
UNION ALL
SELECT
    'Recent Failures (24h)',
    COUNT(*)
FROM system.task_runs
WHERE status = 'FAILED' AND start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME());
```

## Best Practices

1. **Task Naming**: Use descriptive, consistent task codes (e.g., `MAIN_ETL`, `EXPORT_DAILY`)

2. **Heartbeats**: Send heartbeats at major milestones, not too frequently

3. **Error Handling**: Always wrap ETL code in try-catch with proper task failure recording

4. **Monitoring**: Set up alerts based on failure rates and long-running tasks

5. **Retention**: Regularly archive old task runs and events to manage database size

6. **Testing**: Test task wrapper integration in development before production deployment

## Support

For issues or questions:
- Check monitoring queries in `sql/028_task_monitoring.sql`
- Review recent task events for detailed error messages
- Verify Change Tracking versions for data lineage issues