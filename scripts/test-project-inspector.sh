#!/bin/bash

# Test script for project-inspector Edge Function

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
SUPABASE_URL="${SUPABASE_URL:-https://cxzllzyxwpyptfretryc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-$SUPABASE_ANON_KEY}"

echo -e "${BLUE}🧪 Testing Project Inspector Edge Function${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if key is provided
if [ -z "$SUPABASE_KEY" ]; then
    echo -e "${RED}❌ Error: No Supabase key found${NC}"
    echo "Please set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY"
    echo "Example: export SUPABASE_SERVICE_ROLE_KEY=your-key-here"
    exit 1
fi

echo "🔍 Testing endpoint: $SUPABASE_URL/functions/v1/project-inspector"
echo ""

# Test 1: Basic connectivity
echo -e "${YELLOW}Test 1: Basic Connectivity${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" \
    "$SUPABASE_URL/functions/v1/project-inspector" \
    -H "Authorization: Bearer $SUPABASE_KEY")

if [ "$response" -eq 200 ] || [ "$response" -eq 400 ]; then
    echo -e "${GREEN}✅ Endpoint is reachable (Status: $response)${NC}"
else
    echo -e "${RED}❌ Endpoint returned unexpected status: $response${NC}"
fi
echo ""

# Test 2: Full inspection request
echo -e "${YELLOW}Test 2: Full Inspection Request${NC}"
response=$(curl -s -X POST "$SUPABASE_URL/functions/v1/project-inspector" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "root": "./",
        "patterns": [
            "**/agents/**/*.{yaml,yml,json,ts}",
            "**/*.agent.{yaml,yml,json,ts}"
        ],
        "metadata": {
            "test": true,
            "timestamp": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"
        }
    }' \
    -w "\nHTTP_STATUS:%{http_code}")

# Extract status and body
http_status=$(echo "$response" | tail -n1 | cut -d: -f2)
body=$(echo "$response" | sed '$d')

if [ "$http_status" -eq 200 ]; then
    echo -e "${GREEN}✅ Inspection completed successfully${NC}"
    echo "Response:"
    if command -v jq &> /dev/null; then
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        echo "$body"
    fi
else
    echo -e "${RED}❌ Inspection failed with status: $http_status${NC}"
    echo "Response: $body"
fi
echo ""

# Test 3: Check if cron is set up (requires DB access)
echo -e "${YELLOW}Test 3: Checking Cron Schedule (if configured)${NC}"
echo "To verify cron schedules, run this in your Supabase SQL editor:"
echo -e "${BLUE}SELECT * FROM cron.job WHERE jobname LIKE 'project_inspector%';${NC}"
echo ""

# Summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Test Summary:${NC}"
echo ""
echo "1. To manually trigger inspection:"
echo -e "   ${GREEN}curl -X POST $SUPABASE_URL/functions/v1/project-inspector \\${NC}"
echo -e "   ${GREEN}  -H 'Authorization: Bearer YOUR_KEY' \\${NC}"
echo -e "   ${GREEN}  -H 'Content-Type: application/json' \\${NC}"
echo -e "   ${GREEN}  -d '{\"root\": \"./\", \"patterns\": [\"**/*.yaml\"]}'${NC}"
echo ""
echo "2. To start file watcher:"
echo -e "   ${GREEN}./scripts/watch-project-inspector.sh${NC}"
echo ""
echo "3. To enable GitHub Actions:"
echo -e "   ${GREEN}git add .github/workflows/auto-project-inspect.yml${NC}"
echo -e "   ${GREEN}git commit -m 'feat: add auto project inspection'${NC}"
echo -e "   ${GREEN}git push${NC}"