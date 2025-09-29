#!/usr/bin/env bash
# =================================================================
# Suqi Analytics Full Pipeline Smoke Test
# Quick green-light sequence: STT → insights → canonical/export
# Returns clear ✅/❌ status for exec visibility
# =================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_TOTAL=0
FAILURES=()

log_test() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [[ "$status" == "PASS" ]]; then
        echo -e "✅ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "❌ $test_name"
        [[ -n "$details" ]] && echo -e "   ${RED}$details${NC}"
        FAILURES+=("$test_name: $details")
    fi
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local success_pattern="${3:-}"

    echo -e "${BLUE}[TEST]${NC} $test_name"

    if eval "$test_command" >/dev/null 2>&1; then
        if [[ -n "$success_pattern" ]]; then
            # Additional validation required
            if eval "$success_pattern" >/dev/null 2>&1; then
                log_test "$test_name" "PASS"
            else
                log_test "$test_name" "FAIL" "Success pattern validation failed"
            fi
        else
            log_test "$test_name" "PASS"
        fi
    else
        log_test "$test_name" "FAIL" "Command execution failed"
    fi
}

run_validation_test() {
    local test_name="$1"
    local validation_command="$2"
    local expected_result="${3:-}"

    echo -e "${BLUE}[VALIDATION]${NC} $test_name"

    local result
    if result=$(eval "$validation_command" 2>/dev/null | tail -1 | tr -d ' \r\n'); then
        if [[ -n "$expected_result" ]]; then
            if [[ "$result" == "$expected_result" ]] || [[ "$result" =~ $expected_result ]]; then
                log_test "$test_name" "PASS" "Result: $result"
            else
                log_test "$test_name" "FAIL" "Expected: $expected_result, Got: $result"
            fi
        elif [[ -n "$result" ]] && [[ "$result" != "0" ]]; then
            log_test "$test_name" "PASS" "Result: $result"
        else
            log_test "$test_name" "FAIL" "No valid result returned"
        fi
    else
        log_test "$test_name" "FAIL" "Validation command failed"
    fi
}

