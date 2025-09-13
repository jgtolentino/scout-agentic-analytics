# Scout v7 Implementation Plan

This plan breaks down the Scout v7 PRD into 17 detailed implementation steps across 5 milestones.

## M0 — Infrastructure/Docs (Current Phase)

### Step 01: Database Schemas Setup
**ID**: step-01  
**Owner**: Backend Engineer  
**Effort**: M  
**Dependencies**: []

Create complete database schema foundation with all required tables, views, and functions.

**Artifacts**:
- `supabase/migrations/20240913_001_schemas.sql`
- Schema documentation in `docs/DATABASE.md`

### Step 02: Edge Functions Deployment
**ID**: step-02  
**Owner**: Backend Engineer  
**Effort**: L  
**Dependencies**: [step-01]

Deploy all 6 Edge functions for ETL, forecasting, and task management.

**Artifacts**:
- `supabase/functions/mindsdb-query/`
- `supabase/functions/forecast-refresh/`
- `supabase/functions/inventory-report/`
- `supabase/functions/ingest-azure-infer/`
- `supabase/functions/ingest-google-json/`
- `supabase/functions/task-enqueue/`

### Step 03: CI/CD Workflows
**ID**: step-03  
**Owner**: DevOps Engineer  
**Effort**: M  
**Dependencies**: [step-02]

Set up GitHub Actions for automated ETL, deployment, and monitoring.

**Artifacts**:
- `.github/workflows/etl-drive-azure.yml`
- `.github/workflows/etl-drive-json.yml`
- `.github/workflows/s3-inventory-report.yml`
- `.github/workflows/mindsdb-nightly.yml`
- `.github/workflows/scout-auditor.yml`

### Step 04: Auditor Implementation
**ID**: step-04  
**Owner**: DevOps Engineer  
**Effort**: S  
**Dependencies**: [step-03]

Complete the auditor script with all health checks and CI integration.

**Artifacts**:
- `scripts/audit/scout_auditor.sh` (already exists)
- Enhanced health checks for all components

## M1 — ETL + Diagnostics (Week 1)

### Step 05: Google Drive ETL Pipeline
**ID**: step-05  
**Owner**: Data Engineer  
**Effort**: L  
**Dependencies**: [step-01, step-02]

Build complete Google Drive ingestion with schema normalization.

**Artifacts**:
- `scripts/etl/drive-ingest.py`
- `staging.drive_skus` table populated
- Brand resolution trigger implemented

### Step 06: Azure ETL Pipeline
**ID**: step-06  
**Owner**: Data Engineer  
**Effort**: L  
**Dependencies**: [step-01, step-02]

Build Azure products and inference ingestion pipeline.

**Artifacts**:
- `scripts/etl/azure-ingest.py`
- `staging.azure_products` table populated
- `staging.azure_inferences` table populated

### Step 07: Brand Resolution System
**ID**: step-07  
**Owner**: Data Engineer  
**Effort**: L  
**Dependencies**: [step-05, step-06]

Implement fuzzy matching, aliases, and unknown brand triage queue.

**Artifacts**:
- `masterdata.brands` and `masterdata.brand_aliases` tables
- Brand resolution functions with ≥0.72 trigram threshold
- `ops.brand_resolution_log` for audit trail
- Unknown brand triage queue UI

### Step 08: Pipeline Diagnostics
**ID**: step-08  
**Owner**: Data Engineer  
**Effort**: M  
**Dependencies**: [step-07]

Create comprehensive diagnostics views and DQ monitoring.

**Artifacts**:
- `public.v_pipeline_gaps` view
- `public.v_pipeline_summary` view
- `public.v_dq_unmatched` and `public.v_dq_unmatched_daily` views
- `ops.unmatched_inference_log` and `ops.unmatched_payload_log` tables

## M2 — Forecasts (Week 2)

### Step 09: MindsDB Setup
**ID**: step-09  
**Owner**: ML Engineer  
**Effort**: M  
**Dependencies**: [step-08]

