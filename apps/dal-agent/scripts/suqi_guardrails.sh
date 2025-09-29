#!/usr/bin/env bash
# =================================================================
# Suqi Analytics Guardrail Queries
# Post-suqi-validate CI checks for operational health
# =================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[GUARDRAIL]${NC} $*"
}

success() {
    echo -e "${GREEN}✅${NC} $*"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $*"
}

error() {
    echo -e "${RED}❌${NC} $*" >&2
}

check_guardrail() {
    local name="$1"
    local query="$2"
    local expected="$3"
    local severity="${4:-error}"  # error, warn, info

    log "Checking $name..."

    local result
    if result=$("$SCRIPT_DIR/sql.sh" -Q "$query" 2>/dev/null | tail -1 | tr -d ' \r\n'); then
        if [[ "$expected" == ">0" ]]; then
            if [[ "$result" -gt "0" ]]; then
                success "$name: $result (>0 ✓)"
                return 0
            else
                if [[ "$severity" == "error" ]]; then
                    error "$name: $result (expected >0)"
                    return 1
                else
                    warning "$name: $result (expected >0)"
                    return 0
                fi
            fi
        elif [[ "$expected" == ">=30%" ]]; then
            # Special case for coverage percentage
            if [[ "$result" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$result >= 30" | bc -l 2>/dev/null) )); then
                success "$name: ${result}% (≥30% ✓)"
                return 0
            else
                warning "$name: ${result}% (<30%)"
                return 0
            fi
        elif [[ "$result" == "$expected" ]]; then
            success "$name: $result ✓"
            return 0
        else
            if [[ "$severity" == "error" ]]; then
                error "$name: $result (expected $expected)"
                return 1
            else
                warning "$name: $result (expected $expected)"
                return 0
            fi
        fi
    else
        if [[ "$severity" == "error" ]]; then
            error "$name: Query failed"
            return 1
        else
            warning "$name: Query failed (non-critical)"
            return 0
        fi
    fi
}

main() {
    echo -e "${BLUE}🛡️ Running Suqi Analytics Guardrail Checks${NC}"
    echo ""

    local failed_checks=0

    # Critical guardrails (must pass)
    echo -e "${BLUE}=== Critical Guardrails ===${NC}"

    check_guardrail "Intel Transcripts Count" \
        "SELECT COUNT(*) FROM intel.transcripts;" \
        ">0" "error" || failed_checks=$((failed_checks + 1))

    check_guardrail "Intel Persona Inference Count" \
        "SELECT COUNT(*) FROM intel.persona_inference;" \
        ">0" "error" || failed_checks=$((failed_checks + 1))

    check_guardrail "STT Jobs Table Structure" \
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='intel' AND TABLE_NAME='stt_jobs';" \
        ">0" "error" || failed_checks=$((failed_checks + 1))

    # Health guardrails (warnings only)
    echo ""
    echo -e "${BLUE}=== Health Guardrails ===${NC}"

    # Persona coverage heuristic
    local persona_count
    persona_count=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM intel.persona_inference;" 2>/dev/null | tail -1 | tr -d ' \r\n' || echo "0")
    local transcript_count
    transcript_count=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM intel.transcripts;" 2>/dev/null | tail -1 | tr -d ' \r\n' || echo "1")

    if [[ "$persona_count" -gt "0" ]] && [[ "$transcript_count" -gt "0" ]]; then
        local coverage_pct
        coverage_pct=$(echo "scale=1; $persona_count * 100 / $transcript_count" | bc 2>/dev/null || echo "0")
        check_guardrail "Persona Coverage" "SELECT '$coverage_pct'" ">=30%" "warn"
    else
        warning "Persona Coverage: No data to calculate"
    fi

    check_guardrail "STT Jobs Processing Success Rate" \
        "SELECT CASE WHEN COUNT(*) = 0 THEN 100 ELSE ROUND(CAST(COUNT(CASE WHEN status='done' THEN 1 END) AS FLOAT) * 100 / COUNT(*), 1) END FROM intel.stt_jobs WHERE status IN ('done','error');" \
        ">0" "warn"

    check_guardrail "Recent Transcripts (Last 7 Days)" \
        "SELECT COUNT(*) FROM intel.transcripts WHERE created_utc >= DATEADD(day, -7, SYSUTCDATETIME());" \
        ">0" "warn"

    # Operational guardrails (info only)
    echo ""
    echo -e "${BLUE}=== Operational Metrics ===${NC}"

    check_guardrail "Active Stores with Transcripts" \
        "SELECT COUNT(DISTINCT store_id) FROM intel.transcripts WHERE store_id IS NOT NULL;" \
        ">0" "info"

    check_guardrail "Brand Mentions Detected" \
        "SELECT COUNT(*) FROM intel.segment_brands;" \
        ">0" "info"

    check_guardrail "Conversation Segments" \
        "SELECT COUNT(*) FROM intel.conversation_segments;" \
        ">0" "info"

    # Final results
    echo ""
    if [[ $failed_checks -eq 0 ]]; then
        echo -e "${GREEN}🎉 All critical guardrails passed!${NC}"
        echo -e "${GREEN}✅ Suqi Analytics platform is operationally healthy${NC}"
        exit 0
    else
        echo -e "${RED}🚨 $failed_checks critical guardrail(s) failed${NC}"
        echo -e "${RED}❌ Platform requires attention before production use${NC}"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--quiet]"
        echo ""
        echo "Guardrail checks for Suqi Analytics operational health:"
        echo ""
        echo "Critical (must pass):"
        echo "  - Intel transcripts and persona inference counts > 0"
        echo "  - STT jobs table structure exists"
        echo ""
        echo "Health (warnings):"
        echo "  - Persona coverage ≥30%"
        echo "  - STT processing success rate"
        echo "  - Recent transcript activity"
        echo ""
        echo "Operational (informational):"
        echo "  - Store coverage, brand mentions, conversation segments"
        exit 0
        ;;
    --quiet)
        # Suppress detailed output, show only pass/fail
        main "$@" 2>&1 | grep -E "(✅|❌|🎉|🚨)" || true
        exit ${PIPESTATUS[0]}
        ;;
    *)
        main "$@"
        ;;
esac