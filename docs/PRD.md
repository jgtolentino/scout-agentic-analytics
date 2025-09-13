# 📋 Scout Dashboard v7.1 — Product Requirements Document (PRD)

## 1. Executive Summary

Scout Dashboard is a **multi-layer retail intelligence and agentic analytics platform** designed for sari-sari stores, FMCG brands, and executives. It integrates POS transaction funnels, SKU substitution signals, consumer profiling, competitive benchmarking, and **AI-driven ad-hoc analysis** capabilities. The system is powered by a **semantic layer** (CAG + RAG + KG + vectors), **platinum-layer market intelligence**, and **autonomous AI agents** for natural language querying and dynamic visualization generation.

---

## 2. Goals & Objectives

### 2.1 Core Analytics Platform
- Provide **end-to-end analytics** for transactions, product mix, consumer signals, and competitive intelligence
- Support **multi-cohort comparisons** (brands, categories, time, locations)
- Implement **8 core navigation sections** with collapsible sidebar
- Deliver **scalability** from individual sari-sari stores to regional/national aggregates

### 2.2 Agentic Analytics Capabilities
- Enable **natural language querying** with automatic SQL generation
- Provide **dynamic chart creation** through AI agents
- Support **ad-hoc exploration** beyond predefined dashboards
- Integrate **predictive analytics** via MindsDB ML models

---

## 3. Core Modules & Navigation

### 3.1 Collapsible Left Sidebar
**8 Core Sections** with icons + labels:
- 🏠 Executive Overview
- 📈 Transaction Trends
- 📦 Product Mix & SKU Info
- 👥 Consumer Behavior & Preference Signals
- 🧑 Consumer Profiling
- ⚔️ Competitive Analysis
- 🌍 Geographic Intelligence
- 🤖 Agentic Playground (NEW)

### 3.2 Executive Overview
- **KPI Row**: Revenue, Units, Tx Count, Avg Basket + delta vs previous period
- **Time-series Trends**: WoW/MoM/YoY analysis
- **AI Insight Panel**: Autonomous anomaly detection, opportunities, risks

### 3.3 Transaction Trends
- **Time-series Analysis**: Daily/weekly/monthly granularity
- **Delta Comparisons**: Period-over-period analysis
- **Cohort Trends**: Multi-brand/category comparison

### 3.4 Product Mix & SKU Info
- **SKU Distribution**: By brand/category with substitution flows
- **Basket Composition**: Cross-sell insights and recommendations
- **Sankey Flows**: Visual substitution patterns

### 3.5 Consumer Behavior & Preference Signals
- **POS Funnel**: Walk-in → Request → Counter Offer → Acceptance → Basket
- **Behavioral Heatmaps**: Time-of-day and weekday/weekend patterns
- **Brand Switching**: Substitution acceptance signals

### 3.6 Consumer Profiling
- **Demographics**: Age, gender distribution
- **Persona Clusters**: Juan, Maria, Carlo, Lola Rosa personas
- **RFM Analysis**: Frequency, recency, monetary value

### 3.7 Competitive Analysis
- **Multi-Cohort Comparison**: Brand A vs Brand B vs Market
- **Market Share Trends**: Share of wallet over time
- **Battlecards**: AI-generated competitive intelligence
- **Substitution Rates**: Cross-brand acceptance analysis

### 3.8 Geographic Intelligence
- **Choropleth Maps**: Region → City → Barangay drill-down
- **Market Penetration**: Geographic coverage analysis
- **Performance Tables**: Top/bottom locations with sparklines

### 3.9 Agentic Playground (NEW)
- **Natural Language Interface**: "Compare Alaska vs Oishi basket mix in NCR Q2"
- **Dynamic Chart Generation**: Auto-create visualizations on demand
- **Ad-hoc SQL**: AI-generated queries with safety guardrails
- **Chart Pinning**: Save generated insights to dashboard

---

## 4. Global Features

### 4.1 Cascading Filters
- **Hierarchical Selection**: Brand → Category → SKU, Region → City → Barangay
- **Multi-Cohort Support**: A/B/N comparison framework
- **Temporal Deltas**: WoW/MoM/YoY with automatic date handling
- **Context Inheritance**: All agents respect active filters

