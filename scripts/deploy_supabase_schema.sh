#!/bin/bash
# Deploy SQL schema to Supabase using REST API
# MCP-enabled version with automatic context loading
# Usage: ./deploy_supabase_schema.sh <schema_file> [supabase_url] [supabase_key]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if MCP context is available
load_mcp_context() {
    # Check for MCP context file
    if [ -n "$SUPABASE_MCP_CONTEXT" ] && [ -f "$SUPABASE_MCP_CONTEXT" ]; then
        MCP_CONTEXT_FILE="$SUPABASE_MCP_CONTEXT"
    elif [ -f ".mcp/context.json" ]; then
        MCP_CONTEXT_FILE=".mcp/context.json"
    elif [ -f ".supabase/mcp-context.json" ]; then
        MCP_CONTEXT_FILE=".supabase/mcp-context.json"
    elif [ -f "mcp-context.json" ]; then
        MCP_CONTEXT_FILE="mcp-context.json"
    else
        return 1
    fi
    
    # Extract values from MCP context
    if command -v jq >/dev/null 2>&1; then
        SUPABASE_URL=$(jq -r '.project.rest_url // .url' "$MCP_CONTEXT_FILE" 2>/dev/null)
        SUPABASE_KEY=$(jq -r '.tokens.service_role // .service_role_key' "$MCP_CONTEXT_FILE" 2>/dev/null)
        PROJECT_REF=$(jq -r '.project.ref // .project_ref' "$MCP_CONTEXT_FILE" 2>/dev/null)
        BRANCH=$(jq -r '.branch.name // .branch // "main"' "$MCP_CONTEXT_FILE" 2>/dev/null)
        
        if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ]; then
            echo -e "${GREEN}[Fully/MCP] ✅ Context loaded from: $MCP_CONTEXT_FILE${NC}"
            echo -e "[Fully/MCP] 📦 Project: $PROJECT_REF"
            echo -e "[Fully/MCP] 🌿 Branch: $BRANCH"
            return 0
        fi
    fi
    
    return 1
}

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}[Fully] ❌ Error: Missing schema file${NC}"
    echo "Usage: $0 <schema_file> [supabase_url] [supabase_key]"
    echo "Example: $0 ./out/schema.sql"
    echo ""
    echo "If URL and KEY are not provided, they will be loaded from:"
    echo "  1. MCP context file (if running via MCP)"
    echo "  2. Environment variables (SUPABASE_URL, SUPABASE_KEY)"
    exit 1
fi

SCHEMA_FILE=$1

# Try to load from MCP context first
if [ $# -lt 3 ]; then
    if load_mcp_context; then
        echo -e "${GREEN}[Fully/MCP] 🔐 Using MCP context for authentication${NC}"
    else
        # Fall back to environment variables
        if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ]; then
            echo -e "${YELLOW}[Fully] ⚠️  Using environment variables${NC}"
        else
            echo -e "${RED}[Fully] ❌ Error: No Supabase credentials found${NC}"
            echo ""
            echo "Please either:"
            echo "  1. Run via MCP: npx @supabase/mcp-server-supabase run --agent fully"
            echo "  2. Set SUPABASE_URL and SUPABASE_KEY environment variables"
            echo "  3. Provide URL and KEY as arguments"
            exit 1
        fi
    fi
else
    # Use provided arguments
    SUPABASE_URL=$2
    SUPABASE_KEY=$3
fi

# Validate schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}[Fully] ❌ Error: Schema file not found: $SCHEMA_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}[Fully] 🚀 Deploying schema to Supabase...${NC}"
echo "[Fully] 📄 Schema file: $SCHEMA_FILE"
echo "[Fully] 🌐 Target: $SUPABASE_URL"

# Read schema content and escape for JSON
SCHEMA_CONTENT=$(cat "$SCHEMA_FILE" | \
    sed 's/\\/\\\\/g' | \
    sed 's/"/\\"/g' | \
    sed ':a;N;$!ba;s/\n/\\n/g')

# Create JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "query": "$SCHEMA_CONTENT"
}
EOF
)

# Deploy via Supabase REST API
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/exec_sql" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "$JSON_PAYLOAD" 2>&1)

# Check if curl command succeeded
if [ $? -ne 0 ]; then
    echo -e "${RED}[Fully] ❌ Deployment failed: Connection error${NC}"
    echo "$RESPONSE"
    exit 1
fi

# Check for error in response
if echo "$RESPONSE" | grep -q '"error"'; then
    echo -e "${RED}[Fully] ❌ Deployment failed${NC}"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    exit 1
fi

# Alternative method if exec_sql is not available
if echo "$RESPONSE" | grep -q "function exec_sql"; then
    echo -e "${YELLOW}[Fully] ⚠️  exec_sql not available, trying alternative method...${NC}"
    
    # Try using the SQL Editor endpoint (if available)
    RESPONSE=$(curl -s -X POST "$SUPABASE_URL/rest/v1/" \
      -H "apikey: $SUPABASE_KEY" \
      -H "Authorization: Bearer $SUPABASE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$JSON_PAYLOAD" 2>&1)
    
    if [ $? -ne 0 ] || echo "$RESPONSE" | grep -q '"error"'; then
        echo -e "${RED}[Fully] ❌ Alternative deployment also failed${NC}"
        echo -e "${YELLOW}[Fully] 💡 You may need to deploy manually via Supabase Dashboard${NC}"
        echo -e "${YELLOW}    1. Go to $SUPABASE_URL${NC}"
        echo -e "${YELLOW}    2. Navigate to SQL Editor${NC}"
        echo -e "${YELLOW}    3. Paste contents of $SCHEMA_FILE${NC}"
        echo -e "${YELLOW}    4. Run the query${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}[Fully] ✅ Schema deployed successfully!${NC}"

# Display summary
echo "[Fully] 📊 Deployment Summary:"
echo "  - Timestamp: $(date)"
echo "  - Schema: $SCHEMA_FILE"
echo "  - Target: $SUPABASE_URL"

# Optional: List tables (if possible)
echo -e "${YELLOW}[Fully] 🔍 Verifying deployment...${NC}"
TABLES_RESPONSE=$(curl -s -X GET "$SUPABASE_URL/rest/v1/" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" 2>&1)

if [ $? -eq 0 ] && ! echo "$TABLES_RESPONSE" | grep -q '"error"'; then
    echo -e "${GREEN}[Fully] ✅ API endpoint is accessible${NC}"
else
    echo -e "${YELLOW}[Fully] ⚠️  Could not verify tables via API${NC}"
fi

echo -e "${GREEN}[Fully] 🎉 Deployment complete!${NC}"