Configure MindsDB container and establish connection patterns.

**Artifacts**:
- MindsDB container with health checks
- Connection configuration and credentials
- Basic model training capability

### Step 10: Revenue Forecast Model
**ID**: step-10  
**Owner**: ML Engineer  
**Effort**: L  
**Dependencies**: [step-09]

Create and train 14-day revenue forecasting model.

**Artifacts**:
- MindsDB model for 14-day revenue prediction by region/category/brand
- Model training scripts
- MAPE baseline measurement (target ≤15%)

### Step 11: Platinum Prediction Tables
**ID**: step-11  
**Owner**: Data Engineer  
**Effort**: M  
**Dependencies**: [step-10]

Create prediction storage and public views for consumption.

**Artifacts**:
- `scout.platinum_predictions_revenue_14d` table
- `public.v_predictions_revenue_14d` view
- Automated refresh mechanisms via Edge functions

## M3 — Recommendations + Tasks (Week 3)

### Step 12: Recommendations System
**ID**: step-12  
**Owner**: Backend Engineer  
**Effort**: L  
**Dependencies**: [step-11]

Implement prescriptive recommendations with task_id integration.

**Artifacts**:
- `scout.recommendations` table with RLS
- Recommendation generation RPCs
- `task_id` auto-generation and enforcement (already implemented)

### Step 13: Task Queue Implementation
**ID**: step-13  
**Owner**: Backend Engineer  
**Effort**: M  
**Dependencies**: [step-12]

Build executable task queue with multiple execution types.

**Artifacts**:
- `scout.tasks` table with exec_kind support
- Task creation RPCs (`scout.tasks_create`)
- Task status management functions

### Step 14: Task Runner System
**ID**: step-14  
**Owner**: Backend Engineer  
**Effort**: L  
**Dependencies**: [step-13]

Implement queue/claim/complete runner pattern.

**Artifacts**:
- Task runner service with claim/complete logic
- Support for edge_function, sql, mindsdb_sql, gh_workflow, shell execution types
- Retry and error handling mechanisms

## M4 — Hardening (Week 4)

### Step 15: Monitoring & SLO Implementation
**ID**: step-15  
**Owner**: DevOps Engineer  
**Effort**: M  
**Dependencies**: [step-14]

Implement comprehensive monitoring and SLO tracking.

**Artifacts**:
- SLO dashboards for all success metrics
- Alerting for ETL freshness, forecast accuracy, brand resolution
- Performance monitoring and thresholds

### Step 16: Workbench UI Components
**ID**: step-16  
**Owner**: Frontend Engineer  
**Effort**: L  
**Dependencies**: [step-15]

Build admin UI cards for operational visibility.

**Artifacts**:
- `ForecastCard.tsx` component
- `PipelineDiagnostics.tsx` component
- `BrandResolutionCard.tsx` component  
- `DataQualityFlags.tsx` component
- `MindsDBInsights.tsx` component

### Step 17: Final Documentation
**ID**: step-17  
**Owner**: Technical Writer  
**Effort**: S  
**Dependencies**: [step-16]

Complete all documentation and runbooks.

**Artifacts**:
- Updated API documentation
- Operational runbooks
- Incident response procedures
- Final architecture documentation

## Success Criteria (Global Gates)

Every step must satisfy:
1. **Build/Lint/Test**: All commands pass
2. **Artifacts**: All specified files exist with expected functionality
3. **Tests**: Unit and integration tests cover main paths
4. **No TODOs**: All implementation complete
5. **Architect Verification**: PASS status from verification prompt

## Execution Model

1. Generate detailed implementation plans using SuperClaude Architect
2. Implement each step following the Detailed Tasks section
3. Run verification commands and tests
4. Get Architect verification (PASS/FAIL)
5. Update progress tracking
6. Move to next step only after completion

Each step builds incrementally toward the complete Scout v7 system with full traceability and quality gates.