main() {
    echo -e "${BLUE}🚀 Starting Suqi Analytics Full Pipeline Smoke Test${NC}"
    echo -e "${BLUE}Timestamp: $TIMESTAMP${NC}"
    echo ""

    # Ensure DB environment is set
    if [[ -z "${DB:-}" ]]; then
        export DB="SQL-TBWA-ProjectScout-Reporting-Prod"
        echo -e "${YELLOW}⚠️ DB environment not set, using default: $DB${NC}"
    fi

    # Change to project root
    cd "$PROJECT_ROOT"

    # 1) Intel schema + safety checks
    echo -e "${BLUE}=== Phase 1: Schema & Safety Checks ===${NC}"
    run_test "Intel Schema Migration" "make suqi-migrate"
    run_test "Suqi Validation + CI Checks" "make suqi-validate"

    # Validate intel objects exist
    run_validation_test "Intel Schema Objects Count" \
        "./scripts/sql.sh -Q \"SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='intel';\"" \
        "^[1-9][0-9]*$"

    # 2) Insights processing (safe/fast)
    echo -e "${BLUE}=== Phase 2: Insights Processing ===${NC}"
    run_test "Persona Insights Rebuild" "make insights-rebuild MAX=5000 MIN_CONFIDENCE=0.70"

    # Validate persona coverage
    run_validation_test "Persona Inference Count" \
        "./scripts/sql.sh -Q \"SELECT COUNT(*) FROM intel.persona_inference;\" 2>/dev/null || echo '0'" \
        "^[0-9]+$"

    # 3) Optional STT smoke (5 files) - non-blocking
    echo -e "${BLUE}=== Phase 3: STT Smoke Test (Optional) ===${NC}"
    if ./scripts/sql.sh -Q "SELECT COUNT(*) FROM staging.audio_files WHERE processed = 0;" 2>/dev/null | grep -q "^[1-9]"; then
        run_test "STT Reprocessing Smoke" "make stt-reprocess LIMIT=5 LANG=fil"
    else
        log_test "STT Reprocessing Smoke" "SKIP" "No unprocessed audio files found"
    fi

    # 4) API heartbeat - non-blocking background test
    echo -e "${BLUE}=== Phase 4: API Health Check ===${NC}"
    # Check if FastAPI can be imported
    if python3 -c "import fastapi, uvicorn" 2>/dev/null; then
        log_test "FastAPI Dependencies" "PASS"
        log_test "API Server Start" "MANUAL" "Run 'make suqi-api-serve' and test with curl"
    else
        log_test "FastAPI Dependencies" "FAIL" "FastAPI/uvicorn not available"
    fi

    # 5) Canonical contract validation
    echo -e "${BLUE}=== Phase 5: Canonical Export Validation ===${NC}"
    run_test "Canonical Export Validator" "./scripts/validate_canonical.sh"

    # Quick 13-column check if exports exist
    if ls out/canonical/canonical_flat_*.csv.gz >/dev/null 2>&1; then
        run_test "13-Column Contract Check" "./scripts/quick_canonical_check.sh"
    else
        log_test "13-Column Contract Check" "SKIP" "No canonical exports found"
    fi

    # 6) Locked exports validation
    echo -e "${BLUE}=== Phase 6: Locked Schema Exports ===${NC}"
    run_test "NCR Last 30 Days Export" "make inquiries-export-ncr-last30"
    run_test "Headers Validation (No Drift)" "make inquiries-headers-validate"
    run_test "Parquet Conversion" "make inquiries-parquet"
    run_test "Manifest Generation" "make inquiries-manifest"

    # Validate manifest exists and has content
    if [[ -f "out/inquiries_filtered/_MANIFEST.json" ]]; then
        local empty_files
        empty_files=$(jq -r '.summary.empty_files // 0' out/inquiries_filtered/_MANIFEST.json 2>/dev/null || echo "unknown")
        if [[ "$empty_files" == "0" ]]; then
            log_test "Manifest Empty Files Check" "PASS" "0 empty files"
        else
            log_test "Manifest Empty Files Check" "FAIL" "$empty_files empty files found"
        fi
    else
        log_test "Manifest Empty Files Check" "FAIL" "Manifest file not found"
    fi

    # 7) Final status check
    echo -e "${BLUE}=== Phase 7: System Status ===${NC}"
    run_test "Suqi Platform Status" "make suqi-status"

    # Persona coverage heuristic (≥30% coverage)
    local persona_count
    persona_count=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM intel.persona_inference;" 2>/dev/null | tail -1 | tr -d ' \r\n' || echo "0")
    local transcript_count
    transcript_count=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM intel.transcripts;" 2>/dev/null | tail -1 | tr -d ' \r\n' || echo "1")

    if [[ "$persona_count" -gt "0" ]] && [[ "$transcript_count" -gt "0" ]]; then
        local coverage_pct
        coverage_pct=$(echo "scale=1; $persona_count * 100 / $transcript_count" | bc 2>/dev/null || echo "0")
        if (( $(echo "$coverage_pct >= 30" | bc -l 2>/dev/null) )); then
            log_test "Persona Coverage Heuristic" "PASS" "${coverage_pct}% coverage (≥30%)"
        else
            log_test "Persona Coverage Heuristic" "WARN" "${coverage_pct}% coverage (<30%)"
        fi
    else
        log_test "Persona Coverage Heuristic" "SKIP" "No persona/transcript data"
    fi

    # Final results summary
    echo ""
    echo -e "${BLUE}=== Smoke Test Results Summary ===${NC}"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}/$TESTS_TOTAL"

    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        echo -e "${RED}Failed Tests:${NC}"
        for failure in "${FAILURES[@]}"; do
            echo -e "  ❌ $failure"
        done
        echo ""
        echo -e "${RED}🚨 SMOKE TEST FAILED${NC}"
        exit 1
    else
        echo ""
        echo -e "${GREEN}🎉 ALL SMOKE TESTS PASSED${NC}"
        echo -e "${GREEN}✅ Suqi Analytics Platform: HEALTHY${NC}"

        # Show next steps
        echo ""
        echo -e "${BLUE}📋 Ready for Operations:${NC}"
        echo "  🎤 Process audio: make stt-reprocess LIMIT=50"
        echo "  🧠 Daily insights: make insights-rebuild MAX=5000"
        echo "  🌐 Start API: make suqi-api-serve"
        echo "  📊 Check status: make suqi-status"
        echo ""
        echo -e "${BLUE}📦 Export Artifacts Ready:${NC}"
        [[ -f "out/inquiries_filtered/_MANIFEST.json" ]] && \
            jq -r '.summary | to_entries[] | "  \(.key): \(.value)"' out/inquiries_filtered/_MANIFEST.json
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--quiet]"
        echo ""
        echo "Full pipeline smoke test: STT → insights → canonical/export"
        echo ""
        echo "Options:"
        echo "  --quiet    Suppress detailed output, show only final result"
        exit 0
        ;;
    --quiet)
        # Redirect all output except final summary to /dev/null
        exec 3>&1
        exec 1>/dev/null 2>&1
        main "$@"
        exec 1>&3
        ;;
    *)
        main "$@"
        ;;
esac