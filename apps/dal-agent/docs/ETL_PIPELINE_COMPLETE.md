# Scout Analytics ETL Pipeline - Complete Documentation

**Version**: 7.1 Production
**Updated**: 2025-09-25
**Status**: Production Ready with Schema Alignment

## Architecture Overview

Scout Analytics implements a **Medallion Architecture** with proper schema organization for data quality, governance, and performance.

```
Source Systems → Bronze → Silver → Gold → Platinum (Analytics)
     ↓             ↓        ↓       ↓         ↓
Raw Files      bronze.*   N/A   gold.*   dbo.v_* (Views)
```

## Schema Organization

### Production Schema Layout
```sql
-- Raw Data Ingestion
bronze.*                 -- Raw data ingestion (ETL Layer 1)
staging.*               -- Data import and processing staging

-- Clean Transactional Data
scout.*                 -- Clean transactional data (primary source)
ref.*                   -- Reference data and lookup tables

-- Analytics Ready Data
gold.*                  -- Clean, analytics-ready data (ETL Layer 3)
dbo.v_*                 -- Analytics views and exports

-- Specialized Systems
ces.*                   -- Campaign Effectiveness System
cdc.*                   -- Change Data Capture
ops.*                   -- Operational monitoring
```

## ETL Data Flow

### Layer 1: Bronze (Raw Ingestion)
**Schema**: `bronze.*`
**Purpose**: Raw data ingestion with minimal processing

#### Key Tables
```sql
-- Raw transaction ingestion
bronze.transactions
├── id (PK)
├── transaction_id
├── raw_payload (JSON)
├── ingested_at
├── source_file
└── processing_status

-- Bronze transaction staging
bronze.bronze_transactions
├── bronze_id (PK)
├── original_transaction_id
├── payload_json (nvarchar(max))
├── created_at
├── source_system
└── file_path

-- NCR store dimension
bronze.dim_stores_ncr
├── store_id (PK)
├── store_name, region, province, city
├── latitude, longitude
└── operational_status
```

#### Bronze Processing Logic
```sql
-- Raw data ingestion pattern
INSERT INTO bronze.transactions (
    transaction_id,
    raw_payload,
    ingested_at,
    source_file,
    processing_status
)
SELECT
    JSON_VALUE(payload, '$.transactionId') as transaction_id,
    payload as raw_payload,
    GETDATE() as ingested_at,
    @source_file as source_file,
    'pending' as processing_status
FROM OPENJSON(@raw_data);
```

### Layer 2: Silver (Data Cleaning) - Schema: scout.*
**Primary Source**: Clean transactional data for analytics

#### Core Tables
```sql
-- Clean transaction headers
scout.transactions
├── transaction_id (PK, varchar(64))
├── store_id → scout.stores.store_id
├── customer_id → scout.customers.customer_id
├── transaction_datetime
├── total_amount, item_count
├── payment_method
└── created_at, updated_at

-- Transaction line items
scout.transaction_items
├── item_id (PK)
├── transaction_id → scout.transactions.transaction_id
├── product_id → scout.products.product_id
├── sku_code, quantity
├── unit_price, total_price
└── brand_name, category

-- Customer dimension
scout.customers
├── customer_id (PK)
├── age_group, gender, location
├── loyalty_tier
├── total_spent, transaction_count
└── last_transaction

-- Store dimension
scout.stores
├── store_id (PK)
├── store_code, store_name
├── region, province, city, barangay
├── latitude, longitude
└── store_format, status

-- Brand master with Nielsen
scout.brands
├── brand_id (PK)
├── brand_name (unique)
├── manufacturer, category
├── nielsen_category_code
└── is_private_label

-- Product master
scout.products
├── product_id (PK)
├── brand_id → scout.brands.brand_id
├── product_name, category
├── unit_of_measure, pack_size
└── retail_price, cost_price
```

