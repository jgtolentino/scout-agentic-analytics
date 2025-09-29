# Azure Data Factory - Scout Analytics ETL Pipeline

Comprehensive Data Factory configuration for Scout Analytics medallion architecture (Bronze → Silver → Gold → Platinum).

## Overview

**Purpose**: Automated ETL pipeline for Scout transaction data processing with real-time insights generation.

**Architecture**: Event-driven medallion pattern with quality gates and AI-powered enhancement.

**Data Sources**:
- Google Drive (JSON/ZIP transaction files)
- Excel files (cross-tabulation data)
- Real-time streams (webhook endpoints)
- Azure Blob Storage (raw data ingestion)

## Pipeline Architecture

### 1. Bronze Layer (Raw Data Ingestion)
```yaml
pipeline: "scout-bronze-ingestion"
trigger: "blob-created, schedule-hourly"
sources:
  - google_drive: "Scout transaction exports (JSON/ZIP)"
  - blob_storage: "Raw data uploads via API"
  - webhook_endpoint: "Real-time transaction streams"
outputs:
  - bronze_container: "raw-transactions/{year}/{month}/{day}"
validation:
  - file_format: "JSON schema validation"
  - virus_scan: "Defender for Storage"
  - size_limits: "Max 1GB per file"
```

### 2. Silver Layer (Data Cleansing & Normalization)
```yaml
pipeline: "scout-silver-processing"
trigger: "bronze-layer-complete"
transformations:
  - schema_inference: "Auto-detect column types"
  - column_mapping: "Fuzzy matching (0.8 threshold)"
  - data_quality: "Null checks, range validation"
  - standardization: "Date formats, currency normalization"
outputs:
  - silver_container: "cleaned-transactions/{partition_date}"
  - audit_logs: "data-quality-metrics"
quality_gates:
  - completeness: ">95% non-null required fields"
  - uniqueness: "Duplicate transaction detection"
  - consistency: "Cross-table validation"
```

### 3. Gold Layer (Business Logic & Enrichment)
```yaml
pipeline: "scout-gold-enrichment"
trigger: "silver-layer-complete"
enrichments:
  - brand_mapping: "Nielsen taxonomy integration"
  - geo_coding: "Store location to region mapping"
  - seasonality: "Time-based pattern recognition"
  - ai_insights: "OpenAI-powered category prediction"
outputs:
  - gold_container: "enriched-transactions/{partition_date}"
  - vectors: "AI Search index updates (1536-dim embeddings)"
business_rules:
  - revenue_calculation: "Price × quantity with tax"
  - basket_analysis: "Transaction grouping logic"
  - customer_journey: "Multi-touch attribution"
```

### 4. Platinum Layer (Analytics & Insights)
```yaml
pipeline: "scout-platinum-analytics"
trigger: "gold-layer-complete"
analytics:
  - aggregations: "Daily/weekly/monthly rollups"
  - kpi_calculation: "Revenue, volume, basket size trends"
  - ml_predictions: "Sales forecasting, demand planning"
  - anomaly_detection: "Statistical outlier identification"
outputs:
  - analytics_tables: "Pre-computed dashboard data"
  - insight_packs: "AI-generated business insights"
  - alerts: "Threshold breach notifications"
```

## Data Factory Components

### Linked Services
```json
{
  "azure_sql": {
    "type": "AzureSqlDatabase",
    "connectionString": "@Microsoft.KeyVault(SecretUri=https://kv-scout-prod.vault.azure.net/secrets/SQL-CONNECTION/)",
    "authentication": "ManagedIdentity"
  },
  "blob_storage": {
    "type": "AzureBlobStorage",
    "connectionString": "@Microsoft.KeyVault(SecretUri=https://kv-scout-prod.vault.azure.net/secrets/STORAGE-CONNECTION/)",
    "authentication": "ManagedIdentity"
  },
  "ai_search": {
    "type": "RestService",
    "baseUrl": "https://scout-search-prod.search.windows.net",
    "authentication": "ApiKey",
    "apiKey": "@Microsoft.KeyVault(SecretUri=https://kv-scout-prod.vault.azure.net/secrets/SEARCH-KEY/)"
  },
  "openai_service": {
    "type": "RestService",
    "baseUrl": "https://api.openai.com/v1",
    "authentication": "ApiKey",
    "apiKey": "@Microsoft.KeyVault(SecretUri=https://kv-scout-prod.vault.azure.net/secrets/OPENAI-API-KEY/)"
  }
}
```

