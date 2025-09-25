# Azure SQL Database Troubleshooting Runbook

## 🔧 Quick Diagnosis & Resolution

### Connection Issues (90% of flaps)

#### Authentication Failures
**Symptom**: `Login failed for user 'sqladmin'`
```bash
# Check credential freshness
security find-generic-password -s "SQL-TBWA-ProjectScout-Reporting-Prod" -a "scout-analytics" -w

# Refresh vault if stale
security add-generic-password -U \
  -s "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -a "scout-analytics" \
  -w "<fresh-azure-sql-connection-string>"
```

#### Firewall Blocks
**Symptom**: `Client with IP address ... is not allowed to access the server`
```bash
# Add current IP to firewall (most common fix)
CURRENT_IP=$(curl -s ifconfig.me)
az sql server firewall-rule create \
  --resource-group <resource-group-name> \
  --server sqltbwaprojectscoutserver \
  --name "allow-current-ip-$(date +%Y%m%d)" \
  --start-ip-address "$CURRENT_IP" \
  --end-ip-address "$CURRENT_IP"

# Verify rule creation
az sql server firewall-rule list \
  --resource-group <resource-group-name> \
  --server sqltbwaprojectscoutserver \
  --query "[?name=='allow-current-ip-$(date +%Y%m%d)']"
```

#### Resource Throttling
**Symptom**: `The server is too busy` or transport-level errors
```bash
# Use built-in retry with exponential backoff
make persona-ci-retry DB="SQL-TBWA-ProjectScout-Reporting-Prod" MIN_PCT=30

# Or manual retry with delay
for i in {1..5}; do
  echo "Attempt $i/5..."
  make persona-ci && break
  sleep $((30 * i))
done
```

## 🔍 Connection Doctor Usage

### Automatic Diagnostics
```bash
# Quick health check with remediation suggestions
make doctor-db DB="SQL-TBWA-ProjectScout-Reporting-Prod"

# Connection doctor standalone
./scripts/conn_doctor.sh "SQL-TBWA-ProjectScout-Reporting-Prod"
```

### Pattern Recognition
The connection doctor identifies these patterns:
- **Firewall**: `Client with IP address` → IP whitelist needed
- **Auth**: `Login failed` → Credential refresh required
- **Throttle**: `server too busy` → Backoff retry recommended
- **Network**: `transport-level error` → Network issue, retry later
- **Database**: `not currently available` → Azure service issue

## 🔄 Retry Strategies

### Hands-Off Retry (Recommended)
```bash
# Automated retry with exponential backoff (up to 1 hour)
make persona-ci-retry DB="SQL-TBWA-ProjectScout-Reporting-Prod" MIN_PCT=30

# Via Bruno workflow
bruno run retry-until-db-up.yml
```

### Manual Retry Pattern
```bash
# Immediate retry (3 attempts)
for attempt in {1..3}; do
  echo "Attempt $attempt..."
  if make persona-ci DB="SQL-TBWA-ProjectScout-Reporting-Prod"; then
    echo "✅ Success on attempt $attempt"
    break
  fi
  sleep 30
done
```

### CI/GitHub Actions Retry
```bash
# Trigger manual retry workflow
gh workflow run persona_retry.yml
```

## 🧪 Local Development (DB Down)

### Mock Mode Testing
```bash
# Test persona CI pipeline without database
MOCK=1 make persona-ci DB="SQL-TBWA-ProjectScout-Reporting-Prod" MIN_PCT=30

# Validate script logic locally
MOCK=1 ./scripts/sql.sh -d "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -Q "SELECT * FROM gold.v_persona_coverage_summary;"
```

### Mock Data Generation
The mock router (`scripts/sql_mock_router.sh`) provides realistic responses:
- Coverage summary with configurable percentages
- Sample persona assignments with confidence scores
- Distribution data matching production patterns

## 📊 Health Monitoring

### Quick Status Check
```bash
# Smoke test entire persona stack
bruno run smoke-persona-stack-prod.yml

# Coverage snapshot
./scripts/sql.sh -d "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -Q "SELECT * FROM gold.v_persona_coverage_summary;"
```

### Expected Baselines
- **Coverage**: ≥30% persona assignment (current: 34.45%)
- **Confidence**: ≥0.70 average (current: 0.78)
- **Unique Personas**: ≥8 distinct roles detected
- **Response Time**: <30s for persona CI pipeline

## 🚨 Escalation Triggers

### Immediate Action Required
- **Authentication failures** persisting >15min → Check Azure portal access
- **Firewall blocks** from known IPs → Security policy change needed
- **Service unavailable** >1 hour → Azure service incident (check status page)
- **Data quality** drops <25% coverage → Schema/pipeline issue

### Azure Service Status
- Portal: https://status.azure.com/
- Specific service: Azure SQL Database status
- Region: Check East US 2 service health

## 🔧 Advanced Troubleshooting

### Connection String Validation
```bash
# Test connection string format
echo "$AZURE_SQL_CONN_STR" | grep -E "Server=.*database\.windows\.net.*Database=.*User.*Password="

# Extract components for debugging
echo "$AZURE_SQL_CONN_STR" | sed 's/Password=[^;]*/Password=***/'
```

### Network Diagnostics
```bash
# Test DNS resolution
nslookup sqltbwaprojectscoutserver.database.windows.net

# Test port connectivity
nc -zv sqltbwaprojectscoutserver.database.windows.net 1433

# Check for proxy/firewall interference
curl -v telnet://sqltbwaprojectscoutserver.database.windows.net:1433
```

### Resource Limits Check
```bash
# Check DTU usage (if applicable)
az sql db show-usage \
  --resource-group <resource-group> \
  --server sqltbwaprojectscoutserver \
  --name "SQL-TBWA-ProjectScout-Reporting-Prod"
```

## 📞 Contact Points

### Internal Escalation
1. **Database Issues**: TBWA Infrastructure team
2. **Credential Issues**: DevOps/Security team
3. **Azure Service Issues**: Cloud operations team

### External Escalation
1. **Azure Support**: Create support ticket via Azure portal
2. **Priority**: Business impact assessment required
3. **SLA**: Based on support plan tier

---
*Last updated: September 26, 2025*
*Covers: Conversation Intelligence MVP operational scenarios*