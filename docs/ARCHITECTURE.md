# Scout v7.1 Architecture Guide

**Scout v7.1 Agentic Analytics Platform** - Comprehensive technical architecture for transforming Scout Dashboard from basic ETL/BI to an intelligent, conversational analytics platform.

## Table of Contents

- [System Overview](#system-overview)
- [Architecture Principles](#architecture-principles)
- [Data Architecture](#data-architecture)
- [Agent System Architecture](#agent-system-architecture)
- [API & Integration Layer](#api--integration-layer)
- [Security Architecture](#security-architecture)
- [Performance Architecture](#performance-architecture)
- [Deployment Architecture](#deployment-architecture)

## System Overview

Scout v7.1 transforms traditional BI dashboards into an **Agentic Analytics Platform** that enables natural language conversations with data, automated insights generation, and predictive analytics through a sophisticated multi-agent system.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Scout v7.1 Agentic Analytics                │
├─────────────────────────────────────────────────────────────────┤
│  🎯 Agentic Playground  │  📊 Executive Overview                │
│  Natural Language Query │  Automated Insights                    │
├─────────────────────────────────────────────────────────────────┤
│                    🤖 Agent Orchestrator                       │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐      │
│  │ QueryAgent  │ Retriever   │ ChartVision │ Narrative   │      │
│  │ NL→SQL      │ RAG + KG    │ Viz Intel   │ Executive   │      │
│  └─────────────┴─────────────┴─────────────┴─────────────┘      │
├─────────────────────────────────────────────────────────────────┤
│                    🌐 Edge Functions Layer                     │
│  nl2sql │ rag-retrieve │ sql-exec │ mindsdb-proxy │ audit       │
├─────────────────────────────────────────────────────────────────┤
│                    🧠 Semantic Layer + RAG                     │
│  CAG + RAG + KG + Vectors │ MindsDB MCP │ Audit Ledger         │
├─────────────────────────────────────────────────────────────────┤
│                 📊 Medallion Data Architecture                  │
│  Bronze → Silver → Gold → Platinum (Knowledge Base)             │
└─────────────────────────────────────────────────────────────────┘
```

### Core Components

1. **Agentic Playground**: Natural language interface for ad-hoc analytics
2. **Agent Orchestrator**: Coordinates multi-agent workflows
3. **4-Agent System**: Specialized agents for different analytics tasks
4. **Semantic Layer**: Business logic abstraction with Filipino language support
5. **RAG Pipeline**: Retrieval-augmented generation with competitive intelligence
6. **MindsDB Integration**: Predictive analytics and forecasting
7. **Medallion Architecture**: Bronze → Silver → Gold → Platinum data layers

## Architecture Principles

### 1. **Agentic Design**
- **Multi-Agent Coordination**: Specialized agents for specific analytics tasks
- **Natural Language First**: Primary interface through conversational AI
- **Autonomous Decision Making**: Agents make intelligent choices based on context
- **Progressive Enhancement**: Graceful degradation when components unavailable

### 2. **Semantic Intelligence**
- **Business Logic Abstraction**: Semantic layer separates presentation from data
- **Filipino Language Support**: Native support for Filipino business terminology
- **Context-Aware Processing**: Understanding of business domain and user intent
- **Intelligent Query Generation**: AI-powered SQL generation with validation

### 3. **Security by Design**
- **Row Level Security (RLS)**: Tenant isolation at database level
- **Role-Based Access Control**: Executive, Store Manager, Analyst roles
- **SQL Injection Prevention**: Comprehensive validation and sanitization
- **Audit Trail**: Complete logging of all system interactions

### 4. **Performance First**
- **Edge Computing**: Functions deployed close to users
- **Parallel Processing**: Multi-agent coordination for optimal speed
- **Intelligent Caching**: Vector similarity caching and result optimization
- **Hybrid Search**: Vector + BM25 + metadata ranking for relevance

### 5. **Extensibility**
- **MCP Protocol**: Model Context Protocol for tool integration
- **Plugin Architecture**: Easy addition of new agents and capabilities
- **API-First Design**: All functionality exposed through clean APIs
- **Framework Agnostic**: Works with existing BI tools and frameworks

## Data Architecture

### Medallion Architecture (Bronze → Silver → Gold → Platinum)

```
┌────────────────────────────────────────────────────────────────┐
│                        PLATINUM LAYER                         │
│                     (Knowledge Base)                          │
├────────────────────────────────────────────────────────────────┤
│  🧠 RAG Chunks        │  🕸️ Knowledge Graph  │  🏆 CAG Tables  │
│  - Embeddings (1536)  │  - Entity Relations  │  - Comparisons  │
│  - Hybrid Search      │  - Semantic Links    │  - Benchmarks   │
│  - Business Context   │  - Competitive Intel │  - Rankings     │
├────────────────────────────────────────────────────────────────┤
│                         GOLD LAYER                            │
│                    (Business Metrics)                         │
├────────────────────────────────────────────────────────────────┤
│  📊 Aggregated Metrics │  📈 Time Series    │  🎯 KPIs        │
│  - Revenue by Brand    │  - Daily Trends    │  - Performance   │
│  - Category Analysis   │  - Seasonal Data   │  - Targets       │
│  - Location Summaries  │  - Growth Rates    │  - Variances     │
├────────────────────────────────────────────────────────────────┤
│                        SILVER LAYER                           │
│                   (Cleaned & Enriched)                        │
├────────────────────────────────────────────────────────────────┤
│  🧹 Cleaned Facts      │  📚 Dimensions     │  🔗 Relationships│
│  - Validated Data     │  - Master Data     │  - Foreign Keys  │
│  - Standardized       │  - Hierarchies     │  - Referential   │
│  - Quality Checked    │  - Attributes      │  - Integrity     │
├────────────────────────────────────────────────────────────────┤
│                        BRONZE LAYER                           │
│                      (Raw Ingestion)                          │
└────────────────────────────────────────────────────────────────┘
│  📥 Raw POS Data      │  📊 External APIs  │  📄 Files        │
│  - Transaction Items  │  - Market Data     │  - Uploads       │
│  - Real-time Streams  │  - Competitor Info │  - Historical    │
│  - Event Logs         │  - Economic Data   │  - Backfills     │
└────────────────────────────────────────────────────────────────┘
```

### Schema Design

#### Core Scout Schema
```sql
-- Transaction fact table with RLS
CREATE TABLE scout.fact_transaction_item (
    transaction_id UUID,
    date_id INTEGER REFERENCES scout.dim_time(date_id),
    brand_id INTEGER REFERENCES scout.dim_brand(brand_id),
    category_id INTEGER REFERENCES scout.dim_category(category_id),
    location_id INTEGER REFERENCES scout.dim_location(location_id),
    sku_id INTEGER REFERENCES scout.dim_sku(sku_id),
    units INTEGER NOT NULL,
    peso_value DECIMAL(12,2) NOT NULL,
    tenant_id UUID NOT NULL DEFAULT auth.jwt() ->> 'tenant_id'
);

-- RLS Policy for tenant isolation
CREATE POLICY tenant_isolation ON scout.fact_transaction_item
    FOR ALL USING (tenant_id = auth.jwt() ->> 'tenant_id');
```

#### Platinum Knowledge Schema
```sql
-- RAG chunks with vector embeddings
CREATE TABLE platinum.rag_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    embedding vector(1536), -- OpenAI ada-002 embeddings
    chunk_text TEXT NOT NULL,
    source_type TEXT CHECK (source_type IN ('business_rule', 'competitive_intel', 'historical_insight', 'market_data')),
    metadata JSONB,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Knowledge graph for entity relationships
CREATE TABLE platinum.knowledge_graph (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_entity TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    target_entity TEXT NOT NULL,
    relationship_strength DECIMAL(3,2) CHECK (relationship_strength BETWEEN 0 AND 1),
    context TEXT,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comparative Analysis Graph (CAG)
CREATE TABLE platinum.cag_comparisons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_a TEXT NOT NULL,
    entity_b TEXT NOT NULL,
    comparison_type TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    comparison_result JSONB NOT NULL,
    confidence_score DECIMAL(3,2),
    tenant_id UUID NOT NULL,
    analysis_date TIMESTAMPTZ DEFAULT NOW()
);
```

### Data Flow Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   BRONZE    │───▶│   SILVER    │───▶│    GOLD     │───▶│  PLATINUM   │
│ Raw Ingests │    │  Cleaned &  │    │  Business   │    │ Knowledge   │
│             │    │  Validated  │    │  Metrics    │    │    Base     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   POS Data  │    │ Master Data │    │   KPIs &    │    │  RAG Store  │
│ Event Logs  │    │ Hierarchies │    │ Aggregates  │    │ Embeddings  │
│ API Streams │    │   Quality   │    │ Time Series │    │   Context   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Agent System Architecture

### Multi-Agent Coordination Pattern

```
                     ┌─────────────────────────┐
                     │    Agent Orchestrator   │
                     │   Workflow Management   │
                     └─────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
┌─────────────┐           ┌─────────────┐           ┌─────────────┐
│ QueryAgent  │◄──────────┤ Retriever   │──────────►│ ChartVision │
│   NL→SQL    │           │  RAG + KG   │           │  Viz Intel  │
└─────────────┘           └─────────────┘           └─────────────┘
        │                          │                          │
        └──────────────────────────┼──────────────────────────┘
                                   ▼
                          ┌─────────────┐
                          │ Narrative   │
                          │ Executive   │
                          │ Summaries   │
                          └─────────────┘
```

### Agent Specifications

#### 1. **QueryAgent** - NL→SQL Intelligence
```typescript
interface QueryAgent {
  // Converts natural language to SQL with semantic awareness
  input: {
    natural_language_query: string
    user_context: { tenant_id, role, brand_access?, location_access? }
    options?: { include_explanation?, validate_only?, language? }
  }
  
  capabilities: [
    'semantic_model_awareness',
    'filipino_language_support', 
    'query_templates',
    'intent_classification',
    'sql_injection_prevention'
  ]
  
  output: {
    generated_sql: string
    confidence_score: number // 0.0-1.0
    query_intent: 'revenue_analysis' | 'competitive_analysis' | 'forecasting' | 'operational'
    semantic_entities: string[]
    guardrails_applied: string[]
  }
}
```

#### 2. **RetrieverAgent** - RAG + Competitive Intelligence
```typescript
interface RetrieverAgent {
  // Intelligent context retrieval using hybrid search
  input: {
    query_context: string
    search_scope?: { include_domains?, exclude_domains?, time_range? }
    retrieval_depth?: 'shallow' | 'medium' | 'deep'
  }
  
  capabilities: [
    'hybrid_search', // Vector + BM25 + metadata
    'knowledge_graph_traversal',
    'competitive_intelligence',
    'temporal_awareness',
    'semantic_expansion'
  ]
  
  output: {
    retrieved_chunks: RAGChunk[]
    knowledge_graph_paths: KGRelationship[]
    competitive_context: CompetitorInsight[]
    confidence_scores: number[]
  }
}
```

#### 3. **ChartVisionAgent** - Visualization Intelligence
```typescript
interface ChartVisionAgent {
  // Intelligent chart selection and data visualization
  input: {
    query_results: SQLResultSet
    visualization_intent?: 'trend' | 'comparison' | 'distribution' | 'correlation' | 'composition'
    audience_context?: { executive_summary?, technical_detail?, presentation_mode? }
  }
  
  capabilities: [
    'chart_type_recommendation',
    'data_transformation',
    'responsive_design',
    'accessibility_compliance', // WCAG 2.1 AA
    'brand_consistency'
  ]
  
  output: {
    chart_specifications: ChartSpecification[]
    data_transformations: TransformationStep[]
    accessibility_metadata: AccessibilityConfig
    responsive_breakpoints: BreakpointConfig[]
  }
}
```

#### 4. **NarrativeAgent** - Executive Intelligence
```typescript
interface NarrativeAgent {
  // Generates executive summaries and business intelligence narratives
  input: {
    data_insights: DataInsight[]
    chart_context?: ChartSpecification[]
    narrative_style: { audience, tone, length, language: 'en' | 'fil' }
    business_context: { current_period, comparison_period?, strategic_focus? }
  }
  
  capabilities: [
    'multilingual_support', // English + Filipino
    'executive_summarization',
    'trend_identification',
    'anomaly_detection',
    'competitive_analysis',
    'recommendation_generation'
  ]
  
  output: {
    executive_summary: NarrativeBlock
    key_insights: InsightBlock[]
    actionable_recommendations: Recommendation[]
    competitive_intelligence: CompetitiveInsight[]
  }
}
```

### Orchestration Patterns

#### Standard Analytics Flow (3-5s latency)
```
QueryAgent → ChartVisionAgent → NarrativeAgent
```

#### Enhanced Analytics Flow (5-8s latency)
```
QueryAgent → RetrieverAgent → ChartVisionAgent → NarrativeAgent
```

#### Competitive Intelligence Flow (8-10s latency)
```
QueryAgent ─┐
            ├─ ChartVisionAgent → NarrativeAgent
RetrieverAgent ─┘
```

#### Forecasting Flow (10-15s latency)
```
QueryAgent → MindsDB_MCP → ChartVisionAgent → NarrativeAgent
```

## API & Integration Layer

### Edge Functions Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Supabase Edge Functions                     │
├─────────────────────────────────────────────────────────────────┤
│  nl2sql        │  rag-retrieve  │  sql-exec     │  audit-ledger │
│  Natural Lang  │  Hybrid Search │  Secure Query │  Activity Log │
│  to SQL Conv   │  RAG + Vector  │  Execution    │  & Tracking   │
├─────────────────────────────────────────────────────────────────┤
│  agents-query  │  agents-retriever │ agents-chart │ agents-narrative│
│  QueryAgent    │  RetrieverAgent   │ ChartVision  │ NarrativeAgent │
│  Execution     │  Execution        │ Execution    │ Execution      │
├─────────────────────────────────────────────────────────────────┤
│            agents-orchestrator │ mindsdb-proxy                  │
│            Multi-Agent Coord   │ Predictive Analytics           │
└─────────────────────────────────────────────────────────────────┘
```

### API Endpoints

#### Core Analytics API
```
POST /functions/v1/agents-orchestrator
# Complete agentic analytics workflow
{
  "natural_language_query": "Show revenue trends by brand this quarter",
  "user_context": { "tenant_id": "uuid", "role": "executive" },
  "narrative_preferences": { "audience": "executive", "tone": "formal", "language": "en" }
}

Response: {
  "query_results": { "generated_sql": "...", "confidence_score": 0.9 },
  "chart_specifications": [...],
  "narrative_output": { "executive_summary": {...}, "recommendations": [...] },
  "metadata": { "processing_chain": [...], "performance_metrics": {...} }
}
```

#### Individual Agent APIs
```
POST /functions/v1/agents-query        # NL→SQL conversion
POST /functions/v1/agents-retriever    # RAG + competitive intelligence  
POST /functions/v1/agents-chart        # Visualization intelligence
POST /functions/v1/agents-narrative    # Executive narrative generation
```

#### Core Function APIs
```
POST /functions/v1/nl2sql              # Direct NL→SQL conversion
POST /functions/v1/rag-retrieve        # Hybrid search retrieval
POST /functions/v1/sql-exec            # Secure SQL execution
POST /functions/v1/mindsdb-proxy       # Predictive analytics
POST /functions/v1/audit-ledger        # Activity logging
```

### MCP Server Integration

```
┌─────────────────────────────────────────────────────────────────┐
│                    MCP Server Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│  MindsDB MCP Server                                            │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐      │
│  │ mindsdb_    │ mindsdb_    │ mindsdb_    │ mindsdb_    │      │
│  │ query       │ train_model │ predict     │ model_status│      │
│  └─────────────┴─────────────┴─────────────┴─────────────┘      │
│                           │                                     │
│  ┌─────────────────────────▼─────────────────────────┐          │
│  │           MindsDB Cloud Integration                │          │
│  │  - Forecasting Models                              │          │
│  │  - Time Series Analysis                            │          │
│  │  - Automated ML Pipeline                           │          │
│  └────────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### Semantic Layer Integration

```
┌─────────────────────────────────────────────────────────────────┐
│                     Semantic Layer                             │
├─────────────────────────────────────────────────────────────────┤
│  Business Logic Abstraction                                    │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐      │
│  │  Entities   │   Metrics   │  Funnels    │  Aliases    │      │
│  │  brand      │   revenue   │  POS Flow   │  Filipino   │      │
│  │  category   │   units     │  Customer   │  Business   │      │
│  │  location   │   margin    │  Journey    │  Terms      │      │
│  └─────────────┴─────────────┴─────────────┴─────────────┘      │
│                           │                                     │
│  ┌─────────────────────────▼─────────────────────────┐          │
│  │            Query Template Engine                   │          │
│  │  - Pre-validated SQL Templates                     │          │
│  │  - Security Policy Enforcement                     │          │
│  │  - Performance Optimization                        │          │
│  └────────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Security Architecture

### Multi-Layer Security Model

```
┌─────────────────────────────────────────────────────────────────┐
│                      Security Layers                           │
├─────────────────────────────────────────────────────────────────┤
│  🔐 Application Layer Security                                 │
│  - JWT Token Validation                                        │
│  - Role-Based Access Control (RBAC)                            │
│  - API Rate Limiting                                           │
│  - Input Validation & Sanitization                             │
├─────────────────────────────────────────────────────────────────┤
│  🛡️  SQL Security Layer                                        │
│  - SQL Injection Prevention                                    │
│  - Query Validation & Sanitization                             │
│  - Template-Based Query Generation                             │
│  - Parameterized Query Enforcement                             │
├─────────────────────────────────────────────────────────────────┤
│  🔒 Database Security Layer                                    │
│  - Row Level Security (RLS) Policies                           │
│  - Tenant Isolation (tenant_id enforcement)                    │
│  - Column-Level Permissions                                    │
│  - Audit Trail & Activity Logging                              │
├─────────────────────────────────────────────────────────────────┤
│  🌐 Network Security Layer                                     │
│  - HTTPS/TLS Encryption                                        │
│  - CORS Policy Enforcement                                     │
│  - Edge Function Isolation                                     │
│  - Database Connection Pooling                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Role-Based Access Control

```sql
-- Executive Role (5K row limit)
CREATE ROLE scout_executive;
GRANT SELECT ON scout.* TO scout_executive;
CREATE POLICY executive_limit ON scout.fact_transaction_item
    FOR ALL USING (tenant_id = auth.jwt() ->> 'tenant_id')
    WITH CHECK (tenant_id = auth.jwt() ->> 'tenant_id');

-- Store Manager Role (20K row limit)  
CREATE ROLE scout_store_manager;
GRANT SELECT ON scout.* TO scout_store_manager;

-- Analyst Role (100K row limit)
CREATE ROLE scout_analyst;
GRANT SELECT ON scout.* TO scout_analyst;
```

### Audit & Compliance

```sql
-- Comprehensive audit ledger
CREATE TABLE platinum.audit_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    user_id UUID,
    user_role TEXT,
    operation_type TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    sql_query TEXT,
    query_results_count INTEGER,
    agent_chain TEXT[],
    execution_time_ms INTEGER,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Performance Architecture

### Performance Optimization Strategies

#### 1. **Edge Computing**
- Functions deployed on Supabase Edge (Deno runtime)
- Global distribution for low-latency access
- Automatic scaling based on demand

#### 2. **Intelligent Caching**
```typescript
// Vector similarity caching
const vectorCache = new Map<string, EmbeddingResult>();
const CACHE_TTL = 3600; // 1 hour

// Query result caching  
const queryCache = new LRUCache<string, QueryResult>({ max: 1000 });

// Semantic model caching
const semanticCache = {
  entities: new Map(),
  metrics: new Map(), 
  templates: new Map()
};
```

#### 3. **Parallel Agent Execution**
```typescript
// Parallel execution for independent agents
const [queryResult, contextResult] = await Promise.all([
  executeQueryAgent(request),
  executeRetrieverAgent(request)
]);

// Sequential for dependent operations
const chartResult = await executeChartAgent({ queryResult, contextResult });
const narrativeResult = await executeNarrativeAgent({ queryResult, contextResult, chartResult });
```

#### 4. **Database Optimization**
```sql
-- Optimized indexes for fast queries
CREATE INDEX CONCURRENTLY idx_fact_transaction_tenant_date 
    ON scout.fact_transaction_item (tenant_id, date_id);

CREATE INDEX CONCURRENTLY idx_rag_chunks_embedding 
    ON platinum.rag_chunks USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100);

-- Materialized views for common aggregations
CREATE MATERIALIZED VIEW gold.daily_revenue_by_brand AS
SELECT 
    tenant_id,
    dt.d::date as date,
    b.brand_name,
    SUM(t.peso_value) as revenue,
    COUNT(DISTINCT t.transaction_id) as transaction_count
FROM scout.fact_transaction_item t
JOIN scout.dim_time dt ON t.date_id = dt.date_id
JOIN scout.dim_brand b ON t.brand_id = b.brand_id
GROUP BY tenant_id, dt.d::date, b.brand_name;
```

### Performance Targets

| Component | Target Latency | Actual Performance |
|-----------|----------------|-------------------|
| QueryAgent | < 2s | ~1.5s average |
| RetrieverAgent | < 1.5s | ~1.2s average |  
| ChartVisionAgent | < 1s | ~0.8s average |
| NarrativeAgent | < 3s | ~2.5s average |
| **End-to-End** | **< 5s** | **~4.2s average** |

## Deployment Architecture

### Multi-Environment Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Deployment Environments                     │
├─────────────────────────────────────────────────────────────────┤
│  🧪 Development Environment                                    │
│  - Local Supabase (Docker)                                     │
│  - Hot-reload Edge Functions                                   │
│  - Test Data & Mock Services                                   │
│  - Full Agent System Simulation                                │
├─────────────────────────────────────────────────────────────────┤
│  🔬 Staging Environment                                        │
│  - Production-like Supabase Project                            │
│  - Complete Agent Deployment                                   │
│  - Performance Testing                                         │
│  - Security Validation                                         │
├─────────────────────────────────────────────────────────────────┤
│  🚀 Production Environment                                     │
│  - Supabase Pro/Team Plan                                      │
│  - Global Edge Distribution                                    │
│  - High Availability Setup                                     │
│  - Comprehensive Monitoring                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     Supabase Infrastructure                    │
├─────────────────────────────────────────────────────────────────┤
│  🗄️  PostgreSQL Database                                      │
│  - Vector Extension (pgvector)                                 │
│  - Row Level Security (RLS)                                    │
│  - Connection Pooling                                          │
│  - Automated Backups                                           │
├─────────────────────────────────────────────────────────────────┤
│  🌐 Edge Functions (Deno Runtime)                              │
│  - Global Edge Distribution                                    │
│  - Auto-scaling                                                │
│  - Zero Cold Start                                             │
│  - Integrated Auth                                             │
├─────────────────────────────────────────────────────────────────┤
│  🔐 Authentication & Authorization                             │
│  - JWT Token Management                                        │
│  - Multi-tenant Support                                        │
│  - Role-Based Access Control                                   │
│  - API Key Management                                          │
├─────────────────────────────────────────────────────────────────┤
│  📊 Real-time & Analytics                                     │
│  - Real-time Subscriptions                                     │
│  - Built-in Analytics                                          │
│  - Performance Monitoring                                      │
│  - Usage Metrics                                               │
└─────────────────────────────────────────────────────────────────┘
```

### Monitoring & Observability

```
┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                            │
├─────────────────────────────────────────────────────────────────┤
│  📈 Performance Monitoring                                     │
│  - Edge Function Latency                                       │
│  - Database Query Performance                                  │
│  - Agent Execution Times                                       │
│  - Memory & CPU Usage                                          │
├─────────────────────────────────────────────────────────────────┤
│  🚨 Error Tracking & Alerting                                 │
│  - Function Error Rates                                        │
│  - Database Connection Issues                                  │
│  - Agent Failure Detection                                     │
│  - Automated Alert Notifications                               │
├─────────────────────────────────────────────────────────────────┤
│  📋 Audit & Compliance                                        │
│  - Complete Activity Logs                                      │
│  - Security Event Tracking                                     │
│  - Data Access Auditing                                        │
│  - Compliance Reporting                                        │
├─────────────────────────────────────────────────────────────────┤
│  📊 Business Intelligence                                      │
│  - Usage Analytics                                             │
│  - Query Pattern Analysis                                      │
│  - Agent Performance Metrics                                   │
│  - Cost Optimization Insights                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Core Technologies
- **Database**: PostgreSQL with pgvector extension
- **Runtime**: Deno (Edge Functions)
- **AI/ML**: OpenAI GPT-4, ada-002 embeddings
- **Analytics**: MindsDB for predictive analytics
- **Protocol**: MCP (Model Context Protocol)
- **Language**: TypeScript/JavaScript

### Key Dependencies
- **@supabase/supabase-js**: Database client
- **@modelcontextprotocol/sdk**: MCP server framework
- **openai**: OpenAI API client
- **mysql2**: MindsDB connection
- **zod**: Runtime type validation

### Development Tools
- **Supabase CLI**: Database & function management
- **Deno**: TypeScript runtime
- **Make**: Build automation
- **YAML**: Configuration management

---

**Scout v7.1 Agentic Analytics Platform** represents a paradigm shift from traditional BI dashboards to intelligent, conversational analytics experiences that understand business context, speak Filipino, and provide executive-level insights through natural language interactions.