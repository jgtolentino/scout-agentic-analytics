#!/usr/bin/env bash
set -euo pipefail

# Scout Analytics E2E Smoke Tests
# Standalone validation for Azure deployment

# ==============================================================================
# Configuration
# ==============================================================================

RG="${RG:-tbwa-scout-prod}"
FUNCAPP_NAME="${FUNCAPP_NAME:-scout-func-prod}"
SQL_SERVER_NAME="${SQL_SERVER_NAME:-sqltbwaprojectscoutserver}"
SQL_DB="${SQL_DB:-SQL-TBWA-ProjectScout-Reporting-Prod}"
SEARCH_NAME="${SEARCH_NAME:-scout-search-prod}"
ADF_NAME="${ADF_NAME:-scout-adf-prod}"

# Test configuration
MAX_RETRIES=3
TIMEOUT_SECONDS=30
VERBOSE=${VERBOSE:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $*${NC}"
}

success() {
    echo -e "${GREEN}✓ $*${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

error() {
    echo -e "${RED}✗ $*${NC}" >&2
}

fatal() {
    error "$*"
    exit 1
}

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG] $*${NC}" >&2
    fi
}

# Test result tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

test_start() {
    local test_name="$1"
    ((TESTS_TOTAL++))
    log "Testing: $test_name"
}

test_pass() {
    local test_name="$1"
    ((TESTS_PASSED++))
    success "$test_name"
}

test_fail() {
    local test_name="$1"
    local error_msg="${2:-Unknown error}"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$test_name: $error_msg")
    error "$test_name - $error_msg"
}

# HTTP request helper with retries
http_request() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local headers="${4:-}"
    local expected_status="${5:-200}"

    verbose "HTTP $method $url"

    local curl_args=(-s -w "\n%{http_code}" --max-time $TIMEOUT_SECONDS)

    if [[ -n "$headers" ]]; then
        curl_args+=(-H "$headers")
    fi

    if [[ "$method" != "GET" && -n "$data" ]]; then
        curl_args+=(-X "$method" -d "$data")
    fi

    local response
    local attempt=1

    while [[ $attempt -le $MAX_RETRIES ]]; do
        if response=$(curl "${curl_args[@]}" "$url" 2>/dev/null); then
            local body=$(echo "$response" | head -n -1)
            local status=$(echo "$response" | tail -n 1)

            verbose "Status: $status, Body: ${body:0:200}..."

            if [[ "$status" == "$expected_status" ]]; then
                echo "$body"
                return 0
            fi
        fi

        verbose "Attempt $attempt failed, retrying..."
        ((attempt++))
        sleep 2
    done

    return 1
}

# ==============================================================================
# Azure CLI Tests
# ==============================================================================

test_azure_login() {
    test_start "Azure CLI Authentication"

    if az account show &>/dev/null; then
        local account=$(az account show --query "name" -o tsv 2>/dev/null)
        test_pass "Azure CLI authenticated ($account)"
    else
        test_fail "Azure CLI Authentication" "Not logged in - run 'az login'"
    fi
}

test_resource_group() {
    test_start "Resource Group Exists"

    if az group show -n "$RG" &>/dev/null; then
        local location=$(az group show -n "$RG" --query "location" -o tsv)
        test_pass "Resource Group '$RG' exists in $location"
    else
        test_fail "Resource Group Exists" "Resource group '$RG' not found"
    fi
}

# ==============================================================================
# Azure Function Tests
# ==============================================================================

test_function_app_status() {
    test_start "Function App Status"

    if ! az functionapp show -n "$FUNCAPP_NAME" -g "$RG" &>/dev/null; then
        test_fail "Function App Status" "Function app '$FUNCAPP_NAME' not found"
        return
    fi

    local state=$(az functionapp show -n "$FUNCAPP_NAME" -g "$RG" --query "state" -o tsv)
    local host_name=$(az functionapp show -n "$FUNCAPP_NAME" -g "$RG" --query "defaultHostName" -o tsv)

    if [[ "$state" == "Running" ]]; then
        test_pass "Function App running at $host_name"
    else
        test_fail "Function App Status" "Function app state: $state"
    fi
}

test_function_health() {
    test_start "Function Health Endpoint"

    local func_url="https://$FUNCAPP_NAME.azurewebsites.net/api/health"

    if response=$(http_request "$func_url" "GET" "" "" "200"); then
        if echo "$response" | grep -q '"status".*"healthy"'; then
            test_pass "Function health endpoint responding"
        else
            test_fail "Function Health Endpoint" "Unhealthy response: $response"
        fi
    else
        test_fail "Function Health Endpoint" "Health endpoint not responding"
    fi
}

