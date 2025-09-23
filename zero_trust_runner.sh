#!/bin/bash
# ==========================================
# Zero-Trust Location System Runner
# One-shot validator and store management
# ==========================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_URL="${DATABASE_URL:-postgresql://postgres.cxzllzyxwpyptfretryc:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres}"

# Validation functions
run_integrity_check() {
    echo -e "${BLUE}Running zero-trust integrity check...${NC}"

    local result=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT string_agg(
            format('%s: %s violations (Status: %s)',
                check_name,
                violations,
                CASE WHEN violations = 0 THEN 'PASS' ELSE 'FAIL' END
            ),
            E'\n'
        )
        FROM check_zero_trust_integrity();
    ")

    echo -e "${GREEN}Integrity Check Results:${NC}"
    echo "$result"

    # Check if any violations
    local violations=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT SUM(violations) FROM check_zero_trust_integrity();
    ")

    if [[ "$violations" -eq 0 ]]; then
        echo -e "${GREEN}✅ All integrity checks PASSED${NC}"
        return 0
    else
        echo -e "${RED}❌ $violations total violations detected${NC}"
        return 1
    fi
}

run_health_summary() {
    echo -e "${BLUE}Generating system health summary...${NC}"

    PGPASSWORD='Postgres_26' psql "$DB_URL" -c "
        SELECT
            metric,
            value,
            percentage || '%' as percentage,
            CASE status
                WHEN 'EXCELLENT' THEN '✅ ' || status
                WHEN 'GOOD' THEN '🟢 ' || status
                WHEN 'ACCEPTABLE' THEN '🟡 ' || status
                WHEN 'NEEDS_ATTENTION' THEN '🔴 ' || status
                ELSE status
            END as status
        FROM zero_trust_health_summary()
        ORDER BY
            CASE metric
                WHEN 'Total Transactions' THEN 1
                WHEN 'Verified Transactions' THEN 2
                WHEN 'Unknown Municipalities' THEN 3
                WHEN 'Stores in Dimension' THEN 4
                ELSE 5
            END;
    "
}

run_store_report() {
    echo -e "${BLUE}Generating store verification report...${NC}"

    PGPASSWORD='Postgres_26' psql "$DB_URL" -c "
        SELECT
            store_id,
            store_name,
            municipality,
            transactions,
            verified_transactions,
            verification_rate_pct || '%' as verification_rate,
            CASE
                WHEN in_dimension THEN '✅ In Dim'
                ELSE '❌ Missing'
            END as dimension_status
        FROM store_verification_report()
        ORDER BY store_id;
    "
}

add_store() {
    local store_id="$1"
    local store_name="$2"
    local municipality="$3"
    local barangay="${4:-Unknown}"
    local latitude="${5:-}"
    local longitude="${6:-}"

    echo -e "${BLUE}Adding/updating Store $store_id: $store_name${NC}"
    echo "Location: $municipality, $barangay"

    if [[ -n "$latitude" && -n "$longitude" ]]; then
        echo "Coordinates: $latitude, $longitude"
    fi

    local sql="SELECT * FROM add_store_with_rebuild(
        p_store_id := $store_id,
        p_store_name := '$store_name',
        p_municipality := '$municipality',
        p_barangay := '$barangay'"

    if [[ -n "$latitude" && -n "$longitude" ]]; then
        sql+=", p_latitude := $latitude, p_longitude := $longitude"
    fi

    sql+=");"

    local result=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "$sql")
    echo -e "${GREEN}✅ $result${NC}"

    # Run integrity check after addition
    echo -e "${YELLOW}Validating after store addition...${NC}"
    run_integrity_check
}

monitor_regressions() {
    echo -e "${BLUE}Checking for regressions...${NC}"

    # Check for any Unknown municipalities (should be 0)
    local unknown_count=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT COUNT(*)
        FROM public.fact_transactions_location
        WHERE payload_json -> 'location' ->> 'municipality' = 'Unknown';
    ")

    if [[ "$unknown_count" -eq 0 ]]; then
        echo -e "${GREEN}✅ No Unknown municipalities detected${NC}"
    else
        echo -e "${RED}❌ $unknown_count transactions with Unknown municipalities${NC}"
    fi

    # Check verification rate
    local verification_rate=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT ROUND(
            (COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) * 100.0 / COUNT(*)),
            2
        )
        FROM public.fact_transactions_location;
    ")

    echo -e "${BLUE}Current verification rate: ${verification_rate}%${NC}"

    if (( $(echo "$verification_rate >= 95.0" | bc -l) )); then
        echo -e "${GREEN}✅ Verification rate excellent${NC}"
    elif (( $(echo "$verification_rate >= 80.0" | bc -l) )); then
        echo -e "${YELLOW}🟡 Verification rate good${NC}"
    else
        echo -e "${RED}❌ Verification rate needs attention${NC}"
    fi
}

show_help() {
    cat << EOF
Zero-Trust Location System Runner

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    check           Run integrity checks and validation
    health          Show system health summary
    stores          Show store verification report
    monitor         Check for regressions and monitoring
    add-store       Add/update store with coordinates
    full-report     Run all reports
    help            Show this help message

ADD-STORE USAGE:
    $0 add-store STORE_ID "STORE_NAME" "MUNICIPALITY" [BARANGAY] [LATITUDE] [LONGITUDE]

EXAMPLES:
    $0 check                                    # Run integrity validation
    $0 health                                   # Show health summary
    $0 stores                                   # Show store report
    $0 monitor                                  # Check for regressions
    $0 add-store 115 "New Store" "Marikina" "Barangay 1" 14.632830 121.102183
    $0 full-report                             # Generate complete report

ENVIRONMENT:
    DATABASE_URL    PostgreSQL connection string (optional)

EOF
}

generate_full_report() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}Zero-Trust Location System Full Report${NC}"
    echo -e "${BLUE}Generated: $(date)${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo

    run_integrity_check
    echo

    run_health_summary
    echo

    run_store_report
    echo

    monitor_regressions
    echo

    echo -e "${BLUE}===========================================${NC}"
    echo -e "${GREEN}Report Complete${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

# Main execution
main() {
    local command="${1:-help}"

    case "$command" in
        check)
            run_integrity_check
            ;;
        health)
            run_health_summary
            ;;
        stores)
            run_store_report
            ;;
        monitor)
            monitor_regressions
            ;;
        add-store)
            if [[ $# -lt 4 ]]; then
                echo -e "${RED}Error: add-store requires at least STORE_ID, STORE_NAME, and MUNICIPALITY${NC}"
                echo "Usage: $0 add-store STORE_ID \"STORE_NAME\" \"MUNICIPALITY\" [BARANGAY] [LATITUDE] [LONGITUDE]"
                exit 1
            fi
            add_store "${2}" "${3}" "${4}" "${5:-}" "${6:-}" "${7:-}"
            ;;
        full-report)
            generate_full_report
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql is required but not installed${NC}"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}Warning: bc not found, some calculations may not work${NC}"
fi

# Run main function with all arguments
main "$@"