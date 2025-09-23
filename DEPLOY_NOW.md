# Scout v7 Auto-Sync - Emergency Deploy Today 🚀

**Goal**: Get Scout v7 auto-sync running in production within 30 minutes with copy-paste commands.

## Prerequisites ✓
- Azure SQL credentials (reader + writer access)
- Docker installed OR Kubernetes cluster access
- SQL Server firewall allows connections from deployment host

## Step 1: Database Setup (5 minutes)

Run these SQL files in order on `SQL-TBWA-ProjectScout-Reporting-Prod`:

```sql
-- Core database objects
:r .\database\migrations\025_enhanced_etl_column_mapping.sql
:r .\database\migrations\026_task_framework.sql
:r .\database\migrations\029_sp_task_export_flat_delta.sql
:r .\database\migrations\036_sp_task_smoke_test.sql

-- Quick validation
EXEC system.sp_task_smoke_test;   -- Should return all ✅
```

## Step 2A: Docker Deployment (EASIEST - 10 minutes)

### Test Export (One-Shot)
```bash
docker run --rm \
  -e AZSQL_HOST="sqltbwaprojectscoutserver.database.windows.net" \
  -e AZSQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod" \
  -e AZSQL_USER_WRITER="TBWA" \
  -e AZSQL_PASS_WRITER="R@nd0mPA$$2025!" \
  -e LOG_LEVEL="INFO" \
  -e TASK_OVERRIDE="EXPORT_ONCE" \
  ghcr.io/jgtolentino/scout-agentic-analytics/auto-sync:latest
```

### Production Continuous Mode
```bash
docker run -d --name scout-autosync \
  --restart=unless-stopped \
  -p 8080:8080 \
  -v $(pwd)/exports:/app/exports \
  -e AZSQL_HOST="sqltbwaprojectscoutserver.database.windows.net" \
  -e AZSQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod" \
  -e AZSQL_USER_WRITER="TBWA" \
  -e AZSQL_PASS_WRITER="R@nd0mPA$$2025!" \
  -e SYNC_INTERVAL="60" \
  -e LOG_LEVEL="INFO" \
  ghcr.io/jgtolentino/scout-agentic-analytics/auto-sync:latest

# Verify health
curl -fsS http://localhost:8080/healthz && echo "✅ HEALTHY"
```

### Monitor Logs
```bash
docker logs -f scout-autosync
```

## Step 2B: Kubernetes Deployment (15 minutes)

### Create Secret
```bash
kubectl create secret generic scout-autosync-secrets \
  --from-literal=AZSQL_HOST="sqltbwaprojectscoutserver.database.windows.net" \
  --from-literal=AZSQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod" \
  --from-literal=AZSQL_USER_WRITER="TBWA" \
  --from-literal=AZSQL_PASS_WRITER="R@nd0mPA$$2025!"
```

### Deploy Auto-Sync
```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout-autosync
  labels: { app: scout-autosync }
spec:
  replicas: 1
  selector: { matchLabels: { app: scout-autosync } }
  template:
    metadata: { labels: { app: scout-autosync } }
    spec:
      containers:
      - name: autosync
        image: ghcr.io/jgtolentino/scout-agentic-analytics/auto-sync:latest
        envFrom: [{ secretRef: { name: scout-autosync-secrets } }]
        env:
        - { name: SYNC_INTERVAL, value: "60" }
        - { name: LOG_LEVEL, value: "INFO" }
        ports: [{ containerPort: 8080, name: healthz }]
        readinessProbe:
          httpGet: { path: /healthz, port: 8080 }
          initialDelaySeconds: 10
          periodSeconds: 15
        livenessProbe:
          httpGet: { path: /healthz, port: 8080 }
          initialDelaySeconds: 30
          periodSeconds: 30
        resources:
          requests: { cpu: "100m", memory: "256Mi" }
          limits: { cpu: "500m", memory: "512Mi" }
---
apiVersion: v1
kind: Service
metadata:
  name: scout-autosync-svc
spec:
  selector: { app: scout-autosync }
  ports: [{ port: 8080, targetPort: 8080 }]
EOF
```

### Verify Deployment
```bash
kubectl rollout status deployment/scout-autosync
kubectl logs -f deployment/scout-autosync
```

## Step 3: Validation (5 minutes)

