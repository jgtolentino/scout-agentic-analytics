# Scout v7 Auto-Sync Grafana Observability Pack

Complete observability suite for Scout v7 Auto-Sync system with production-grade monitoring and alerting.

## Dashboard Features

### At-a-Glance Metrics
- **Running Tasks**: Live count of tasks running in last 15 minutes
- **Success Rate**: Configurable time window (1h to 168h)
- **Last Export Rows**: Most recent export volume
- **Parity Diff Ratio**: Data consistency gauge with color-coded thresholds

### Operational Views
- **Run Duration Timeline**: Performance trends by task type
- **Exports per Hour**: Activity patterns and peak detection
- **Last 50 Runs**: Detailed run history with status and errors
- **Recent Errors**: Real-time error feed for troubleshooting

## Alert Rules (Grafana 9+ Unified Alerting)

### High Parity Diff Alert
- **Trigger**: Parity diff ratio > 1% for 2 minutes
- **Severity**: Warning
- **Purpose**: Detect data consistency degradation

### Task Failures Alert
- **Trigger**: Any failed tasks in last 30 minutes
- **Severity**: Critical
- **Purpose**: Immediate failure notification

## Installation

### Quick Import (Manual)
1. Go to Grafana → Dashboards → Import
2. Upload `scout_v7_autosync_dashboard.json`
3. Configure MSSQL datasource connection
4. Import `scout_v7_alert_rules.json` via Alerting → Alert Rules → Import

### API Import (Automated)
```bash
# Import dashboard
curl -X POST "<GRAFANA_URL>/api/dashboards/db" \
  -H "Authorization: Bearer <API_KEY>" \
  -H "Content-Type: application/json" \
  --data-binary @scout_v7_autosync_dashboard.json

# Import alert rules (Grafana 9+)
curl -X POST "<GRAFANA_URL>/api/v1/provisioning/alert-rules" \
  -H "Authorization: Bearer <API_KEY>" \
  -H "Content-Type: application/json" \
  --data-binary @scout_v7_alert_rules.json
```

### Provisioning (Infrastructure as Code)
1. Place `datasource-provisioning.yaml` in `/etc/grafana/provisioning/datasources/`
2. Set environment variables: `AZSQL_HOST`, `AZSQL_DB`, `AZSQL_USER_READER`, `AZSQL_PASS_READER`
3. Restart Grafana to auto-provision datasource

## Configuration

### Environment Variables
```bash
# Database connection (read-only user recommended)
AZSQL_HOST=sqltbwaprojectscoutserver.database.windows.net
AZSQL_DB=SQL-TBWA-ProjectScout-Reporting-Prod
AZSQL_USER_READER=scout_reader
AZSQL_PASS_READER=<readonly_password>
```

### Dashboard Variables
- **Task Filter**: Multi-select dropdown for specific tasks
- **Time Window**: 1h, 3h, 6h, 12h, 24h, 48h, 168h options

### Color Coding
- **Green**: Healthy operations (parity diff < 1%)
- **Orange**: Warning threshold (parity diff 1-5%)
- **Red**: Critical threshold (parity diff > 5% or failures)

## Database Views Required

The dashboard queries these Scout v7 views:
- `system.v_task_status` - Current task status
- `system.v_task_run_history` - Historical run data
- `system.task_events` - Event log for troubleshooting

## Alert Channel Integration

Configure notification channels in Grafana:
- **Slack**: `#scout-alerts` channel
- **PagerDuty**: Critical failures escalation
- **Email**: Operations team distribution list

## Troubleshooting

### Common Issues
- **No Data**: Check MSSQL datasource connection and permissions
- **Missing Metrics**: Verify task framework tables exist and are populated
- **Alert Spam**: Adjust thresholds in alert rule conditions

### SQL Query Validation
Test dashboard queries directly:
```sql
-- Running tasks check
SELECT COUNT(1) AS running_count
FROM system.v_task_status WITH (NOLOCK)
WHERE status = 'RUNNING'
  AND last_heartbeat >= DATEADD(MINUTE, -15, SYSUTCDATETIME());

-- Success rate check
SELECT SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END)*1.0/COUNT(*) AS success_rate
FROM system.v_task_run_history WITH (NOLOCK)
WHERE start_time >= DATEADD(HOUR, -24, SYSUTCDATETIME());
```

## Maintenance

### Regular Tasks
- **Weekly**: Review alert thresholds and tune for false positives
- **Monthly**: Archive old task_events data (>90 days)
- **Quarterly**: Update dashboard for new Scout v7 features

### Performance Optimization
- **Indexes**: Ensure proper indexing on task framework tables
- **NOLOCK Hints**: Used for dashboard queries to avoid blocking
- **Connection Pooling**: Configure appropriate pool sizes in datasource

This observability pack provides enterprise-grade monitoring for Scout v7 Auto-Sync operations with immediate visibility into system health and performance.