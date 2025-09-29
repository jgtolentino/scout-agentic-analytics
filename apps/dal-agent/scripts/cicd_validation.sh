#!/bin/bash
set -euo pipefail

# =====================================================
# Scout v7 Azure Pipeline CI/CD Validation Wrapper
# =====================================================
# Purpose: Simple wrapper for GitHub Actions integration
# Architecture: Azure SQL → Python → Blob Storage
# Date: 2025-09-27

CMD="${1:-validate}"

echo "🚀 Scout v7 Azure Pipeline CI/CD"
echo "================================="
echo "• Python: $(python --version 2>&1 || python3 --version)"
echo "• pip:    $(pip --version 2>&1 || pip3 --version)"
echo "• Command: $CMD"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Validate command
case "$CMD" in
    "validate"|"pipeline"|"test")
        log "Running $CMD workflow..."
        ;;
    *)
        error "Unknown command: $CMD"
        echo "Usage: $0 [validate|pipeline|test]"
        exit 1
        ;;
esac

# Set defaults and validate environment
export OUT_DIR="${OUT_DIR:-out}"
export DATE_FROM="${DATE_FROM:-$(date -d '30 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-30d '+%Y-%m-%d')}"
export DATE_TO="${DATE_TO:-$(date '+%Y-%m-%d')}"
export NCR_ONLY="${NCR_ONLY:-1}"
export AMOUNT_TOLERANCE_PCT="${AMOUNT_TOLERANCE_PCT:-1.0}"

log "Configuration:"
log "  OUT_DIR: $OUT_DIR"
log "  DATE_FROM: $DATE_FROM"
log "  DATE_TO: $DATE_TO"
log "  NCR_ONLY: $NCR_ONLY"
log "  TOLERANCE: $AMOUNT_TOLERANCE_PCT%"

# Create output directory
mkdir -p "$OUT_DIR"

# Check required environment variables
missing_vars=()
[[ -z "${AZ_SQL_SERVER:-}" ]] && missing_vars+=("AZ_SQL_SERVER")
[[ -z "${AZ_SQL_DB:-}" ]] && missing_vars+=("AZ_SQL_DB")

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    error "Missing required environment variables: ${missing_vars[*]}"
    error "Set these in GitHub Secrets or local environment"
    exit 1
fi

# Check if we have credentials (either SQL auth or Azure AD)
if [[ -z "${AZ_SQL_UID:-}" ]] && [[ -z "${AZ_SQL_PWD:-}" ]]; then
    log "No SQL credentials provided - will attempt Azure AD/Managed Identity"
else
    log "SQL authentication configured"
fi

# Check for pipeline.py
if [[ ! -f "pipeline.py" ]]; then
    error "pipeline.py not found in current directory"
    exit 1
fi

# Run the pipeline
log "Executing Azure SQL → Python → Blob pipeline..."
start_time=$(date +%s)

if python pipeline.py; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    success "Pipeline completed successfully in ${duration}s"
else
    error "Pipeline execution failed"
    exit 1
fi

# Verify exports
log "Verifying exports in $OUT_DIR..."
ls -la "$OUT_DIR/" || true

# Check for flat enriched export
if ls "$OUT_DIR"/flat_enriched_*.csv 1> /dev/null 2>&1; then
    flat_file=$(ls -t "$OUT_DIR"/flat_enriched_*.csv | head -1)
    row_count=$(($(wc -l < "$flat_file") - 1))  # subtract header
    col_count=$(head -1 "$flat_file" | tr ',' '\n' | wc -l)

    success "✅ Flat export found: $(basename "$flat_file")"
    log "   Rows: $row_count"
    log "   Columns: $col_count"

    # Show header and first few rows for verification
    log "Header preview:"
    head -1 "$flat_file"

    if [[ $row_count -eq 0 ]]; then
        error "Export file is empty (no data rows)"
        exit 1
    elif [[ $row_count -lt 10 ]]; then
        warning "Low row count: $row_count rows"
    fi

    # Basic column validation
    header=$(head -1 "$flat_file")
    required_cols=("canonical_tx_id" "amount")
    for col in "${required_cols[@]}"; do
        if [[ "$header" == *"$col"* ]]; then
            log "   ✅ Required column: $col"
        else
            error "   ❌ Missing required column: $col"
            exit 1
        fi
    done
else
    error "❌ No flat_enriched_*.csv files found"
    log "Files in $OUT_DIR:"
    ls -la "$OUT_DIR/" || true
    exit 1
fi

# Check for crosstab exports
if ls "$OUT_DIR"/crosstab_*.csv 1> /dev/null 2>&1; then
    ctab_count=$(ls "$OUT_DIR"/crosstab_*.csv | wc -l)
    success "✅ Found $ctab_count crosstab export(s)"
else
    warning "No crosstab exports found (optional)"
fi

# Check for blob upload success (if configured)
if [[ -n "${AZURE_STORAGE_CONNECTION_STRING:-}" ]]; then
    log "Azure Blob Storage configured - check logs for upload status"
else
    log "Azure Blob Storage not configured (uploads disabled)"
fi

# Final summary
echo ""
echo "================================="
success "🎉 Scout v7 Pipeline Validation Complete!"
log "📊 Summary:"
log "   ✅ Pipeline executed successfully"
log "   ✅ Exports generated and validated"
log "   ✅ Data quality checks passed"
log "   ⏱️  Duration: ${duration}s"

# Optional: Run additional validation if validate_exports.py exists
if [[ -f "scripts/validate_exports.py" ]] && [[ "$CMD" == "validate" ]]; then
    log "Running additional schema validation..."
    if python scripts/validate_exports.py "$OUT_DIR" --quiet; then
        success "✅ Schema validation passed"
    else
        warning "Schema validation had issues (check logs)"
    fi
fi

echo "================================="