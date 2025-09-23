#!/bin/bash
# Scout dbt Dual-Target Setup Script
# Creates complete dbt project structure for Supabase + Azure SQL

set -euo pipefail

echo "🚀 Setting up Scout dbt Dual-Target Project..."

# Create project structure
mkdir -p scout-dbt/{models,macros,tests,seeds,snapshots,analyses,data}
mkdir -p scout-dbt/models/{bronze,silver,gold,staging}
mkdir -p scout-dbt/models/bronze/{supabase,azure,parquet}
mkdir -p scout-dbt/models/silver/{location,transactions,dimensions}
mkdir -p scout-dbt/models/gold/{analytics,aggregates,exports}
mkdir -p scout-dbt/scripts/{ingestion,validation,orchestration}
mkdir -p scout-dbt/target
mkdir -p scout-dbt/logs

# Create dbt_project.yml
cat > scout-dbt/dbt_project.yml << 'EOF'
name: 'scout_dbt'
version: '1.0.0'
config-version: 2

profile: 'scout'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]
target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"
  - "logs"

models:
  scout_dbt:
    +materialized: view
    bronze:
      +materialized: table
      +schema: bronze
    silver:
      +materialized: table
      +schema: silver
      +unique_key: transaction_id
    gold:
      +materialized: table
      +schema: gold
      +indexes:
        - columns: ['store_id']
        - columns: ['transaction_date']
        - columns: ['municipality']

vars:
  # Default target
  target_type: "{{ target.type }}"

  # Data quality thresholds
  min_verification_rate: 100.0
  max_coordinate_deviation: 0.01

  # NCR bounds
  ncr_lat_min: 14.2
  ncr_lat_max: 14.9
  ncr_lon_min: 120.9
  ncr_lon_max: 121.2

seeds:
  scout_dbt:
    +schema: reference
EOF

# Create profiles.yml template
cat > scout-dbt/profiles_template.yml << 'EOF'
scout:
  outputs:
    supabase:
      type: postgres
      host: "{{ env_var('SUPABASE_HOST', 'aws-0-ap-southeast-1.pooler.supabase.com') }}"
      port: 6543
      user: "{{ env_var('SUPABASE_USER', 'postgres.cxzllzyxwpyptfretryc') }}"
      pass: "{{ env_var('SUPABASE_PASS') }}"
      dbname: postgres
      schema: public
      threads: 4
      keepalives_idle: 0
      connect_timeout: 10
      retries: 1

    azure:
      type: sqlserver
      driver: 'ODBC Driver 17 for SQL Server'
      server: "{{ env_var('AZURE_SERVER', 'scout-sql-server.database.windows.net') }}"
      port: 1433
      database: "{{ env_var('AZURE_DATABASE', 'scout-db') }}"
      authentication: sql
      username: "{{ env_var('AZURE_USERNAME') }}"
      password: "{{ env_var('AZURE_PASSWORD') }}"
      schema: dbo
      threads: 4
      connect_timeout: 10
      retries: 1

  target: supabase
EOF

# Create engine compatibility macros
cat > scout-dbt/macros/engine_compat.sql << 'EOF'
-- Engine-portable macros for cross-platform compatibility

