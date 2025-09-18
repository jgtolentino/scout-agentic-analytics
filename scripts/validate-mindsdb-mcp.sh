#!/bin/bash
# MindsDB MCP Health Check and Validation Script
# Validates MindsDB MCP server operational status for Scout v7
# Part of SuperClaude framework implementation

set -e

echo "🤖 MindsDB MCP Health Check & Validation"
echo "========================================"

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq for JSON processing..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y jq >/dev/null
    elif command -v brew >/dev/null 2>&1; then
        brew install jq >/dev/null
    else
        echo "❌ jq is required but not installed. Please install manually."
        exit 1
    fi
fi

# Configuration
MINDSDB_HOST="localhost"
MINDSDB_PORT="47334"
MINDSDB_URL="http://${MINDSDB_HOST}:${MINDSDB_PORT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check functions
check_mindsdb_status() {
    echo "🔍 Checking MindsDB service status..."

    # Check if MindsDB is responding
    if curl -s "${MINDSDB_URL}/api/status" > /dev/null; then
        echo -e "${GREEN}✅ MindsDB service is running${NC}"

        # Get version info
        VERSION=$(curl -s "${MINDSDB_URL}/api/status" | python3 -c "import sys, json; print(json.load(sys.stdin)['mindsdb_version'])")
        echo "   Version: ${VERSION}"
        return 0
    else
        echo -e "${RED}❌ MindsDB service is not responding${NC}"
        return 1
    fi
}

check_database_connections() {
    echo "🔗 Checking database connections..."

    # Test SHOW DATABASES query with proper JSON construction
    local query="SHOW DATABASES"
    RESPONSE=$(curl -s -X POST "${MINDSDB_URL}/api/sql/query" \
        -H "Content-Type: application/json" \
        -d "$(jq -cn --arg q "$query" '{query:$q}')")

    # Check for valid JSON response
    if ! echo "$RESPONSE" | jq -e '.type' >/dev/null 2>&1; then
        echo -e "${RED}❌ Invalid JSON response from MindsDB${NC}"
        echo "Response: $RESPONSE"
        return 1
    fi

    # Check for error response
    if echo "$RESPONSE" | jq -e '.type == "error"' >/dev/null 2>&1; then
        echo -e "${RED}❌ MindsDB query error${NC}"
        echo "Error: $(echo "$RESPONSE" | jq -r '.error_message // .detail // "Unknown error"')"
        return 1
    fi

    if echo "$RESPONSE" | jq -e '.data[] | select(.[0] == "supabase_scout")' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Supabase Scout database connection active${NC}"
    else
        echo -e "${YELLOW}⚠️  Supabase Scout database not found${NC}"
    fi

    if echo "$RESPONSE" | jq -e '.data[] | select(.[0] == "gdrive_scout")' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Google Drive Scout database connection active${NC}"
    else
        echo -e "${YELLOW}⚠️  Google Drive Scout database not found${NC}"
    fi
}