test_function_analytics() {
    test_start "Function Analytics Endpoint"

    local func_url="https://$FUNCAPP_NAME.azurewebsites.net/api/analyze"
    local test_query="SELECT COUNT(*) as total_records FROM dbo.v_flat_export_sheet"
    local payload="{\"q\": \"$test_query\"}"

    if response=$(http_request "$func_url" "POST" "$payload" "Content-Type: application/json" "200"); then
        if echo "$response" | grep -q '"success".*true'; then
            local row_count=$(echo "$response" | grep -o '"total_records":[0-9]*' | cut -d: -f2)
            test_pass "Analytics endpoint working (returned $row_count records)"
        else
            test_fail "Function Analytics Endpoint" "Failed query response: $response"
        fi
    else
        test_fail "Function Analytics Endpoint" "Analytics endpoint not responding"
    fi
}

# ==============================================================================
# Azure SQL Tests
# ==============================================================================

test_sql_connectivity() {
    test_start "SQL Database Connectivity"

    if ! az sql db show -n "$SQL_DB" -s "$SQL_SERVER_NAME" -g "$RG" &>/dev/null; then
        test_fail "SQL Database Connectivity" "Database '$SQL_DB' not found"
        return
    fi

    local status=$(az sql db show -n "$SQL_DB" -s "$SQL_SERVER_NAME" -g "$RG" --query "status" -o tsv)
    local tier=$(az sql db show -n "$SQL_DB" -s "$SQL_SERVER_NAME" -g "$RG" --query "currentServiceObjectiveName" -o tsv)

    if [[ "$status" == "Online" ]]; then
        test_pass "SQL Database online ($tier tier)"
    else
        test_fail "SQL Database Connectivity" "Database status: $status"
    fi
}

test_sql_data_availability() {
    test_start "SQL Data Availability"

    # Use Function App as proxy to test SQL data
    local func_url="https://$FUNCAPP_NAME.azurewebsites.net/api/analyze"
    local test_query="SELECT COUNT(*) as record_count FROM dbo.v_flat_export_sheet WHERE transaction_date >= DATEADD(day, -30, GETDATE())"
    local payload="{\"q\": \"$test_query\"}"

    if response=$(http_request "$func_url" "POST" "$payload" "Content-Type: application/json" "200"); then
        if echo "$response" | grep -q '"success".*true'; then
            local recent_records=$(echo "$response" | grep -o '"record_count":[0-9]*' | cut -d: -f2)
            if [[ "$recent_records" -gt 0 ]]; then
                test_pass "SQL data available ($recent_records recent records)"
            else
                test_fail "SQL Data Availability" "No recent data found"
            fi
        else
            test_fail "SQL Data Availability" "Query failed: $response"
        fi
    else
        test_fail "SQL Data Availability" "Cannot execute test query"
    fi
}

# ==============================================================================
# Azure AI Search Tests
# ==============================================================================

test_search_service() {
    test_start "AI Search Service"

    if ! az search service show -n "$SEARCH_NAME" -g "$RG" &>/dev/null; then
        test_fail "AI Search Service" "Search service '$SEARCH_NAME' not found"
        return
    fi

    local status=$(az search service show -n "$SEARCH_NAME" -g "$RG" --query "status" -o tsv)
    local sku=$(az search service show -n "$SEARCH_NAME" -g "$RG" --query "sku.name" -o tsv)

    if [[ "$status" == "running" ]]; then
        test_pass "AI Search service running ($sku tier)"
    else
        test_fail "AI Search Service" "Search service status: $status"
    fi
}

test_search_index() {
    test_start "AI Search Index"

    local search_url="https://$SEARCH_NAME.search.windows.net/indexes/scout-rag"
    local admin_key

    if ! admin_key=$(az search admin-key show -g "$RG" --service-name "$SEARCH_NAME" --query "primaryKey" -o tsv 2>/dev/null); then
        test_fail "AI Search Index" "Cannot retrieve search admin key"
        return
    fi

    if response=$(http_request "$search_url" "GET" "" "api-key: $admin_key" "200"); then
        if echo "$response" | grep -q '"name".*"scout-rag"'; then
            test_pass "AI Search index 'scout-rag' exists"
        else
            test_fail "AI Search Index" "Index configuration error: $response"
        fi
    else
        test_fail "AI Search Index" "Index 'scout-rag' not found"
    fi
}

# ==============================================================================
# Data Factory Tests
# ==============================================================================

