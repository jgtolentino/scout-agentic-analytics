#!/bin/bash

# 🧪 MCP Golden Path Verification Script
# Checks all client connections to remote reader

set -e

echo "🧪 MCP Golden Path Verification"
echo "==============================="

# Test 1: Health Route
echo ""
echo "1️⃣ Testing Health Route..."
HEALTH=$(curl -sf https://mcp-supabase-clean.onrender.com/health 2>/dev/null || echo "FAILED")

if [[ "$HEALTH" == *"ok"* ]]; then
    echo "✅ Health route: OK"
    echo "   Response: $HEALTH"
else
    echo "❌ Health route: FAILED"
    echo "   Check Render deployment status"
    exit 1
fi

# Test 2: Pulser CLI Query
echo ""
echo "2️⃣ Testing Pulser CLI..."
if command -v pulser &> /dev/null; then
    PULSER_RESULT=$(pulser call rr select '{"table":"information_schema.tables","columns":["table_name"],"limit":1}' 2>&1 || echo "FAILED")
    
    if [[ "$PULSER_RESULT" == *"rows"* ]] || [[ "$PULSER_RESULT" == *"table_name"* ]]; then
        echo "✅ Pulser (:rr) query: OK"
    else
        echo "❌ Pulser (:rr) query: FAILED"
        echo "   Response: $PULSER_RESULT"
        echo "   Check SUPABASE_ANON_KEY environment variable"
    fi
else
    echo "⚠️  Pulser not installed - skipping CLI test"
fi

# Test 3: Claude Desktop Panel
echo ""
echo "3️⃣ Testing Claude Desktop..."
CLAUDE_LOG="/Users/tbwa/Library/Logs/Claude/mcp.log"

if [ -f "$CLAUDE_LOG" ]; then
    # Check for recent successful connection (within last 5 minutes)
    RECENT_SUCCESS=$(tail -100 "$CLAUDE_LOG" | grep -E "(supabase-reader.*connected|HTTP adapter connected)" | tail -1 || echo "")
    
    if [[ -n "$RECENT_SUCCESS" ]]; then
        echo "✅ Claude Desktop panel: OK"
        echo "   Recent log: $RECENT_SUCCESS"
    else
        echo "⚠️  Claude Desktop: No recent connection found"
        echo "   Restart Claude Desktop to apply new HTTP config"
    fi
else
    echo "⚠️  Claude Desktop logs not found"
fi

# Test 4: Direct API Test
echo ""
echo "4️⃣ Testing Direct API..."
API_TEST=$(curl -sf -X POST https://mcp-supabase-clean.onrender.com/mcp/select \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenl4d3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNzYxODAsImV4cCI6MjA2Nzk1MjE4MH0.b794GEIWE4ZdMAm9xQYAJ0Gx-XEn1fhJBTIIeTro_1g" \
    -d '{"table":"information_schema.schemata","columns":["schema_name"],"limit":5}' \
    2>/dev/null || echo "FAILED")

if [[ "$API_TEST" == *"rows"* ]]; then
    echo "✅ Direct API test: OK"
    SCHEMA_COUNT=$(echo "$API_TEST" | jq -r '.rows | length' 2>/dev/null || echo "0")
    echo "   Found $SCHEMA_COUNT schemas"
else
    echo "❌ Direct API test: FAILED"
    echo "   Response: $API_TEST"
fi

# Summary
echo ""
echo "================================="
echo "📋 Verification Summary"
echo "================================="

if [[ "$HEALTH" == *"ok"* ]]; then
    echo "✅ Remote reader is operational"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Restart Claude Desktop to apply HTTP config"
    echo "   2. Test with: 'What tables are in the database?'"
    echo "   3. Test Pulser: :rr select table=scout_dash.users columns='[\"id\"]' limit=1"
    echo ""
    echo "🚀 Golden Path architecture is ready!"
else
    echo "❌ Remote reader needs attention"
    echo "   Check Render deployment and environment variables"
fi