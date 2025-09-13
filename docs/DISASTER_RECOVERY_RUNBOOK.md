# Disaster Recovery Runbook

## Overview
This runbook provides step-by-step procedures for backup, recovery, and disaster response for the TBWA Scout Dashboard v5.0 platform.

## Table of Contents
1. [Backup Strategy](#backup-strategy)
2. [Recovery Procedures](#recovery-procedures)
3. [Incident Response](#incident-response)
4. [Testing & Validation](#testing--validation)
5. [Contact Information](#contact-information)

## Backup Strategy

### 1. Database Backups (Supabase)

#### Automated Backups
```bash
# Daily automated backups via Supabase Dashboard
# Location: Supabase Dashboard > Settings > Backups
# Retention: 30 days
# Schedule: Daily at 2:00 AM UTC
```

#### Manual Backup Script
```bash
#!/bin/bash
# scripts/backup/database-backup.sh

set -euo pipefail

# Load environment variables
source .env.production

# Timestamp for backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/database/${TIMESTAMP}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Export database schema
pg_dump "${SUPABASE_DB_URL}" \
  --schema-only \
  --no-owner \
  --no-privileges \
  --file="${BACKUP_DIR}/schema.sql"

# Export data
pg_dump "${SUPABASE_DB_URL}" \
  --data-only \
  --exclude-schema=supabase_functions \
  --file="${BACKUP_DIR}/data.sql"

# Compress backup
tar -czf "${BACKUP_DIR}.tar.gz" "${BACKUP_DIR}"
rm -rf "${BACKUP_DIR}"

# Upload to S3/Azure Storage
aws s3 cp "${BACKUP_DIR}.tar.gz" "s3://tbwa-backups/database/${TIMESTAMP}.tar.gz"

echo "Backup completed: ${BACKUP_DIR}.tar.gz"
```

### 2. Application Code Backups

#### Git Repository
- **Primary**: GitHub (https://github.com/jgtolentino/tbwa-agency-databank.git)
- **Mirror**: Internal GitLab instance
- **Backup Schedule**: On every push (automated)

#### Backup Script
```bash
#!/bin/bash
# scripts/backup/code-backup.sh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/code/${TIMESTAMP}"

# Create full repository backup
git bundle create "${BACKUP_DIR}.bundle" --all
git bundle verify "${BACKUP_DIR}.bundle"

# Upload to backup storage
aws s3 cp "${BACKUP_DIR}.bundle" "s3://tbwa-backups/code/${TIMESTAMP}.bundle"
```

### 3. Environment & Configuration Backups

#### Environment Variables
```bash
#!/bin/bash
# scripts/backup/env-backup.sh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/env/${TIMESTAMP}"

# Encrypt and backup environment files
tar -czf - .env.* | \
  openssl enc -aes-256-cbc -salt -out "${BACKUP_DIR}.tar.gz.enc" -k "${BACKUP_ENCRYPTION_KEY}"

# Store encryption key separately (in secure vault)
echo "${BACKUP_ENCRYPTION_KEY}" | vault kv put secret/backups/${TIMESTAMP} key=-
```

### 4. Media & Static Assets

```bash
#!/bin/bash
# scripts/backup/assets-backup.sh

# Sync Supabase Storage buckets
supabase storage cp -r / "s3://tbwa-backups/storage/${TIMESTAMP}/"
```

## Recovery Procedures

### 1. Database Recovery

#### From Supabase Backup
```bash
# 1. Access Supabase Dashboard
# 2. Navigate to Settings > Backups
# 3. Select backup to restore
# 4. Click "Restore" and confirm

# OR via CLI
supabase db restore --backup-id <backup-id>
```

#### From Manual Backup
```bash
#!/bin/bash
# scripts/recovery/database-restore.sh

BACKUP_FILE=$1
TEMP_DIR="./temp/restore"

# Extract backup
mkdir -p "${TEMP_DIR}"
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Restore schema
psql "${SUPABASE_DB_URL}" < "${TEMP_DIR}/schema.sql"

# Restore data
psql "${SUPABASE_DB_URL}" < "${TEMP_DIR}/data.sql"

# Clean up
rm -rf "${TEMP_DIR}"

echo "Database restored from ${BACKUP_FILE}"
```

### 2. Application Recovery

#### Vercel Rollback
```bash
# Immediate rollback to previous deployment
vercel rollback

# Rollback to specific deployment
vercel rollback <deployment-url>

# List recent deployments
vercel list
```

#### From Git Backup
```bash
#!/bin/bash
# scripts/recovery/code-restore.sh

BUNDLE_FILE=$1

# Restore from bundle
git clone "${BUNDLE_FILE}" restored-repo
cd restored-repo

# Push to new remote if needed
git remote add recovery <new-remote-url>
git push recovery --all
git push recovery --tags
```

### 3. Environment Recovery

```bash
#!/bin/bash
# scripts/recovery/env-restore.sh

ENCRYPTED_BACKUP=$1
TIMESTAMP=$(basename "${ENCRYPTED_BACKUP}" .tar.gz.enc)

# Retrieve decryption key from vault
DECRYPTION_KEY=$(vault kv get -field=key secret/backups/${TIMESTAMP})

# Decrypt and restore
openssl enc -d -aes-256-cbc -in "${ENCRYPTED_BACKUP}" -k "${DECRYPTION_KEY}" | tar -xzf -

echo "Environment files restored"
```

## Incident Response

### Severity Levels

| Level | Description | Response Time | Example |
|-------|-------------|---------------|---------|
| P1 | Complete outage | < 15 minutes | Database unreachable |
| P2 | Major functionality loss | < 1 hour | Auth system down |
| P3 | Partial functionality loss | < 4 hours | Slow queries |
| P4 | Minor issues | < 24 hours | UI glitches |

### Response Procedures

#### 1. Initial Assessment (0-15 minutes)
```yaml
steps:
  - Check monitoring dashboards (Sentry, Vercel Analytics)
  - Verify database connectivity
  - Check API health endpoints
  - Review recent deployments
  - Identify affected components
```

#### 2. Containment (15-30 minutes)
```yaml
containment_actions:
  database_issue:
    - Enable read-only mode
    - Redirect traffic to replica
    - Scale up resources
  
  application_issue:
    - Rollback deployment
    - Enable maintenance mode
    - Clear CDN cache
  
  security_issue:
    - Disable affected endpoints
    - Rotate credentials
    - Enable additional logging
```

#### 3. Recovery Steps

##### Database Failure
```bash
# 1. Switch to read replica
./scripts/dr/switch-to-replica.sh

# 2. Diagnose primary
./scripts/dr/diagnose-database.sh

# 3. Restore from backup if needed
./scripts/recovery/database-restore.sh <backup-file>

# 4. Validate data integrity
./scripts/dr/validate-database.sh

# 5. Switch back to primary
./scripts/dr/switch-to-primary.sh
```

##### Application Failure
```bash
# 1. Enable maintenance mode
./scripts/dr/maintenance-mode.sh enable

# 2. Rollback or hotfix
vercel rollback  # OR
git revert <commit> && git push

# 3. Clear caches
./scripts/dr/clear-all-caches.sh

# 4. Validate functionality
./scripts/dr/smoke-tests.sh

# 5. Disable maintenance mode
./scripts/dr/maintenance-mode.sh disable
```

### 4. Communication Plan

#### Internal Communication
```yaml
channels:
  immediate: 
    - Slack: #incident-response
    - PagerDuty: @on-call-engineer
  
  updates:
    - Status Page: status.tbwa.com
    - Email: engineering@tbwa.com
```

#### External Communication
```yaml
templates:
  initial:
    subject: "Service Disruption - {service_name}"
    body: |
      We are currently experiencing issues with {service_name}.
      Our team is actively investigating.
      
      Affected Services: {affected_services}
      Start Time: {incident_start}
      
      Updates: {status_page_url}
  
  update:
    subject: "Update: Service Disruption - {service_name}"
    body: |
      Status: {current_status}
      Progress: {progress_description}
      ETA: {estimated_resolution}
  
  resolution:
    subject: "Resolved: Service Disruption - {service_name}"
    body: |
      The issue has been resolved.
      Duration: {total_duration}
      Root Cause: {root_cause_summary}
      
      Full postmortem: {postmortem_url}
```

## Testing & Validation

### Backup Testing Schedule
```yaml
daily:
  - Verify backup completion
  - Check backup file integrity
  
weekly:
  - Test database restore to staging
  - Validate restored data
  
monthly:
  - Full DR drill
  - Update runbook based on findings
  
quarterly:
  - Cross-region failover test
  - Review and update contact list
```

### Validation Scripts

#### Database Validation
```bash
#!/bin/bash
# scripts/dr/validate-database.sh

echo "Validating database..."

# Check table counts
TABLES=$(psql "${SUPABASE_DB_URL}" -t -c "
  SELECT COUNT(*) 
  FROM information_schema.tables 
  WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
")

# Check critical tables
CRITICAL_TABLES=("scout_dash.campaigns" "scout_dash.spots" "hr_admin.employees")

for table in "${CRITICAL_TABLES[@]}"; do
  COUNT=$(psql "${SUPABASE_DB_URL}" -t -c "SELECT COUNT(*) FROM ${table}")
  echo "${table}: ${COUNT} records"
done

# Run integrity checks
psql "${SUPABASE_DB_URL}" -c "
  SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
  FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
  LIMIT 20;
"
```

#### Application Health Check
```bash
#!/bin/bash
# scripts/dr/health-check.sh

ENDPOINTS=(
  "https://api.tbwa.com/health"
  "https://api.tbwa.com/api/v1/status"
  "https://scout.tbwa.com/"
)

for endpoint in "${ENDPOINTS[@]}"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${endpoint}")
  if [ "${STATUS}" -eq 200 ]; then
    echo "✅ ${endpoint} - OK"
  else
    echo "❌ ${endpoint} - Failed (${STATUS})"
  fi
done
```

## Contact Information

### Escalation Matrix

| Role | Name | Contact | Availability |
|------|------|---------|--------------|
| On-Call Engineer | Rotation | PagerDuty | 24/7 |
| Engineering Lead | John Doe | john@tbwa.com | Business hours |
| Database Admin | Jane Smith | jane@tbwa.com | Business hours |
| Security Lead | Bob Johnson | bob@tbwa.com | 24/7 for P1 |
| VP Engineering | Alice Brown | alice@tbwa.com | P1 escalation |

### External Contacts

| Service | Support Level | Contact | SLA |
|---------|---------------|---------|-----|
| Supabase | Enterprise | enterprise@supabase.com | 1 hour |
| Vercel | Pro | support@vercel.com | 4 hours |
| AWS | Business | AWS Support Console | 1 hour |
| GitHub | Enterprise | github.com/support | 4 hours |

## Appendix

### A. Useful Commands
```bash
# Check Supabase status
supabase status

# View Vercel logs
vercel logs --follow

# Database connection test
psql "${SUPABASE_DB_URL}" -c "SELECT 1"

# Redis connection test
redis-cli ping

# Clear all caches
npm run cache:clear
```

### B. Recovery Time Objectives (RTO)

| Component | RTO | RPO | Notes |
|-----------|-----|-----|-------|
| Database | 1 hour | 1 hour | Point-in-time recovery available |
| Application | 15 minutes | 0 | Instant rollback via Vercel |
| Auth System | 30 minutes | 0 | Stateless, config-driven |
| File Storage | 2 hours | 1 hour | S3 cross-region replication |

### C. Runbook Maintenance
- Review: Monthly
- Full test: Quarterly
- Update after: Every incident
- Owner: Platform Team

Last Updated: 2025-08-21
Next Review: 2025-09-21