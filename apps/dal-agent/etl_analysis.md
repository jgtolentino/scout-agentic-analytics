# ETL Pipeline Analysis for Scout DAL Agent

## Overview
This ETL script processes Scout transaction data from the same Azure SQL database that our DAL agent uses, creating a flattened dataset for analytics.

## Data Flow Architecture

### 1. Bronze Layer (Raw Data)
- **Source**: `bronze.PayloadTransactions`
- **Joins**: `dbo.SalesInteractions` for interaction data
- **Time Window**: Last 30 days (5000 records)
- **Key Fields**: canonical_tx_id, session_id, device_id, store_id, payload_json

### 2. Silver Layer (Flattened)
- **Process**: DataFlattener with FlattenConfig
- **Function**: Extracts nested JSON from payload_json
- **Output**: Normalized tabular structure

### 3. Gold Layer (Enriched)
- **Enrichment**: Store and geographic data
- **Sources**: `dbo.Stores` + `dbo.GeographicHierarchy`
- **Added Fields**: store_name, barangay, city, region_name, lat/lng

## Integration with DAL Agent

### Shared Database Tables
Both ETL and DAL agent use:
- `dbo.Stores` - Store master data
- `dbo.GeographicHierarchy` - Location hierarchy
- Transaction data (Bronze vs Gold layers)

### DAL Agent Table Usage
Our deployed DAL agent queries:
- `gold.scout_dashboard_transactions` - Pre-processed analytics data
- `dbo.brands_ref` - Brand ownership flags

### Data Pipeline Relationship
```
Raw Data (Bronze) → ETL Flatten → Clean/Enrich (Gold) → DAL Agent Queries
```

## Recommendations

### 1. ETL Output Alignment
The ETL should populate `gold.scout_dashboard_transactions` that DAL agent queries:

```sql
-- ETL final insert should match DAL expectations
INSERT INTO gold.scout_dashboard_transactions
SELECT
  canonical_tx_id as id,
  peso_value,
  timestamp,
  store_id,
  brand_name,
  product_category,
  longitude,
  latitude,
  location_city
FROM flattened_data
```

### 2. Brand Reference Integration
ETL should also populate/update `dbo.brands_ref`:

```sql
-- Ensure brand ownership flags are maintained
MERGE dbo.brands_ref br
USING (SELECT DISTINCT brand_name FROM flattened_data) src
ON br.brand_name = src.brand_name
WHEN NOT MATCHED THEN
  INSERT (brand_name, is_owned) VALUES (src.brand_name, 0); -- Default to competitor
```

### 3. Real-time Sync
Consider scheduling ETL to run frequently to keep DAL agent data fresh:
- Incremental processing based on `ingestion_timestamp`
- Delta updates to gold layer
- Automated brand reference updates

### 4. Data Quality Validation
Both ETL and DAL should validate:
- Non-null canonical_tx_id
- Valid store_id references
- Proper timestamp formats
- Numeric peso_value validation

## Connection Configuration
The ETL and DAL agent share the same database connection:
- **Server**: sqltbwaprojectscoutserver.database.windows.net
- **Database**: SQL-TBWA-ProjectScout-Reporting-Prod
- **Authentication**: TBWA user with R@nd0mPA$2025! password

## Next Steps
1. Align ETL output schema with DAL agent expectations
2. Implement incremental processing for real-time updates
3. Add data quality checks and monitoring
4. Consider ETL scheduling automation
5. Validate brand ownership flag accuracy