#!/usr/bin/env bash
# MindsDB ⇄ Supabase prod-ready preflight + live probe until GREEN
# Enhanced version with proper SQL quoting and error handling
# Part of SuperClaude framework implementation

set -euo pipefail

MINDSDB_URL="${MINDSDB_URL:-http://localhost:47334}"
BASE="$MINDSDB_URL"
HDR=(-H "Content-Type: application/json")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure jq is available
jqcheck() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Installing jq..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y jq >/dev/null
        elif command -v brew >/dev/null 2>&1; then
            brew install jq >/dev/null
        else
            echo "❌ Install jq manually"
            exit 1
        fi
    fi
}

# Safe SQL execution with proper JSON construction
sql() {
    local q="$1"
    curl -sS -X POST "$BASE/api/sql/query" "${HDR[@]}" \
        -d "$(jq -cn --arg q "$q" '{query:$q}')" \
        | jq .
}

# Single comprehensive probe run
run_probe_once() {
    local overall_ok=1
    echo -e "${BLUE}🔎 Running MindsDB preflight checks...${NC}"

    # 1) API status check
    echo -n "1️⃣ API Status... "
    local status_response
    if status_response=$(curl -sS "$BASE/api/status" 2>/dev/null) &&
       echo "$status_response" | jq -e '.mindsdb_version' >/dev/null 2>&1; then
        local version=$(echo "$status_response" | jq -r '.mindsdb_version')
        echo -e "${GREEN}✅ OK (v$version)${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        overall_ok=0
    fi

    # 2) Database availability check
    echo -n "2️⃣ Database Sources... "
    local dbs_response
    dbs_response=$(sql "SHOW DATABASES" 2>/dev/null)

    if echo "$dbs_response" | jq -e '.type == "table"' >/dev/null 2>&1; then
        local has_supabase
        has_supabase=$(echo "$dbs_response" | jq -e '.data[] | select(.[0] == "supabase_scout")' >/dev/null && echo true || echo false)

        if [[ "$has_supabase" == "true" ]]; then
            echo -e "${GREEN}✅ supabase_scout available${NC}"
        else
            echo -e "${RED}❌ supabase_scout NOT found${NC}"
            overall_ok=0
        fi
    else
        echo -e "${RED}❌ SHOW DATABASES failed${NC}"
        if echo "$dbs_response" | jq -e '.type == "error"' >/dev/null 2>&1; then
            echo "   Error: $(echo "$dbs_response" | jq -r '.error_message')"
        fi
        overall_ok=0
    fi

    # 3) Schema enumeration
    echo -n "3️⃣ Schema Access... "
    local schemas_response
    schemas_response=$(sql "SELECT schema_name FROM supabase_scout.information_schema.schemata WHERE schema_name NOT IN ('pg_catalog','information_schema') ORDER BY 1" 2>/dev/null)

    if echo "$schemas_response" | jq -e '.type == "table"' >/dev/null 2>&1; then
        local schema_count=$(echo "$schemas_response" | jq '.data | length')
        echo -e "${GREEN}✅ $schema_count schemas accessible${NC}"
    else
        echo -e "${RED}❌ Schema enumeration failed${NC}"
        if echo "$schemas_response" | jq -e '.type == "error"' >/dev/null 2>&1; then
            echo "   Error: $(echo "$schemas_response" | jq -r '.error_message')"
        fi
        overall_ok=0
    fi

    # 4) Table enumeration (scout schema specifically)
    echo -n "4️⃣ Scout Tables... "
    local tables_response
    tables_response=$(sql "SELECT table_name FROM supabase_scout.information_schema.tables WHERE table_schema = 'scout' AND table_type = 'BASE TABLE' ORDER BY table_name LIMIT 10" 2>/dev/null)

    if echo "$tables_response" | jq -e '.type == "table"' >/dev/null 2>&1; then
        local table_count=$(echo "$tables_response" | jq '.data | length')
        echo -e "${GREEN}✅ $table_count scout tables found${NC}"
    else
        echo -e "${RED}❌ Scout table enumeration failed${NC}"
        if echo "$tables_response" | jq -e '.type == "error"' >/dev/null 2>&1; then
            echo "   Error: $(echo "$tables_response" | jq -r '.error_message')"
        fi
        overall_ok=0
    fi

    # 5) Data sampling (auto-detect first available table)
    echo -n "5️⃣ Data Sampling... "
    local meta_response
    meta_response=$(sql "SELECT table_schema, table_name FROM supabase_scout.information_schema.tables WHERE table_schema = 'scout' AND table_type = 'BASE TABLE' ORDER BY table_name LIMIT 1" 2>/dev/null)

    if echo "$meta_response" | jq -e '.type == "table" and (.data | length > 0)' >/dev/null 2>&1; then
        local schema=$(echo "$meta_response" | jq -r '.data[0][0]')
        local table=$(echo "$meta_response" | jq -r '.data[0][1]')

        # Use proper double quotes for identifiers
        local sample_query="SELECT * FROM supabase_scout.\"$schema\".\"$table\" LIMIT 2"
        local sample_response
        sample_response=$(sql "$sample_query" 2>/dev/null)

        if echo "$sample_response" | jq -e '.type == "table"' >/dev/null 2>&1; then
            local record_count=$(echo "$sample_response" | jq '.data | length')
            echo -e "${GREEN}✅ $record_count records from $schema.$table${NC}"
        else
            echo -e "${RED}❌ Data sampling failed${NC}"
            if echo "$sample_response" | jq -e '.type == "error"' >/dev/null 2>&1; then
                echo "   Error: $(echo "$sample_response" | jq -r '.error_message')"
            fi
            overall_ok=0
        fi
    else
        echo -e "${RED}❌ No tables found for sampling${NC}"
        overall_ok=0
    fi

    # 6) Performance test
    echo -n "6️⃣ Performance... "
    local start_time=$(date +%s%3N)
    curl -sS "$BASE/api/status" >/dev/null 2>&1
    local end_time=$(date +%s%3N)
    local response_time=$((end_time - start_time))

    if [ $response_time -lt 100 ]; then
        echo -e "${GREEN}✅ ${response_time}ms (Excellent)${NC}"
    elif [ $response_time -lt 500 ]; then
        echo -e "${YELLOW}⚠️ ${response_time}ms (Acceptable)${NC}"
    else
        echo -e "${RED}❌ ${response_time}ms (Poor)${NC}"
        overall_ok=0
    fi

    return $overall_ok
}