### 4.2 Floating AI Assistant
- **Context-Aware**: Inherits current filters, cohorts, and page context
- **Role-Aware**: Executive vs Store Manager vs Analyst personas
- **Domain-Aware**: Scout (retail), CES (creative), Docs (knowledge)
- **Capabilities**:
  - Explain charts in natural language
  - Generate brand/category comparisons
  - Summarize consumer behavior funnels
  - Provide market intelligence insights

---

## 5. Data Architecture

### 5.1 Medallion Architecture
- **Bronze**: Raw POS transactions, brand/SKU ingestion
- **Silver**: Cleaned tables, normalized dimensions
- **Gold**: Aggregated analytics, funnel views, cohort metrics
- **Platinum**: Market-level enrichment via cron Edge Functions

### 5.2 POS Transaction Funnel
```
Walk-in Traffic → Customer Request → Counter Offer → Acceptance/Decline → Basket Completion
     ↓               ↓                    ↓                ↓                    ↓
  foot_traffic    ask_events        offer_events      accept_events      basket_events
```

### 5.3 Key Tables
**Dimensions**:
- `dim_brand`, `dim_category`, `dim_sku`, `dim_time`, `dim_location`

**Facts**:
- `fact_transaction_item` (base transactions)
- `fact_funnel_stages` (ask/offer/accept/basket events)

**Gold Views**:
- `gold.funnel_view` (conversion metrics by stage)
- `gold.cohort_metrics` (multi-brand/category KPIs)
- `gold.substitution_flows` (brand switching patterns)

**Platinum Intelligence**:
- `platinum.market_intel` (external competitor signals)
- `platinum.rag_chunks` (vector embeddings for semantic search)
- `platinum.kg_entities` (knowledge graph entities and relationships)

### 5.4 Core RPCs & Functions
- `fn_filter_options(_filters)` → cascading dimension values
- `fn_cohort_metrics(_cohorts, _metric, _granularity)` → comparative KPIs
- `fn_funnel_metrics(_filters)` → POS funnel conversion rates
- `fn_rag_semantic_search(_query, _threshold)` → vector similarity search
- `fn_market_enrichment()` → platinum layer updates

---

## 6. Semantic & AI Layer

### 6.1 Semantic Model (`semantic/model.yaml`)
**Entities**: brand, category, SKU, location, date with primary keys and labels
**Metrics**: revenue, units, tx_count, avg_basket with SQL definitions and grain
**Funnels**: POS funnel stages with source views
**Aliases**: Synonym mapping ("yosi" → cigarettes, "sari-sari" → convenience store)
**Policies**: RLS enforcement and tenant scoping

### 6.2 Agentic Components
**CAG (Comparative Analysis Graph)**: Brand-to-brand substitution edges with weights
**RAG (Retrieval Augmented Generation)**: Vector + BM25 + metadata hybrid search
**KG (Knowledge Graph)**: Hierarchical taxonomy (brand → category → SKU)
**Vector Store**: Embedding-based similarity for colloquial queries

### 6.3 AI Agent Orchestra
**QueryAgent**: NL → SQL translation with semantic model awareness
**ChartVisionAgent**: SQL results → chart specifications (Recharts/Vega/Plotly)
**RetrieverAgent**: RAG pipeline orchestration and context assembly
**NarrativeAgent**: Insight summarization with role-aware language

### 6.4 MindsDB Integration
**MCP Server**: Tools for query, train, deploy, predict operations
**Edge Functions**: Cron-scheduled ML model updates and predictions
**NL→SQL Delegation**: Automatic handoff for forecast intents

### 6.5 Context & Enforcement (Normative)
- **Context Propagation**: All RPCs and Edge Functions accept a `Context` envelope:
  `{ filters, cohorts?, role, domain, tenant_id }`. Server code MUST derive `tenant_id` from JWT where available and ignore conflicting client values.
- **RLS First**: Views/functions NEVER rely solely on client filters; `tenant_id` is enforced in SQL via RLS and checked in executor wrappers.
- **Role Limits**:
  - Executive: LIMIT 5000 rows, only `gold_*` and `dim_*` views.
  - Store Manager: LIMIT 20000 rows, location-scoped, no PII columns.
  - Analyst: LIMIT 100000 rows with `reason` flag; access to `gold_*`, `dim_*`, and approved `fact_*` projections.

---

## 7. Security & Governance

### 7.1 Row Level Security (RLS)
- **Tenant Isolation**: `auth.jwt() ->> 'tenant_id'` enforcement
- **Role-Based Access**: Executive/Analyst/Store Manager permissions
- **Data Scoping**: Store/chain/brand level access controls