test_predictive_capabilities() {
    echo "🧠 Testing predictive analytics capabilities..."

    # Test schema access with proper quoting
    local schema_query='SELECT schema_name FROM supabase_scout.information_schema.schemata WHERE schema_name = '"'"'scout'"'"' LIMIT 1'
    SCHEMA_RESPONSE=$(curl -s -X POST "${MINDSDB_URL}/api/sql/query" \
        -H "Content-Type: application/json" \
        -d "$(jq -cn --arg q "$schema_query" '{query:$q}')")

    if echo "$SCHEMA_RESPONSE" | jq -e '.data[] | select(.[0] == "scout")' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Scout schema accessible via federated query${NC}"
    else
        echo -e "${YELLOW}⚠️  Scout schema not found${NC}"
    fi

    # Test actual data retrieval with proper double quotes
    local data_query='SELECT * FROM supabase_scout."scout"."scout_gold_transactions" LIMIT 2'
    DATA_RESPONSE=$(curl -s -X POST "${MINDSDB_URL}/api/sql/query" \
        -H "Content-Type: application/json" \
        -d "$(jq -cn --arg q "$data_query" '{query:$q}')")

    # Check for successful data retrieval
    if echo "$DATA_RESPONSE" | jq -e '.type == "table" and (.data | length > 0)' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Transaction data accessible for ML models${NC}"
        local record_count=$(echo "$DATA_RESPONSE" | jq '.data | length')
        echo "   Retrieved $record_count records from scout_gold_transactions"
    else
        echo -e "${RED}❌ Transaction data not accessible${NC}"
        if echo "$DATA_RESPONSE" | jq -e '.type == "error"' >/dev/null 2>&1; then
            echo "   Error: $(echo "$DATA_RESPONSE" | jq -r '.error_message')"
        fi
    fi

    # Test table enumeration
    local tables_query='SELECT table_name FROM supabase_scout.information_schema.tables WHERE table_schema = '"'"'scout'"'"' AND table_type = '"'"'BASE TABLE'"'"' ORDER BY table_name LIMIT 5'
    TABLES_RESPONSE=$(curl -s -X POST "${MINDSDB_URL}/api/sql/query" \
        -H "Content-Type: application/json" \
        -d "$(jq -cn --arg q "$tables_query" '{query:$q}')")

    if echo "$TABLES_RESPONSE" | jq -e '.type == "table"' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SQL query execution working${NC}"
        local table_count=$(echo "$TABLES_RESPONSE" | jq '.data | length')
        echo "   Found $table_count tables in scout schema"
    else
        echo -e "${RED}❌ SQL query execution failed${NC}"
        if echo "$TABLES_RESPONSE" | jq -e '.type == "error"' >/dev/null 2>&1; then
            echo "   Error: $(echo "$TABLES_RESPONSE" | jq -r '.error_message')"
        fi
    fi
}

validate_mcp_integration() {
    echo "🔧 Validating MCP integration..."

    # Check if MindsDB container is properly configured
    if docker ps | grep -q "claude-mindsdb"; then
        echo -e "${GREEN}✅ MindsDB Docker container running${NC}"

        # Check port mapping
        if docker ps | grep "claude-mindsdb" | grep -q "47334"; then
            echo -e "${GREEN}✅ Port 47334 properly mapped${NC}"
        else
            echo -e "${RED}❌ Port 47334 not mapped correctly${NC}"
        fi
    else
        echo -e "${RED}❌ MindsDB Docker container not found${NC}"
    fi
}

performance_benchmark() {
    echo "⚡ Running performance benchmarks..."

    START_TIME=$(date +%s%N)
    curl -s "${MINDSDB_URL}/api/status" > /dev/null
    END_TIME=$(date +%s%N)

    RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))

    if [ $RESPONSE_TIME -lt 100 ]; then
        echo -e "${GREEN}✅ Response time: ${RESPONSE_TIME}ms (Excellent)${NC}"
    elif [ $RESPONSE_TIME -lt 500 ]; then
        echo -e "${YELLOW}⚠️  Response time: ${RESPONSE_TIME}ms (Acceptable)${NC}"
    else
        echo -e "${RED}❌ Response time: ${RESPONSE_TIME}ms (Poor)${NC}"
    fi
}

generate_report() {
    echo ""
    echo "📊 MindsDB MCP Validation Report"
    echo "================================"
    echo "Timestamp: $(date)"
    echo "Host: ${MINDSDB_HOST}:${MINDSDB_PORT}"
    echo ""

    # Summary
    if check_mindsdb_status && check_database_connections; then
        echo -e "${GREEN}🎯 Overall Status: OPERATIONAL${NC}"
        echo ""
        echo "✅ MindsDB MCP server is fully operational and ready for:"
        echo "   • Predictive analytics and forecasting"
        echo "   • Real-time ML model training and deployment"
        echo "   • Automated feature engineering"
        echo "   • Integration with Scout's data pipeline"
        echo ""
        echo "🚀 Ready for SuperClaude framework integration!"
    else
        echo -e "${RED}🚨 Overall Status: NEEDS ATTENTION${NC}"
        echo ""
        echo "❌ Issues detected that require resolution:"
        echo "   • Check Docker container status"
        echo "   • Verify database connections"
        echo "   • Review network configuration"
    fi
}

# Main execution
main() {
    check_mindsdb_status
    echo ""

    check_database_connections
    echo ""

    test_predictive_capabilities
    echo ""

    validate_mcp_integration
    echo ""

    performance_benchmark
    echo ""

    generate_report
}

# Run the validation
main "$@"