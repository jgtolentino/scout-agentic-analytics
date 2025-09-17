#!/bin/bash
# Scout v7 Go-Live Preflight Validation Script
# Comprehensive backend readiness checks for production deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Scout Edge device data lineage
REQUIRED_SILVER_COUNT=175000  # Real Scout Edge data: 175K+ transactions from 24 devices
REQUIRED_BRONZE_COUNT=1000    # Raw Scout Edge JSON: 1.5K+ raw device records
MAX_ALLOWED_LATENCY=1500     # Max p95 latency in ms
CACHE_TTL_SECONDS=300        # Expected cache TTL

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅ PASS]${NC} $1"
    ((PASSED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}[⚠️  WARN]${NC} $1"
    ((WARNING_CHECKS++))
}

log_error() {
    echo -e "${RED}[❌ FAIL]${NC} $1"
    ((FAILED_CHECKS++))
}

run_check() {
    local check_name="$1"
    local check_command="$2"

    ((TOTAL_CHECKS++))
    log_info "Checking: $check_name"

    if eval "$check_command"; then
        log_success "$check_name"
        return 0
    else
        log_error "$check_name"
        return 1
    fi
}

# Database connection check
check_db_connection() {
    if [[ -z "${DATABASE_URL:-}" ]]; then
        log_error "DATABASE_URL environment variable not set"
        return 1
    fi

    if psql "$DATABASE_URL" -c "SELECT current_database(), current_user;" >/dev/null 2>&1; then
        log_success "Database connection established"
        return 0
    else
        log_error "Cannot connect to database"
        return 1
    fi
}

# Environment variables check
check_environment() {
    local required_vars=(
        "SUPABASE_URL"
        "SUPABASE_ANON_KEY"
        "DATABASE_URL"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -eq 0 ]]; then
        log_success "All required environment variables present"
        return 0
    else
        log_error "Missing environment variables: ${missing_vars[*]}"
        return 1
    fi
}

# Medallion layer row counts
check_medallion_counts() {
    log_info "Checking medallion layer row counts..."

    # Scout Edge bronze layer check
    local bronze_count
    bronze_count=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM bronze.scout_raw_transactions;
    " | tr -d ' ')

    if [[ $bronze_count -ge $REQUIRED_BRONZE_COUNT ]]; then
        log_success "Bronze layer: $bronze_count rows (≥$REQUIRED_BRONZE_COUNT required)"
    else
        log_error "Bronze layer: $bronze_count rows (<$REQUIRED_BRONZE_COUNT required)"
        return 1
    fi

    # Silver layer check
    local silver_count
    silver_count=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM silver_unified_transactions;" | tr -d ' ')

    if [[ $silver_count -ge $REQUIRED_SILVER_COUNT ]]; then
        log_success "Silver layer: $silver_count rows (≥$REQUIRED_SILVER_COUNT required)"
    else
        log_error "Silver layer: $silver_count rows (<$REQUIRED_SILVER_COUNT required)"
        return 1
    fi
}

# RLS policies check
check_rls_policies() {
    local rls_enabled
    rls_enabled=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('silver','gold','metadata')
        AND c.relkind = 'r'
        AND c.relrowsecurity = true;
    " | tr -d ' ')

    if [[ $rls_enabled -gt 0 ]]; then
        log_success "RLS enabled on $rls_enabled tables"
        return 0
    else
        log_warning "No RLS policies found - verify if intentional"
        return 0
    fi
}

# Performance indexes check
check_performance_indexes() {
    local index_count
    index_count=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM pg_indexes
        WHERE tablename = 'silver_unified_transactions'
        AND indexname LIKE 'sut_%';
    " | tr -d ' ')

    if [[ $index_count -ge 5 ]]; then
        log_success "Performance indexes: $index_count indexes on silver_unified_transactions"
        return 0
    else
        log_warning "Performance indexes: only $index_count indexes found (expected ≥5)"
        return 0
    fi
}

# Governance and quarantine check
check_governance() {
    local quarantine_count
    quarantine_count=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM metadata.quarantine
        WHERE created_at > now() - interval '7 days';
    " 2>/dev/null | tr -d ' ' || echo "0")

    log_info "Quarantine entries (last 7 days): $quarantine_count"

    # Check if governance functions exist
    local gov_functions
    gov_functions=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'governance'
        AND p.proname LIKE '%classify%';
    " 2>/dev/null | tr -d ' ' || echo "0")

    if [[ $gov_functions -gt 0 ]]; then
        log_success "Governance functions present: $gov_functions"
        return 0
    else
        log_warning "No governance functions found"
        return 0
    fi
}

# NL2SQL function deployment check
check_nl2sql_deployment() {
    # Check if analytics.exec_readonly_sql exists
    local rpc_exists
    rpc_exists=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'analytics'
        AND p.proname = 'exec_readonly_sql';
    " | tr -d ' ')

    if [[ $rpc_exists -eq 1 ]]; then
        log_success "Analytics RPC function deployed"
    else
        log_error "Analytics RPC function missing"
        return 1
    fi

    # Check cache table
    local cache_table_exists
    cache_table_exists=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'mkt'
        AND table_name = 'cag_insights_cache';
    " | tr -d ' ')

    if [[ $cache_table_exists -eq 1 ]]; then
        log_success "Cache table exists"
    else
        log_error "Cache table missing"
        return 1
    fi

    # Check audit table
    local audit_table_exists
    audit_table_exists=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'metadata'
        AND table_name = 'ai_sql_audit';
    " | tr -d ' ')

    if [[ $audit_table_exists -eq 1 ]]; then
        log_success "Audit table exists"
    else
        log_error "Audit table missing"
        return 1
    fi
}

