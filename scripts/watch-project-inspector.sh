#!/bin/bash

# Scout Project Inspector - Local File Watcher
# Automatically triggers project-inspector on file changes

# Check if required environment variables are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "❌ Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set"
    echo "Usage: export SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co"
    echo "       export SUPABASE_SERVICE_ROLE_KEY=your-service-key"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Install chokidar-cli if not present
if ! command -v chokidar &> /dev/null; then
    echo -e "${YELLOW}Installing chokidar-cli...${NC}"
    npm install -g chokidar-cli
fi

echo -e "${BLUE}🔍 Scout Project Inspector - File Watcher${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Watching for changes in:"
echo "  - YAML/YML files (agents, configurations)"
echo "  - JSON files (configurations, schemas)"
echo "  - TypeScript files (agent definitions)"
echo ""
echo -e "${GREEN}Press Ctrl+C to stop${NC}"
echo ""

# Function to call project inspector
call_inspector() {
    local changed_file=$1
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] File changed: $changed_file${NC}"
    
    # Call the Edge Function
    response=$(curl -s -X POST "$SUPABASE_URL/functions/v1/project-inspector" \
        -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "root": "./",
            "patterns": [
                "**/agents/**/*.{yaml,yml,json,ts}",
                "**/scout/**/*.{yaml,yml,json,ts}",
                "**/*.agent.{yaml,yml,json,ts}",
                "**/pulser/**/*.{yaml,yml}",
                "**/claude/**/*.{yaml,yml}"
            ],
            "metadata": {
                "trigger": "file_watcher",
                "changed_file": "'"$changed_file"'",
                "timestamp": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"
            }
        }' \
        -w "\nHTTP_STATUS:%{http_code}")
    
    # Extract HTTP status
    http_status=$(echo "$response" | tail -n1 | cut -d: -f2)
    body=$(echo "$response" | sed '$d')
    
    # Check status
    if [ "$http_status" -eq 200 ]; then
        echo -e "${GREEN}✅ Project Inspector updated successfully${NC}"
        # Pretty print JSON response if jq is available
        if command -v jq &> /dev/null; then
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
        else
            echo "$body"
        fi
    else
        echo -e "${RED}❌ Project Inspector failed with status $http_status${NC}"
        echo "$body"
    fi
    
    echo ""
}

# Watch for file changes
chokidar "**/*.{yaml,yml,json,ts,tsx}" \
    --ignore "node_modules/**" \
    --ignore ".git/**" \
    --ignore "dist/**" \
    --ignore "build/**" \
    --ignore ".next/**" \
    --ignore "coverage/**" \
    --ignore "*.log" \
    --ignore ".env*" \
    -c 'bash -c "source '$0' && call_inspector {path}"' \
    --initial=false \
    --verbose