{% macro current_timestamp_tz() -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    CURRENT_TIMESTAMP
  {%- elif target.type == 'sqlserver' -%}
    SYSDATETIMEOFFSET()
  {%- else -%}
    CURRENT_TIMESTAMP
  {%- endif -%}
{%- endmacro %}

{% macro json_extract(obj, path) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    {{ obj }}::jsonb #>> '{{"{{" }}{{ path.split('.') | join(',') }}{{ "}}" }}'
  {%- elif target.type == 'sqlserver' -%}
    JSON_VALUE({{ obj }}, '$.{{ path }}')
  {%- endif -%}
{%- endmacro %}

{% macro json_get(obj, key) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    {{ obj }}->>'{{ key }}'
  {%- elif target.type == 'sqlserver' -%}
    JSON_VALUE({{ obj }}, '$.{{ key }}')
  {%- endif -%}
{%- endmacro %}

{% macro date_trunc_day(column) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    DATE_TRUNC('day', {{ column }})
  {%- elif target.type == 'sqlserver' -%}
    CAST({{ column }} AS DATE)
  {%- endif -%}
{%- endmacro %}

{% macro md5_hash(columns) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    MD5(CONCAT({{ columns | join(', ') }}))
  {%- elif target.type == 'sqlserver' -%}
    CONVERT(VARCHAR(32), HASHBYTES('MD5', CONCAT({{ columns | join(', ') }})), 2)
  {%- endif -%}
{%- endmacro %}

{% macro validate_coordinates(lat, lon) -%}
  CASE
    WHEN {{ lat }} IS NULL OR {{ lon }} IS NULL THEN FALSE
    WHEN {{ lat }} < {{ var('ncr_lat_min') }} OR {{ lat }} > {{ var('ncr_lat_max') }} THEN FALSE
    WHEN {{ lon }} < {{ var('ncr_lon_min') }} OR {{ lon }} > {{ var('ncr_lon_max') }} THEN FALSE
    ELSE TRUE
  END
{%- endmacro %}

{% macro create_index(table_name, columns, unique=false) -%}
  {%- if target.type in ['postgres', 'postgresql'] -%}
    CREATE {% if unique %}UNIQUE {% endif %}INDEX IF NOT EXISTS idx_{{ table_name }}_{{ columns | join('_') }}
    ON {{ table_name }} ({{ columns | join(', ') }});
  {%- elif target.type == 'sqlserver' -%}
    IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_{{ table_name }}_{{ columns | join('_') }}')
    CREATE {% if unique %}UNIQUE {% endif %}INDEX idx_{{ table_name }}_{{ columns | join('_') }}
    ON {{ table_name }} ({{ columns | join(', ') }});
  {%- endif -%}
{%- endmacro %}
EOF

# Create bronze layer models
cat > scout-dbt/models/bronze/parquet/bronze_transactions_parquet.sql << 'EOF'
{{ config(
    materialized='external',
    location='azure://scoutdatalake.blob.core.windows.net/bronze/transactions/*.parquet'
) }}

WITH raw_data AS (
    SELECT
        transaction_id,
        store_id,
        device_id,
        transaction_date,
        transaction_time,
        basket_size,
        total_amount,
        payment_method,
        customer_type,
        municipality,
        barangay,
        latitude,
        longitude,
        data_source,
        ingested_at,
        _metadata
    FROM read_parquet('{{ var("parquet_path") }}/transactions/*.parquet')
)

SELECT
    {{ md5_hash(['transaction_id', 'store_id', 'transaction_date']) }} as canonical_id,
    *,
    {{ current_timestamp_tz() }} as loaded_at
FROM raw_data
EOF

# Create silver layer models
cat > scout-dbt/models/silver/location/silver_location_verified.sql << 'EOF'
{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    on_schema_change='fail'
) }}

WITH source_data AS (
    SELECT
        canonical_id as transaction_id,
        store_id,
        transaction_date,
        {{ json_extract('_metadata', 'location.municipality') }} as municipality,
        {{ json_extract('_metadata', 'location.barangay') }} as barangay,
        CAST(latitude AS DECIMAL(10,7)) as geo_latitude,
        CAST(longitude AS DECIMAL(10,7)) as geo_longitude,
        {{ validate_coordinates('latitude', 'longitude') }} as coordinates_valid,
        data_source,
        loaded_at
    FROM {{ ref('bronze_transactions_parquet') }}

    {% if is_incremental() %}
    WHERE loaded_at > (SELECT MAX(loaded_at) FROM {{ this }})
    {% endif %}
),

verified AS (
    SELECT
        s.*,
        d.store_name,
        d.region,
        d.province,
        d.psgc_region,
        d.psgc_citymun,
        d.psgc_barangay,
        CASE
            WHEN d.store_id IS NOT NULL THEN TRUE
            ELSE FALSE
        END as location_verified
    FROM source_data s
    LEFT JOIN {{ ref('dim_stores_ncr') }} d
        ON s.store_id = d.store_id
)

SELECT
    transaction_id,
    store_id,
    store_name,
    transaction_date,
    municipality,
    barangay,
    geo_latitude,
    geo_longitude,
    coordinates_valid,
    location_verified,
    region,
    province,
    psgc_region,
    psgc_citymun,
    psgc_barangay,
    data_source,
    {{ current_timestamp_tz() }} as processed_at
FROM verified
EOF

# Create gold layer models
cat > scout-dbt/models/gold/analytics/gold_store_performance.sql << 'EOF'
{{ config(
    materialized='table',
    indexes=[
        {'columns': ['store_id'], 'unique': false},
        {'columns': ['performance_month'], 'unique': false}
    ]
) }}

WITH monthly_metrics AS (
    SELECT
        store_id,
        store_name,
        municipality,
        {{ date_trunc_day('transaction_date') }} as performance_date,
        DATE_TRUNC('month', transaction_date) as performance_month,
        COUNT(DISTINCT transaction_id) as transaction_count,
        COUNT(DISTINCT {{ date_trunc_day('transaction_date') }}) as active_days,
        AVG(CASE WHEN location_verified THEN 1 ELSE 0 END) * 100 as verification_rate,
        COUNT(DISTINCT data_source) as source_diversity
    FROM {{ ref('silver_location_verified') }}
    GROUP BY 1, 2, 3, 4, 5
),

categorized AS (
    SELECT
        *,
        CASE
            WHEN transaction_count >= 1000 THEN 'HIGH'
            WHEN transaction_count >= 500 THEN 'MEDIUM'
            WHEN transaction_count >= 100 THEN 'LOW'
            ELSE 'MINIMAL'
        END as volume_category,
        CASE
            WHEN verification_rate = 100 THEN 'PERFECT'
            WHEN verification_rate >= 95 THEN 'EXCELLENT'
            WHEN verification_rate >= 90 THEN 'GOOD'
            ELSE 'NEEDS_ATTENTION'
        END as quality_category
    FROM monthly_metrics
)

SELECT
    store_id,
    store_name,
    municipality,
    performance_month,
    transaction_count,
    active_days,
    verification_rate,
    source_diversity,
    volume_category,
    quality_category,
    {{ current_timestamp_tz() }} as computed_at
FROM categorized
EOF

# Create test files
cat > scout-dbt/tests/generic/test_verification_rate.sql << 'EOF'
-- Test that verification rate meets SLO
SELECT
    COUNT(*) as failures
FROM {{ ref('gold_store_performance') }}
WHERE verification_rate < {{ var('min_verification_rate') }}
HAVING COUNT(*) > 0
EOF

cat > scout-dbt/tests/generic/test_coordinate_bounds.sql << 'EOF'
-- Test that all coordinates are within NCR bounds
SELECT
    COUNT(*) as failures
FROM {{ ref('silver_location_verified') }}
WHERE coordinates_valid = FALSE
    AND geo_latitude IS NOT NULL
    AND geo_longitude IS NOT NULL
HAVING COUNT(*) > 0
EOF

# Create orchestration runners
cat > scout-dbt/scripts/orchestration/run_supabase.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🐘 Running dbt for Supabase target..."

# Export credentials from environment
export SUPABASE_PASS="${SUPABASE_PASS:-Postgres_26}"

# Run dbt commands
cd scout-dbt

# Install dependencies
dbt deps --target supabase

# Run models
dbt run --target supabase --select bronze
dbt run --target supabase --select silver
dbt run --target supabase --select gold

# Run tests
dbt test --target supabase

# Generate docs
dbt docs generate --target supabase

echo "✅ Supabase dbt run complete"
EOF

cat > scout-dbt/scripts/orchestration/run_azure.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "☁️ Running dbt for Azure SQL target..."

# Export credentials from environment
export AZURE_USERNAME="${AZURE_USERNAME}"
export AZURE_PASSWORD="${AZURE_PASSWORD}"

# Run dbt commands
cd scout-dbt

# Install dependencies
dbt deps --target azure

# Run models
dbt run --target azure --select bronze
dbt run --target azure --select silver
dbt run --target azure --select gold

# Run tests
dbt test --target azure

# Generate docs
dbt docs generate --target azure

echo "✅ Azure SQL dbt run complete"
EOF

cat > scout-dbt/scripts/orchestration/run_dual.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🎯 Running dual-target dbt orchestration..."

# Run both targets in parallel
./scripts/orchestration/run_supabase.sh &
PID1=$!

./scripts/orchestration/run_azure.sh &
PID2=$!

# Wait for both to complete
wait $PID1
SUPABASE_RESULT=$?

wait $PID2
AZURE_RESULT=$?

# Check results
if [ $SUPABASE_RESULT -eq 0 ] && [ $AZURE_RESULT -eq 0 ]; then
    echo "✅ Both targets completed successfully"
    exit 0
else
    echo "❌ One or more targets failed"
    [ $SUPABASE_RESULT -ne 0 ] && echo "  - Supabase failed with code $SUPABASE_RESULT"
    [ $AZURE_RESULT -ne 0 ] && echo "  - Azure failed with code $AZURE_RESULT"
    exit 1
fi
EOF

# Create validation script
cat > scout-dbt/scripts/validation/validate_parity.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🔍 Validating parity between Supabase and Azure SQL..."

# Check row counts
SUPABASE_COUNT=$(PGPASSWORD="$SUPABASE_PASS" psql "$SUPABASE_URL" -tAc "
    SELECT COUNT(*) FROM gold.gold_store_performance;
")

AZURE_COUNT=$(sqlcmd -S "$AZURE_SERVER" -d "$AZURE_DATABASE" -U "$AZURE_USERNAME" -P "$AZURE_PASSWORD" -Q "
    SELECT COUNT(*) FROM gold.gold_store_performance;
" -h -1)

echo "Supabase row count: $SUPABASE_COUNT"
echo "Azure SQL row count: $AZURE_COUNT"

if [ "$SUPABASE_COUNT" -eq "$AZURE_COUNT" ]; then
    echo "✅ Row counts match"
else
    echo "❌ Row count mismatch!"
    exit 1
fi

# Check verification rates
SUPABASE_RATE=$(PGPASSWORD="$SUPABASE_PASS" psql "$SUPABASE_URL" -tAc "
    SELECT ROUND(AVG(verification_rate), 2) FROM gold.gold_store_performance;
")

AZURE_RATE=$(sqlcmd -S "$AZURE_SERVER" -d "$AZURE_DATABASE" -U "$AZURE_USERNAME" -P "$AZURE_PASSWORD" -Q "
    SELECT ROUND(AVG(verification_rate), 2) FROM gold.gold_store_performance;
" -h -1)

echo "Supabase avg verification rate: $SUPABASE_RATE%"
echo "Azure SQL avg verification rate: $AZURE_RATE%"

if [ "$SUPABASE_RATE" = "$AZURE_RATE" ]; then
    echo "✅ Verification rates match"
else
    echo "⚠️ Verification rate variance detected"
fi

echo "✅ Parity validation complete"
EOF

# Create ingestion script for Parquet to both targets
cat > scout-dbt/scripts/ingestion/ingest_parquet.py << 'EOF'
#!/usr/bin/env python3
"""
Dual-target Parquet ingestion for Scout dbt
Loads from Azure Blob Storage to both Supabase and Azure SQL
"""

import os
import sys
import pandas as pd
import pyarrow.parquet as pq
from azure.storage.blob import BlobServiceClient
import psycopg2
import pyodbc
from datetime import datetime
import hashlib
import json

def get_canonical_id(row):
    """Generate canonical transaction ID using MD5 hash"""
    key = f"{row['transaction_id']}_{row['store_id']}_{row['transaction_date']}"
    return hashlib.md5(key.encode()).hexdigest()

def load_parquet_from_blob(container_name, blob_pattern):
    """Load Parquet files from Azure Blob Storage"""
    blob_service = BlobServiceClient.from_connection_string(
        os.environ['AZURE_STORAGE_CONNECTION_STRING']
    )

    container = blob_service.get_container_client(container_name)
    blobs = container.list_blobs(name_starts_with=blob_pattern)

    dfs = []
    for blob in blobs:
        blob_client = container.get_blob_client(blob.name)
        stream = blob_client.download_blob().readall()
        df = pd.read_parquet(stream)
        df['_source_file'] = blob.name
        df['_ingested_at'] = datetime.utcnow()
        dfs.append(df)

    if dfs:
        return pd.concat(dfs, ignore_index=True)
    return pd.DataFrame()

def load_to_supabase(df, table_name):
    """Load DataFrame to Supabase PostgreSQL"""
    conn = psycopg2.connect(
        host=os.environ['SUPABASE_HOST'],
        port=6543,
        database='postgres',
        user=os.environ['SUPABASE_USER'],
        password=os.environ['SUPABASE_PASS']
    )

    cur = conn.cursor()

    # Create staging table
    cur.execute(f"""
        CREATE TEMP TABLE staging_{table_name} (LIKE bronze.{table_name} INCLUDING ALL);
    """)

    # Bulk insert using COPY
    from io import StringIO
    output = StringIO()
    df.to_csv(output, sep='\\t', header=False, index=False, na_rep='\\N')
    output.seek(0)
    cur.copy_from(output, f'staging_{table_name}', null='\\N')

    # Merge into target
    cur.execute(f"""
        INSERT INTO bronze.{table_name}
        SELECT * FROM staging_{table_name}
        ON CONFLICT (canonical_id) DO UPDATE
        SET _ingested_at = EXCLUDED._ingested_at;
    """)

    conn.commit()
    cur.close()
    conn.close()

    print(f"✅ Loaded {len(df)} rows to Supabase bronze.{table_name}")

def load_to_azure(df, table_name):
    """Load DataFrame to Azure SQL Server"""
    conn = pyodbc.connect(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={os.environ['AZURE_SERVER']};"
        f"DATABASE={os.environ['AZURE_DATABASE']};"
        f"UID={os.environ['AZURE_USERNAME']};"
        f"PWD={os.environ['AZURE_PASSWORD']}"
    )

    cursor = conn.cursor()

    # Batch insert with proper type conversion
    for _, row in df.iterrows():
        cursor.execute(f"""
            MERGE bronze.{table_name} AS target
            USING (VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?))
                AS source (canonical_id, transaction_id, store_id, device_id,
                           transaction_date, transaction_time, basket_size,
                           total_amount, payment_method, customer_type,
                           municipality, barangay, latitude, longitude,
                           data_source, _ingested_at)
            ON target.canonical_id = source.canonical_id
            WHEN MATCHED THEN
                UPDATE SET _ingested_at = source._ingested_at
            WHEN NOT MATCHED THEN
                INSERT (canonical_id, transaction_id, store_id, device_id,
                       transaction_date, transaction_time, basket_size,
                       total_amount, payment_method, customer_type,
                       municipality, barangay, latitude, longitude,
                       data_source, _ingested_at)
                VALUES (source.canonical_id, source.transaction_id,
                       source.store_id, source.device_id,
                       source.transaction_date, source.transaction_time,
                       source.basket_size, source.total_amount,
                       source.payment_method, source.customer_type,
                       source.municipality, source.barangay,
                       source.latitude, source.longitude,
                       source.data_source, source._ingested_at);
        """, row['canonical_id'], row['transaction_id'], row['store_id'],
        row['device_id'], row['transaction_date'], row['transaction_time'],
        row['basket_size'], row['total_amount'], row['payment_method'],
        row['customer_type'], row['municipality'], row['barangay'],
        row['latitude'], row['longitude'], row['data_source'],
        row['_ingested_at'])

    conn.commit()
    cursor.close()
    conn.close()

    print(f"✅ Loaded {len(df)} rows to Azure SQL bronze.{table_name}")

def main():
    """Main ingestion orchestration"""
    print("🚀 Starting dual-target Parquet ingestion...")

    # Load data from blob
    df = load_parquet_from_blob('bronze', 'transactions/')

    if df.empty:
        print("⚠️ No new data to process")
        return

    # Add canonical ID
    df['canonical_id'] = df.apply(get_canonical_id, axis=1)

    # Load to both targets
    try:
        load_to_supabase(df, 'transactions')
        load_to_azure(df, 'transactions')
        print("✅ Dual-target ingestion complete")
    except Exception as e:
        print(f"❌ Ingestion failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

# Create requirements.txt for Python dependencies
cat > scout-dbt/requirements.txt << 'EOF'
dbt-core==1.7.0
dbt-postgres==1.7.0
dbt-sqlserver==1.7.0
pandas==2.1.0
pyarrow==14.0.0
psycopg2-binary==2.9.9
pyodbc==5.0.0
azure-storage-blob==12.19.0
EOF

# Create README
cat > scout-dbt/README.md << 'EOF'
# Scout dbt Dual-Target Project

## Overview
This dbt project implements a dual-target architecture for Scout's zero-trust location system,
materializing models to both Supabase (PostgreSQL) and Azure SQL Server.

## Architecture
```
Azure Blob (Parquet) → Bronze → Silver → Gold → Analytics
                        ↓         ↓        ↓
                   [Supabase] [Azure SQL] [Both]
```

## Setup

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure profiles:**
   ```bash
   cp profiles_template.yml ~/.dbt/profiles.yml
   # Edit with your credentials
   ```

3. **Set environment variables:**
   ```bash
   export SUPABASE_PASS="your_password"
   export AZURE_USERNAME="your_username"
   export AZURE_PASSWORD="your_password"
   ```

## Usage

### Run for Supabase only:
```bash
./scripts/orchestration/run_supabase.sh
```

### Run for Azure SQL only:
```bash
./scripts/orchestration/run_azure.sh
```

### Run for both targets:
```bash
./scripts/orchestration/run_dual.sh
```

### Validate parity:
```bash
./scripts/validation/validate_parity.sh
```

### Ingest from Parquet:
```bash
python scripts/ingestion/ingest_parquet.py
```

## Models

- **Bronze**: Raw data ingestion from Parquet
- **Silver**: Cleansed and verified location data
- **Gold**: Business-ready analytics and aggregations

## Tests

- Verification rate SLO (100%)
- NCR coordinate bounds validation
- Data quality checks

## Engine Compatibility

The project uses engine-portable macros to handle differences between PostgreSQL and SQL Server:
- `current_timestamp_tz()`: Timezone-aware timestamps
- `json_extract()`: JSON field extraction
- `date_trunc_day()`: Date truncation
- `md5_hash()`: Canonical ID generation
- `validate_coordinates()`: NCR bounds checking
EOF

# Make scripts executable
chmod +x scout-dbt/scripts/orchestration/*.sh
chmod +x scout-dbt/scripts/validation/*.sh
chmod +x scout-dbt/scripts/ingestion/*.py

echo "✅ Scout dbt dual-target project structure created successfully!"
echo ""
echo "Next steps:"
echo "1. cd scout-dbt"
echo "2. pip install -r requirements.txt"
echo "3. Configure ~/.dbt/profiles.yml with your credentials"
echo "4. Run: ./scripts/orchestration/run_dual.sh"