#!/usr/bin/env bash
# =================================================================
# Suqi Analytics One-Tap Operational Flows
# Recommended workflows for different operational scenarios
# =================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $*"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $*" >&2
}

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

deploy_everything() {
    log "🚀 Deploy Everything Once - Complete Suqi Analytics Platform"
    make suqi-deploy
    success "Complete platform deployed"
}

daily_insights() {
    log "📊 Daily Operations - Insights Only"
    make insights-rebuild MAX=5000
    make suqi-status
    success "Daily insights processing completed"
}

weekly_stt() {
    log "🎤 Weekly Operations - Small STT Batch + Insights"
    make stt-reprocess LIMIT=50
    make insights-rebuild MAX=2000
    make suqi-status
    success "Weekly STT and insights processing completed"
}

locked_exports() {
    log "📦 Locked Schema Exports + Validation"
    make inquiries-export-ncr-last30
    make inquiries-headers-validate
    make inquiries-parquet
    make inquiries-manifest
    success "Locked schema exports with validation completed"

    log "📋 Export artifacts summary:"
    if [[ -f "out/inquiries_filtered/_MANIFEST.json" ]]; then
        jq -r '.summary | to_entries[] | "  \(.key): \(.value)"' out/inquiries_filtered/_MANIFEST.json
    fi
}

canonical_safety() {
    log "🔒 Canonical Export Safety Check"
    make canonical-export-prod
    make canonical-snapshot-record
    bash scripts/quick_canonical_check.sh
    make canonical-validate-script
    success "Canonical export safety validation completed"
}

smoke_test() {
    log "🔥 Complete Smoke Test Pipeline"
    make inquiries-smoke
    success "Complete smoke test passed"
}

show_help() {
    echo "Suqi Analytics One-Tap Operational Flows"
    echo ""
    echo "Usage: $0 <flow>"
    echo ""
    echo "Available flows:"
    echo "  deploy-everything  - Complete platform deployment (first time)"
    echo "  daily-insights     - Daily insights processing (MAX=5000)"
    echo "  weekly-stt         - Weekly STT batch (LIMIT=50) + insights"
    echo "  locked-exports     - Locked schema exports with validation"
    echo "  canonical-safety   - Canonical export with safety checks"
    echo "  smoke-test         - Complete pipeline smoke test"
    echo ""
    echo "Examples:"
    echo "  $0 deploy-everything    # First-time setup"
    echo "  $0 daily-insights       # Daily operations"
    echo "  $0 weekly-stt           # Weekly processing"
    echo "  $0 locked-exports       # Export with validation"
}

main() {
    case "${1:-}" in
        deploy-everything)
            deploy_everything
            ;;
        daily-insights)
            daily_insights
            ;;
        weekly-stt)
            weekly_stt
            ;;
        locked-exports)
            locked_exports
            ;;
        canonical-safety)
            canonical_safety
            ;;
        smoke-test)
            smoke_test
            ;;
        --help|-h|help)
            show_help
            ;;
        *)
            echo "❌ Unknown flow: ${1:-}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"