### 7.2 Query Guardrails
- **SQL Validation**: Whitelist approved schemas (scout.gold_*, scout.dim_*)
- **Injection Prevention**: Parameterized queries only
- **Resource Limits**: Query timeouts and row limits by role
- **Audit Logging**: All generated queries and chart creations logged

### 7.3 AI Safety
- **Prompt Constraints**: Template-based generation with validation
- **Credential Isolation**: Bruno environment injection (no hardcoded secrets)
- **Output Sanitization**: Chart specs validated before rendering

### 7.4 Data Governance
- **PII Policy**: RAG chunks are anonymized; no customer names, phone numbers, or addresses in embeddings
- **Embedding Refresh**: Weekly vector refresh at @03:00 PHT; stale embeddings flagged after 14 days
- **Delete Propagation**: GDPR-style deletion cascades through `platinum.rag_chunks` within 72 hours

---

## 8. User Roles & Personas

### 8.1 Executive
- **Access**: Market share, deltas, competitive dashboards
- **Language**: Executive summaries, trend explanations
- **Limits**: 5K row queries, pre-aggregated views

### 8.2 Store Manager
- **Access**: SKU substitution, inventory risk, in-store funnel
- **Language**: Operational recommendations, actionable insights
- **Limits**: Location-scoped data only

### 8.3 Analyst
- **Access**: Granular data exports, deep drilldowns, custom SQL
- **Language**: Technical details, statistical insights
- **Limits**: 100K row queries with justification

---

## 9. Technical Architecture

### 9.1 Frontend Stack
- **Framework**: Next.js with TypeScript
- **UI Components**: Tailwind CSS + Headless UI
- **State Management**: Zustand for filter bus and global state
- **Charts**: Recharts primary, Vega-Lite for complex visualizations
- **Maps**: Mapbox for choropleth and geographic intelligence

### 9.2 Backend Infrastructure
- **Database**: Supabase (PostgreSQL) with pgvector extension
- **Functions**: Supabase Edge Functions (Deno runtime)
- **Authentication**: Supabase Auth with RLS
- **AI/ML**: MindsDB for predictive models
- **Agent Orchestration**: Pulser/Bruno runtime

### 9.3 Deployment Pipeline
- **Frontend**: Vercel with preview deployments
- **Database**: Supabase cloud with automated backups
- **CI/CD**: GitHub Actions with security gates
- **Monitoring**: Built-in observability and health checks

---

## 10. API Contracts

### 10.1 REST API (PostgREST)
- All gold views accessible via `/rest/v1/`
- RPC functions callable via `/rest/v1/rpc/`
- Real-time subscriptions for live updates

### 10.2 Edge Functions
- `nl2sql`: Natural language to SQL translation
- `sql_exec`: Secure SQL execution with validation
- `rag_retrieve`: Hybrid semantic search
- `scout_ai`: Assistant orchestrator endpoint
- `mindsdb_proxy`: ML model integration
- `platinum_refresh`: Market intelligence updates (cron)
- `audit_ledger`: Append-only log of NL→SQL → execution mappings and rowcounts

### 10.3 Context Contract
```json
{
  "filters": {
    "brand_ids": [], "category_ids": [], "location_ids": [],
    "date_from": null, "date_to": null, "granularity": "week"
  },
  "cohorts": [{"key": "A", "name": "Cohort A", "filters": {...}}],
  "role": "executive|analyst|store_manager",
  "domain": "scout|ces|docs",
  "tenant_id": "string"
}
```

### 10.4 Metric Registry (Normative)
| Metric       | SQL                                  | Grain                      | Rounding | Null rule |
|--------------|---------------------------------------|----------------------------|----------|-----------|
| revenue      | `sum(peso_value)`                     | date, brand, category, geo | 2 dp     | treat null=0 |
| units        | `sum(qty)`                            | date, brand, category, geo | int      | 0         |
| tx_count     | `count(distinct tx_id)`               | date, geo                  | int      | 0         |
| avg_basket   | `sum(peso_value)/nullif(count(distinct tx_id),0)` | date, geo | 2 dp | show "—" if denom=0 |

Allowed cuts: {brand, category, sku?, region/city/barangay, cohort}. Prohibit mixing SKU with brand unless SKU→brand is unique for the slice.