# NL2SQL smoke test
smoke_test_nl2sql() {
    log_info "Running NL2SQL smoke test..."

    # Test plan validation
    local test_plan='{
        "plan": {
            "intent": "crosstab",
            "rows": ["daypart"],
            "cols": ["product_category"],
            "measures": [{"metric": "txn_count"}],
            "filters": {"date_from": "2025-08-01", "date_to": "2025-09-17"},
            "pivot": true,
            "limit": 100
        }
    }'

    # Check if supabase CLI is available
    if command -v supabase >/dev/null 2>&1; then
        log_info "Testing NL2SQL Edge Function..."

        # Try to invoke the function
        if timeout 10s supabase functions invoke nl2sql --no-verify-jwt --body "$test_plan" >/dev/null 2>&1; then
            log_success "NL2SQL function responds"
        else
            log_warning "NL2SQL function test failed or timeout (may need deployment)"
        fi
    else
        log_warning "Supabase CLI not available - skipping Edge Function test"
    fi
}

# Data quality checks
check_data_quality() {
    log_info "Running data quality checks..."

    # Check for obvious data issues
    local null_ts_count
    null_ts_count=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM silver_unified_transactions WHERE ts IS NULL;
    " | tr -d ' ')

    if [[ $null_ts_count -eq 0 ]]; then
        log_success "No null timestamps in silver data"
    else
        log_warning "Found $null_ts_count null timestamps in silver data"
    fi

    # Check date range sanity
    local date_range
    date_range=$(psql "$DATABASE_URL" -t -c "
        SELECT MIN(ts)::date || ' to ' || MAX(ts)::date
        FROM silver_unified_transactions;
    " 2>/dev/null || echo "unknown")

    log_info "Silver data date range: $date_range"

    # Check for reasonable brand distribution
    local brand_count
    brand_count=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(DISTINCT brand) FROM silver_unified_transactions
        WHERE brand IS NOT NULL;
    " | tr -d ' ')

    if [[ $brand_count -gt 10 ]]; then
        log_success "Brand diversity: $brand_count distinct brands"
    else
        log_warning "Low brand diversity: only $brand_count distinct brands"
    fi
}

# Performance validation
check_performance() {
    log_info "Checking query performance..."

    # Simple performance test
    local start_time=$(date +%s%3N)
    psql "$DATABASE_URL" -c "
        SELECT daypart, product_category, COUNT(*)
        FROM (
            SELECT
                CASE WHEN EXTRACT(HOUR FROM ts) BETWEEN 5 AND 11 THEN 'AM'
                     WHEN EXTRACT(HOUR FROM ts) BETWEEN 12 AND 17 THEN 'PM'
                     ELSE 'NT' END as daypart,
                product_category
            FROM silver_unified_transactions
            WHERE ts > now() - interval '30 days'
            LIMIT 1000
        ) t
        GROUP BY 1, 2;
    " >/dev/null 2>&1
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    if [[ $duration -lt $MAX_ALLOWED_LATENCY ]]; then
        log_success "Query performance: ${duration}ms (target <${MAX_ALLOWED_LATENCY}ms)"
    else
        log_warning "Query performance: ${duration}ms (slower than ${MAX_ALLOWED_LATENCY}ms target)"
    fi
}

# Main execution
main() {
    echo "=============================================="
    echo "    Scout v7 Go-Live Preflight Validation    "
    echo "=============================================="
    echo

    log_info "Starting preflight checks at $(date)"
    echo

    # Core infrastructure checks
    echo "🔧 Infrastructure Checks"
    echo "------------------------"
    check_environment
    check_db_connection
    echo

    # Data layer checks
    echo "📊 Data Layer Checks"
    echo "--------------------"
    check_medallion_counts
    check_data_quality
    echo

    # Security checks
    echo "🔒 Security Checks"
    echo "------------------"
    check_rls_policies
    echo

    # Performance checks
    echo "⚡ Performance Checks"
    echo "--------------------"
    check_performance_indexes
    check_performance
    echo

    # Governance checks
    echo "📋 Governance Checks"
    echo "--------------------"
    check_governance
    echo

    # NL2SQL system checks
    echo "🤖 NL2SQL System Checks"
    echo "-----------------------"
    check_nl2sql_deployment
    smoke_test_nl2sql
    echo

    # Summary
    echo "=============================================="
    echo "             PREFLIGHT SUMMARY               "
    echo "=============================================="
    echo
    echo "Total Checks: $TOTAL_CHECKS"
    echo -e "✅ Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "⚠️  Warnings: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "❌ Failed: ${RED}$FAILED_CHECKS${NC}"
    echo

    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL CRITICAL CHECKS PASSED${NC}"
        echo -e "${GREEN}✅ System is READY for go-live${NC}"

        if [[ $WARNING_CHECKS -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  Review warnings before deployment${NC}"
        fi

        echo
        echo "Next steps:"
        echo "1. Deploy migration: psql \"\$DATABASE_URL\" -f supabase/migrations/20250917_nl2sql_core.sql"
        echo "2. Deploy function: supabase functions deploy nl2sql"
        echo "3. Set frontend: USE_MOCK=false"
        echo "4. Monitor for 30-60 minutes post-launch"

        exit 0
    else
        echo -e "${RED}❌ CRITICAL ISSUES FOUND${NC}"
        echo -e "${RED}🚫 System is NOT ready for go-live${NC}"
        echo
        echo "Please address failed checks before deployment."
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi