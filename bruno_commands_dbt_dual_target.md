# :bruno Commands - Scout dbt Dual-Target Implementation

**Copy-paste ready commands for Scout dbt dual-target deployment**

## 1. Initial Setup

```bash
# Execute the setup script
./scout-dbt/setup_dbt_dual_target.sh

# Install Python dependencies
cd scout-dbt && pip install -r requirements.txt

# Install dbt dependencies
dbt deps
```

## 2. Environment Configuration

```bash
# Create profiles directory
mkdir -p ~/.dbt

# Copy and configure profiles
cp profiles_template.yml ~/.dbt/profiles.yml

# Set environment variables (Bruno will inject from vault)
export SUPABASE_HOST="aws-0-ap-southeast-1.pooler.supabase.com"
export SUPABASE_USER="postgres.cxzllzyxwpyptfretryc"
export SUPABASE_PASS="{{SUPABASE_PASS}}"  # Bruno injects
export AZURE_SERVER="scout-sql-server.database.windows.net"
export AZURE_DATABASE="scout-db"
export AZURE_USERNAME="{{AZURE_USERNAME}}"  # Bruno injects
export AZURE_PASSWORD="{{AZURE_PASSWORD}}"  # Bruno injects
export AZURE_STORAGE_CONNECTION_STRING="{{AZURE_STORAGE_CONNECTION_STRING}}"  # Bruno injects
```

## 3. Schema Initialization

```sql
-- Supabase schema setup
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS reference;

-- Azure SQL schema setup (run via Bruno)
:sql azure
CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;
CREATE SCHEMA reference;
```

## 4. Bronze Layer Tables

```sql
-- Create bronze.transactions in Supabase
:sql supabase
CREATE TABLE IF NOT EXISTS bronze.transactions (
    canonical_id VARCHAR(32) PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL,
    store_id INTEGER,
    device_id VARCHAR(255),
    transaction_date DATE,
    transaction_time TIME,
    basket_size INTEGER,
    total_amount DECIMAL(10,2),
    payment_method VARCHAR(50),
    customer_type VARCHAR(50),
    municipality VARCHAR(100),
    barangay VARCHAR(100),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    data_source VARCHAR(50),
    _source_file VARCHAR(500),
    _ingested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    loaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bronze_transactions_store_id ON bronze.transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_bronze_transactions_date ON bronze.transactions(transaction_date);
```

```sql
-- Create bronze.transactions in Azure SQL
:sql azure
CREATE TABLE bronze.transactions (
    canonical_id VARCHAR(32) PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL,
    store_id INTEGER,
    device_id VARCHAR(255),
    transaction_date DATE,
    transaction_time TIME,
    basket_size INTEGER,
    total_amount DECIMAL(10,2),
    payment_method VARCHAR(50),
    customer_type VARCHAR(50),
    municipality VARCHAR(100),
    barangay VARCHAR(100),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    data_source VARCHAR(50),
    _source_file VARCHAR(500),
    _ingested_at DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET(),
    loaded_at DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET()
);

CREATE INDEX idx_bronze_transactions_store_id ON bronze.transactions(store_id);
CREATE INDEX idx_bronze_transactions_date ON bronze.transactions(transaction_date);
```

## 5. Dimension Table Sync

```sql
-- Sync dim_stores_ncr to bronze schema in both targets
:sql supabase
CREATE TABLE IF NOT EXISTS bronze.dim_stores_ncr AS
SELECT * FROM public.dim_stores_ncr;

:sql azure
-- Use bcp or bulk insert to sync from Supabase
-- (handled by ingestion script)
```

## 6. dbt Model Execution

```bash
# Run Supabase target
cd scout-dbt
./scripts/orchestration/run_supabase.sh

# Run Azure SQL target
./scripts/orchestration/run_azure.sh

# Run both targets in parallel
./scripts/orchestration/run_dual.sh
```

## 7. Data Ingestion from Parquet

