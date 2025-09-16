# Google Drive ETL Operations Runbook
## Scout v7 Analytics Platform

### Table of Contents
1. [Daily Operations](#daily-operations)
2. [Monitoring and Alerting](#monitoring-and-alerting)
3. [Incident Response](#incident-response)
4. [Maintenance Procedures](#maintenance-procedures)
5. [Troubleshooting Guide](#troubleshooting-guide)
6. [Performance Optimization](#performance-optimization)
7. [Security Operations](#security-operations)

---

## Daily Operations

### Morning Health Check (9:00 AM)

**Check ETL Status:**
```sql
-- Check last 24 hours of ETL executions
SELECT 
  job_name,
  execution_id,
  started_at,
  completed_at,
  status,
  files_processed,
  files_succeeded,
  files_failed,
  processing_duration_seconds
FROM drive_intelligence.etl_execution_history
WHERE started_at > NOW() - INTERVAL '24 hours'
ORDER BY started_at DESC;
```

**Verify File Processing:**
```sql
-- Check files processed in last 24 hours
SELECT 
  processing_status,
  COUNT(*) as file_count,
  AVG(quality_score) as avg_quality,
  COUNT(CASE WHEN contains_pii THEN 1 END) as pii_files
FROM drive_intelligence.bronze_files 
WHERE synced_at > NOW() - INTERVAL '24 hours'
GROUP BY processing_status;
```

**Check System Health:**
```bash
#!/bin/bash
# File: /Users/tbwa/scout-v7/operations/daily-health-check.sh

echo "=== Google Drive ETL Health Check - $(date) ==="

# Test edge function connectivity
echo "Testing drive-mirror function..."
curl -s -X POST "https://your-project-ref.supabase.co/functions/v1/drive-mirror" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"folderId": "1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA", "dryRun": true}' | jq '.'

# Check Google API quota
echo "Checking Google API quota..."
# Add quota check implementation

# Verify database connections
echo "Testing database connectivity..."
psql $DATABASE_URL -c "SELECT COUNT(*) FROM drive_intelligence.bronze_files;"

echo "Health check completed at $(date)"
```

### Evening Summary Report (6:00 PM)

**Generate Daily Report:**
```sql
-- Daily processing summary
SELECT 
  DATE(synced_at) as process_date,
  COUNT(*) as total_files,
  COUNT(CASE WHEN processing_status = 'completed' THEN 1 END) as completed_files,
  COUNT(CASE WHEN processing_status = 'failed' THEN 1 END) as failed_files,
  COUNT(CASE WHEN contains_pii THEN 1 END) as pii_files,
  AVG(quality_score) as avg_quality_score,
  AVG(EXTRACT(EPOCH FROM (processed_at - synced_at))) as avg_processing_time_seconds
FROM drive_intelligence.bronze_files 
WHERE synced_at >= CURRENT_DATE
GROUP BY DATE(synced_at)
ORDER BY process_date DESC;
```

---

## Monitoring and Alerting

### Key Performance Indicators (KPIs)

**Operational Metrics:**
- File processing success rate: >99%
- Average processing time: <30 seconds per file
- API response time: <2 seconds
- System uptime: >99.9%

**Business Metrics:**
- Files processed per day: Target based on business volume
- PII detection accuracy: >95%
- Content extraction success rate: >90%
- Document classification accuracy: >85%

### Grafana Dashboard Queries

**File Processing Rate:**
```promql
# Files processed per hour
rate(drive_files_processed_total[1h])

# Processing success rate
(rate(drive_files_succeeded_total[5m]) / rate(drive_files_processed_total[5m])) * 100

# Average processing duration
rate(drive_processing_duration_seconds_sum[5m]) / rate(drive_processing_duration_seconds_count[5m])
```

**System Health:**
```promql
# Function availability
up{job="supabase-functions"}

# Database connection health
pg_up{job="postgresql"}

# Google API quota usage
google_api_quota_usage_percent{api="drive"}
```

### Alert Rules

**Critical Alerts (Immediate Response):**
```yaml
# /Users/tbwa/scout-v7/operations/alert-rules.yml
groups:
  - name: drive-etl-critical
    rules:
      - alert: DriveETLDown
        expr: up{job="drive-mirror"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Drive ETL system is down"
          description: "Drive mirror function has been down for more than 2 minutes"
          
      - alert: HighErrorRate
        expr: (rate(drive_errors_total[5m]) / rate(drive_requests_total[5m])) * 100 > 5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate in Drive ETL"
          description: "Error rate is {{ $value }}% over the last 5 minutes"
          
      - alert: GoogleAPIQuotaExhausted
        expr: google_api_quota_usage_percent > 95
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Google Drive API quota nearly exhausted"
          description: "API quota usage is at {{ $value }}%"
```

**Warning Alerts (Investigation Required):**
```yaml
  - name: drive-etl-warnings
    rules:
      - alert: SlowProcessing
        expr: rate(drive_processing_duration_seconds_sum[10m]) / rate(drive_processing_duration_seconds_count[10m]) > 60
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Slow file processing detected"
          description: "Average processing time is {{ $value }} seconds"
          
      - alert: HighPIIDetection
        expr: rate(drive_pii_files_detected_total[1h]) > 10
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "High rate of PII detection"
          description: "{{ $value }} files with PII detected in the last hour"
```

### Notification Channels

**Slack Integration:**
```json
{
  "webhook_url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
  "channel": "#scout-alerts",
  "title": "Scout Drive ETL Alert",
  "text": "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}"
}
```

**Email Notifications:**
```yaml
smtp_smarthost: 'smtp.gmail.com:587'
smtp_from: 'alerts@tbwa.com'
receivers:
  - name: 'dev-team'
    email_configs:
      - to: 'dev-team@tbwa.com'
        subject: '[Scout] Drive ETL Alert: {{ .GroupLabels.alertname }}'
        body: |
          Alert: {{ .GroupLabels.alertname }}
          Severity: {{ .CommonLabels.severity }}
          Description: {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
```

---

## Incident Response

### Incident Classification

**P0 - Critical (Response Time: 15 minutes)**
- Complete system down
- Data corruption detected
- Security breach

**P1 - High (Response Time: 1 hour)**
- Partial system functionality loss
- High error rates (>10%)
- API quota exhausted

**P2 - Medium (Response Time: 4 hours)**
- Performance degradation
- Non-critical feature failures
- Monitoring alerts

**P3 - Low (Response Time: Next business day)**
- Minor bugs
- Enhancement requests
- Documentation updates

### Incident Response Procedures

#### P0 Critical Incident Response

**Immediate Actions (0-15 minutes):**
1. **Acknowledge Alert:**
   ```bash
   # Update incident status
   echo "P0 Incident acknowledged at $(date)" >> /var/log/incidents/$(date +%Y%m%d).log
   ```

2. **Check System Status:**
   ```bash
   # Quick system health check
   curl -s https://your-project-ref.supabase.co/functions/v1/health | jq '.'
   
   # Check database connectivity
   psql $DATABASE_URL -c "SELECT 1;"
   
   # Verify Google API connectivity
   curl -s "https://www.googleapis.com/drive/v3/about" -H "Authorization: Bearer $GOOGLE_ACCESS_TOKEN"
   ```

3. **Notify Stakeholders:**
   ```bash
   # Send immediate notification
   curl -X POST $SLACK_WEBHOOK_URL \
     -H 'Content-Type: application/json' \
     -d '{"text": "🚨 P0 Incident: Google Drive ETL system down. Investigation in progress."}'
   ```

**Investigation Phase (15-30 minutes):**
1. **Check Recent Changes:**
   ```bash
   # Check recent deployments
   git log --oneline --since="24 hours ago" supabase/functions/drive-*
   
   # Check migration history
   psql $DATABASE_URL -c "SELECT * FROM metadata.migration_log ORDER BY executed_at DESC LIMIT 10;"
   ```

2. **Analyze Error Logs:**
   ```bash
   # Check function logs
   supabase functions logs drive-mirror --limit 100
   
   # Check execution history
   psql $DATABASE_URL -c "SELECT * FROM drive_intelligence.etl_execution_history WHERE started_at > NOW() - INTERVAL '2 hours' ORDER BY started_at DESC;"
   ```

3. **Identify Root Cause:**
   - Service account authentication issues
   - Google API quota limits
   - Database connection problems
   - Code deployment issues

**Resolution Phase (30-60 minutes):**
1. **Apply Immediate Fix:**
   ```bash
   # Rollback deployment if needed
   git revert <commit-hash>
   supabase functions deploy drive-mirror
   
   # Restart services if needed
   supabase functions restart drive-mirror
   
   # Clear cache if needed
   redis-cli FLUSHDB
   ```

2. **Verify Fix:**
   ```bash
   # Test system functionality
   curl -X POST "https://your-project-ref.supabase.co/functions/v1/drive-mirror" \
     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
     -d '{"folderId": "1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA", "dryRun": true}'
   ```

3. **Update Status:**
   ```bash
   # Notify resolution
   curl -X POST $SLACK_WEBHOOK_URL \
     -H 'Content-Type: application/json' \
     -d '{"text": "✅ P0 Incident resolved. System functionality restored."}'
   ```

#### P1 High Priority Response

**API Quota Exhaustion:**
```bash
#!/bin/bash
# File: /Users/tbwa/scout-v7/operations/quota-exhaustion-response.sh

echo "Handling API quota exhaustion..."

# Check current quota usage
curl -s "https://www.googleapis.com/drive/v3/about?fields=quotaBytesUsed,quotaBytesTotal" \
  -H "Authorization: Bearer $GOOGLE_ACCESS_TOKEN" | jq '.'

# Implement exponential backoff
echo "Implementing exponential backoff..."
psql $DATABASE_URL -c "UPDATE drive_intelligence.etl_job_registry SET enabled = false WHERE job_name LIKE '%Daily%';"

# Schedule reduced frequency sync
echo "Scheduling reduced frequency sync..."
psql $DATABASE_URL -c "UPDATE drive_intelligence.etl_job_registry SET schedule_cron = '0 */6 * * *' WHERE job_name = 'TBWA_Scout_Daily_Drive_Sync';"

# Send notification
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d '{"text": "⚠️ Google Drive API quota exhausted. Reduced sync frequency implemented."}'
```

**High Error Rate Response:**
```bash
#!/bin/bash
# File: /Users/tbwa/scout-v7/operations/high-error-response.sh

echo "Investigating high error rate..."

# Check recent errors
psql $DATABASE_URL -c "
SELECT 
  error_details,
  COUNT(*) as error_count
FROM drive_intelligence.bronze_files 
WHERE processing_status = 'failed' 
  AND synced_at > NOW() - INTERVAL '1 hour'
GROUP BY error_details
ORDER BY error_count DESC;
"

# Check function logs for patterns
supabase functions logs drive-mirror --limit 50 | grep -i error

# Retry failed files with exponential backoff
psql $DATABASE_URL -c "
UPDATE drive_intelligence.bronze_files 
SET processing_status = 'pending', 
    retry_count = COALESCE(retry_count, 0) + 1
WHERE processing_status = 'failed' 
  AND retry_count < 3 
  AND synced_at > NOW() - INTERVAL '1 hour';
"
```

### Post-Incident Procedures

**Incident Report Template:**
```markdown
# Incident Report: [YYYY-MM-DD-HH:MM] - [Brief Description]

## Summary
- **Incident ID:** INC-YYYY-MM-DD-XXX
- **Severity:** P0/P1/P2/P3
- **Start Time:** YYYY-MM-DD HH:MM UTC
- **End Time:** YYYY-MM-DD HH:MM UTC
- **Duration:** X hours Y minutes
- **Impact:** [Description of business impact]

## Timeline
- **HH:MM** - Alert triggered
- **HH:MM** - Incident acknowledged
- **HH:MM** - Investigation started
- **HH:MM** - Root cause identified
- **HH:MM** - Fix implemented
- **HH:MM** - Resolution verified

## Root Cause Analysis
[Detailed explanation of what caused the incident]

## Resolution
[Description of the fix applied]

## Prevention Measures
[Actions to prevent similar incidents]

## Action Items
- [ ] [Action item 1] - Assigned to [Person] - Due: [Date]
- [ ] [Action item 2] - Assigned to [Person] - Due: [Date]
```

---

## Maintenance Procedures

### Weekly Maintenance (Sundays 2:00 AM)

**Database Maintenance:**
```sql
-- Cleanup old execution logs (keep 90 days)
DELETE FROM drive_intelligence.etl_execution_history 
WHERE started_at < NOW() - INTERVAL '90 days';

-- Cleanup old webhook events (keep 30 days)
DELETE FROM drive_intelligence.webhook_events 
WHERE received_at < NOW() - INTERVAL '30 days';

-- Update table statistics
ANALYZE drive_intelligence.bronze_files;
ANALYZE drive_intelligence.silver_document_intelligence;

-- Reindex if needed
REINDEX INDEX CONCURRENTLY idx_bronze_files_folder;
REINDEX INDEX CONCURRENTLY idx_bronze_files_status;
```

**Performance Optimization:**
```bash
#!/bin/bash
# File: /Users/tbwa/scout-v7/operations/weekly-maintenance.sh

echo "Starting weekly maintenance - $(date)"

# Vacuum database tables
psql $DATABASE_URL -c "VACUUM ANALYZE drive_intelligence.bronze_files;"
psql $DATABASE_URL -c "VACUUM ANALYZE drive_intelligence.silver_document_intelligence;"

# Check and optimize slow queries
psql $DATABASE_URL -c "
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
WHERE query LIKE '%drive_intelligence%' 
ORDER BY mean_exec_time DESC 
LIMIT 10;
"

# Clean up temporary files
find /tmp -name "scout-drive-*" -mtime +7 -delete

# Rotate logs
logrotate /etc/logrotate.d/scout-drive-etl

echo "Weekly maintenance completed - $(date)"
```

### Monthly Maintenance (First Sunday 1:00 AM)

**Security Review:**
```bash
#!/bin/bash
# File: /Users/tbwa/scout-v7/operations/monthly-security-review.sh

echo "Starting monthly security review - $(date)"

# Check service account key rotation
echo "Checking service account key age..."
gcloud iam service-accounts keys list \
  --iam-account=scout-drive-etl@$PROJECT_ID.iam.gserviceaccount.com \
  --format="table(name,validAfterTime,validBeforeTime)"

# Check OAuth token expiration
echo "Checking OAuth token status..."
# Add OAuth token validation

# Review access logs
echo "Reviewing access patterns..."
psql $DATABASE_URL -c "
SELECT 
  DATE(started_at) as access_date,
  COUNT(*) as access_count,
  COUNT(DISTINCT execution_id) as unique_sessions
FROM drive_intelligence.etl_execution_history 
WHERE started_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(started_at)
ORDER BY access_date;
"

# Check for suspicious activity
psql $DATABASE_URL -c "
SELECT 
  job_id,
  COUNT(*) as execution_count
FROM drive_intelligence.etl_execution_history 
WHERE started_at > NOW() - INTERVAL '30 days'
  AND status = 'failed'
GROUP BY job_id
HAVING COUNT(*) > 10;
"

echo "Monthly security review completed - $(date)"
```

**Performance Review:**
```sql
-- Monthly performance metrics
SELECT 
  DATE_TRUNC('week', started_at) as week,
  COUNT(*) as total_executions,
  AVG(processing_duration_seconds) as avg_duration,
  AVG(files_processed) as avg_files_processed,
  COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_executions
FROM drive_intelligence.etl_execution_history 
WHERE started_at > NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('week', started_at)
ORDER BY week;
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: Authentication Failures

**Symptoms:**
- "Token refresh failed" errors
- "Service account key not configured" errors
- 401 Unauthorized responses from Google API

**Diagnosis:**
```bash
# Check environment variables
echo "Checking environment variables..."
env | grep -E "(GOOGLE_|DRIVE_)" | sed 's/=.*/=***/'

# Test token refresh
curl -X POST 'https://oauth2.googleapis.com/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=$GOOGLE_DRIVE_CLIENT_ID&client_secret=$GOOGLE_DRIVE_CLIENT_SECRET&refresh_token=$GOOGLE_DRIVE_REFRESH_TOKEN&grant_type=refresh_token"
```

**Solutions:**
1. **Refresh OAuth Token:**
   ```bash
   # Generate new refresh token
   # Use Google OAuth 2.0 Playground or custom script
   ```

2. **Rotate Service Account Key:**
   ```bash
   # Create new service account key
   gcloud iam service-accounts keys create new-key.json \
     --iam-account=scout-drive-etl@$PROJECT_ID.iam.gserviceaccount.com
   
   # Update Supabase secrets
   supabase secrets set GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY=$(base64 -i new-key.json)
   ```

#### Issue: High Processing Times

**Symptoms:**
- Files taking >60 seconds to process
- Timeouts in edge functions
- Queue backlog building up

**Diagnosis:**
```sql
-- Check processing time distribution
SELECT 
  file_category,
  AVG(EXTRACT(EPOCH FROM (processed_at - synced_at))) as avg_processing_time,
  MAX(EXTRACT(EPOCH FROM (processed_at - synced_at))) as max_processing_time,
  COUNT(*) as file_count
FROM drive_intelligence.bronze_files 
WHERE processed_at IS NOT NULL 
  AND synced_at > NOW() - INTERVAL '24 hours'
GROUP BY file_category
ORDER BY avg_processing_time DESC;
```

**Solutions:**
1. **Optimize Large File Handling:**
   ```bash
   # Update file size limits
   psql $DATABASE_URL -c "
   UPDATE drive_intelligence.etl_job_registry 
   SET max_file_size_mb = 50 
   WHERE job_name = 'TBWA_Scout_Daily_Drive_Sync';
   "
   ```

2. **Implement Parallel Processing:**
   ```bash
   # Increase batch size for parallel processing
   psql $DATABASE_URL -c "
   UPDATE drive_intelligence.etl_job_registry 
   SET processing_config = processing_config || '{\"max_parallel\": 20}'::jsonb 
   WHERE job_name = 'TBWA_Scout_Daily_Drive_Sync';
   "
   ```

#### Issue: PII Detection False Positives

**Symptoms:**
- High rate of PII flags on non-sensitive documents
- Business documents incorrectly classified as containing PII

**Diagnosis:**
```sql
-- Check PII detection patterns and their accuracy
SELECT 
  p.pattern_name,
  p.pii_type,
  COUNT(f.id) as files_flagged,
  p.false_positive_rate
FROM drive_intelligence.pii_detection_patterns p
LEFT JOIN drive_intelligence.bronze_files f ON f.pii_types @> to_jsonb(p.pii_type)
WHERE f.synced_at > NOW() - INTERVAL '7 days'
GROUP BY p.pattern_name, p.pii_type, p.false_positive_rate
ORDER BY files_flagged DESC;
```

**Solutions:**
1. **Update PII Patterns:**
   ```sql
   -- Disable overly aggressive patterns
   UPDATE drive_intelligence.pii_detection_patterns 
   SET enabled = false 
   WHERE pattern_name = 'Overly_Broad_Pattern' 
     AND false_positive_rate > 0.2;
   
   -- Add more specific patterns
   INSERT INTO drive_intelligence.pii_detection_patterns 
   (pattern_name, pattern_regex, pii_type, severity, false_positive_rate) 
   VALUES 
   ('Philippine_SSS_Specific', '\b\d{2}-\d{7}-\d{1}\b', 'ssn', 'high', 0.05);
   ```

#### Issue: Webhook Delivery Failures

**Symptoms:**
- Missing real-time updates
- Webhook events not being processed
- "No active subscription" errors

**Diagnosis:**
```sql
-- Check webhook subscription status
SELECT 
  channel_id,
  folder_id,
  expiration_time,
  active,
  last_notification_at,
  total_notifications
FROM drive_intelligence.webhook_subscriptions 
ORDER BY created_at DESC;

-- Check recent webhook events
SELECT 
  resource_state,
  processing_status,
  COUNT(*) as event_count
FROM drive_intelligence.webhook_events 
WHERE received_at > NOW() - INTERVAL '24 hours'
GROUP BY resource_state, processing_status;
```

**Solutions:**
1. **Re-register Webhooks:**
   ```bash
   # Re-register webhook
   curl -X POST "https://www.googleapis.com/drive/v3/files/watch" \
     -H "Authorization: Bearer $GOOGLE_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "id": "scout-drive-webhook-'$(date +%s)'",
       "type": "web_hook",
       "address": "https://your-project-ref.supabase.co/functions/v1/drive-webhook-handler"
     }'
   ```

2. **Clean Up Expired Subscriptions:**
   ```sql
   -- Mark expired subscriptions as inactive
   UPDATE drive_intelligence.webhook_subscriptions 
   SET active = false 
   WHERE expiration_time < NOW();
   ```

### Performance Optimization Scripts

#### Optimize Database Queries

```sql
-- File: /Users/tbwa/scout-v7/operations/optimize-queries.sql

-- Add missing indexes for common queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bronze_files_synced_processing 
ON drive_intelligence.bronze_files(synced_at, processing_status) 
WHERE processing_status IN ('pending', 'processing');

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_silver_docs_processed_at 
ON drive_intelligence.silver_document_intelligence(processed_at);

-- Optimize frequent aggregation queries
CREATE MATERIALIZED VIEW IF NOT EXISTS drive_intelligence.daily_processing_summary AS
SELECT 
  DATE(synced_at) as process_date,
  file_category,
  COUNT(*) as total_files,
  COUNT(CASE WHEN processing_status = 'completed' THEN 1 END) as completed_files,
  COUNT(CASE WHEN processing_status = 'failed' THEN 1 END) as failed_files,
  AVG(quality_score) as avg_quality_score
FROM drive_intelligence.bronze_files 
GROUP BY DATE(synced_at), file_category;

-- Create refresh function
CREATE OR REPLACE FUNCTION drive_intelligence.refresh_daily_summary()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY drive_intelligence.daily_processing_summary;
END;
$$ LANGUAGE plpgsql;
```

#### Cache Optimization

```bash
#!/bin/bash
# File: /Users/tbwa/scout-v7/operations/optimize-cache.sh

echo "Optimizing cache configuration..."

# Redis cache optimization for session data
redis-cli CONFIG SET maxmemory-policy allkeys-lru
redis-cli CONFIG SET maxmemory 256mb

# Clean up old cache entries
redis-cli --scan --pattern "drive_token:*" | xargs redis-cli DEL
redis-cli --scan --pattern "file_metadata:*" | grep -E "$(date -d '7 days ago' +%Y%m%d)" | xargs redis-cli DEL

echo "Cache optimization completed"
```

---

This operations runbook provides comprehensive procedures for managing the Google Drive ETL system in production. It covers daily operations, monitoring, incident response, maintenance, and troubleshooting to ensure reliable system operation.

Key areas covered:
- **Daily Operations**: Health checks and reporting procedures
- **Monitoring**: KPIs, dashboards, and alerting rules  
- **Incident Response**: Classified response procedures for different severity levels
- **Maintenance**: Weekly and monthly maintenance routines
- **Troubleshooting**: Common issues and their solutions
- **Performance**: Optimization scripts and procedures

This runbook should be regularly updated based on operational experience and system evolution.