# Azure SQL Scout ETL Deployment Guide

Complete step-by-step deployment guide for Scout Analytics ETL on Azure SQL Database.

## 🎯 Overview

This guide deploys the complete Scout Analytics ETL system:
- **Source**: Azure Blob Storage (`projectscoutautoregstr/gdrive-scout-ingest`)
- **Target**: Azure SQL Database with medallion architecture
- **Features**: Real-time ingestion, data quality validation, audit trails

## 📋 Prerequisites

### 1. Azure Resources Required
- ✅ **Azure SQL Database** (existing: scout-analytics-server)
- ✅ **Azure Blob Storage** (existing: projectscoutautoregstr)
- ✅ **SAS Token** for blob storage access
- ✅ **SQL Admin Credentials** (sqladmin / Azure_pw26)

### 2. Access Requirements
- Azure SQL Database admin access
- Azure Blob Storage read permissions
- SQL Server Management Studio or Azure Data Studio

### 3. Data Files in Blob Storage
Expected structure in `gdrive-scout-ingest` container:
```
/transactions/
  ├── scout_transactions_YYYYMMDD.csv
  ├── scout_transactions_YYYYMMDD.csv.gz
  └── ...
/stores/
  ├── scout_stores_YYYYMMDD.csv
  ├── scout_stores_YYYYMMDD.csv.gz
  └── ...
```

## 🚀 Deployment Steps

### Step 1: Connect to Azure SQL Database

#### Option A: Azure Portal Query Editor
1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to **SQL databases** → **scout-analytics-db**
3. Click **Query editor (preview)**
4. Login with:
   - **Login**: `sqladmin`
   - **Password**: `Azure_pw26`

#### Option B: SQL Server Management Studio
1. Open SQL Server Management Studio
2. Connect to server: `[CORRECT_SERVER_NAME].database.windows.net`
3. Authentication: SQL Server Authentication
4. Login: `sqladmin` / Password: `Azure_pw26`

#### Option C: Azure Data Studio
1. Open Azure Data Studio
2. New Connection → Azure SQL Database
3. Server: `[CORRECT_SERVER_NAME].database.windows.net`
4. Authentication: SQL Login
5. User: `sqladmin` / Password: `Azure_pw26`

### Step 2: Get SAS Token for Blob Storage

1. Navigate to **Storage accounts** → **projectscoutautoregstr**
2. Go to **Security + networking** → **Shared access signature**
3. Configure permissions:
   - ✅ **Allowed services**: Blob
   - ✅ **Allowed resource types**: Container, Object
   - ✅ **Allowed permissions**: Read, List
   - ⏰ **Start time**: Current time
   - ⏰ **Expiry time**: +1 year
4. Click **Generate SAS and connection string**
5. Copy the **SAS token** (starts with `?sv=`)

### Step 3: Deploy ETL Schema and Procedures

1. Open `/Users/tbwa/scout-v7/sql/azure_blob_to_gold_etl.sql`
2. **IMPORTANT**: Replace `<PASTE_SAS_TOKEN_HERE>` with your SAS token:
   ```sql
   CREATE DATABASE SCOPED CREDENTIAL cr_scout_blob_storage
   WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
   SECRET = '?sv=2022-11-02&ss=b&srt=co&sp=rl&se=2025-09-22T...'; -- Your SAS token here
   ```
3. Execute the entire script in Azure SQL Database
4. Verify deployment:
   ```sql
   -- Check schemas created
   SELECT name FROM sys.schemas WHERE name IN ('staging', 'gold', 'audit');

   -- Check procedures created
   SELECT name FROM sys.procedures WHERE name LIKE 'sp_%scout%';
   ```

### Step 4: Test Blob Storage Connection

Execute connection test:
```sql
-- Test external data source
SELECT name, location, type_desc
FROM sys.external_data_sources
WHERE name = 'eds_scout_blob_storage';

-- Test credential
SELECT name, credential_identity
FROM sys.database_scoped_credentials
WHERE name = 'cr_scout_blob_storage';
```

Expected results:
- ✅ External data source showing blob storage URL
- ✅ Credential showing 'SHARED ACCESS SIGNATURE'

### Step 5: Run Initial ETL Load

