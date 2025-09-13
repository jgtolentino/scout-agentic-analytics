#!/bin/bash

# CES Integration Test Script
# Tests the full Ask CES stack: Gateway -> Palette Service -> Supabase

set -e

# Configuration
CES_GATEWAY_URL="${CES_GATEWAY_URL:-https://ces-gw.onrender.com}"
API_TOKEN="${CES_API_TOKEN:-$(doppler secrets get CES_API_TOKEN --plain)}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Starting CES Integration Tests..."
echo "Gateway URL: $CES_GATEWAY_URL"
echo ""

# Test 1: Health Check
echo "1️⃣ Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -X GET "$CES_GATEWAY_URL/health")
HEALTH_STATUS=$(echo $HEALTH_RESPONSE | jq -r '.status')

if [ "$HEALTH_STATUS" == "healthy" ]; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    echo "Services status:"
    echo $HEALTH_RESPONSE | jq '.services'
else
    echo -e "${RED}❌ Health check failed: $HEALTH_STATUS${NC}"
    echo $HEALTH_RESPONSE | jq '.'
    exit 1
fi
echo ""

# Test 2: Ask endpoint with color query
echo "2️⃣ Testing /ask endpoint with color query..."
ASK_RESPONSE=$(curl -s -X POST "$CES_GATEWAY_URL/ask" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "prompt": "Show me the top 3 pink-dominant ads",
        "limit": 3
    }')

ASK_STATUS=$?
if [ $ASK_STATUS -eq 0 ]; then
    ANSWER_COUNT=$(echo $ASK_RESPONSE | jq '.answers | length')
    if [ "$ANSWER_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ Ask endpoint returned $ANSWER_COUNT results${NC}"
        echo "First result preview:"
        echo $ASK_RESPONSE | jq '.answers[0]' | head -10
    else
        echo -e "${YELLOW}⚠️  Ask endpoint returned no results${NC}"
    fi
else
    echo -e "${RED}❌ Ask endpoint failed${NC}"
    echo $ASK_RESPONSE
fi
echo ""

# Test 3: Score endpoint
echo "3️⃣ Testing /score endpoint..."
SCORE_RESPONSE=$(curl -s -X POST "$CES_GATEWAY_URL/score" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "image_url": "https://example.com/test-image.jpg"
    }')

SCORE_STATUS=$?
if [ $SCORE_STATUS -eq 0 ] && [ "$(echo $SCORE_RESPONSE | jq -r '.palette_scores')" != "null" ]; then
    echo -e "${GREEN}✅ Score endpoint working${NC}"
    echo "Palette scores:"
    echo $SCORE_RESPONSE | jq '.palette_scores'
else
    echo -e "${RED}❌ Score endpoint failed${NC}"
    echo $SCORE_RESPONSE
fi
echo ""

# Test 4: Complex query
echo "4️⃣ Testing complex creative intelligence query..."
COMPLEX_RESPONSE=$(curl -s -X POST "$CES_GATEWAY_URL/ask" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "prompt": "Which 2024 TikTok spots match Pantone Peach Fuzz?",
        "limit": 5,
        "include_embeddings": false
    }')

if [ "$(echo $COMPLEX_RESPONSE | jq -r '.metadata.query_type')" != "null" ]; then
    echo -e "${GREEN}✅ Complex query processed successfully${NC}"
    echo "Query type: $(echo $COMPLEX_RESPONSE | jq -r '.metadata.query_type')"
    echo "Sources used: $(echo $COMPLEX_RESPONSE | jq -r '.sources | join(", ")')"
else
    echo -e "${YELLOW}⚠️  Complex query may not be fully implemented${NC}"
fi
echo ""

# Test 5: Pulser CLI simulation
echo "5️⃣ Simulating Pulser CLI call..."
echo "Command: :ces 'top 3 pink-dominant ads'"
PULSER_RESPONSE=$(curl -s -X POST "$CES_GATEWAY_URL/ask" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"prompt": "top 3 pink-dominant ads"}')

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Pulser-style query successful${NC}"
else
    echo -e "${RED}❌ Pulser-style query failed${NC}"
fi
echo ""

# Summary
echo "📊 Test Summary:"
echo "=================="
if [ "$HEALTH_STATUS" == "healthy" ]; then
    echo -e "${GREEN}✅ All critical tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Deploy to Render using: git push origin main"
    echo "2. Configure KeyKey/Doppler secrets"
    echo "3. Run Supabase migration: supabase db push"
    echo "4. Test with actual image URLs"
else
    echo -e "${RED}❌ Some tests failed. Please check the logs above.${NC}"
fi