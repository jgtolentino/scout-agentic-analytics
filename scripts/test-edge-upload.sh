#!/bin/bash
# Test script for edge device upload
set -euo pipefail

# Configuration
PROJECT_REF="${SUPABASE_PROJECT_REF:-cxzllzyxwpyptfretryc}"
EDGE_TOKEN="${EDGE_TOKEN:?Please set EDGE_TOKEN}"
DEVICE_ID="${DEVICE_ID:-pi-test-01}"
DATE=$(date +%Y-%m-%d)

# Create test data
TEST_FILE="/tmp/test-transactions.jsonl"
cat > "$TEST_FILE" << 'EOF'
{"transaction_id":"TXN001","store_id":"STORE-101","ts":"2024-01-20T10:30:00Z","peso_value":250.50,"sku":"PROD-001","brand_name":"TestBrand","product_category":"Electronics"}
{"transaction_id":"TXN002","store_id":"STORE-102","ts":"2024-01-20T10:31:00Z","peso_value":150.00,"sku":"PROD-002","brand_name":"TestBrand","product_category":"Grocery"}
{"transaction_id":"TXN003","store_id":"STORE-101","ts":"2024-01-20T10:32:00Z","peso_value":320.75,"sku":"PROD-003","brand_name":"AnotherBrand","product_category":"Electronics"}
EOF

echo "📤 Uploading test data..."
echo "   Date: $DATE"
echo "   Device: $DEVICE_ID"
echo "   File: $TEST_FILE"

# Upload to storage
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $EDGE_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@$TEST_FILE" \
  "https://${PROJECT_REF}.supabase.co/storage/v1/object/scout-ingest/${DATE}/${DEVICE_ID}/transactions-$(date +%s).jsonl")

echo "📡 Response: $RESPONSE"

# Test direct Edge Function ingestion
echo ""
echo "🔄 Testing direct Edge Function ingestion..."

INGEST_RESPONSE=$(curl -s -X POST \
  "https://${PROJECT_REF}.functions.supabase.co/ingest-transaction" \
  -H "Content-Type: application/jsonl" \
  -H "x-device-id: $DEVICE_ID" \
  --data-binary "@$TEST_FILE")

echo "📊 Ingest Response: $INGEST_RESPONSE"

# Trigger Bronze loading
echo ""
echo "⚙️  Triggering Bronze loader..."

BRONZE_RESPONSE=$(curl -s -X POST \
  "https://${PROJECT_REF}.functions.supabase.co/load-bronze-from-storage" \
  -H "Content-Type: application/json" \
  -d "{\"date\":\"$DATE\"}")

echo "🗄️  Bronze Response: $BRONZE_RESPONSE"

echo ""
echo "✅ Test complete! Check your Bronze table for data."