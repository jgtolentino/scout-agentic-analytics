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
