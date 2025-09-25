# Scout Analytics Platform - Complete ETL Pipeline Guide

**Version**: 3.0
**Database**: SQL-TBWA-ProjectScout-Reporting-Prod
**Updated**: September 2025

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Medallion Architecture Implementation](#medallion-architecture-implementation)
3. [Data Pipeline Flow](#data-pipeline-flow)
4. [ETL Processes](#etl-processes)
5. [Data Quality & Monitoring](#data-quality--monitoring)
6. [Performance Optimization](#performance-optimization)
7. [Error Handling & Recovery](#error-handling--recovery)
8. [Deployment & Operations](#deployment--operations)

## Architecture Overview

### System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data Sources  │    │   Azure SQL DB  │    │   Consuming     │
│                 │───▶│      Scout      │───▶│   Applications  │
│ • Drive JSON    │    │   Medallion     │    │ • Suqi Dashboard│
│ • Excel Files   │    │   Architecture  │    │ • Power BI      │
│ • Real-time API │    │                 │    │ • Analytics API │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Technology Stack

- **Database**: Azure SQL Database
- **ETL Framework**: Custom T-SQL procedures with Python orchestration
- **Data Formats**: JSON, CSV, Excel (XLSX)
- **Architecture Pattern**: Medallion (Bronze → Silver → Gold → Platinum)
- **Monitoring**: Custom monitoring views and audit tables
- **Performance**: Columnstore indexes, partitioning, parallel processing

## Medallion Architecture Implementation

### Layer Definitions

| Layer | Purpose | Tables/Views | Data Quality | Update Frequency |
|-------|---------|-------------|--------------|------------------|
| **Bronze** | Raw ingestion | `PayloadTransactions`, `SalesInteractions` | Minimal validation | Real-time |
| **Silver** | Cleaned data | `TransactionItems`, `Transactions` | Full validation, deduplication | Batch (15 min) |
| **Gold** | Business views | `v_transactions_flat_production` | Business rules applied | Near real-time |
| **Platinum** | Analytics aggregations | `v_nielsen_complete_analytics` | Analytical transformations | Scheduled |

### Data Flow Diagram

```
Bronze Layer (Raw)
    ↓
PayloadTransactions ──┐
SalesInteractions ────┤
    ↓                 │
Silver Layer (Clean)  │
    ↓                 │
TransactionItems ──┬──┘
Transactions ──────┤
BrandSubstitutions ─┤
TransactionBaskets ─┤
    ↓               │
Gold Layer (Business)
    ↓               │
v_transactions_flat_production ──┐
v_insight_base ───────────────────┤
    ↓                             │
Platinum Layer (Analytics)        │
    ↓                             │
v_nielsen_complete_analytics ──┬──┘
v_xtab_time_brand_category_abs ─┤
v_data_quality_monitor ─────────┤
```

## Data Pipeline Flow

### 1. Data Ingestion (Bronze Layer)

#### Source Systems Integration

**Google Drive Integration**
```python
# Data extraction from Google Drive
def extract_google_drive_data():
    """
    Extract JSON and ZIP files from Google Drive
    Process both historical and incremental data
    """
    sources = {
        'transaction_files': '/drive/scout/transactions/',
        'interaction_files': '/drive/scout/interactions/',
        'supplementary_data': '/drive/scout/supplements/'
    }

    for source_type, path in sources.items():
        files = get_drive_files(path, since_last_run=True)
        for file in files:
            if file.type == 'json':
                process_json_file(file)
            elif file.type == 'zip':
                extract_and_process_zip(file)
```

**Raw Data Processing**
```sql
-- Bronze layer ingestion stored procedure
CREATE PROCEDURE dbo.sp_IngestRawTransactionData
    @BatchId VARCHAR(100),
    @DataSource VARCHAR(100),
    @ProcessingMode VARCHAR(20) = 'incremental' -- 'full' or 'incremental'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RecordsProcessed INT = 0;

    BEGIN TRY
        -- Insert raw payload data
        INSERT INTO dbo.PayloadTransactions (
            transaction_id, interaction_id, canonical_tx_id,
            payload_json, payload_hash, txn_ts, total_amount,
            total_items, payment_method, store_id, source_system,
            etl_batch_id, processing_status
        )
        SELECT
            JSON_VALUE(payload, '$.transaction_id'),
            JSON_VALUE(payload, '$.interaction_id'),
            JSON_VALUE(payload, '$.canonical_tx_id'),
            payload,
            HASHBYTES('SHA2_256', payload),
            CAST(JSON_VALUE(payload, '$.timestamp') AS DATETIME2),
            CAST(JSON_VALUE(payload, '$.total_amount') AS DECIMAL(12,2)),
            CAST(JSON_VALUE(payload, '$.total_items') AS INT),
            JSON_VALUE(payload, '$.payment_method'),
            JSON_VALUE(payload, '$.store_id'),
            @DataSource,
            @BatchId,
            'pending'
        FROM dbo.PayloadTransactionsStaging
        WHERE batch_id = @BatchId
        AND (@ProcessingMode = 'full' OR ingestion_timestamp > DATEADD(hour, -1, GETDATE()));

        SET @RecordsProcessed = @@ROWCOUNT;

        -- Log successful ingestion
        INSERT INTO audit.ETLProcessingLog (
            process_name, batch_id, start_time, end_time,
            status, records_processed, records_successful
        )
        VALUES (
            'Bronze Layer Ingestion', @BatchId, @StartTime, GETDATE(),
            'completed', @RecordsProcessed, @RecordsProcessed
        );

    END TRY
    BEGIN CATCH
        -- Log error
        INSERT INTO audit.ETLProcessingLog (
            process_name, batch_id, start_time, end_time,
            status, records_processed, error_message
        )
        VALUES (
            'Bronze Layer Ingestion', @BatchId, @StartTime, GETDATE(),
            'failed', @RecordsProcessed, ERROR_MESSAGE()
        );
        THROW;
    END CATCH
END;
```

### 2. Data Cleaning & Transformation (Silver Layer)

#### Transaction Item Extraction

```sql
-- Extract transaction items from JSON payload
CREATE PROCEDURE dbo.sp_ExtractTransactionItems
    @BatchId VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear existing items for reprocessing (idempotent)
    DELETE ti FROM dbo.TransactionItems ti
    INNER JOIN dbo.PayloadTransactions pt ON ti.canonical_tx_id = pt.canonical_tx_id
    WHERE pt.etl_batch_id = @BatchId;

    -- Extract items using JSON functions
    WITH ExtractedItems AS (
        SELECT
            pt.transaction_id,
            pt.canonical_tx_id,
            item.value AS item_json,
            ROW_NUMBER() OVER (PARTITION BY pt.canonical_tx_id ORDER BY item.[key]) AS item_sequence
        FROM dbo.PayloadTransactions pt
        CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS item
        WHERE pt.etl_batch_id = @BatchId
        AND pt.processing_status = 'pending'
    )
    INSERT INTO dbo.TransactionItems (
        transaction_id, canonical_tx_id, product_name, sku_name,
        barcode, brand_detected, category_detected, pack_size,
        unit_price, quantity, total_price, extraction_confidence,
        processing_batch_id
    )
    SELECT
        ei.transaction_id,
        ei.canonical_tx_id,
        JSON_VALUE(ei.item_json, '$.product_name'),
        JSON_VALUE(ei.item_json, '$.sku'),
        JSON_VALUE(ei.item_json, '$.barcode'),
        dbo.fn_DetectBrandName(JSON_VALUE(ei.item_json, '$.product_name')),
        dbo.fn_ClassifyCategory(JSON_VALUE(ei.item_json, '$.product_name')),
        JSON_VALUE(ei.item_json, '$.pack_size'),
        CAST(JSON_VALUE(ei.item_json, '$.unit_price') AS DECIMAL(10,2)),
        CAST(JSON_VALUE(ei.item_json, '$.quantity') AS INT),
        CAST(JSON_VALUE(ei.item_json, '$.total_price') AS DECIMAL(10,2)),
        CAST(JSON_VALUE(ei.item_json, '$.confidence') AS DECIMAL(3,2)),
        @BatchId
    FROM ExtractedItems ei;

    -- Update processing status
    UPDATE dbo.PayloadTransactions
    SET processing_status = 'processed'
    WHERE etl_batch_id = @BatchId;
END;
```

#### Brand Detection & Category Classification

```sql
-- Advanced brand detection function using fuzzy matching
CREATE FUNCTION dbo.fn_DetectBrandName(@ProductName NVARCHAR(200))
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @DetectedBrand VARCHAR(100);

    -- Exact match first
    SELECT TOP 1 @DetectedBrand = standardized_brand_name
    FROM ref.nielsen_brand_map
    WHERE UPPER(@ProductName) LIKE '%' + UPPER(original_brand_name) + '%'
    AND confidence_score >= 0.9
    ORDER BY confidence_score DESC, LEN(original_brand_name) DESC;

    -- Fuzzy match if no exact match
    IF @DetectedBrand IS NULL
    BEGIN
        SELECT TOP 1 @DetectedBrand = standardized_brand_name
        FROM ref.nielsen_brand_map
        WHERE dbo.fn_FuzzyMatch(@ProductName, original_brand_name) >= 0.8
        ORDER BY dbo.fn_FuzzyMatch(@ProductName, original_brand_name) DESC;
    END;

    RETURN COALESCE(@DetectedBrand, 'Unknown Brand');
END;
```

#### Deduplication Logic

```sql
-- Comprehensive deduplication procedure
CREATE PROCEDURE dbo.sp_DeduplicateTransactions
    @BatchId VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- Create deduplication view
    WITH DuplicateAnalysis AS (
        SELECT
            canonical_tx_id,
            payload_hash,
            txn_ts,
            total_amount,
            store_id,
            ROW_NUMBER() OVER (
                PARTITION BY payload_hash
                ORDER BY ingestion_timestamp ASC
            ) AS duplicate_rank,
            ROW_NUMBER() OVER (
                PARTITION BY canonical_tx_id, store_id, txn_ts, total_amount
                ORDER BY ingestion_timestamp ASC
            ) AS business_duplicate_rank
        FROM dbo.PayloadTransactions
        WHERE etl_batch_id = @BatchId
    )
    -- Mark duplicates
    UPDATE pt SET
        is_duplicate = 1,
        validation_errors = CASE
            WHEN da.duplicate_rank > 1 THEN 'Exact payload duplicate'
            WHEN da.business_duplicate_rank > 1 THEN 'Business logic duplicate'
            ELSE NULL
        END
    FROM dbo.PayloadTransactions pt
    INNER JOIN DuplicateAnalysis da ON pt.canonical_tx_id = da.canonical_tx_id
    WHERE (da.duplicate_rank > 1 OR da.business_duplicate_rank > 1)
    AND pt.etl_batch_id = @BatchId;
END;
```

### 3. Business Intelligence Views (Gold Layer)

#### Primary Transaction View

```sql
-- Main production view for transaction analytics
CREATE OR ALTER VIEW dbo.v_transactions_flat_production AS
WITH TransactionBase AS (
    SELECT
        t.canonical_tx_id,
        t.transaction_id,
        t.txn_ts,
        t.store_id,
        t.total_amount,
        t.total_items,
        t.payment_method,
        t.daypart,
        t.weekday_weekend,
        s.StoreName AS store_name,
        s.MunicipalityName,
        s.ProvinceName,
        s.RegionID
    FROM dbo.Transactions t
    LEFT JOIN dbo.Stores s ON t.store_id = s.StoreID
    WHERE t.processing_status = 'active'
),
ItemAggregation AS (
    SELECT
        ti.canonical_tx_id,
        -- Primary brand/category (most expensive item)
        FIRST_VALUE(ti.brand_detected) OVER (
            PARTITION BY ti.canonical_tx_id
            ORDER BY ti.total_price DESC
        ) AS brand,
        FIRST_VALUE(ti.category_detected) OVER (
            PARTITION BY ti.canonical_tx_id
            ORDER BY ti.total_price DESC
        ) AS category,
        FIRST_VALUE(ti.nielsen_category) OVER (
            PARTITION BY ti.canonical_tx_id
            ORDER BY ti.total_price DESC
        ) AS nielsen_category,
        FIRST_VALUE(ti.nielsen_department) OVER (
            PARTITION BY ti.canonical_tx_id
            ORDER BY ti.total_price DESC
        ) AS nielsen_department,
        -- Aggregated metrics
        COUNT(*) AS item_count,
        COUNT(DISTINCT ti.brand_detected) AS brand_count,
        COUNT(DISTINCT ti.category_detected) AS category_count,
        SUM(ti.total_price) AS calculated_total,
        AVG(ti.extraction_confidence) AS avg_confidence
    FROM dbo.TransactionItems ti
    WHERE ti.brand_detected IS NOT NULL
    GROUP BY ti.canonical_tx_id
)
SELECT
    tb.canonical_tx_id,
    tb.transaction_id,
    tb.txn_ts,
    tb.store_id,
    tb.store_name,
    tb.MunicipalityName,
    tb.ProvinceName,
    tb.total_amount,
    tb.total_items,
    tb.payment_method,
    tb.daypart,
    tb.weekday_weekend,
    -- Enhanced product data
    ia.brand,
    ia.category,
    ia.nielsen_category,
    ia.nielsen_department,
    ia.item_count,
    ia.brand_count,
    ia.category_count,
    -- Quality indicators
    CASE
        WHEN ABS(tb.total_amount - ia.calculated_total) < 0.01 THEN 1.0
        ELSE 0.8
    END AS data_quality_score,
    ia.avg_confidence AS extraction_confidence
FROM TransactionBase tb
LEFT JOIN ItemAggregation ia ON tb.canonical_tx_id = ia.canonical_tx_id;
```

#### Nielsen Complete Analytics View

```sql
-- Nielsen taxonomy aligned analytics view
CREATE OR ALTER VIEW dbo.v_nielsen_complete_analytics AS
WITH NielsenTransactions AS (
    SELECT
        vt.canonical_tx_id,
        vt.transaction_id,
        vt.txn_ts AS transaction_timestamp,
        DATEPART(HOUR, vt.txn_ts) AS hour_of_day,
        vt.daypart,
        vt.weekday_weekend,
        vt.total_amount AS transaction_value,
        vt.total_items AS basket_size,
        vt.payment_method,
        -- Nielsen taxonomy
        COALESCE(bcm.nielsen_category, vt.category, 'Unspecified') AS nielsen_category,
        COALESCE(bcm.nielsen_department, 'General Merchandise') AS nielsen_department,
        COALESCE(bcm.brand_name, vt.brand, 'Unknown Brand') AS brand_name,
        -- Geographic data
        vt.store_id,
        vt.store_name,
        r.RegionName AS region,
        p.ProvinceName AS province_name,
        m.MunicipalityName AS municipality_name
    FROM dbo.v_transactions_flat_production vt
    LEFT JOIN dbo.BrandCategoryMapping bcm ON UPPER(vt.brand) = UPPER(bcm.brand_name)
    LEFT JOIN dbo.Stores s ON vt.store_id = s.StoreID
    LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
    LEFT JOIN dbo.Province p ON s.ProvinceID = p.ProvinceID
    LEFT JOIN dbo.Municipality m ON s.MunicipalityID = m.MunicipalityID
    WHERE vt.data_quality_score >= 0.7
),
CustomerInsights AS (
    SELECT
        si.canonical_tx_id,
        si.age_bracket,
        si.gender,
        si.customer_type,
        si.emotions,
        si.substitution_event,
        si.substitution_reason,
        si.suggestion_accepted
    FROM dbo.SalesInteractions si
    WHERE si.canonical_tx_id IS NOT NULL
),
PackSizeAnalysis AS (
    SELECT
        ti.canonical_tx_id,
        STRING_AGG(
            CASE
                WHEN ti.pack_size IS NOT NULL AND ti.pack_size != ''
                THEN ti.pack_size
                ELSE 'Standard'
            END,
            ', '
        ) AS pack_size
    FROM dbo.TransactionItems ti
    GROUP BY ti.canonical_tx_id
)
SELECT
    nt.canonical_tx_id,
    nt.transaction_id,
    nt.transaction_timestamp,
    nt.hour_of_day,
    nt.daypart,
    nt.weekday_weekend,
    nt.transaction_value,
    nt.basket_size,
    nt.payment_method,
    nt.brand_name,
    nt.nielsen_category,
    nt.nielsen_department,
    COALESCE(psa.pack_size, 'Standard') AS pack_size,
    -- Customer insights
    ci.age_bracket,
    ci.gender,
    ci.customer_type,
    ci.emotions,
    -- Geographic data
    nt.store_id,
    nt.store_name,
    nt.region,
    nt.province_name,
    nt.municipality_name,
    -- Substitution data
    ci.substitution_event,
    ci.substitution_reason,
    ci.suggestion_accepted
FROM NielsenTransactions nt
LEFT JOIN CustomerInsights ci ON nt.canonical_tx_id = ci.canonical_tx_id
LEFT JOIN PackSizeAnalysis psa ON nt.canonical_tx_id = psa.canonical_tx_id;
```

### 4. Advanced Analytics (Platinum Layer)

#### Cross-tabulation Analytics

```sql
-- Time-based cross-tabulation view
CREATE OR ALTER VIEW dbo.v_xtab_time_brand_category_abs AS
WITH TimeBasedAnalysis AS (
    SELECT
        vna.nielsen_category,
        vna.nielsen_department,
        vna.brand_name,
        -- Time dimensions
        CAST(vna.transaction_timestamp AS DATE) AS transaction_date,
        DATEPART(YEAR, vna.transaction_timestamp) AS year,
        DATEPART(MONTH, vna.transaction_timestamp) AS month,
        DATEPART(WEEK, vna.transaction_timestamp) AS week,
        DATEPART(HOUR, vna.transaction_timestamp) AS hour,
        vna.daypart,
        vna.weekday_weekend,
        -- Metrics
        COUNT(*) AS transaction_count,
        SUM(vna.transaction_value) AS total_revenue,
        SUM(vna.basket_size) AS total_items,
        AVG(vna.transaction_value) AS avg_transaction_value,
        AVG(vna.basket_size) AS avg_basket_size,
        -- Customer metrics
        COUNT(DISTINCT vna.canonical_tx_id) AS unique_transactions,
        COUNT(DISTINCT CASE WHEN vna.age_bracket IS NOT NULL THEN vna.canonical_tx_id END) AS transactions_with_demographics
    FROM dbo.v_nielsen_complete_analytics vna
    WHERE vna.transaction_timestamp >= DATEADD(month, -12, GETDATE())
    GROUP BY
        vna.nielsen_category,
        vna.nielsen_department,
        vna.brand_name,
        CAST(vna.transaction_timestamp AS DATE),
        DATEPART(YEAR, vna.transaction_timestamp),
        DATEPART(MONTH, vna.transaction_timestamp),
        DATEPART(WEEK, vna.transaction_timestamp),
        DATEPART(HOUR, vna.transaction_timestamp),
        vna.daypart,
        vna.weekday_weekend
),
RankingAnalysis AS (
    SELECT
        *,
        -- Rankings within category
        ROW_NUMBER() OVER (
            PARTITION BY nielsen_category, transaction_date
            ORDER BY total_revenue DESC
        ) AS daily_revenue_rank,
        ROW_NUMBER() OVER (
            PARTITION BY nielsen_category, year, month
            ORDER BY total_revenue DESC
        ) AS monthly_revenue_rank,
        -- Market share calculations
        total_revenue / SUM(total_revenue) OVER (
            PARTITION BY nielsen_category, transaction_date
        ) * 100 AS daily_category_share,
        transaction_count / SUM(transaction_count) OVER (
            PARTITION BY transaction_date
        ) * 100 AS daily_market_share
    FROM TimeBasedAnalysis
)
SELECT
    nielsen_category,
    nielsen_department,
    brand_name,
    transaction_date,
    year,
    month,
    week,
    hour,
    daypart,
    weekday_weekend,
    transaction_count,
    total_revenue,
    total_items,
    avg_transaction_value,
    avg_basket_size,
    unique_transactions,
    transactions_with_demographics,
    daily_revenue_rank,
    monthly_revenue_rank,
    daily_category_share,
    daily_market_share,
    -- Performance indicators
    CASE
        WHEN daily_revenue_rank <= 3 THEN 'Top Performer'
        WHEN daily_revenue_rank <= 10 THEN 'Strong Performer'
        WHEN daily_category_share >= 5 THEN 'Market Leader'
        WHEN daily_category_share >= 2 THEN 'Established Player'
        ELSE 'Emerging Brand'
    END AS performance_tier
FROM RankingAnalysis;
```

## Data Quality & Monitoring

### Quality Control Framework

```sql
-- Data quality monitoring view
CREATE OR ALTER VIEW dbo.v_data_quality_monitor AS
WITH QualityMetrics AS (
    SELECT
        'PayloadTransactions' AS table_name,
        COUNT(*) AS total_records,
        COUNT(*) - COUNT(is_duplicate) AS non_duplicate_records,
        AVG(CASE WHEN is_duplicate = 0 THEN 1.0 ELSE 0.0 END) * 100 AS deduplication_rate,
        AVG(quality_score) * 100 AS avg_quality_score,
        MIN(ingestion_timestamp) AS earliest_record,
        MAX(ingestion_timestamp) AS latest_record
    FROM dbo.PayloadTransactions
    WHERE ingestion_timestamp >= DATEADD(day, -7, GETDATE())

    UNION ALL

    SELECT
        'TransactionItems' AS table_name,
        COUNT(*) AS total_records,
        COUNT(CASE WHEN brand_detected IS NOT NULL AND brand_detected != 'Unknown Brand' THEN 1 END) AS records_with_brand,
        AVG(CASE WHEN brand_detected IS NOT NULL AND brand_detected != 'Unknown Brand' THEN 1.0 ELSE 0.0 END) * 100 AS brand_detection_rate,
        AVG(extraction_confidence) * 100 AS avg_extraction_confidence,
        MIN(extracted_timestamp) AS earliest_record,
        MAX(extracted_timestamp) AS latest_record
    FROM dbo.TransactionItems
    WHERE extracted_timestamp >= DATEADD(day, -7, GETDATE())

    UNION ALL

    SELECT
        'v_nielsen_complete_analytics' AS table_name,
        COUNT(*) AS total_records,
        COUNT(CASE WHEN nielsen_category != 'Unspecified' THEN 1 END) AS categorized_records,
        AVG(CASE WHEN nielsen_category != 'Unspecified' THEN 1.0 ELSE 0.0 END) * 100 AS categorization_rate,
        100.0 AS avg_quality_score, -- View-level quality is always 100%
        MIN(transaction_timestamp) AS earliest_record,
        MAX(transaction_timestamp) AS latest_record
    FROM dbo.v_nielsen_complete_analytics
    WHERE transaction_timestamp >= DATEADD(day, -7, GETDATE())
)
SELECT
    table_name,
    total_records,
    non_duplicate_records,
    deduplication_rate,
    avg_quality_score,
    earliest_record,
    latest_record,
    -- Quality assessment
    CASE
        WHEN avg_quality_score >= 95 THEN 'Excellent'
        WHEN avg_quality_score >= 90 THEN 'Good'
        WHEN avg_quality_score >= 80 THEN 'Acceptable'
        WHEN avg_quality_score >= 70 THEN 'Needs Improvement'
        ELSE 'Critical Issues'
    END AS quality_status,
    -- Freshness assessment
    CASE
        WHEN DATEDIFF(hour, latest_record, GETDATE()) <= 2 THEN 'Fresh'
        WHEN DATEDIFF(hour, latest_record, GETDATE()) <= 24 THEN 'Recent'
        WHEN DATEDIFF(day, latest_record, GETDATE()) <= 7 THEN 'Stale'
        ELSE 'Very Stale'
    END AS freshness_status
FROM QualityMetrics;
```

### Pipeline Monitoring

```sql
-- Real-time pipeline monitoring
CREATE OR ALTER VIEW dbo.v_pipeline_realtime_monitor AS
WITH ProcessingStats AS (
    SELECT
        process_name,
        COUNT(*) AS total_runs,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) AS successful_runs,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) AS failed_runs,
        COUNT(CASE WHEN status = 'running' THEN 1 END) AS currently_running,
        AVG(processing_duration_seconds) AS avg_duration_seconds,
        MAX(end_time) AS last_run_time,
        SUM(records_processed) AS total_records_processed,
        AVG(CASE WHEN status = 'completed' THEN records_processed ELSE NULL END) AS avg_records_per_run
    FROM audit.ETLProcessingLog
    WHERE start_time >= DATEADD(hour, -24, GETDATE())
    GROUP BY process_name
),
CurrentStatus AS (
    SELECT
        process_name,
        status AS current_status,
        start_time AS current_run_start,
        DATEDIFF(second, start_time, GETDATE()) AS current_run_duration_seconds,
        records_processed AS current_records_processed,
        ROW_NUMBER() OVER (PARTITION BY process_name ORDER BY start_time DESC) AS rn
    FROM audit.ETLProcessingLog
    WHERE start_time >= DATEADD(hour, -2, GETDATE())
)
SELECT
    ps.process_name,
    ps.total_runs,
    ps.successful_runs,
    ps.failed_runs,
    ps.currently_running,
    ROUND(ps.avg_duration_seconds / 60.0, 2) AS avg_duration_minutes,
    ps.last_run_time,
    ps.total_records_processed,
    ps.avg_records_per_run,
    -- Current run status
    cs.current_status,
    cs.current_run_start,
    ROUND(cs.current_run_duration_seconds / 60.0, 2) AS current_run_duration_minutes,
    cs.current_records_processed,
    -- Health indicators
    CASE
        WHEN ps.failed_runs = 0 AND ps.successful_runs > 0 THEN 'Healthy'
        WHEN ps.failed_runs * 1.0 / ps.total_runs < 0.1 THEN 'Good'
        WHEN ps.failed_runs * 1.0 / ps.total_runs < 0.25 THEN 'Warning'
        ELSE 'Critical'
    END AS health_status,
    CASE
        WHEN DATEDIFF(minute, ps.last_run_time, GETDATE()) <= 30 THEN 'Active'
        WHEN DATEDIFF(hour, ps.last_run_time, GETDATE()) <= 2 THEN 'Recent'
        WHEN DATEDIFF(hour, ps.last_run_time, GETDATE()) <= 24 THEN 'Delayed'
        ELSE 'Stalled'
    END AS activity_status
FROM ProcessingStats ps
LEFT JOIN CurrentStatus cs ON ps.process_name = cs.process_name AND cs.rn = 1;
```

## Performance Optimization

### Indexing Strategy

```sql
-- Performance optimization indexes
-- Transaction Items - Core business queries
CREATE NONCLUSTERED INDEX IX_TransactionItems_Brand_Category_Date
ON dbo.TransactionItems (brand_detected, category_detected, extracted_timestamp)
INCLUDE (canonical_tx_id, product_name, total_price);

-- PayloadTransactions - ETL processing
CREATE NONCLUSTERED INDEX IX_PayloadTransactions_Processing
ON dbo.PayloadTransactions (processing_status, etl_batch_id, ingestion_timestamp)
INCLUDE (canonical_tx_id, payload_hash);

-- SalesInteractions - Analytics queries
CREATE NONCLUSTERED INDEX IX_SalesInteractions_Demographics_Date
ON dbo.SalesInteractions (age_bracket, gender, interaction_timestamp)
INCLUDE (canonical_tx_id, customer_type, emotions);

-- Stores - Geographic analysis
CREATE NONCLUSTERED INDEX IX_Stores_Geography
ON dbo.Stores (RegionID, ProvinceID, MunicipalityID, IsActive)
INCLUDE (StoreID, StoreName, StoreType);
```

### Partitioning Strategy

```sql
-- Partition function for time-based data
CREATE PARTITION FUNCTION pf_MonthlyPartition (DATETIME2)
AS RANGE RIGHT FOR VALUES (
    '2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01',
    '2024-05-01', '2024-06-01', '2024-07-01', '2024-08-01',
    '2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01',
    '2025-01-01', '2025-02-01', '2025-03-01', '2025-04-01'
);

-- Partition scheme
CREATE PARTITION SCHEME ps_MonthlyPartition
AS PARTITION pf_MonthlyPartition
TO (
    [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY],
    [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY],
    [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY],
    [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY]
);

-- Apply partitioning to high-volume tables
ALTER TABLE dbo.PayloadTransactions
DROP CONSTRAINT PK_PayloadTransactions;

ALTER TABLE dbo.PayloadTransactions
ADD CONSTRAINT PK_PayloadTransactions
PRIMARY KEY (transaction_id, ingestion_timestamp);

-- Recreate table with partitioning
CREATE TABLE dbo.PayloadTransactions_Partitioned (
    -- Same columns as original table
    transaction_id varchar(50),
    ingestion_timestamp datetime2,
    -- ... other columns
    CONSTRAINT PK_PayloadTransactions_Partitioned
    PRIMARY KEY (transaction_id, ingestion_timestamp)
) ON ps_MonthlyPartition(ingestion_timestamp);
```

## Error Handling & Recovery

### Error Classification System

```sql
-- Error handling and recovery procedures
CREATE PROCEDURE dbo.sp_HandleProcessingErrors
    @ProcessName VARCHAR(200),
    @BatchId VARCHAR(100),
    @ErrorSeverity VARCHAR(20), -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    @MaxRetries INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentRetries INT;
    DECLARE @ShouldRetry BIT = 0;

    -- Get current retry count
    SELECT @CurrentRetries = ISNULL(retry_count, 0)
    FROM audit.ETLProcessingLog
    WHERE process_name = @ProcessName
    AND batch_id = @BatchId
    AND status = 'failed';

    -- Determine retry strategy based on error severity
    IF @ErrorSeverity IN ('LOW', 'MEDIUM') AND @CurrentRetries < @MaxRetries
    BEGIN
        SET @ShouldRetry = 1;

        -- Exponential backoff delay
        DECLARE @DelaySeconds INT = POWER(2, @CurrentRetries) * 60; -- 1min, 2min, 4min
        WAITFOR DELAY FORMAT(@DelaySeconds / 60, '00') + ':' + FORMAT(@DelaySeconds % 60, '00') + ':00';
    END;

    IF @ShouldRetry = 1
    BEGIN
        -- Update retry count
        UPDATE audit.ETLProcessingLog
        SET retry_count = @CurrentRetries + 1,
            status = 'retrying'
        WHERE process_name = @ProcessName
        AND batch_id = @BatchId;

        -- Re-execute the process based on type
        IF @ProcessName LIKE '%Ingestion%'
            EXEC dbo.sp_IngestRawTransactionData @BatchId, 'retry';
        ELSE IF @ProcessName LIKE '%Extract%'
            EXEC dbo.sp_ExtractTransactionItems @BatchId;
        ELSE IF @ProcessName LIKE '%Deduplicate%'
            EXEC dbo.sp_DeduplicateTransactions @BatchId;
    END
    ELSE
    BEGIN
        -- Alert operations team for critical errors
        IF @ErrorSeverity = 'CRITICAL'
        BEGIN
            EXEC dbo.sp_SendAlert
                @AlertType = 'ETL_CRITICAL_ERROR',
                @Message = 'Critical ETL error requires immediate attention',
                @ProcessName = @ProcessName,
                @BatchId = @BatchId;
        END;
    END;
END;
```

### Data Recovery Procedures

```sql
-- Data recovery and rollback procedures
CREATE PROCEDURE dbo.sp_RollbackBatch
    @BatchId VARCHAR(100),
    @RollbackReason NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Record rollback initiation
        INSERT INTO audit.ETLProcessingLog (
            process_name, batch_id, status, start_time, error_message
        )
        VALUES (
            'Batch Rollback', @BatchId, 'running', GETDATE(), @RollbackReason
        );

        -- Remove processed data in reverse dependency order
        DELETE FROM dbo.TransactionBaskets
        WHERE interaction_id IN (
            SELECT interaction_id FROM dbo.PayloadTransactions
            WHERE etl_batch_id = @BatchId
        );

        DELETE FROM dbo.BrandSubstitutions
        WHERE transaction_id IN (
            SELECT transaction_id FROM dbo.PayloadTransactions
            WHERE etl_batch_id = @BatchId
        );

        DELETE FROM dbo.TransactionItems
        WHERE processing_batch_id = @BatchId;

        DELETE FROM dbo.Transactions
        WHERE canonical_tx_id IN (
            SELECT canonical_tx_id FROM dbo.PayloadTransactions
            WHERE etl_batch_id = @BatchId
        );

        -- Mark PayloadTransactions for reprocessing
        UPDATE dbo.PayloadTransactions
        SET processing_status = 'rollback',
            validation_errors = @RollbackReason
        WHERE etl_batch_id = @BatchId;

        -- Record successful rollback
        UPDATE audit.ETLProcessingLog
        SET status = 'completed',
            end_time = GETDATE(),
            processing_duration_seconds = DATEDIFF(second, start_time, GETDATE())
        WHERE process_name = 'Batch Rollback'
        AND batch_id = @BatchId;

        COMMIT TRANSACTION;

        PRINT 'Batch ' + @BatchId + ' successfully rolled back.';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        -- Log rollback failure
        UPDATE audit.ETLProcessingLog
        SET status = 'failed',
            end_time = GETDATE(),
            error_message = ERROR_MESSAGE()
        WHERE process_name = 'Batch Rollback'
        AND batch_id = @BatchId;

        THROW;
    END CATCH;
END;
```

## Deployment & Operations

### Deployment Checklist

1. **Pre-deployment Validation**
   ```sql
   -- Validate database objects
   EXEC dbo.sp_ValidateCanonicalTaxonomy;
   EXEC dbo.sp_ValidateNielsenCompleteAnalytics;
   EXEC dbo.sp_scout_health_check;
   ```

2. **Schema Migration Process**
   ```bash
   # Run schema updates
   sqlcmd -S server -d database -i "01_enhanced_schema.sql"
   sqlcmd -S server -d database -i "02_business_intelligence_views.sql"

   # Validate deployment
   sqlcmd -S server -d database -i "validate_deployment.sql"
   ```

3. **Data Migration & Backfill**
   ```sql
   -- Backfill historical data
   EXEC dbo.sp_BackfillNielsenTaxonomy
       @StartDate = '2024-01-01',
       @EndDate = '2025-01-01';

   -- Refresh materialized views
   EXEC dbo.sp_refresh_analytics_views;
   ```

### Monitoring & Alerting Setup

```sql
-- Automated monitoring job
CREATE PROCEDURE dbo.sp_MonitorETLHealth
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Issues TABLE (
        issue_type VARCHAR(50),
        severity VARCHAR(20),
        description NVARCHAR(500)
    );

    -- Check for failed ETL processes
    INSERT INTO @Issues
    SELECT
        'ETL_FAILURE' AS issue_type,
        'HIGH' AS severity,
        'ETL process ' + process_name + ' failed in batch ' + batch_id AS description
    FROM audit.ETLProcessingLog
    WHERE status = 'failed'
    AND start_time >= DATEADD(hour, -2, GETDATE());

    -- Check for stale data
    INSERT INTO @Issues
    SELECT
        'STALE_DATA' AS issue_type,
        'MEDIUM' AS severity,
        'Table ' + table_name + ' has not been updated in 4+ hours' AS description
    FROM dbo.v_data_quality_monitor
    WHERE freshness_status = 'Stale';

    -- Check for quality degradation
    INSERT INTO @Issues
    SELECT
        'QUALITY_DEGRADATION' AS issue_type,
        'MEDIUM' AS severity,
        'Table ' + table_name + ' quality score dropped to ' + CAST(avg_quality_score AS VARCHAR(10)) AS description
    FROM dbo.v_data_quality_monitor
    WHERE quality_status IN ('Needs Improvement', 'Critical Issues');

    -- Send alerts if issues found
    IF EXISTS (SELECT 1 FROM @Issues)
    BEGIN
        DECLARE @AlertMessage NVARCHAR(MAX);
        SELECT @AlertMessage = STRING_AGG(description, CHAR(13) + CHAR(10))
        FROM @Issues;

        EXEC dbo.sp_SendAlert
            @AlertType = 'ETL_HEALTH_CHECK',
            @Message = @AlertMessage;
    END;
END;
```

### Performance Tuning Guidelines

1. **Query Optimization**
   - Use appropriate indexes for frequent query patterns
   - Implement columnstore indexes for analytical workloads
   - Partition large tables by date for improved query performance

2. **ETL Optimization**
   - Process data in batches of 1000-5000 records
   - Use parallel processing for independent operations
   - Implement incremental loading strategies

3. **Resource Management**
   - Monitor CPU and memory usage during ETL operations
   - Schedule heavy processes during off-peak hours
   - Implement connection pooling for concurrent operations

### Backup & Recovery Strategy

1. **Automated Backups**
   - Full backup: Daily at 2:00 AM
   - Differential backup: Every 6 hours
   - Transaction log backup: Every 15 minutes

2. **Recovery Procedures**
   - Point-in-time recovery capability
   - Cross-region backup replication
   - Regular recovery testing (monthly)

This comprehensive ETL pipeline documentation provides the foundation for managing the Scout Analytics Platform's data processing workflows, ensuring data quality, and maintaining optimal performance.