### Database Checks
```sql
-- Task status
SELECT * FROM system.v_task_status ORDER BY last_heartbeat DESC;

-- Recent runs
SELECT TOP 10 task_name, status, start_time, end_time, rows_read
FROM system.v_task_run_history
ORDER BY start_time DESC;

-- Export data available
SELECT COUNT(*) AS total_rows FROM gold.vw_FlatExport;
SELECT TOP 5 * FROM gold.vw_FlatExport ORDER BY txn_ts DESC;
```

### Health Endpoint
```bash
# Docker
curl -fsS http://localhost:8080/healthz

# Kubernetes
kubectl port-forward svc/scout-autosync-svc 8080:8080 &
curl -fsS http://localhost:8080/healthz
```

## Step 4: Consumer Integration (2 minutes)

Point all downstream tools to:
```sql
SELECT * FROM gold.vw_FlatExport
WHERE txn_ts >= DATEADD(DAY, -30, SYSUTCDATETIME())
ORDER BY txn_ts DESC;
```

**Key Fields**:
- `canonical_tx_id_norm`: Normalized transaction ID (join key)
- `txn_ts`: Authoritative timestamp (SI-sourced only)
- `transaction_date`: Date partition
- `amount`, `basket_count`: Transaction metrics
- `store_name`, `region_name`: Location data
- `age_group`, `gender`, `emotion`: Demographics

## Step 5: Operational Commands

### One-Shot Operations
```bash
# Parity check (30 days)
docker run --rm \
  -e AZSQL_HOST="sqltbwaprojectscoutserver.database.windows.net" \
  -e AZSQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod" \
  -e AZSQL_USER_WRITER="TBWA" \
  -e AZSQL_PASS_WRITER="R@nd0mPA$$2025!" \
  -e TASK_OVERRIDE="PARITY_CHECK" \
  -e PARITY_DAYS_BACK="30" \
  ghcr.io/jgtolentino/scout-agentic-analytics/auto-sync:latest

# Single sync cycle test
docker run --rm \
  -e AZSQL_HOST="sqltbwaprojectscoutserver.database.windows.net" \
  -e AZSQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod" \
  -e AZSQL_USER_WRITER="TBWA" \
  -e AZSQL_PASS_WRITER="R@nd0mPA$$2025!" \
  -e TASK_OVERRIDE="SYNC_ONCE" \
  ghcr.io/jgtolentino/scout-agentic-analytics/auto-sync:latest
```

## Troubleshooting

### Common Issues & Fixes

**🔥 SQL Connection Fails**
```bash
# Test connection directly
sqlcmd -S sqltbwaprojectscoutserver.database.windows.net \
        -d SQL-TBWA-ProjectScout-Reporting-Prod \
        -U TBWA -P 'R@nd0mPA$$2025!' \
        -Q "SELECT SYSUTCDATETIME() AS current_time"
```

**🔥 Container Won't Start**
```bash
# Check logs
docker logs scout-autosync

# Check environment
docker exec scout-autosync env | grep AZSQL
```

**🔥 No Data in Export View**
```sql
-- Check silver layer
SELECT COUNT(*) FROM silver.Transactions;

-- Check change tracking
SELECT CHANGE_TRACKING_CURRENT_VERSION() AS current_version;

-- Force sync state reset
UPDATE system.sync_state SET last_version = NULL;
```

**🔥 Image Pull Fails**
```bash
# Use local build instead
git clone <repo>
cd scout-v7
docker build -f etl/agents/Dockerfile -t scout-autosync:local .

# Then use scout-autosync:local instead of ghcr.io/... image
```

## Success Criteria ✅

1. **Health Check**: `curl /healthz` returns 200 OK
2. **Task Runs**: `system.v_task_status` shows recent heartbeats
3. **Data Export**: `gold.vw_FlatExport` has recent transactions
4. **Parity Check**: No significant differences detected
5. **Continuous Operation**: Worker processes new changes automatically

## Next Steps (Optional)

- **Grafana Dashboard**: Import `grafana/scout_v7_autosync_dashboard.json`
- **Scaling**: Add replicas for high availability
- **Monitoring**: Set up alerts on task failures
- **Backup**: Schedule export file archival

**🎯 Total Time**: 20-30 minutes for full deployment
**🔒 Status**: Production-ready with enterprise safeguards