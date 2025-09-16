#!/usr/bin/env bash
set -euo pipefail

echo "🧪 Backend-Only Smoke Test via Bruno"
echo "======================================"

# This script demonstrates the one-liner backend smoke pattern
# Adjust paths and commands based on your actual setup

cd /Users/tbwa/scout-v7
echo "📍 Working directory: $(pwd)"

echo "🔧 Loading environment from vault (Bruno handles secrets)..."
# source ./scripts/env.from.vault.sh || true

echo "📊 Supabase migrations check..."
# Bruno will inject credentials for actual DB operations
echo "   ℹ️  Run via Bruno: supabase db push --db-url \"\$DB_URL\""

echo "🏗️ dbt models check..."
if [[ -d "dbt-scout" ]]; then
  cd dbt-scout
  echo "   ℹ️  Run via Bruno: dbt deps && dbt run --select silver+ gold+ && dbt test --select silver+ gold+"
  cd ..
else
  echo "   ⚠️  dbt-scout directory not found"
fi

echo "🔍 Great Expectations check..."
if [[ -d "great_expectations" ]]; then
  echo "   ℹ️  Run via Bruno: great_expectations checkpoint run bronze_quarantine_suite"
else
  echo "   ⚠️  great_expectations directory not found"
fi

echo ""
echo "✅ Backend smoke structure validated"
echo "🔒 Actual DB/network operations require Bruno credential injection"
echo ""
echo "To run with real credentials:"
echo "  :bruno run \"$(cat $0)\""