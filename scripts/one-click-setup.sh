#!/bin/bash
# One-click setup - no CLI/Desktop switching, no SQL copy-paste

set -euo pipefail

PROJECT_REF="cxzllzyxwpyptfretryc"
BASE_URL="https://$PROJECT_REF.functions.supabase.co"

echo "🎯 ONE-CLICK SCOUT SETUP"
echo "========================"

# 1. Deploy Edge Functions
echo "📦 Step 1: Deploying Edge Functions..."
export SUPABASE_PROJECT_REF="$PROJECT_REF"
./scripts/deploy-all-functions.sh

# 2. Setup database schema via HTTP
echo ""
echo "🗄️  Step 2: Setting up database schema..."
SCHEMA_RESPONSE=$(curl -s -X POST "$BASE_URL/admin-sql" \
  -H "Content-Type: application/json" \
  -d '{"action": "setup-scout-schema"}')

echo "Schema Response: $SCHEMA_RESPONSE"

# 3. Process Eugene's data via HTTP
echo ""
echo "📊 Step 3: Processing Eugene's data from storage..."
PROCESS_RESPONSE=$(curl -s -X POST "$BASE_URL/process-eugene-data" \
  -H "Content-Type: application/json" \
  -d '{"action": "process-zip", "payload": {"zipPath": "json.zip"}}')

echo "Processing Response: $PROCESS_RESPONSE"

# 4. Get final stats
echo ""
echo "📈 Step 4: Getting processing stats..."
STATS_RESPONSE=$(curl -s -X POST "$BASE_URL/process-eugene-data" \
  -H "Content-Type: application/json" \
  -d '{"action": "get-stats"}')

echo "Stats: $STATS_RESPONSE"

echo ""
echo "✅ SETUP COMPLETE!"
echo ""
echo "🔗 Available HTTP endpoints:"
echo "• Setup: $BASE_URL/admin-sql"
echo "• Process: $BASE_URL/process-eugene-data"
echo "• Ingest: $BASE_URL/scout-ingest"
echo "• Load Storage: $BASE_URL/load-bronze-from-storage"
echo ""
echo "🎯 Test commands:"
echo "• curl -X POST $BASE_URL/process-eugene-data -d '{\"action\":\"get-stats\"}'"
echo "• curl -X POST $BASE_URL/scout-ingest -H 'Content-Type: application/json' -d '{\"test\":\"data\"}'"
echo "• curl -X POST $BASE_URL/load-bronze-from-storage -d '{\"action\":\"get-storage-stats\"}'"