#!/bin/bash
# Deploy all Edge Functions without CLI switching

set -euo pipefail

echo "🚀 Deploying all Edge Functions..."

# Load environment
source scripts/secrets.sh 2>/dev/null || echo "⚠️  No secrets.sh found, using environment variables"

# Check required vars
if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo "❌ SUPABASE_PROJECT_REF not set"
  exit 1
fi

# Deploy functions
FUNCTIONS=(
  "process-eugene-data"
  "admin-sql"
  "scout-ingest"
  "load-bronze-from-storage"
)

for func in "${FUNCTIONS[@]}"; do
  echo "📦 Deploying $func..."
  if supabase functions deploy "$func" --project-ref "$SUPABASE_PROJECT_REF" --no-verify-jwt; then
    echo "✅ $func deployed successfully"
  else
    echo "❌ Failed to deploy $func"
    exit 1
  fi
done

echo ""
echo "🎉 All functions deployed!"
echo ""
echo "📋 Available endpoints:"
echo "• Setup schema: POST https://$SUPABASE_PROJECT_REF.functions.supabase.co/admin-sql"
echo "• Process Eugene's data: POST https://$SUPABASE_PROJECT_REF.functions.supabase.co/process-eugene-data"
echo "• Direct ingestion: POST https://$SUPABASE_PROJECT_REF.functions.supabase.co/ingest-transaction"
echo ""

# Test schema setup
echo "🧪 Testing schema setup..."
SCHEMA_RESPONSE=$(curl -s -X POST \
  "https://$SUPABASE_PROJECT_REF.functions.supabase.co/admin-sql" \
  -H "Content-Type: application/json" \
  -d '{"action": "setup-scout-schema"}')

if echo "$SCHEMA_RESPONSE" | grep -q "success"; then
  echo "✅ Schema setup successful"
else
  echo "⚠️  Schema setup response: $SCHEMA_RESPONSE"
fi

echo ""
echo "🎯 Next steps:"
echo "1. Process Eugene's data: curl -X POST https://$SUPABASE_PROJECT_REF.functions.supabase.co/process-eugene-data"
echo "2. Check stats: curl -X POST https://$SUPABASE_PROJECT_REF.functions.supabase.co/process-eugene-data -d '{\"action\":\"get-stats\"}'"