# Main execution with retry logic
main() {
    jqcheck

    local MAX_TRIES=${MAX_TRIES:-30}
    local SLEEP_SECS=${SLEEP_SECS:-5}
    local try=1

    echo -e "${BLUE}🤖 MindsDB Preflight Checker${NC}"
    echo "================================"
    echo "Target: $MINDSDB_URL"
    echo "Max attempts: $MAX_TRIES (${SLEEP_SECS}s intervals)"
    echo ""

    while (( try <= MAX_TRIES )); do
        echo -e "${BLUE}🔄 Attempt $try/$MAX_TRIES${NC}"

        if run_probe_once; then
            echo ""
            echo -e "${GREEN}🟢 GREEN: MindsDB ⇄ Supabase is production-ready!${NC}"
            echo ""
            echo "✅ All systems operational:"
            echo "   • API responding with proper version info"
            echo "   • supabase_scout database connected"
            echo "   • Schema enumeration working"
            echo "   • Scout tables accessible"
            echo "   • Data sampling successful with proper quoting"
            echo "   • Performance within acceptable limits"
            echo ""
            echo "🚀 Ready for ML model deployment and predictive analytics!"
            exit 0
        else
            echo ""
            if (( try < MAX_TRIES )); then
                echo -e "${YELLOW}⏳ Not green yet. Retrying in ${SLEEP_SECS}s...${NC}"
                sleep "$SLEEP_SECS"
            fi
            try=$((try+1))
        fi
        echo ""
    done

    echo -e "${RED}🔴 FAILED: Could not reach GREEN status within $MAX_TRIES attempts${NC}"
    echo ""
    echo "❌ Issues detected:"
    echo "   • Check MindsDB container status: docker ps | grep mindsdb"
    echo "   • Verify Supabase connection configuration"
    echo "   • Review network connectivity"
    echo "   • Check MindsDB logs: docker logs claude-mindsdb"
    echo ""
    echo "🔧 Quick fixes:"
    echo "   1. Restart MindsDB: docker restart claude-mindsdb"
    echo "   2. Check port mapping: docker port claude-mindsdb"
    echo "   3. Verify database registration in MindsDB"

    exit 2
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "MindsDB Preflight Checker"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --quick        Run single check (no retries)"
        echo "  --verbose      Show detailed output"
        echo ""
        echo "Environment Variables:"
        echo "  MINDSDB_URL    MindsDB server URL (default: http://localhost:47334)"
        echo "  MAX_TRIES      Maximum attempts (default: 30)"
        echo "  SLEEP_SECS     Retry interval in seconds (default: 5)"
        exit 0
        ;;
    --quick)
        MAX_TRIES=1
        ;;
    --verbose)
        set -x
        ;;
esac

# Run the preflight checks
main "$@"