```bash
# Run the Parquet ingestion script
cd scout-dbt
python scripts/ingestion/ingest_parquet.py

# Verify ingestion
./scripts/validation/validate_parity.sh
```

## 8. Monitoring and Validation

```bash
# Check row counts in both targets
:sql supabase
SELECT
    'bronze' as layer, 'transactions' as table_name, COUNT(*) as row_count
FROM bronze.transactions
UNION ALL
SELECT
    'silver' as layer, 'location_verified' as table_name, COUNT(*) as row_count
FROM silver.location_verified
UNION ALL
SELECT
    'gold' as layer, 'store_performance' as table_name, COUNT(*) as row_count
FROM gold.store_performance;

:sql azure
SELECT
    'bronze' as layer, 'transactions' as table_name, COUNT(*) as row_count
FROM bronze.transactions
UNION ALL
SELECT
    'silver' as layer, 'location_verified' as table_name, COUNT(*) as row_count
FROM silver.location_verified
UNION ALL
SELECT
    'gold' as layer, 'store_performance' as table_name, COUNT(*) as row_count
FROM gold.store_performance;
```

## 9. Quality Validation

```bash
# Run dbt tests on both targets
cd scout-dbt

# Test Supabase
dbt test --target supabase

# Test Azure SQL
dbt test --target azure

# Validate cross-platform parity
./scripts/validation/validate_parity.sh
```

## 10. Documentation Generation

```bash
# Generate dbt docs for both targets
cd scout-dbt

dbt docs generate --target supabase
dbt docs generate --target azure

# Serve documentation
dbt docs serve --port 8080
```

## 11. Automation Setup

```bash
# Create cron job for daily runs
crontab -e

# Add the following line for daily 2 AM execution:
# 0 2 * * * cd /path/to/scout-v7/scout-dbt && ./scripts/orchestration/run_dual.sh >> logs/daily_run.log 2>&1
```

## 12. Emergency Procedures

```bash
# Full refresh of all models
cd scout-dbt
dbt run --target supabase --full-refresh
dbt run --target azure --full-refresh

# Specific model refresh
dbt run --target supabase --select gold.gold_store_performance --full-refresh
dbt run --target azure --select gold.gold_store_performance --full-refresh

# Clear dbt cache
dbt clean

# Reset target databases (CAUTION)
dbt snapshot --target supabase
dbt run --target supabase --full-refresh
```

## Environment Variables Reference

```bash
# Supabase (PostgreSQL)
SUPABASE_HOST="aws-0-ap-southeast-1.pooler.supabase.com"
SUPABASE_USER="postgres.cxzllzyxwpyptfretryc"
SUPABASE_PASS="{{VAULT_SUPABASE_PASS}}"  # Bruno manages

# Azure SQL Server
AZURE_SERVER="scout-sql-server.database.windows.net"
AZURE_DATABASE="scout-db"
AZURE_USERNAME="{{VAULT_AZURE_USERNAME}}"  # Bruno manages
AZURE_PASSWORD="{{VAULT_AZURE_PASSWORD}}"  # Bruno manages

# Azure Storage (for Parquet source)
AZURE_STORAGE_CONNECTION_STRING="{{VAULT_AZURE_STORAGE_CONNECTION}}"  # Bruno manages

# dbt Configuration
DBT_PROFILES_DIR="~/.dbt"
DBT_PROJECT_DIR="/path/to/scout-v7/scout-dbt"
```

## Status Validation Commands

```bash
# Check dbt project status
cd scout-dbt && dbt debug --target supabase
cd scout-dbt && dbt debug --target azure

# Verify model lineage
cd scout-dbt && dbt docs generate && dbt docs serve

# Check data freshness
cd scout-dbt && dbt source freshness

# Run data quality tests
cd scout-dbt && dbt test --store-failures
```

---

**Notes:**
- All credentials managed by Bruno vault system
- No secrets in repository or commands
- Parallel execution supported for performance
- Full parity validation between targets
- Engine-portable SQL via dbt macros
- Comprehensive monitoring and alerting
- Production-ready with error handling