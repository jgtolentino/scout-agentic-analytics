# Scout ETL Deployment Runbook

## 🚀 Complete HTTP-Based Pipeline (No CLI Required)

This runbook deploys a complete Edge-to-Dashboard pipeline using only HTTP endpoints.

## 1. Apply Database Schema

Run these SQL files in order in Supabase SQL Editor:

```sql
-- 1. Create storage bucket and policies
-- Run: platform/supabase/sql/000_buckets_policies.sql

-- 2. Create Bronze schema
-- Run: platform/supabase/sql/010_bronze.sql

-- 3. Create Silver schema  
-- Run: platform/supabase/sql/020_silver.sql

-- 4. Create Gold schema
-- Run: platform/supabase/sql/030_gold.sql
```

## 2. Deploy Edge Functions

```bash
# Deploy transaction ingestion endpoint
supabase functions deploy ingest-transaction --no-verify-jwt

# Deploy storage loader endpoint
supabase functions deploy load-bronze-from-storage --no-verify-jwt
```

## 3. Generate Edge Device Token

```bash
# Using the token generator from earlier
node scripts/generate-uploader-token.js --days 30 --name "pi5-device"
```

## 4. Test Edge Upload (From Pi 5)

```bash
# Set your token and project
export EDGE_TOKEN="eyJ..."
export PROJECT_REF="cxzllzyxwpyptfretryc"

# Upload JSONL file
./scripts/smoke/edge_upload.sh
```

## 5. Process Data via HTTP

```bash
# Trigger Bronze loading
curl -X POST "https://$PROJECT_REF.functions.supabase.co/load-bronze-from-storage" \
  -H "Content-Type: application/json" \
  -d '{"date":"2024-01-20"}'

# Or direct transaction post
curl -X POST "https://$PROJECT_REF.functions.supabase.co/ingest-transaction" \
  -H "Content-Type: application/jsonl" \
  -H "x-device-id: pi-05" \
  --data-binary @transactions.jsonl
```

## 6. Run ETL Pipeline

The GitHub Actions workflow runs automatically every 10 minutes, or trigger manually:

1. Go to Actions tab in GitHub
2. Select "Scout ETL" workflow
3. Click "Run workflow"

## 7. Verify Results

Check your data:

```sql
-- Bronze layer
SELECT COUNT(*) FROM scout_bronze.transactions_raw;

-- Silver layer (after dbt run)
SELECT COUNT(*) FROM scout_silver.transactions;

-- Gold layer
SELECT * FROM scout_gold.revenue_trend ORDER BY date DESC LIMIT 10;
```

Check published datasets:

```bash
# Latest manifest
curl "https://$PROJECT_REF.supabase.co/storage/v1/object/public/sample/scout/v1/manifests/latest.json"
```

## Environment Variables Required

```bash
# For Edge Functions
SUPABASE_URL=https://[project].supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# For GitHub Actions
DATABASE_URL=postgresql://...
SUPABASE_FUNCTIONS_BASE=https://[project].functions.supabase.co

# Optional Superset
SUPERSET_URL=https://...
SUPERSET_TOKEN=...
```

## Complete Data Flow

1. **Edge Device** → POST JSONL to storage bucket via HTTP
2. **Edge Function** → Loads from storage to Bronze table
3. **dbt** → Transforms Bronze → Silver → Gold
4. **Publisher** → Exports Gold to storage as CSV
5. **Superset** → Reads from Gold views

All operations are HTTP-based - no CLI switching required!