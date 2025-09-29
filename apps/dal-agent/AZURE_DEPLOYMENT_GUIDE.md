# Scout v7 Azure Deployment Guide

## Overview

This guide covers deploying the Scout v7 Azure SQL → Python → Blob pipeline in various Azure environments with proper CI/CD validation.

## Architecture

```
Azure SQL Database → Python Pipeline → Azure Blob Storage
        ↓                    ↓                ↓
   GOLD/SILVER tables    QA Gates        CSV Exports
                         Validation
                         Monitoring
```

## Deployment Options

### 1. Azure Functions (Recommended for Scheduled Jobs)

**Setup:**
```bash
# Create Function App
az functionapp create \
  --resource-group scout-rg \
  --consumption-plan-location eastus \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --name scout-pipeline-func \
  --storage-account scoutpipelinestorage

# Configure App Settings
az functionapp config appsettings set \
  --name scout-pipeline-func \
  --resource-group scout-rg \
  --settings \
    AZ_SQL_SERVER="sqltbwaprojectscoutserver.database.windows.net" \
    AZ_SQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod" \
    AZ_SQL_UID="scout_reader" \
    AZ_SQL_PWD="@Microsoft.KeyVault(SecretUri=https://scout-keyvault.vault.azure.net/secrets/sql-password)" \
    AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;..." \
    BLOB_CONTAINER="exports" \
    NCR_ONLY="1" \
    AMOUNT_TOLERANCE_PCT="1.0"
```

**Function Code Structure:**
```
scout-pipeline-func/
├── function_app.py          # Main function
├── pipeline.py              # Pipeline logic
├── requirements.txt         # Dependencies
├── scripts/
│   ├── validate_exports.py  # Validation
│   └── performance_monitor.py
└── host.json               # Function configuration
```

**function_app.py:**
```python
import azure.functions as func
import logging
from pipeline import main as run_pipeline

app = func.FunctionApp()

@app.schedule(schedule="0 2 * * *", arg_name="myTimer", run_on_startup=False)
def scout_pipeline_timer(myTimer: func.TimerRequest) -> None:
    logging.info('Scout v7 pipeline timer trigger started')

    try:
        run_pipeline()
        logging.info('Pipeline completed successfully')
    except Exception as e:
        logging.error(f'Pipeline failed: {e}')
        raise
```

### 2. Azure Container Apps (For Complex Pipelines)

**Dockerfile:**
```dockerfile
FROM python:3.11-slim

# Install ODBC Driver
RUN apt-get update && apt-get install -y \
    curl apt-transport-https gnupg2 \
    && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql18

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["python", "pipeline.py"]
```

**Deploy:**
```bash
# Build and push container
az acr build --registry scoutregistry --image scout-pipeline:latest .

# Create Container App
az containerapp create \
  --name scout-pipeline \
  --resource-group scout-rg \
  --environment scout-env \
  --image scoutregistry.azurecr.io/scout-pipeline:latest \
  --cpu 1.0 --memory 2.0Gi \
  --env-vars \
    AZ_SQL_SERVER="sqltbwaprojectscoutserver.database.windows.net" \
    AZ_SQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod" \
  --secrets \
    sql-password="$(az keyvault secret show --vault-name scout-keyvault --name sql-password --query value -o tsv)"
```

### 3. Azure Synapse Analytics (For Large-Scale Processing)

**Setup Synapse Pipeline:**
1. Create Synapse workspace
2. Add Python script as Synapse Notebook
3. Configure linked services for Azure SQL and Blob Storage
4. Create pipeline with triggers

**Synapse Notebook:**
```python
# Cell 1: Setup
import sys
sys.path.append('/opt/microsoft/spark/python/lib/py4j-0.10.9.5-src.zip')

# Cell 2: Run Pipeline
exec(open('pipeline.py').read())
```

### 4. GitHub Actions CI/CD Integration

**Secrets to Configure:**
- `AZ_SQL_SERVER`
- `AZ_SQL_DB`
- `AZ_SQL_UID`
- `AZ_SQL_PWD`
- `AZURE_STORAGE_CONNECTION_STRING`
- `SLACK_WEBHOOK`

**Workflow triggers:**
- Daily at 2 AM UTC (after Azure SQL refresh)
- On push to main/develop
- Manual dispatch with parameters

## Security Best Practices

### 1. Authentication Methods

**SQL Authentication (Basic):**
```python
AZ_SQL_UID = "scout_reader"
AZ_SQL_PWD = "from_keyvault_or_secret"
```

**Azure AD Authentication (Recommended):**
```python
# Uses DefaultAzureCredential
ENGINE_URL = f"mssql+pyodbc://@{AZ_SQL_SERVER}:1433/{AZ_SQL_DB}?driver={ODBC}&Authentication=ActiveDirectoryMsi"
```

**Managed Identity (Production):**
```bash
# Assign SQL permissions to managed identity
az sql server ad-admin set \
  --resource-group scout-rg \
  --server-name sqltbwaprojectscoutserver \
  --display-name scout-pipeline-identity \
  --object-id $(az identity show --resource-group scout-rg --name scout-pipeline-identity --query principalId -o tsv)
```

### 2. Key Vault Integration

**Store secrets in Azure Key Vault:**
```bash
az keyvault secret set --vault-name scout-keyvault --name sql-password --value "your-password"
az keyvault secret set --vault-name scout-keyvault --name storage-connection --value "your-connection-string"
```

**Reference in App Settings:**
```
AZ_SQL_PWD=@Microsoft.KeyVault(SecretUri=https://scout-keyvault.vault.azure.net/secrets/sql-password)
```

## Monitoring and Alerting

### 1. Azure Monitor Integration

**Log Analytics Workspace:**
```bash
az monitor log-analytics workspace create \
  --resource-group scout-rg \
  --workspace-name scout-logs \
  --location eastus
```

**Application Insights:**
```bash
az monitor app-insights component create \
  --app scout-pipeline-insights \
  --location eastus \
  --resource-group scout-rg \
  --workspace scout-logs
```

### 2. Alert Rules

**Pipeline Failure Alert:**
```bash
az monitor metrics alert create \
  --name "Scout Pipeline Failure" \
  --resource-group scout-rg \
  --scopes "/subscriptions/{subscription}/resourceGroups/scout-rg/providers/Microsoft.Web/sites/scout-pipeline-func" \
  --condition "count 'FunctionExecutionCount' failed > 0" \
  --window-size 5m \
  --action-group scout-alerts
```

**Data Quality Alert:**
```bash
az monitor log-analytics query \
  --workspace scout-logs \
  --analytics-query "
    traces
    | where message contains 'QA Gates' and message contains 'failed'
    | summarize count() by bin(timestamp, 5m)
  "
```

## Environment Configuration

### Development
```bash
export AZ_SQL_SERVER="sqltbwaprojectscoutserver.database.windows.net"
export AZ_SQL_DB="SQL-TBWA-ProjectScout-Reporting-Dev"
export AZ_SQL_UID="dev_user"
export AZ_SQL_PWD="dev_password"
export DATE_FROM="2025-09-01"
export DATE_TO="2025-09-02"
export NCR_ONLY="1"
export OUT_DIR="./out"
```

### Production
```bash
export AZ_SQL_SERVER="sqltbwaprojectscoutserver.database.windows.net"
export AZ_SQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod"
# Use Managed Identity or Key Vault
export DATE_FROM=$(date -d '30 days ago' '+%Y-%m-%d')
export DATE_TO=$(date '+%Y-%m-%d')
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;..."
export BLOB_CONTAINER="exports"
```

## Testing and Validation

### Local Testing
```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
source .env

# Run pipeline
python pipeline.py

# Run validation
./scripts/cicd_validation.sh validate
```

### CI/CD Testing
```bash
# Test with GitHub Actions
git push origin main

# Manual dispatch with parameters
gh workflow run "Scout v7 Azure Pipeline Validation" \
  --ref main \
  -f date_from="2025-09-01" \
  -f date_to="2025-09-02" \
  -f strict_mode="true"
```

## Troubleshooting

### Common Issues

**ODBC Driver Not Found:**
```bash
# Install on Ubuntu/Debian
sudo apt-get install msodbcsql18

# Install on RHEL/CentOS
sudo yum install msodbcsql18
```

**Azure SQL Connection Timeout:**
```python
# Add connection timeout and retry logic
ENGINE_URL += "&Connection+Timeout=30&Connect+Timeout=30"
```

**Blob Upload Failures:**
```python
# Add retry logic
from azure.core.exceptions import AzureError
import time

def upload_with_retry(blob_client, data, max_retries=3):
    for attempt in range(max_retries):
        try:
            blob_client.upload_blob(data, overwrite=True)
            return
        except AzureError as e:
            if attempt == max_retries - 1:
                raise
            time.sleep(2 ** attempt)
```

### Monitoring Queries

**Pipeline Success Rate:**
```kusto
traces
| where message contains "SUCCESS" or message contains "FAILED"
| summarize Success = countif(message contains "SUCCESS"),
           Failed = countif(message contains "FAILED") by bin(timestamp, 1h)
| extend SuccessRate = Success * 100.0 / (Success + Failed)
```

**Data Quality Metrics:**
```kusto
traces
| where message contains "rows=" and message contains "cols="
| parse message with * "rows=" rows:int " cols=" cols:int *
| summarize avg(rows), avg(cols) by bin(timestamp, 1d)
```

## Performance Optimization

### Database Optimization
- Use read-only replicas for reporting queries
- Implement query result caching
- Optimize date range filtering with partitioning

### Pipeline Optimization
- Enable parallel processing for large datasets
- Use chunked processing for memory efficiency
- Implement incremental exports for large tables

### Blob Storage Optimization
- Use hot/cool/archive tiers appropriately
- Enable compression for CSV exports
- Implement lifecycle management policies