Execute the master ETL procedure:
```sql
-- Run complete ETL process
EXEC sp_run_scout_etl;
```

This procedure will:
1. 🔄 Load transactions from blob storage
2. 🔄 Load stores from blob storage
3. 🔄 Merge data into staging tables
4. 🔄 Create gold layer views
5. ✅ Generate audit trail

### Step 6: Validate ETL Results

Run validation queries from `/Users/tbwa/scout-v7/sql/azure_etl_validation.sql`:

#### Quick Health Check
```sql
-- Executive summary
WITH summary_stats AS (
    SELECT
        (SELECT COUNT(*) FROM staging.transactions) as staging_transactions,
        (SELECT COUNT(*) FROM staging.stores) as staging_stores,
        (SELECT COUNT(*) FROM gold.v_transactions_flat) as gold_transactions,
        (SELECT COUNT(DISTINCT brand) FROM gold.v_transactions_flat) as unique_brands,
        (SELECT COUNT(DISTINCT store_name) FROM gold.v_transactions_flat) as unique_stores
)
SELECT
    CASE
        WHEN staging_transactions > 0 AND gold_transactions > 0
        THEN 'HEALTHY ✅'
        ELSE 'NEEDS_ATTENTION ⚠️'
    END as overall_status,
    staging_transactions,
    gold_transactions,
    unique_brands,
    unique_stores
FROM summary_stats;
```

#### Real Filipino Brands Validation
```sql
-- Check for real vs test brands
SELECT
    brand,
    COUNT(*) as transaction_count,
    CASE
        WHEN brand IN ('Safeguard', 'Jack ''n Jill', 'Piattos', 'Combi', 'Pantene')
        THEN 'Real Filipino Brand ✅'
        WHEN brand LIKE 'Brand %' OR brand LIKE 'Test%'
        THEN 'Test/Placeholder ⚠️'
        ELSE 'Unknown/Other ❓'
    END as brand_classification
FROM gold.v_transactions_flat
GROUP BY brand
ORDER BY transaction_count DESC;
```

### Step 7: Set Up Automated Refresh (Optional)

Create SQL Agent job for regular ETL updates:
```sql
-- Create ETL refresh job (requires SQL Agent)
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'Scout ETL Refresh',
    @description = N'Daily refresh of Scout Analytics data from blob storage';

EXEC dbo.sp_add_jobstep
    @job_name = N'Scout ETL Refresh',
    @step_name = N'Run ETL',
    @command = N'EXEC sp_run_scout_etl',
    @database_name = N'scout-analytics-db';

EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily at 6 AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 060000;

EXEC dbo.sp_attach_schedule
    @job_name = N'Scout ETL Refresh',
    @schedule_name = N'Daily at 6 AM';

EXEC dbo.sp_add_jobserver
    @job_name = N'Scout ETL Refresh';
```

## 🔍 Troubleshooting

### Common Issues and Solutions

#### 1. Connection Timeout to Azure SQL
**Error**: `Login timeout expired`
**Solution**:
- Verify correct server name (not `scout-analytics-server.database.windows.net`)
- Check firewall rules allow your IP
- Ensure credentials are correct: `sqladmin` / `Azure_pw26`

#### 2. Blob Storage Access Denied
**Error**: `Cannot access external data source`
**Solutions**:
- Verify SAS token is valid and not expired
- Check SAS token has Read and List permissions
- Ensure container name is exactly `gdrive-scout-ingest`

#### 3. No Data in Staging Tables
**Error**: Staging tables empty after ETL
**Solutions**:
- Check blob storage has CSV files in expected paths
- Verify file naming convention: `scout_transactions_YYYYMMDD.csv`
- Run individual COPY INTO procedures to isolate issue

#### 4. JSON Parsing Errors
**Error**: Invalid JSON in raw_json column
**Solutions**:
- Check source CSV files for malformed JSON
- Verify JSON escaping in CSV files
- Use TRY_PARSE function for error handling

#### 5. Test Brands in Production
**Warning**: Brands like 'Brand A', 'Brand B' detected
**Solutions**:
- Verify source data contains real Filipino brands
- Check data mapping from blob storage
- Validate brand categorization logic

