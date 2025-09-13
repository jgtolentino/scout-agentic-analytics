#!/usr/bin/env bash
# Test Scout API access after fixes
set -euo pipefail

# Use environment variable or prompt for anon key
ANON_KEY="${SUPABASE_ANON_KEY:-}"
if [ -z "$ANON_KEY" ]; then
  echo "Enter your Supabase ANON key (from Dashboard > Settings > API):"
  read -r ANON_KEY
fi

PROJECT_URL="https://cxzllzyxwpyptfretryc.supabase.co"

echo "🔍 Testing Scout Schema API Access..."
echo "===================================="
echo ""

# Test 1: Without Accept-Profile header (should fail with 406)
echo "Test 1: Query without Accept-Profile header (expecting 406):"
curl -s \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  "$PROJECT_URL/rest/v1/dal_transactions_flat?select=*&limit=1" \
  -w "\nHTTP Status: %{http_code}\n" || true

echo ""
echo "---"
echo ""

# Test 2: With Accept-Profile: scout header (should work)
echo "Test 2: Query with Accept-Profile: scout header:"
RESPONSE=$(curl -s \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Accept-Profile: scout" \
  "$PROJECT_URL/rest/v1/dal_transactions_flat?select=store_id,gross_sales,net_sales,daypart&limit=3" \
  -w "\nHTTP_STATUS:%{http_code}")

HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "HTTP Status: $HTTP_STATUS"
echo "Response:"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

echo ""
echo "---"
echo ""

# Test 3: Check if v_gold_transactions_flat exists
echo "Test 3: Query v_gold_transactions_flat with ZIP filter:"
curl -s \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Accept-Profile: scout" \
  "$PROJECT_URL/rest/v1/v_gold_transactions_flat?select=transaction_id,source_type,gross_sales&source_type=eq.ZIP&limit=3" | jq '.' 2>/dev/null || echo "View not found or no ZIP data"

echo ""
echo "===================================="
echo "📊 Results Summary:"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ Scout schema is properly exposed and accessible!"
  echo "✅ Your app should now work without 406 errors"
else
  echo "❌ Scout schema access still failing (HTTP $HTTP_STATUS)"
  echo ""
  echo "Required fixes:"
  echo "1. Go to Supabase Dashboard > Settings > API > Exposed Schemas"
  echo "2. Add 'scout' to the list"
  echo "3. Save (this restarts PostgREST)"
  echo "4. Run: psql \$DATABASE_URL -f scripts/fix-scout-schema-access.sql"
fi