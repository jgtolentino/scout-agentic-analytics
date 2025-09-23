#!/bin/bash

# Scout v7 Dashboard Deployment Verification Script
# Tests all critical endpoints on the live deployment

set -e

DEPLOYMENT_URL="https://scout-dashboard-xi.vercel.app"
echo "🔍 Verifying Scout v7 Dashboard Deployment"
echo "URL: $DEPLOYMENT_URL"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local description=$2
    local url="${DEPLOYMENT_URL}${endpoint}"

    echo -n "Testing $description... "

    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$url")
    http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo $response | sed -e 's/HTTPSTATUS:.*//g')

    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✅ OK${NC} (${http_code})"

        # Parse JSON response if it's valid
        if echo "$body" | jq . >/dev/null 2>&1; then
            echo "   Response preview: $(echo "$body" | jq -c . | cut -c1-100)..."
        else
            echo "   Response length: ${#body} characters"
        fi
    else
        echo -e "${RED}❌ FAILED${NC} (${http_code})"
        echo "   Error: $(echo "$body" | head -c 200)"
        return 1
    fi

    echo ""
}

# Test main page
echo "Testing main dashboard page..."
response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$DEPLOYMENT_URL/")
http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✅ Main page loads${NC} (${http_code})"

    # Check for loading indicators or error messages
    body=$(echo $response | sed -e 's/HTTPSTATUS:.*//g')
    if echo "$body" | grep -q "Loading..."; then
        echo -e "${YELLOW}⚠️  Found 'Loading...' text - might indicate stuck loading state${NC}"
    fi

    if echo "$body" | grep -q "Error"; then
        echo -e "${YELLOW}⚠️  Found 'Error' text in page${NC}"
    fi

    if echo "$body" | grep -q "Scout v7"; then
        echo -e "${GREEN}✅ Scout v7 branding found${NC}"
    fi
else
    echo -e "${RED}❌ Main page failed${NC} (${http_code})"
fi

echo ""

# Test API endpoints
echo "Testing API endpoints..."
test_endpoint "/api/health" "Health check"
test_endpoint "/api/dq/summary" "Data quality summary"
test_endpoint "/api/transactions/kpis" "Transaction KPIs"
test_endpoint "/api/stores/geo" "Store geolocation"

# Test authentication pages
echo "Testing authentication pages..."
test_endpoint "/auth/login" "Login page"
test_endpoint "/auth/unauthorized" "Unauthorized page"

echo ""
echo "🔍 Environment Variable Check"
echo "================================"

# Test health endpoint for environment info
health_response=$(curl -s "$DEPLOYMENT_URL/api/health")
if echo "$health_response" | jq . >/dev/null 2>&1; then
    echo "Environment status:"
    echo "$health_response" | jq '.client_env'

    # Check critical variables
    ok_status=$(echo "$health_response" | jq -r '.ok')
    if [ "$ok_status" = "true" ]; then
        echo -e "${GREEN}✅ Environment configuration looks good${NC}"
    else
        echo -e "${RED}❌ Environment configuration issues detected${NC}"
        echo "$health_response" | jq '.'
    fi
else
    echo -e "${RED}❌ Could not parse health endpoint response${NC}"
fi

echo ""
echo "🚀 Browser Test Recommendations"
echo "================================"
echo "1. Open $DEPLOYMENT_URL in browser"
echo "2. Check browser console for JavaScript errors"
echo "3. Monitor Network tab for failed API calls"
echo "4. Look for 'Loading...' states that don't resolve"

echo ""
echo "🔧 Quick Fix Commands"
echo "===================="
echo "If issues found:"
echo "1. Check logs: vercel logs $DEPLOYMENT_URL --since=1h"
echo "2. Test locally: vercel dev"
echo "3. Deploy preview: vercel"
echo "4. Deploy production: vercel --prod"

echo ""
echo "✅ Verification complete!"