#### Silver Processing Logic
```sql
-- Clean transaction extraction
INSERT INTO scout.transactions (
    transaction_id,
    store_id,
    customer_id,
    transaction_datetime,
    total_amount,
    item_count,
    payment_method
)
SELECT
    JSON_VALUE(raw_payload, '$.transactionId'),
    JSON_VALUE(raw_payload, '$.storeId'),
    JSON_VALUE(raw_payload, '$.customerId'),
    CAST(JSON_VALUE(raw_payload, '$.timestamp') AS datetime2),
    CAST(JSON_VALUE(raw_payload, '$.totalAmount') AS decimal(10,2)),
    JSON_VALUE(raw_payload, '$.itemCount'),
    JSON_VALUE(raw_payload, '$.paymentMethod')
FROM bronze.transactions
WHERE processing_status = 'pending';
```

### Layer 3: Gold (Analytics Ready) - Schema: gold.*
**Purpose**: Clean, aggregated, analytics-ready datasets

#### Key Tables
```sql
-- Primary analytics table (12,192 canonical transactions)
gold.scout_dashboard_transactions
├── id (PK)
├── canonical_tx_id (unique) → scout.transactions.transaction_id
├── store_location, transaction_value
├── basket_size, primary_category, primary_brand
├── customer_age_group, customer_gender
├── daypart, weekday_name, is_weekend
├── payment_method, transaction_datetime
└── created_at

-- TBWA client brand portfolio
gold.tbwa_client_brands
├── brand_id (PK)
├── brand_name (unique)
├── client_name, category
├── nielsen_code, is_flagship
├── market_share
└── created_at
```

#### Gold Processing Logic
```sql
-- Analytics-ready transaction aggregation
INSERT INTO gold.scout_dashboard_transactions (
    canonical_tx_id,
    store_location,
    transaction_value,
    basket_size,
    primary_category,
    primary_brand,
    customer_age_group,
    customer_gender,
    daypart,
    weekday_name,
    is_weekend,
    payment_method,
    transaction_datetime
)
SELECT
    t.transaction_id as canonical_tx_id,
    s.city + ', ' + s.province as store_location,
    t.total_amount as transaction_value,
    t.item_count as basket_size,

    -- Get primary category (highest value item)
    (SELECT TOP 1 ti.category
     FROM scout.transaction_items ti
     WHERE ti.transaction_id = t.transaction_id
     ORDER BY ti.total_price DESC) as primary_category,

    -- Get primary brand (highest value item)
    (SELECT TOP 1 ti.brand_name
     FROM scout.transaction_items ti
     WHERE ti.transaction_id = t.transaction_id
     ORDER BY ti.total_price DESC) as primary_brand,

    c.age_group as customer_age_group,
    c.gender as customer_gender,

    -- Daypart logic
    CASE
        WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END as daypart,

    DATENAME(WEEKDAY, t.transaction_datetime) as weekday_name,

    CASE
        WHEN DATEPART(WEEKDAY, t.transaction_datetime) IN (1,7) THEN 1
        ELSE 0
    END as is_weekend,

    t.payment_method,
    t.transaction_datetime

FROM scout.transactions t
JOIN scout.stores s ON t.store_id = s.store_id
JOIN scout.customers c ON t.customer_id = c.customer_id
WHERE t.total_amount > 0
  AND t.item_count > 0;
```

### Layer 4: Platinum (Analytics Views) - Schema: dbo.v_*
**Purpose**: Final analytics views for dashboards and exports

#### Key Analytics Views
```sql
-- Primary flat export (12,192 transactions)
dbo.v_flat_export_sheet
├── All transaction dimensions flattened
├── Fixed join multiplication issue
├── Used by dashboards and exports
└── 26/26 fields per Scout Data Dictionary

-- CSV-safe export version
dbo.v_flat_export_csvsafe
├── Same data as v_flat_export_sheet
├── CR/LF characters stripped from text fields
├── NULL values handled properly
└── Eliminates JSON parsing errors

-- Nielsen taxonomy integration
dbo.v_nielsen_complete_analytics
├── Maps 113 brands to Nielsen hierarchy
├── 6-level category structure
├── Reduces "Unspecified" from 48.3% to <10%
└── Industry-standard categorization

-- Gold layer analytics
gold.v_transactions_flat
├── Clean, validated transactions
├── Proper data types
├── Quality metrics passed
└── Ready for ML and BI tools
```

## Reference Data Integration