### Debug Queries

#### Check ETL Progress
```sql
-- Last ETL execution time
SELECT MAX(created_at) as last_staging_update
FROM staging.transactions;

-- Data freshness
SELECT
    DATEDIFF(hour, MAX(created_at), GETDATE()) as hours_since_update,
    CASE
        WHEN DATEDIFF(hour, MAX(created_at), GETDATE()) <= 24 THEN 'FRESH'
        WHEN DATEDIFF(hour, MAX(created_at), GETDATE()) <= 72 THEN 'MODERATE'
        ELSE 'STALE'
    END as data_freshness
FROM staging.transactions;
```

#### Check Blob Files
```sql
-- List available files in blob storage
SELECT *
FROM OPENROWSET(
    BULK 'transactions/',
    DATA_SOURCE = 'eds_scout_blob_storage',
    FORMAT = 'CSV'
) WITH (filename VARCHAR(255) '1') as files;
```

#### Manual COPY INTO Test
```sql
-- Test transaction loading manually
COPY INTO staging.transactions
FROM 'transactions/scout_transactions_20240922.csv'
WITH (
    DATA_SOURCE = 'eds_scout_blob_storage',
    FILE_TYPE = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);
```

## 📊 Monitoring and Maintenance

### Daily Health Checks
Run these queries daily to ensure ETL health:

```sql
-- 1. Data freshness check
SELECT
    'Data Freshness' as metric,
    DATEDIFF(hour, MAX(created_at), GETDATE()) as hours_old,
    CASE
        WHEN DATEDIFF(hour, MAX(created_at), GETDATE()) <= 24 THEN 'PASS'
        ELSE 'FAIL'
    END as status
FROM staging.transactions;

-- 2. Record count validation
SELECT
    'Record Counts' as metric,
    (SELECT COUNT(*) FROM staging.transactions) as staging_count,
    (SELECT COUNT(*) FROM gold.v_transactions_flat) as gold_count,
    CASE
        WHEN (SELECT COUNT(*) FROM gold.v_transactions_flat) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as status;

-- 3. Brand quality check
SELECT
    'Brand Quality' as metric,
    COUNT(CASE WHEN brand LIKE 'Brand %' THEN 1 END) as test_brands,
    CASE
        WHEN COUNT(CASE WHEN brand LIKE 'Brand %' THEN 1 END) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as status
FROM gold.v_transactions_flat;
```

### Performance Optimization
```sql
-- Create indexes for better performance
CREATE INDEX IX_transactions_timestamp
ON staging.transactions(created_at);

CREATE INDEX IX_transactions_store_id
ON staging.transactions(store_id);

CREATE INDEX IX_transactions_canonical_id
ON staging.transactions(canonical_tx_id);
```

### Audit Trail Review
```sql
-- Review recent exports and operations
SELECT TOP 10
    export_timestamp,
    operation_type,
    record_count,
    validation_status,
    file_hash
FROM audit.export_log
ORDER BY export_timestamp DESC;
```

## ✅ Success Criteria

ETL deployment is successful when:

1. **✅ Connectivity**: Azure SQL and blob storage connections established
2. **✅ Schema**: All staging, gold, and audit schemas created
3. **✅ Data Loading**: Staging tables populated with real production data
4. **✅ Gold Views**: Flat and crosstab views returning data
5. **✅ Real Brands**: Filipino brands (Safeguard, Jack 'n Jill) detected, no test brands
6. **✅ Audit Trail**: Export log capturing all operations
7. **✅ Data Quality**: >95% quality score on validation metrics
8. **✅ Performance**: Queries executing in <5 seconds

## 🎉 Next Steps

After successful deployment:

1. **Configure automated exports** using Python scripts
2. **Set up monitoring dashboards** in Azure
3. **Schedule regular ETL refreshes** via SQL Agent
4. **Implement data quality alerts** for production monitoring
5. **Deploy business intelligence reports** on gold layer views

## 📞 Support

For deployment issues:
- Check `/Users/tbwa/scout-v7/sql/azure_etl_validation.sql` for diagnostic queries
- Review Azure SQL Database logs in Azure Portal
- Validate blob storage file structure and permissions
- Test individual ETL components before full deployment