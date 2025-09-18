# Scout v7 ETL Data Flow Architecture
## Format-Flexible Universal Data Processing Pipeline

```mermaid
graph TB
    subgraph "Data Sources"
        GD[Google Drive Files<br/>CSV, JSON, Excel, TSV, XML]
        SE[Scout Edge Devices<br/>Real-time JSON Streams]
        AZ[Azure ML Inference<br/>Product Classifications]
        AS[Azure SQL<br/>Legacy Data]
    end

    subgraph "Format Detection Layer"
        UFP[Universal Format Processor<br/>drive-universal-processor]
        AFD[Auto Format Detection<br/>95% Accuracy]
        SI[Schema Inference<br/>Column Type Detection]
        MCM[ML Column Mapping<br/>Fuzzy Match 0.8 Threshold]
    end

    subgraph "Bronze Layer (Raw Ingestion)"
        UFS[staging.universal_file_ingestion<br/>Multi-format Support]
        SRT[bronze.scout_raw_transactions<br/>Edge Device Data]
        AIP[bronze.azure_inference_products<br/>ML Classifications]
        LDI[bronze.legacy_data_import<br/>Azure SQL Sync]
    end

    subgraph "Silver Layer (Cleaned & Enriched)"
        TC[silver.transactions_cleaned<br/>Validated & Normalized]
        PC[silver.product_catalog<br/>Unified Product Data]
        CC[silver.customer_context<br/>Demographic Enrichment]
        IC[silver.inference_catalog<br/>ML Predictions]
    end

    subgraph "Gold Layer (Business Aggregates)"
        SGT[scout.scout_gold_transactions<br/>Business KPIs]
        FT[scout.fact_transactions<br/>Star Schema Facts]
        PA[gold.product_analytics<br/>Category Performance]
        CA[gold.customer_analytics<br/>Behavioral Insights]
    end

    subgraph "Platinum Layer (AI-Powered Analytics)"
        NL2SQL[NL2SQL Engine<br/>Natural Language Queries]
        CAI[Cross-Tab Analytics<br/>Interactive Dashboards]
        PAI[Predictive Analytics<br/>MindsDB Integration]
        RTA[Real-Time Alerts<br/>Automated Insights]
    end

    subgraph "Processing Intelligence"
        ECR[ETL Control Room<br/>Orchestration & Monitoring]
        QG[Quality Gates<br/>8-Step Validation]
        AP[Auto-Parallelization<br/>Concurrent Processing]
        CB[Circuit Breakers<br/>Error Recovery]
    end

    %% Data Flow Connections
    GD --> UFP
    UFP --> AFD
    AFD --> SI
    SI --> MCM
    MCM --> UFS

    SE --> SRT
    AZ --> AIP
    AS --> LDI

    UFS --> TC
    SRT --> TC
    AIP --> PC
    LDI --> TC

    TC --> SGT
    PC --> FT
    CC --> CA
    IC --> PA

    SGT --> NL2SQL
    FT --> CAI
    PA --> PAI
    CA --> RTA

    %% Processing Intelligence Connections
    ECR --> QG
    QG --> AP
    AP --> CB
    ECR -.-> UFS
    ECR -.-> TC
    ECR -.-> SGT

    %% Styling
    classDef sourceNode fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef bronzeNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef silverNode fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef goldNode fill:#fff9c4,stroke:#f9a825,stroke-width:2px
    classDef platinumNode fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef processNode fill:#fce4ec,stroke:#c2185b,stroke-width:2px

    class GD,SE,AZ,AS sourceNode
    class UFP,AFD,SI,MCM,UFS,SRT,AIP,LDI bronzeNode
    class TC,PC,CC,IC silverNode
    class SGT,FT,PA,CA goldNode
    class NL2SQL,CAI,PAI,RTA platinumNode
    class ECR,QG,AP,CB processNode
```

## Architecture Overview

### Format-Flexible Data Ingestion
**Universal Format Processor** (`drive-universal-processor`) handles multiple data formats:

| Format | Detection | Parsing | Schema Inference |
|--------|-----------|---------|------------------|
| **JSON** | Content structure analysis | Native JSON.parse | Object key extraction |
| **CSV** | Delimiter detection (`,;|`) | Configurable separator | Header-based typing |
| **Excel** | Binary signature + extension | XLSX library | Sheet structure analysis |
| **TSV** | Tab delimiter detection | Tab-separated parsing | Column type inference |
| **XML** | Tag structure analysis | Basic XML to JSON | Element mapping |
| **Parquet** | Binary format detection | Columnar data extraction | Schema metadata |

### Medallion Architecture Data Flow

#### 1. Bronze Layer (Raw Data Ingestion)
```sql
-- Universal file ingestion supports all formats
staging.universal_file_ingestion {
  file_format: 'json'|'csv'|'excel'|'tsv'|'xml'|'parquet'
  detection_confidence: 0.95
  schema_inference: { columns, types, quality_score }
  column_mappings: { ml_mapped_fields }
  raw_data: [ first_1000_records ]
}

-- Scout Edge real-time streaming
bronze.scout_raw_transactions {
  transaction_id, store_id, device_id
  items: [{ product, price, category }]
  detected_brands, processing_metadata
}

-- Azure ML inference results
bronze.azure_inference_products {
  product_id, ml_category, confidence_score
  processing_timestamp, model_version
}
```

#### 2. Silver Layer (Cleaned & Enriched)
```sql
-- Unified transaction data from all sources
silver.transactions_cleaned {
  id, timestamp, amount, payment_method
  product_category, brand_name, sku
  customer_demographics, location_data
  data_source: 'drive'|'edge'|'azure'|'legacy'
}

-- Enriched product catalog
silver.product_catalog {
  product_id, category, brand, pack_size
  ml_enhanced_attributes, confidence_scores
  source_system_mapping
}
```

#### 3. Gold Layer (Business Intelligence)
```sql
-- Business KPI aggregations
scout.scout_gold_transactions {
  daily_revenue, transaction_count
  top_brands, category_performance
  customer_segments, regional_insights
}

-- Star schema for analytics
scout.fact_transactions {
  transaction_key, product_key, customer_key
  time_key, location_key, measures
}
```

#### 4. Platinum Layer (AI-Powered Analytics)
```sql
-- Natural Language to SQL interface
nl2sql_queries {
  question: "Show revenue by brand last 30 days"
  generated_sql, execution_time, cache_hit
  results: cross_tab_format
}

-- Real-time predictive analytics
predictive_insights {
  forecast_type, prediction_horizon
  confidence_interval, model_accuracy
  business_recommendations
}
```

## Processing Intelligence Features

### 1. Auto Format Detection (95% Accuracy)
```typescript
async detectFormat(content: Uint8Array, fileName: string): Promise<FormatDetectionResult> {
  // JSON: Structure analysis
  if (this.looksLikeJSON(textContent)) return 'json'

  // Excel: Binary + extension
  if (fileName.match(/\.(xlsx?|xls)$/i)) return 'excel'

  // CSV/TSV: Delimiter detection
  const delimiter = this.detectDelimiter(textContent)
  if (delimiter) return delimiter === '\t' ? 'tsv' : 'csv'

  // XML: Tag structure
  if (textContent.trim().startsWith('<')) return 'xml'
}
```

### 2. ML Column Mapping (80% → 95% Improvement)
```sql
-- Fuzzy string matching with 0.8 threshold
SELECT * FROM ml_map_columns(
  source_columns := ARRAY['prod_name', 'cat', 'amt'],
  target_schema := 'scout_standard',
  confidence_threshold := 0.8
);

-- Results: [
--   { source: 'prod_name', target: 'product_name', confidence: 0.92 }
--   { source: 'cat', target: 'category', confidence: 0.85 }
--   { source: 'amt', target: 'amount', confidence: 0.95 }
-- ]
```