### Nielsen Taxonomy (ref.* schema)
```sql
-- Nielsen department hierarchy
ref.NielsenDepartments
├── DepartmentCode (PK, varchar(5))
├── DepartmentName (varchar(100))
└── SortOrder, IsActive

-- Nielsen category taxonomy
ref.NielsenCategories
├── CategoryCode (PK, varchar(10))
├── CategoryName (varchar(200))
├── DepartmentCode → ref.NielsenDepartments
├── ParentCategoryCode (self-reference)
└── Level, SortOrder, IsActive

-- SKU master with Nielsen integration
ref.SkuDimensions
├── sku_id (PK)
├── sku_code (unique)
├── sku_name, brand_name
├── category_code → ref.NielsenCategories
├── pack_size, unit_price
└── nielsen_category

-- Customer persona rules
ref.persona_rules
├── rule_id (PK)
├── age_min, age_max, gender
├── emotional_state
├── persona_name, persona_description
└── priority, is_active
```

### Brand-Category Mapping (dbo.* schema - Legacy)
```sql
-- 113 canonical brand mappings
dbo.BrandCategoryMapping
├── MappingID (PK)
├── BrandNameNorm (varchar(200))
├── CategoryCode → ref.NielsenCategories.CategoryCode
├── CategoryName, Confidence
├── MappingSource ('manual', 'ml', 'fuzzy')
└── CreatedAt
```

## Data Quality & Validation

### Quality Gates
```sql
-- 1. Row count validation (12,192 canonical)
SELECT COUNT(*) as canonical_count
FROM gold.scout_dashboard_transactions;
-- Expected: 12,192

-- 2. Brand mapping coverage (113 brands)
SELECT COUNT(DISTINCT BrandNameNorm) as mapped_brands
FROM dbo.BrandCategoryMapping
WHERE CategoryCode IS NOT NULL;
-- Expected: 113

-- 3. Category coverage improvement
SELECT
    SUM(CASE WHEN primary_category = 'Unspecified' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as unspecified_pct
FROM gold.scout_dashboard_transactions;
-- Target: <10% (improved from 48.3%)

-- 4. Data integrity checks
SELECT COUNT(*) as integrity_violations
FROM gold.scout_dashboard_transactions
WHERE transaction_value <= 0
   OR basket_size <= 0
   OR canonical_tx_id IS NULL;
-- Expected: 0
```

### Monitoring Views
```sql
-- Pipeline health monitoring
dbo.v_pipeline_realtime_monitor
├── Processing status by layer
├── Error rates and recovery metrics
├── Data freshness indicators
└── Volume trend analysis

-- Data quality dashboard
dbo.v_data_quality_monitor
├── Completeness metrics
├── Accuracy indicators
├── Consistency validation
└── Timeliness monitoring
```

## ETL Orchestration

### Processing Schedule
```yaml
etl_schedule:
  bronze_ingestion:
    frequency: "Every 15 minutes"
    source: "File watchers, API endpoints"
    target: "bronze.* tables"

  silver_processing:
    frequency: "Every 30 minutes"
    source: "bronze.* tables"
    target: "scout.* tables"
    validation: "Data quality rules"

  gold_analytics:
    frequency: "Every hour"
    source: "scout.* tables"
    target: "gold.* tables"
    aggregation: "Analytics ready format"

  platinum_views:
    frequency: "On demand / Real-time"
    source: "gold.* tables + ref.* lookups"
    target: "dbo.v_* analytics views"
    caching: "Materialized where needed"
```

### Error Handling & Recovery
```sql
-- ETL audit logging
ops.etl_execution_log
├── execution_id (PK)
├── pipeline_stage ('bronze', 'silver', 'gold')
├── start_time, end_time, duration
├── records_processed, records_failed
├── error_message, stack_trace
└── recovery_action_taken

-- Failed record quarantine
ops.failed_records_quarantine
├── quarantine_id (PK)
├── source_record_id
├── pipeline_stage, failure_reason
├── raw_data, attempted_transforms
├── quarantine_date
└── resolution_status
```

## Performance Optimization