### 10.5 NL→SQL Guardrails
**Whitelist**: `scout.gold_*`, `scout.dim_*`, `scout.v_*_public`.  
**Query rules**: must include date range; no `SELECT *`; joins require keys; `CROSS JOIN` forbidden; `GROUP BY` keys must match selected dims.  
**Execution**: generation and execution are separate endpoints; the executor injects tenant filter + LIMIT based on role, and writes to `audit_ledger`.

### 10.6 Forecast Delegation
Intent classifier delegates to MindsDB when `(keyword in ["forecast","predict","projection"]) OR (intent_score ≥ 0.8)`.  
Fallback: SQL seasonal naïve (last-year-same-period) if MindsDB unavailable; log incident to `platinum.job_runs`.

---

## 11. Performance Requirements

### 11.1 Response Times
- **Gold View Queries**: p95 <400ms
- **NL→SQL Generation**: <2s end-to-end
- **Chart Rendering**: <500ms for standard visualizations
- **RAG Retrieval**: <1s for semantic search (top-k=8, MMR α=0.5)
- **Platinum Cron**: p95 < 15m end-to-end with retries (3, exp backoff)

### 11.2 Scalability
- **Transactions**: Handle 1M+ POS transactions
- **SKUs**: Support 10k+ product catalog
- **Concurrent Users**: 100+ simultaneous analysts
- **Vector Search**: Sub-second similarity queries

### 11.3 Reliability
- **Uptime**: 99.9% availability SLA
- **Data Freshness**: Hourly ETL updates
- **Backup**: Point-in-time recovery within 15 minutes

### 11.4 Observability
- **Edge Function Latency**: p95/p99 tracked per endpoint
- **NL→SQL Parse Success Rate**: ≥95% target with error categorization
- **Chart Render Failures**: <2% failure rate with timeout/error tracking
- **Vector Search Performance**: p95 latency and recall@k metrics
- **Audit Coverage**: ≥95% of agentic queries logged to `audit_ledger`

---

## 12. Definition of Done

### 12.1 Core Features
✅ **Navigation**: Collapsible sidebar with 8 sections implemented
✅ **Filtering**: Cascading filters with multi-cohort support
✅ **Analytics**: All dashboard pages functional with gold layer data
✅ **AI Assistant**: Context-aware, role-aware, domain-aware responses

### 12.2 Agentic Capabilities
✅ **NL Querying**: Natural language to SQL translation working
✅ **Dynamic Charts**: ChartVision agent generating valid specifications
✅ **Ad-hoc Analysis**: Agentic Playground page fully functional
✅ **Semantic Search**: RAG retrieval with hybrid ranking

### 12.3 Quality Gates
✅ **Security**: RLS policies enforced, no credential exposure; executor injects tenant & LIMIT; audit_ledger populated for ≥95% of agentic runs
✅ **Performance**: All SLAs met under load testing
✅ **Testing**: Full test suite (unit, integration, e2e)
✅ **Accessibility**: WCAG 2.1 AA compliance with keyboard navigation for sidebar + charts; aria labels for all interactive elements
✅ **Documentation**: Complete API docs and user guides
✅ **Internationalization**: Filipino/English toggle support for labels and messages

### 12.4 AI Integration
✅ **MindsDB**: MCP server functional with all tools
✅ **Platinum Updates**: Nightly market enrichment running
✅ **Agent Orchestra**: All 4 agents deployed and orchestrated
✅ **Safety**: Query guardrails and prompt constraints active

---

## 13. Future Extensions

### 13.1 Advanced Analytics
- **Predictive Metrics**: Demand forecasting, churn prediction
- **Optimization**: Inventory and pricing recommendations
- **Anomaly Detection**: Automated outlier identification

### 13.2 Multi-Modal Analysis
- **Voice Interface**: Audio queries and responses
- **Image Analysis**: Product photo recognition
- **Document Processing**: Report and receipt analysis

### 13.3 Platform Extensions
- **Saved Queries**: AI insight templates and bookmarks
- **Export Capabilities**: PDF/PPT generation, scheduled reports
- **Multi-Tenant Federation**: Cross-platform analytics (Scout + CES)

---

## 14. Success Metrics

### 14.1 Operational KPIs
- **Query Success Rate**: >95% of NL queries resolve to valid SQL
- **Chart Generation**: >90% of auto-generated charts are useful
- **User Adoption**: 80% of analysts use agentic features weekly
- **Response Accuracy**: <5% false positive insights from AI

### 14.2 Business Impact
- **Decision Speed**: 50% reduction in time-to-insight
- **Data Democratization**: 3x increase in self-service analytics
- **Competitive Intelligence**: Daily updated market insights
- **Operational Efficiency**: 30% reduction in manual reporting

---

⚡ **This PRD defines a complete transformation** from traditional BI dashboard to an **autonomous analytics platform** capable of understanding natural language, generating insights on demand, and adapting to user context and role requirements.

The system provides both **structured dashboards** for routine analysis and **agentic capabilities** for exploratory data science, making advanced analytics accessible to business users while maintaining enterprise security and governance standards.

---

## Appendix A — Agentic Design Patterns Addendum

This appendix maps Scout Dashboard v7.1 components to well-established **Agentic Design Patterns** (cf. Antonio Gullì, *Agentic Design Patterns*).  
It ensures that Scout's agentic analytics features align with best practices in the wider AI systems community.

---

### A.1 Orchestrator Pattern
- **Definition**: One agent delegates tasks to specialized sub-agents and sequences their outputs.
- **Scout Implementation**:
  - **Pulser runtime** as orchestrator
  - **Pipeline**: `QueryAgent → RetrieverAgent → ChartVisionAgent → NarrativeAgent`
  - **Execution Flow**:
    1. NL query parsed by QueryAgent (NL→SQL).
    2. RetrieverAgent adds context (RAG + KG).
    3. ChartVisionAgent generates visualization spec.
    4. NarrativeAgent produces role-aware explanation.

---

### A.2 Toolformer Pattern
- **Definition**: Agent learns when to invoke external tools/APIs, guided by prompt constraints or fine-tuned examples.
- **Scout Implementation**:
  - QueryAgent decides between:
    - `sql_exec` (structured DB query)
    - `rag_retrieve` (semantic vector search)
    - `mindsdb_proxy` (predictive forecast)
  - Guardrails ensure only whitelisted schemas are touched.
- **Future Enhancement**:
  - Add *confidence thresholding* so agents auto-retry with different tools if initial attempt fails.

---

### A.3 Reflector Pattern
- **Definition**: Agent critiques and validates its own output before surfacing it.
- **Scout Implementation**:
  - ChartVisionAgent validates:
    - Chart spec schema (Vega/Recharts schema check)
    - Dim/metric match against semantic model
  - NarrativeAgent checks for hallucination against retrieved facts.
- **Future Enhancement**:
  - Introduce *meta-agent critic* that can re-issue the query if anomalies are detected (e.g., empty cohorts, extreme deltas).

---

### A.4 Crew Pattern
- **Definition**: Specialized agents work in parallel as a "crew," each aligned to a persona/role.
- **Scout Implementation**:
  - Role-aware assistant responses:
    - **Executive**: KPIs, deltas, summaries
    - **Store Manager**: SKU substitution, inventory recommendations
    - **Analyst**: SQL detail, anomaly breakdown
  - Agents adapt tone and scope to persona.
- **Future Enhancement**:
  - Add *crew consensus* mode: multiple agents respond, then orchestrator merges into a unified insight.

---

### A.5 Memory Pattern
- **Definition**: Persist useful outputs for reuse, replay, or learning.
- **Scout Implementation**:
  - **ops.audit_ledger**: permanent record of NL→SQL queries, rowcounts, chart hints, errors
  - **platinum.job_runs**: lineage for enrichment jobs
- **Future Enhancement**:
  - Expose **Saved Insights**: successful agentic charts pinned to dashboards.
  - Enable **few-shot seeding**: reuse past successful queries as training context for NL→SQL.

---

### A.6 Safety & Governance Pattern
- **Definition**: Enforce explicit limits and checks across the agent loop.
- **Scout Implementation**:
  - RLS tenant isolation
  - Schema whitelist, CTE requirement, `SELECT *` banned
  - Role-based row limits (Exec 5K, Store 20K, Analyst 100K)
  - Audit coverage ≥95% required
- **Future Enhancement**:
  - Build **audit dashboards** to visualize compliance.
  - Auto-alert on policy violations.

---

### A.7 Hybrid Pattern (CAG + RAG + KG)
- **Definition**: Combine multiple retrieval methods (graph, semantic, lexical) for resilience.
- **Scout Implementation**:
  - **CAG**: Comparative Analysis Graph edges (substitution signals)
  - **RAG**: pgvector hybrid (dense + BM25 + metadata)
  - **KG**: Taxonomy (brand → category → SKU)