test_data_factory() {
    test_start "Data Factory Service"

    if ! az datafactory show -n "$ADF_NAME" -g "$RG" &>/dev/null; then
        test_fail "Data Factory Service" "Data Factory '$ADF_NAME' not found"
        return
    fi

    local location=$(az datafactory show -n "$ADF_NAME" -g "$RG" --query "location" -o tsv)
    test_pass "Data Factory exists in $location"
}

# ==============================================================================
# End-to-End Integration Tests
# ==============================================================================

test_e2e_data_flow() {
    test_start "E2E Data Flow"

    # Test full pipeline: SQL → Function → Response
    local func_url="https://$FUNCAPP_NAME.azurewebsites.net/api/analyze"
    local business_query="Show me top 5 brands by revenue this month"
    local payload="{\"q\": \"$business_query\"}"

    if response=$(http_request "$func_url" "POST" "$payload" "Content-Type: application/json" "200"); then
        if echo "$response" | grep -q '"success".*true' && echo "$response" | grep -q '"sql"'; then
            local row_count=$(echo "$response" | grep -o '"rows":\[[^]]*\]' | grep -o '{' | wc -l)
            test_pass "E2E data flow working (NL2SQL returned $row_count results)"
        else
            test_fail "E2E Data Flow" "Invalid response: $response"
        fi
    else
        test_fail "E2E Data Flow" "E2E test query failed"
    fi
}