### Indexing Strategy
```sql
-- Scout schema performance indexes
CREATE NONCLUSTERED INDEX IX_scout_transactions_datetime
ON scout.transactions (transaction_datetime DESC);

CREATE NONCLUSTERED INDEX IX_scout_transactions_store
ON scout.transactions (store_id, transaction_datetime DESC);

CREATE NONCLUSTERED INDEX IX_scout_transaction_items_tx
ON scout.transaction_items (transaction_id)
INCLUDE (product_id, brand_name, category, total_price);

-- Gold schema analytics indexes
CREATE UNIQUE NONCLUSTERED INDEX IX_gold_dashboard_canonical
ON gold.scout_dashboard_transactions (canonical_tx_id);

CREATE NONCLUSTERED INDEX IX_gold_dashboard_analytics
ON gold.scout_dashboard_transactions (store_location, primary_category, customer_age_group);
```

### Partitioning Strategy
```sql
-- Time-based partitioning for large tables
ALTER TABLE scout.transactions
PARTITION BY RANGE (transaction_datetime) (
    PARTITION p202401 VALUES LESS THAN ('2024-02-01'),
    PARTITION p202402 VALUES LESS THAN ('2024-03-01'),
    -- ... monthly partitions
);
```

## Deployment & Operations

### Environment Strategy
```yaml
environments:
  development:
    database: "SQL-TBWA-ProjectScout-Dev"
    schema_prefix: "dev_"
    data_retention: "30 days"

  staging:
    database: "SQL-TBWA-ProjectScout-Staging"
    schema_prefix: "stg_"
    data_retention: "90 days"
    validation: "Full quality gates"

  production:
    database: "SQL-TBWA-ProjectScout-Reporting-Prod"
    schema_prefix: ""  # No prefix
    data_retention: "7 years"
    monitoring: "24/7 alerting"
    backup: "Point-in-time recovery"
```

### Migration Strategy
```sql
-- Zero-downtime deployment pattern
1. Deploy new schema objects with versioning
2. Run dual-write to old and new schemas
3. Validate data consistency
4. Switch reads to new schema
5. Remove old schema objects
6. Update documentation
```

## Analytics Integration

### Export Formats
```yaml
analytics_exports:
  flat_export:
    view: "dbo.v_flat_export_csvsafe"
    format: "CSV (bullet-proof)"
    rows: 12192
    refresh: "Real-time"

  nielsen_analytics:
    view: "dbo.v_nielsen_complete_analytics"
    format: "CSV + JSON"
    taxonomy: "6-level hierarchy"
    brand_coverage: "113/113 (100%)"

  cross_tabulations:
    views: "dbo.v_xtab_*"
    formats: "CSV, JSON, Excel"
    dimensions: "16 cross-tab combinations"
    aggregation: "Absolute counts + percentages"
```

### API Integration Points
```yaml
api_endpoints:
  transactions: "/api/v1/transactions"
  brands: "/api/v1/brands"
  stores: "/api/v1/stores"
  analytics: "/api/v1/analytics"
  nielsen: "/api/v1/nielsen"
  exports: "/api/v1/exports"
```

## Security & Compliance

### Data Protection
```sql
-- Row-level security for multi-tenant access
ALTER TABLE scout.transactions
ADD client_id varchar(50) DEFAULT 'tbwa';

CREATE SECURITY POLICY client_access_policy
ON scout.transactions
ADD FILTER PREDICATE client_id = USER_NAME();
```

### Audit Trail
```sql
-- Change data capture for audit
sys.sp_cdc_enable_table
    @source_schema = 'scout',
    @source_name = 'transactions',
    @role_name = 'cdc_admin';
```

## Success Metrics

### Data Quality KPIs
- **Completeness**: 99.25% (12,101/12,192 valid transactions)
- **Brand Coverage**: 100% (113/113 brands mapped)
- **Category Resolution**: >90% (improved from 51.7%)
- **Processing Latency**: <5 minutes end-to-end
- **Data Freshness**: <15 minutes from source

### Business Impact
- **Analytics Ready**: 12,192 canonical transactions
- **Dashboard Performance**: <200ms response times
- **Export Reliability**: 100% success rate with bullet-proof CSV
- **Nielsen Integration**: Industry-standard categorization
- **Scalability**: Handles 10K+ transactions/hour

---

**Status**: ✅ Production Ready
**Last Updated**: 2025-09-25
**Next Review**: 2025-10-25