### Datasets
```json
{
  "bronze_transactions": {
    "type": "Json",
    "linkedService": "blob_storage",
    "folderPath": "bronze/transactions/{year}/{month}/{day}",
    "compression": "gzip"
  },
  "silver_transactions": {
    "type": "Parquet",
    "linkedService": "blob_storage",
    "folderPath": "silver/transactions",
    "partitionedBy": ["transaction_date"]
  },
  "gold_transactions": {
    "type": "AzureSqlTable",
    "linkedService": "azure_sql",
    "tableName": "scout.transactions_gold"
  },
  "analytics_views": {
    "type": "AzureSqlTable",
    "linkedService": "azure_sql",
    "tableName": "scout.v_analytics_dashboard"
  }
}
```

## Pipeline Triggers

### Schedule-Based Triggers
```yaml
daily_full_refresh:
  schedule: "0 2 * * *"  # Daily at 2 AM UTC
  pipeline: "scout-full-pipeline"
  parameters:
    process_date: "@formatDateTime(utcnow(), 'yyyy-MM-dd')"

hourly_incremental:
  schedule: "0 * * * *"  # Every hour
  pipeline: "scout-incremental-pipeline"
  parameters:
    window_start: "@subtractFromTime(utcnow(), 1, 'Hour')"
    window_end: "@utcnow()"
```

### Event-Based Triggers
```yaml
blob_trigger:
  events: ["Microsoft.Storage.BlobCreated"]
  scope: "/subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{storage}/blobServices/default/containers/bronze"
  pipeline: "scout-bronze-ingestion"

webhook_trigger:
  endpoint: "https://scout-adf-prod.southeastasia.datafactory.azure.net/api/webhooks/{webhook-id}"
  authentication: "Bearer"
  pipeline: "scout-realtime-processing"
```

## Error Handling & Monitoring

### Retry Policies
```yaml
default_retry:
  count: 3
  interval: "PT30S"  # 30 seconds
  exponential_backoff: true

sql_retry:
  count: 5
  interval: "PT60S"  # 1 minute
  timeout: "PT10M"   # 10 minutes

api_retry:
  count: 2
  interval: "PT15S"  # 15 seconds
  timeout: "PT5M"    # 5 minutes
```

### Error Notifications
```yaml
email_alerts:
  - pipeline_failure: "scout-admins@tbwa.com"
  - data_quality_issues: "data-team@tbwa.com"
  - high_error_rate: "ops-team@tbwa.com"

slack_notifications:
  - channel: "#scout-alerts"
  - webhook: "@Microsoft.KeyVault(SecretUri=https://kv-scout-prod.vault.azure.net/secrets/SLACK-WEBHOOK/)"
```

### Monitoring & Metrics
```yaml
azure_monitor:
  - pipeline_runs: "Success/failure rates, duration"
  - data_volumes: "Records processed per layer"
  - error_rates: "By pipeline and activity"
  - cost_tracking: "Compute units consumed"

custom_metrics:
  - data_freshness: "Time since last successful run"
  - quality_score: "Percentage of clean records"
  - processing_lag: "End-to-end pipeline duration"
```

## Security & Compliance

### Identity & Access Management
```yaml
managed_identity:
  - user_assigned: "mi-scout-prod"
  - permissions:
    - sql_database: "db_datareader, db_datawriter"
    - blob_storage: "Storage Blob Data Contributor"
    - key_vault: "Key Vault Secrets User"
    - ai_search: "Search Index Data Contributor"

rbac_assignments:
  - data_factory_contributor: "data-engineering-team"
  - monitoring_reader: "ops-team"
  - key_vault_administrator: "security-team"
```

### Data Protection
```yaml
encryption:
  - at_rest: "Customer-managed keys (Azure Key Vault)"
  - in_transit: "TLS 1.2+ for all connections"
  - column_level: "Sensitive PII fields encrypted"

audit_logging:
  - all_pipeline_runs: "Diagnostic settings enabled"
  - data_access: "SQL audit logs to Log Analytics"
  - key_vault_access: "All secret access logged"
```

## Performance Optimization

