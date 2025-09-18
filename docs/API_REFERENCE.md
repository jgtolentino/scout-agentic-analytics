# 📡 Scout v7 API Reference
*Complete Edge Functions, Database Operations & MCP Integration Guide*

## 🚀 Quick Navigation

**Edge Functions** → [Analytics](#-analytics-functions) | [Data Processing](#-data-processing) | [AI/ML](#-aiml-functions)
**Database** → [Schemas](#-database-schemas) | [Functions](#-database-functions)
**Authentication** → [JWT](#-authentication) | [Permissions](#-permissions)

---

## 🧠 Analytics Functions

### NL2SQL Engine
**Endpoint**: `/functions/v1/nl2sql`
**Method**: `POST`
**Purpose**: Convert natural language to SQL queries with cross-tab analytics

#### Request Schema
```typescript
interface NL2SQLRequest {
  question?: string          // Natural language query
  plan?: {                  // Or direct execution plan
    intent: 'aggregate' | 'crosstab'
    rows: string[]          // Max 2 dimensions
    cols: string[]          // Max 1 dimension
    measures: Array<{metric: string}>
    filters?: {
      date_from?: string    // ISO date
      date_to?: string      // ISO date
      brand_in?: string[]   // Brand filter
      category_in?: string[] // Category filter
      is_weekend?: boolean  // Weekend filter
    }
    pivot?: boolean         // Enable pivoting
    limit?: number          // 1-10000 records
  }
}
```

#### Response Schema
```typescript
interface NL2SQLResponse {
  plan: ValidatedPlan       // Execution plan used
  sql: string              // Generated SQL (safe)
  rows: any[]             // Query results
  cache_hit: boolean      // Cache performance
  processing_time_ms: number
}
```

#### Example Usage
```bash
curl -X POST https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/nl2sql \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Show revenue by brand and category last 30 days"
  }'
```

---

## 🔄 Data Processing Functions

### Universal Format Processor
**Endpoint**: `/functions/v1/drive-universal-processor`
**Method**: `POST`
**Purpose**: Format-flexible data ingestion (CSV, JSON, Excel, TSV, XML)

#### Request Schema (Multipart)
```typescript
// Form data upload
const formData = new FormData()
formData.append('file', fileBlob)
formData.append('options', JSON.stringify({
  fileId: 'unique-file-id',
  forceFormat?: 'csv' | 'json' | 'excel' | 'tsv' | 'xml',
  sheetName?: string,     // For Excel files
  delimiter?: string,     // For CSV/TSV
  skipRows?: number,
  maxRows?: number
}))
```

#### Response Schema
```typescript
interface ProcessingResponse {
  success: boolean
  fileId: string
  fileName: string
  processing: {
    format: {
      detectedFormat: string    // 'csv' | 'json' | 'excel' | etc.
      confidence: number        // 0.0-1.0
      mimeType: string
      hasHeaders: boolean
      delimiter?: string
      encoding: string
      sheetNames?: string[]     // For Excel
      sampleData: any[]
    }
    schema: {
      columns: Array<{
        name: string
        type: 'string' | 'number' | 'boolean' | 'date' | 'json'
        nullable: boolean
        unique: boolean
        examples: any[]
      }>
      totalRows: number
      qualityScore: number      // 0.0-1.0
      issues: string[]
    }
    mapping: {
      original_schema: object
      column_mappings: Array<{
        source: string
        target: string
        confidence: number
      }>
      mapping_confidence: number
    }
    records_processed: number
    processing_time_ms: number
  }
}
```

---

## 🤖 AI/ML Functions

### Brand Intelligence
**Endpoint**: `/functions/v1/brand-intelligence`
**Method**: `POST`
**Purpose**: Automated brand detection and categorization

#### Request Schema
```typescript
interface BrandIntelligenceRequest {
  productName: string
  description?: string
  category?: string
  sku?: string
  confidence_threshold?: number  // Default: 0.8
}
```

#### Response Schema
```typescript
interface BrandIntelligenceResponse {
  detected_brand: string
  confidence: number
  category_suggested: string
  reasoning: string[]
  alternatives: Array<{
    brand: string
    confidence: number
  }>
}
```

---

## 💾 Database Schemas

### Bronze Layer (Raw Data)
```sql
-- Scout Edge transactions
bronze.scout_raw_transactions {
  transaction_id: UUID PRIMARY KEY
  store_id: TEXT NOT NULL
  device_id: TEXT NOT NULL
  transaction_timestamp: TIMESTAMPTZ
  items: JSONB NOT NULL
  detected_brands: JSONB
  processing_metadata: JSONB
  ingested_at: TIMESTAMPTZ DEFAULT NOW()
}

-- Universal file ingestion
staging.universal_file_ingestion {
  id: UUID PRIMARY KEY
  file_id: TEXT NOT NULL
  file_name: TEXT NOT NULL
  file_format: TEXT CHECK (file_format IN ('json','csv','excel','tsv','xml','parquet'))
  detection_confidence: DECIMAL(3,2)
  schema_inference: JSONB NOT NULL
  column_mappings: JSONB
  raw_data: JSONB NOT NULL
  total_records: INTEGER
  processing_metadata: JSONB NOT NULL
  status: TEXT DEFAULT 'ingested'
  created_at: TIMESTAMPTZ DEFAULT NOW()
}
```

### Silver Layer (Cleaned Data)
```sql
-- Unified transactions
silver.transactions_cleaned {
  id: UUID PRIMARY KEY
  timestamp: TIMESTAMPTZ NOT NULL
  amount: DECIMAL(10,2)
  payment_method: TEXT
  product_category: TEXT
  brand_name: TEXT
  sku: TEXT
  customer_id: TEXT
  store_id: TEXT
  age_bracket: TEXT
  gender: TEXT
  location_data: JSONB
  data_source: TEXT -- 'drive'|'edge'|'azure'
  quality_score: DECIMAL(3,2)
  loaded_at: TIMESTAMPTZ DEFAULT NOW()
}
```

### Gold Layer (Analytics)
```sql
-- Business KPIs
scout.scout_gold_transactions {
  id: BIGINT PRIMARY KEY
  transaction_date: DATE NOT NULL
  brand_name: TEXT
  product_category: TEXT
  store_id: TEXT
  revenue_peso: DECIMAL(12,2)
  transaction_count: INTEGER
  unique_customers: INTEGER
  avg_basket_size: DECIMAL(8,2)
  created_at: TIMESTAMPTZ DEFAULT NOW()
}
```

---

## 🔄 Database Functions

### Analytics Functions
```sql
-- Safe SQL executor for NL2SQL
SELECT analytics.exec_readonly_sql(
  'SELECT brand_name, SUM(peso_value) FROM silver.transactions_cleaned GROUP BY brand_name',
  '{}'::text[]
);

-- Cache operations
SELECT mkt.cache_get('query_hash_123');
SELECT mkt.cache_put('query_hash_123', '{"results": [...]}', 300);
```

### ETL Functions
```sql
-- Quality scoring
SELECT bronze.calculate_scout_edge_quality_score(
  '{"items": [...]}',
  '{"alaska": {...}}',
  ARRAY['stt', 'ocr', 'nlp'],
  'audio transcript text'
);

-- Brand extraction
SELECT bronze.extract_scout_edge_brands('{"alaska": {"confidence": 0.95}}');
```

---

## 🔐 Authentication

### JWT Token Structure
```typescript
interface JWTPayload {
  aud: 'authenticated'
  exp: number          // Expiry timestamp
  iat: number          // Issued at
  iss: 'supabase'
  sub: string          // User ID
  email?: string
  role: 'authenticated' | 'service_role'
}
```

### Row Level Security (RLS)
```sql
-- Example: Users can only see their own data
CREATE POLICY user_data_access
  ON scout.user_analytics
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid());
```

---

## ⚡ Performance & Caching

### Response Times
| Function | Target | P95 | Cache TTL |
|----------|--------|-----|-----------|
| `nl2sql` | <200ms | <500ms | 300s |
| `universal-processor` | <2s | <5s | 0s |
| `brand-intelligence` | <100ms | <200ms | 3600s |

### Rate Limits
| Tier | Requests/Hour | Burst |
|------|---------------|-------|
| **Anonymous** | 1,000 | 100 |
| **Authenticated** | 10,000 | 500 |
| **Service Role** | Unlimited | 1,000 |

---

## 🔧 SDK Examples

### TypeScript SDK
```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// NL2SQL query
const { data, error } = await supabase.functions.invoke('nl2sql', {
  body: { question: 'Show top 10 brands by revenue this month' }
})

// File processing
const formData = new FormData()
formData.append('file', file)
formData.append('options', JSON.stringify({ fileId: 'unique-id' }))

const { data: processed } = await supabase.functions.invoke('drive-universal-processor', {
  body: formData
})
```

### cURL Examples
```bash
# Natural language analytics
curl -X POST $SUPABASE_URL/functions/v1/nl2sql \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question": "Top performing categories this quarter"}'

# File upload processing
curl -X POST $SUPABASE_URL/functions/v1/drive-universal-processor \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -F "file=@data.csv" \
  -F 'options={"fileId":"csv_001","delimiter":","}'
```

---

## 📚 Additional Resources

- **[Edge Functions Guide](EDGE_FUNCTIONS_GUIDE.md)** → Detailed function documentation
- **[Database Schema](../supabase/MEDALLION_ARCHITECTURE.md)** → Complete schema reference
- **[ETL Pipeline](ETL_Data_Flow_Architecture.md)** → Data processing workflows
- **[Monitoring](MONITORING.md)** → Observability and alerting
- **[SuperClaude Integration](../CLAUDE.md)** → MCP server configuration

---

*Last Updated: 2025-09-17 | Scout v7.1 API Reference | SuperClaude Framework v3.0*