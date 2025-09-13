#!/usr/bin/env bash
# Real-time NDJSON streaming to Scout platform
set -euo pipefail

: "${SUPABASE_EDGE_TOKEN:?Environment variable SUPABASE_EDGE_TOKEN is required}"
: "${PROJECT_REF:?Environment variable PROJECT_REF is required}"

URL="https://${PROJECT_REF}.functions.supabase.co/ingest-stream"
DEVICE_ID="${DEVICE_ID:-pi-05}"
FILE="${1:-/dev/stdin}"

echo "🚀 Streaming NDJSON to Scout Platform"
echo "====================================="
echo "Device ID: $DEVICE_ID"
echo "Endpoint: $URL"
echo "Source: $FILE"
echo ""

# Stream data with curl
echo "📡 Starting stream..."
RESPONSE=$(curl -N -sS -X POST "$URL" \
  -H "Authorization: Bearer $SUPABASE_EDGE_TOKEN" \
  -H "Content-Type: application/x-ndjson" \
  -H "x-device-id: $DEVICE_ID" \
  --data-binary @"$FILE" \
  --max-time 300 \
  --connect-timeout 10) || {
  echo "❌ Stream failed with exit code $?"
  exit 1
}

echo "📥 Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false' 2>/dev/null || echo "false")
if [ "$SUCCESS" = "true" ]; then
  LINES=$(echo "$RESPONSE" | jq -r '.lines_seen // 0' 2>/dev/null || echo "0")
  INSERTED=$(echo "$RESPONSE" | jq -r '.inserted // 0' 2>/dev/null || echo "0")
  ERRORS=$(echo "$RESPONSE" | jq -r '.errors // 0' 2>/dev/null || echo "0")
  
  echo ""
  echo "✅ Stream completed successfully!"
  echo "📊 Lines processed: $LINES"
  echo "💾 Records inserted: $INSERTED"
  if [ "$ERRORS" -gt 0 ]; then
    echo "⚠️  Parse errors: $ERRORS"
  fi
else
  echo ""
  echo "❌ Stream failed"
  exit 1
fi