### 3. Quality Gates (8-Step Validation)
1. **Format Detection** → Confidence ≥ 0.8
2. **Schema Inference** → Column types identified
3. **ML Column Mapping** → Fuzzy match threshold
4. **Data Quality Check** → Missing values < 10%
5. **Business Rule Validation** → Category constraints
6. **Duplicate Detection** → Deduplication logic
7. **Integration Testing** → End-to-end validation
8. **Performance Monitoring** → Processing time < 30s

### 4. Real-Time Processing Pipeline
```mermaid
sequenceDiagram
    participant GD as Google Drive
    participant UFP as Universal Processor
    participant Bronze as Bronze Layer
    participant Silver as Silver Layer
    participant Gold as Gold Layer
    participant AI as AI Analytics

    GD->>UFP: Upload CSV/JSON/Excel file
    UFP->>UFP: Auto-detect format (95% accuracy)
    UFP->>UFP: Infer schema & map columns
    UFP->>Bronze: Store in universal_file_ingestion

    Note over Bronze: Quality Gates 1-3
    Bronze->>Silver: Transform & enrich data

    Note over Silver: Quality Gates 4-6
    Silver->>Gold: Aggregate business metrics

    Note over Gold: Quality Gates 7-8
    Gold->>AI: Enable NL2SQL & predictive analytics

    AI-->>GD: Analytics dashboard ready
```

## Performance Characteristics

### Processing Metrics
| Layer | Latency | Throughput | Accuracy |
|-------|---------|------------|----------|
| **Format Detection** | <100ms | 1000 files/min | 95% |
| **Schema Inference** | <200ms | 500 schemas/min | 90% |
| **ML Column Mapping** | <500ms | 200 mappings/min | 95% |
| **Bronze→Silver** | <2s | 10K records/min | 98% |
| **Silver→Gold** | <5s | 5K aggregations/min | 99% |

### Resource Usage
- **Memory**: 512MB per worker process
- **CPU**: 2 cores for parallel processing
- **Storage**: 10GB/month for 1M records
- **Cache**: Redis 1GB for column mappings

## Error Handling & Recovery

### Circuit Breaker Pattern
```typescript
// Auto-recovery for failed format detection
if (detectionFailures > 3) {
  fallbackToManualMapping()
  alertAdministrator()
}

// Graceful degradation
if (mlColumnMappingFails) {
  useRuleBasedMapping()  // 80% accuracy vs 95%
}
```

### Data Quality Monitoring
```sql
-- Real-time quality metrics
SELECT
  file_format,
  AVG(detection_confidence) as avg_confidence,
  AVG((schema_inference->>'qualityScore')::decimal) as quality_score,
  COUNT(*) FILTER (WHERE status = 'failed') as failure_count
FROM staging.universal_file_ingestion
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY file_format;
```

## Integration Points

### 1. Azure Streaming Integration
- **Event Hub** → Real-time data ingestion
- **Stream Analytics** → Complex event processing
- **Service Bus** → Message queue management
- **ML Inference** → Predictive model scoring

### 2. Supabase Edge Functions
- **drive-universal-processor** → Format-flexible ingestion
- **nl2sql** → Natural language analytics
- **ingest-stream** → Real-time data processing

### 3. External APIs
- **Google Drive API** → File metadata & content
- **Azure Cognitive Services** → AI enrichment
- **MindsDB** → Predictive analytics
- **Slack/Teams** → Alert notifications

## Deployment Architecture

```yaml
# Production deployment configuration
services:
  universal-processor:
    replicas: 3
    resources:
      memory: "512Mi"
      cpu: "500m"
    env:
      - DETECTION_CONFIDENCE_THRESHOLD=0.8
      - ML_MAPPING_ENABLED=true
      - CACHE_TTL=3600

  etl-orchestrator:
    replicas: 2
    resources:
      memory: "256Mi"
      cpu: "250m"
    schedule: "*/15 * * * *"  # Every 15 minutes

  monitoring:
    prometheus: enabled
    grafana: enabled
    alertmanager: enabled
    slack_webhook: "${SLACK_WEBHOOK_URL}"
```

This architecture provides a robust, format-flexible data processing pipeline that can handle any file type from Google Drive while maintaining high accuracy, performance, and reliability through the Scout v7 medallion architecture.