- **Future Enhancement**:
  - Weighted fusion layer with learning-to-rank for retrieval ordering.

---

## Summary
Scout v7.1 applies **seven core agentic design patterns** out of the box (Orchestrator, Toolformer, Reflector, Crew, Memory, Safety, Hybrid).  
These patterns make the system:
- **Composable** (agents specialize, orchestrator sequences),
- **Safe** (guardrails + audit),
- **Adaptive** (role/context aware),
- **Extensible** (crew consensus, saved insights, meta-critics can be added incrementally).

This appendix ensures future extensions remain **pattern-aligned** and execution-grade.

---

## Appendix B — SuperClaude Execution Framework Integration

While Appendix A documents *industry-standard agentic patterns*, Scout Dashboard v7.1 is **executed through the SuperClaude Framework**, which provides the mechanics of persona routing, MCP server orchestration, and wave-mode execution.

---

### B.1 Personas → Crew Pattern Mapping
SuperClaude personas activate across Scout agents as follows:

- **Architect Persona** → powers **QueryAgent** (NL→SQL decomposition, filter enforcement).
- **Analyzer Persona** → powers **RetrieverAgent** (RAG, KG, CAG enrichment).
- **Frontend Persona** → powers **ChartVisionAgent** (chart spec generation, component binding).
- **Backend Persona** → powers **NarrativeAgent** (insight stitching, role-based summaries).

This aligns directly with the **Crew Pattern** in Appendix A.

---

### B.2 MCP Servers → Toolformer Pattern Mapping
SuperClaude's MCP servers extend Scout's execution:

- **Context7** → schema/context injection into NL→SQL prompts.  
- **Sequential** → step-wise reasoning server, used for SQL plan + validation.  
- **Magic** → chart auto-layout, color schemes, and design token injection.  
- **Playwright** → automated browser testing of Scout Dashboard pages.

This matches the **Toolformer Pattern** in Appendix A.

---

### B.3 Wave Orchestration → Orchestrator Pattern Mapping
SuperClaude supports multi-stage "wave" orchestration:

- **Wave 1** → intent parsing & context assembly (QueryAgent + Context7).  
- **Wave 2** → retrieval & enrichment (RetrieverAgent + Sequential).  
- **Wave 3** → visualization (ChartVisionAgent + Magic).  
- **Wave 4** → narrative (NarrativeAgent).  

This ensures **compound queries** (e.g. *"Compare Alaska vs Oishi in NCR Q2 and forecast next quarter"*) are decomposed, executed, and recomposed in order.

---

### B.4 Flag Usage (Execution Controls)
- **`--think-hard`** → activates Sequential MCP for deep reasoning; used in complex SQL generation or multi-join contexts.  
- **`--wave-mode`** → enforces multi-stage orchestration rather than direct tool calls.  
- **`--uc` (ultra-compression)** → token efficiency mode; reduces verbosity in chart specs or SQL expansions.  

Flags act as **execution-time optimizers**, not architectural changes.

---

### B.5 Commands & Eligibility
- **`/analyze`** → eligible for RetrieverAgent + Analyzer persona (RAG/KG/CAG).  
- **`/build`** → eligible for ChartVisionAgent + Frontend persona (chart/UI generation).  
- **`/improve`** → eligible for Architect persona (query refinement, prompt optimization).  

Eligibility is resolved by **wave orchestration** so only the correct agents are engaged.

---

### B.6 Summary
- **Agentic Patterns (Appendix A)** define *what* Scout's AI agents do.  
- **SuperClaude Framework (Appendix B)** defines *how* those agents are executed, optimized, and tested.  

Together they ensure Scout v7.1 is:
- **Architecturally aligned** (Agentic Design Patterns)  
- **Operationally robust** (SuperClaude execution mechanics)  
- **Future-proof** (wave orchestration and MCP extensibility)

---

## Appendix C — Visual Architecture Mapping

The following diagram illustrates the direct mapping between Agentic Design Patterns (Appendix A) and SuperClaude Execution Framework (Appendix B):

![Agentic × SuperClaude Architecture Mapping](agentic-superclaude-map.svg)

**Machine-Readable Specification**: `semantic/agentic-mapping.yaml` provides the complete YAML specification for validation, orchestration, and compliance checking.

This visual mapping ensures stakeholders can immediately understand how Scout v7.1's **architectural patterns** (what) align with **execution mechanics** (how) through the SuperClaude Framework.