### Parallel Processing
```yaml
copy_activities:
  - parallel_copies: 8
  - degree_of_copy_parallelism: 4
  - staging_location: "blob_storage_temp"

sql_activities:
  - max_concurrent_connections: 10
  - query_timeout: "PT30M"
  - batch_size: 10000
```

### Partitioning Strategy
```yaml
bronze_layer:
  - partition_by: "year/month/day/hour"
  - retention: "90 days"
  - compression: "gzip"

silver_layer:
  - partition_by: "transaction_date"
  - format: "parquet"
  - retention: "2 years"

gold_layer:
  - clustered_index: "transaction_date, brand_id"
  - columnstore_index: "analytics queries"
  - retention: "7 years"
```

## Development & Deployment

### CI/CD Pipeline
```yaml
source_control:
  - repository: "Azure DevOps / GitHub"
  - branch_strategy: "feature → develop → main"
  - arm_templates: "Infrastructure as Code"

deployment_stages:
  - dev: "Automated deployment on feature branch"
  - test: "Integration testing with sample data"
  - prod: "Manual approval required"

testing_strategy:
  - unit_tests: "Individual activity validation"
  - integration_tests: "End-to-end pipeline testing"
  - data_validation: "Schema and content verification"
```

### Environment Configuration
```yaml
dev_environment:
  - reduced_data_volume: "1% sample"
  - shorter_retention: "30 days"
  - basic_monitoring: "Essential metrics only"

production_environment:
  - full_data_volume: "100% transaction data"
  - full_retention: "Regulatory compliance"
  - comprehensive_monitoring: "All metrics + alerting"
```

## Getting Started

### Prerequisites
```bash
# Azure CLI with Data Factory extension
az extension add --name datafactory

# PowerShell with Az modules
Install-Module -Name Az.DataFactory

# Required permissions
az role assignment create --role "Data Factory Contributor" --assignee $USER_ID
```

### Deployment Steps
```bash
# 1. Deploy infrastructure
./scripts/deploy_scout_azure.sh

# 2. Import pipeline definitions
az datafactory pipeline create \
  --factory-name scout-adf-prod \
  --resource-group tbwa-scout-prod \
  --name scout-bronze-ingestion \
  --pipeline @pipelines/bronze-ingestion.json

# 3. Configure triggers
az datafactory trigger create \
  --factory-name scout-adf-prod \
  --resource-group tbwa-scout-prod \
  --name daily-trigger \
  --properties @triggers/daily-schedule.json

# 4. Start monitoring
az datafactory trigger start \
  --factory-name scout-adf-prod \
  --resource-group tbwa-scout-prod \
  --name daily-trigger
```

### Monitoring Dashboard
- **Azure Portal**: Data Factory monitoring blade
- **Azure Monitor**: Custom workbooks with KPI metrics
- **Power BI**: Executive dashboard with business metrics
- **Grafana**: Technical metrics and alerting (optional)

## Troubleshooting

### Common Issues

**Pipeline Failures**:
```bash
# Check pipeline run status
az datafactory pipeline-run show \
  --factory-name scout-adf-prod \
  --resource-group tbwa-scout-prod \
  --run-id $RUN_ID

# View activity errors
az datafactory activity-run query-by-pipeline-run \
  --factory-name scout-adf-prod \
  --resource-group tbwa-scout-prod \
  --pipeline-run-id $RUN_ID
```

**Data Quality Issues**:
```sql
-- Check data quality metrics
SELECT
  layer_name,
  quality_metric,
  metric_value,
  threshold,
  status
FROM scout.data_quality_metrics
WHERE processing_date = CAST(GETDATE() AS DATE)
ORDER BY processing_timestamp DESC;
```

**Performance Issues**:
```bash
# Monitor pipeline duration
az monitor metrics list \
  --resource /subscriptions/$SUB_ID/resourceGroups/tbwa-scout-prod/providers/Microsoft.DataFactory/factories/scout-adf-prod \
  --metric "PipelineRuns" \
  --aggregation Average
```

### Support Contacts
- **Data Engineering**: data-engineering@tbwa.com
- **Platform Operations**: ops-team@tbwa.com
- **Business Analytics**: analytics-team@tbwa.com
- **Emergency Support**: scout-support@tbwa.com

---

**Last Updated**: 2024-09-28
**Version**: 1.0
**Status**: Production Ready