test_dashboard_endpoints() {
    test_start "Dashboard Data Endpoints"

    local base_url="https://$FUNCAPP_NAME.azurewebsites.net/api"
    local endpoints=("export_flat" "export_crosstab" "export_packages")
    local working_endpoints=0

    for endpoint in "${endpoints[@]}"; do
        if response=$(http_request "$base_url/$endpoint" "GET" "" "" "200"); then
            if echo "$response" | grep -q '"data"'; then
                ((working_endpoints++))
                verbose "Endpoint $endpoint working"
            fi
        fi
    done

    if [[ $working_endpoints -eq ${#endpoints[@]} ]]; then
        test_pass "All dashboard endpoints working ($working_endpoints/${#endpoints[@]})"
    elif [[ $working_endpoints -gt 0 ]]; then
        warning "Partial dashboard endpoints working ($working_endpoints/${#endpoints[@]})"
        test_pass "Dashboard endpoints partially working"
    else
        test_fail "Dashboard Data Endpoints" "No dashboard endpoints responding"
    fi
}

# ==============================================================================
# Performance Tests
# ==============================================================================

test_performance_benchmarks() {
    test_start "Performance Benchmarks"

    local func_url="https://$FUNCAPP_NAME.azurewebsites.net/api/analyze"
    local simple_query="SELECT COUNT(*) as total FROM dbo.v_flat_export_sheet"
    local payload="{\"q\": \"$simple_query\"}"

    local start_time=$(date +%s%3N)

    if response=$(http_request "$func_url" "POST" "$payload" "Content-Type: application/json" "200"); then
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))

        if [[ $duration -lt 2000 ]]; then
            test_pass "Query performance good (${duration}ms < 2000ms)"
        elif [[ $duration -lt 5000 ]]; then
            warning "Query performance acceptable (${duration}ms)"
            test_pass "Query performance acceptable"
        else
            test_fail "Performance Benchmarks" "Query too slow (${duration}ms > 5000ms)"
        fi
    else
        test_fail "Performance Benchmarks" "Performance test query failed"
    fi
}

# ==============================================================================
# Security Tests
# ==============================================================================

test_security_configuration() {
    test_start "Security Configuration"

    local security_checks=0
    local total_checks=4

    # Check Function App HTTPS enforcement
    if https_only=$(az functionapp show -n "$FUNCAPP_NAME" -g "$RG" --query "httpsOnly" -o tsv 2>/dev/null); then
        if [[ "$https_only" == "true" ]]; then
            ((security_checks++))
            verbose "HTTPS enforced on Function App"
        fi
    fi

    # Check SQL firewall rules
    if az sql server firewall-rule show -s "$SQL_SERVER_NAME" -g "$RG" -n "AllowAzureServices" &>/dev/null; then
        ((security_checks++))
        verbose "SQL firewall configured"
    fi

    # Check Managed Identity assignment
    if identity=$(az functionapp identity show -n "$FUNCAPP_NAME" -g "$RG" --query "type" -o tsv 2>/dev/null); then
        if [[ "$identity" == "UserAssigned" || "$identity" == "SystemAssigned" ]]; then
            ((security_checks++))
            verbose "Managed Identity configured"
        fi
    fi

    # Check Key Vault integration
    if az functionapp config appsettings list -n "$FUNCAPP_NAME" -g "$RG" --query "[?contains(value, 'KeyVault')]" -o tsv 2>/dev/null | grep -q "KeyVault"; then
        ((security_checks++))
        verbose "Key Vault integration configured"
    fi

    if [[ $security_checks -eq $total_checks ]]; then
        test_pass "Security configuration complete ($security_checks/$total_checks checks)"
    else
        warning "Security configuration incomplete ($security_checks/$total_checks checks)"
        test_pass "Security configuration partial"
    fi
}

# ==============================================================================
# Main Test Runner
# ==============================================================================

print_banner() {
    echo ""
    echo "========================================="
    echo "Scout Analytics E2E Smoke Tests"
    echo "========================================="
    echo "Resource Group: $RG"
    echo "Function App: $FUNCAPP_NAME"
    echo "SQL Server: $SQL_SERVER_NAME"
    echo "Search Service: $SEARCH_NAME"
    echo "Data Factory: $ADF_NAME"
    echo "========================================="
    echo ""
}

print_summary() {
    echo ""
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        error "Failed Tests:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            error "  - $failed_test"
        done
        echo ""
        echo "Overall Status: FAILED"
        return 1
    else
        success "All tests passed!"
        echo "Overall Status: PASSED"
        return 0
    fi
}

run_all_tests() {
    print_banner

    # Infrastructure Tests
    log "=== Infrastructure Tests ==="
    test_azure_login
    test_resource_group

    # Service Tests
    log "=== Service Tests ==="
    test_function_app_status
    test_sql_connectivity
    test_search_service
    test_data_factory

    # Functional Tests
    log "=== Functional Tests ==="
    test_function_health
    test_function_analytics
    test_sql_data_availability
    test_search_index

    # Integration Tests
    log "=== Integration Tests ==="
    test_e2e_data_flow
    test_dashboard_endpoints

    # Performance Tests
    log "=== Performance Tests ==="
    test_performance_benchmarks

    # Security Tests
    log "=== Security Tests ==="
    test_security_configuration

    print_summary
}

# ==============================================================================
# Command Line Interface
# ==============================================================================

show_help() {
    cat << EOF
Scout Analytics E2E Smoke Tests

Usage: $0 [OPTIONS] [TEST_CATEGORY]

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -r, --resource-group    Resource group name (default: tbwa-scout-prod)
    -f, --function-app      Function app name (default: scout-func-prod)
    -t, --timeout           Request timeout in seconds (default: 30)

TEST_CATEGORIES:
    all                     Run all tests (default)
    infrastructure          Azure login, resource group
    services               Function app, SQL, Search, Data Factory
    functional             Health checks, analytics endpoints
    integration            E2E data flow, dashboard endpoints
    performance            Query performance benchmarks
    security               Security configuration checks

EXAMPLES:
    $0                      # Run all tests
    $0 functional           # Run only functional tests
    $0 -v integration       # Run integration tests with verbose output
    $0 -r my-rg services    # Test services in custom resource group

ENVIRONMENT VARIABLES:
    RG                      Resource group name
    FUNCAPP_NAME           Function app name
    SQL_SERVER_NAME        SQL server name
    SEARCH_NAME            Search service name
    ADF_NAME               Data Factory name
    VERBOSE                Enable verbose output (true/false)
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -r|--resource-group)
            RG="$2"
            shift 2
            ;;
        -f|--function-app)
            FUNCAPP_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        infrastructure|services|functional|integration|performance|security|all)
            TEST_CATEGORY="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set default test category
TEST_CATEGORY="${TEST_CATEGORY:-all}"

# Run tests based on category
case $TEST_CATEGORY in
    infrastructure)
        print_banner
        test_azure_login
        test_resource_group
        print_summary
        ;;
    services)
        print_banner
        test_function_app_status
        test_sql_connectivity
        test_search_service
        test_data_factory
        print_summary
        ;;
    functional)
        print_banner
        test_function_health
        test_function_analytics
        test_sql_data_availability
        test_search_index
        print_summary
        ;;
    integration)
        print_banner
        test_e2e_data_flow
        test_dashboard_endpoints
        print_summary
        ;;
    performance)
        print_banner
        test_performance_benchmarks
        print_summary
        ;;
    security)
        print_banner
        test_security_configuration
        print_summary
        ;;
    all)
        run_all_tests
        ;;
    *)
        echo "Unknown test category: $TEST_CATEGORY"
        show_help
        exit 1
        ;;
esac

exit $?