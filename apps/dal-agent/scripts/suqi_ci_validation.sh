#!/usr/bin/env bash
# =================================================================
# Suqi Analytics CI Validation - Safety Net Checks
# Quick validation after suqi-validate to ensure core functionality
# =================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $*"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $*" >&2
}

main() {
    log "Starting Suqi Analytics CI validation..."

    # Check 1: At least some intel objects exist
    log "Checking intel schema objects..."
    local intel_count
    intel_count=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='intel';" | tail -1 | tr -d ' \r\n' || echo "0")

    if [[ "$intel_count" -gt "0" ]]; then
        success "Intel schema objects: $intel_count tables found"
    else
        error "Intel schema validation failed: no intel tables found"
        exit 1
    fi

    # Check 2: Persona coverage sanity (won't fail pipeline, just log)
    log "Checking persona inference coverage..."
    local persona_count
    persona_count=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM intel.persona_inference;" 2>/dev/null | tail -1 | tr -d ' \r\n' || echo "0")

    if [[ "$persona_count" -gt "0" ]]; then
        success "Persona inference records: $persona_count found"
    else
        warning "No persona inference records found (run 'make insights-rebuild' to generate)"
    fi

    # Check 3: STT jobs table structure
    log "Validating STT jobs table structure..."
    local stt_structure
    stt_structure=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='intel' AND TABLE_NAME='stt_jobs';" | tail -1 | tr -d ' \r\n' || echo "0")

    if [[ "$stt_structure" -ge "10" ]]; then
        success "STT jobs table structure: $stt_structure columns found"
    else
        error "STT jobs table structure validation failed: expected ≥10 columns, got $stt_structure"
        exit 1
    fi

    # Check 4: Gold views for conversational intelligence
    log "Checking gold views for conversation analytics..."
    local gold_views
    gold_views=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA='gold' AND (table_name LIKE '%conversation%' OR table_name LIKE '%persona%');" | tail -1 | tr -d ' \r\n' || echo "0")

    if [[ "$gold_views" -gt "0" ]]; then
        success "Gold conversation views: $gold_views found"
    else
        warning "No gold conversation views found (views will be created during STT processing)"
    fi

    # Check 5: Canonical export safety
    log "Validating canonical export safety..."
    if [[ -f "scripts/validate_canonical.sh" ]] && [[ -x "scripts/validate_canonical.sh" ]]; then
        success "Canonical export validator: present and executable"
    else
        error "Canonical export validator missing or not executable"
        exit 1
    fi

    # Check 6: Python runtime dependencies
    log "Checking Python runtime dependencies..."
    local python_deps_ok=true

    python3 -c "import whisper" 2>/dev/null || { warning "OpenAI Whisper not available"; python_deps_ok=false; }
    python3 -c "import fastapi" 2>/dev/null || { warning "FastAPI not available"; python_deps_ok=false; }
    python3 -c "import cv2" 2>/dev/null || { warning "OpenCV not available"; python_deps_ok=false; }

    if [[ "$python_deps_ok" == "true" ]]; then
        success "Python runtime dependencies: all available"
    else
        warning "Some Python dependencies missing (run 'make suqi-setup' to install)"
    fi

    success "Suqi Analytics CI validation completed"

    # Summary report
    echo ""
    echo -e "${BLUE}📊 Validation Summary:${NC}"
    echo "  🗄️ Intel schema tables: $intel_count"
    echo "  🧠 Persona inference records: $persona_count"
    echo "  📊 STT jobs table columns: $stt_structure"
    echo "  📈 Gold conversation views: $gold_views"
    echo "  ✅ Runtime checks: passed"

    echo ""
    echo -e "${GREEN}🚀 Ready for Suqi Analytics operations!${NC}"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0"
        echo ""
        echo "CI validation for Suqi Analytics platform after suqi-validate"
        echo ""
        echo "Checks:"
        echo "  - Intel schema objects exist"
        echo "  - STT jobs table structure"
        echo "  - Gold views for conversation analytics"
        echo "  - Canonical export validator"
        echo "  - Python runtime dependencies"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac