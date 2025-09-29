#!/usr/bin/env bash
# ========================================================================
# Canonical Export Wrapper Script
# Purpose: Standardized canonical exports with validation and compression
# ========================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
source "$ROOT/scripts/conn_default.sh" 2>/dev/null || true

# Configuration
OUTPUT_DIR="$ROOT/out/canonical"
LOG_FILE="$OUTPUT_DIR/export.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Usage function
usage() {
    cat << EOF
Canonical Export Script - Standardized 13-column flat exports

Usage: $0 [OPTIONS]

OPTIONS:
    -f, --date-from DATE    Start date filter (YYYY-MM-DD)
    -t, --date-to DATE      End date filter (YYYY-MM-DD)
    -r, --region REGION     Region filter
    -c, --category CATEGORY Category filter
    -s, --store STORE_ID    Store ID filter
    -o, --output FILE       Output filename (default: auto-generated)
    -C, --compress         Compress output with gzip
    -H, --no-header        Skip header row
    -v, --validate         Validate schema before export
    -q, --quiet            Minimal output
    -h, --help             Show this help

EXAMPLES:
    # Export all data
    $0

    # Export tobacco category for last month
    $0 --category tobacco --date-from 2025-08-01 --date-to 2025-08-31

    # Export specific region with compression
    $0 --region "Metro Manila" --compress

    # Export to specific file
    $0 --output my_export.csv

SPECIALIZED EXPORTS:
    --tobacco              Export tobacco category only
    --laundry              Export laundry category only
    --bulk                 Export all categories separately

EOF
}

# Parse command line arguments
parse_args() {
    DATE_FROM=""
    DATE_TO=""
    REGION=""
    CATEGORY=""
    STORE_ID=""
    OUTPUT_FILE=""
    COMPRESS=false
    INCLUDE_HEADER=true
    VALIDATE=true
    QUIET=false
    SPECIALIZED=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--date-from)
                DATE_FROM="$2"
                shift 2
                ;;
            -t|--date-to)
                DATE_TO="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -c|--category)
                CATEGORY="$2"
                shift 2
                ;;
            -s|--store)
                STORE_ID="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -C|--compress)
                COMPRESS=true
                shift
                ;;
            -H|--no-header)
                INCLUDE_HEADER=false
                shift
                ;;
            -v|--validate)
                VALIDATE=true
                shift
                ;;
            --no-validate)
                VALIDATE=false
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --tobacco)
                SPECIALIZED="tobacco"
                CATEGORY="tobacco"
                shift
                ;;
            --laundry)
                SPECIALIZED="laundry"
                CATEGORY="laundry"
                shift
                ;;
            --bulk)
                SPECIALIZED="bulk"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Generate output filename if not provided
    if [[ -z "$OUTPUT_FILE" ]]; then
        local filter_suffix=""
        [[ -n "$CATEGORY" ]] && filter_suffix="${filter_suffix}_${CATEGORY}"
        [[ -n "$REGION" ]] && filter_suffix="${filter_suffix}_$(echo "$REGION" | tr ' ' '_')"
        [[ -n "$DATE_FROM" ]] && filter_suffix="${filter_suffix}_from_${DATE_FROM}"
        [[ -n "$DATE_TO" ]] && filter_suffix="${filter_suffix}_to_${DATE_TO}"

        OUTPUT_FILE="canonical_flat${filter_suffix}_${TIMESTAMP}.csv"
    fi

    # Ensure .csv extension
    if [[ "$OUTPUT_FILE" != *.csv ]]; then
        OUTPUT_FILE="${OUTPUT_FILE}.csv"
    fi
}

# Validate database connection
validate_connection() {
    if [[ "$QUIET" != true ]]; then
        log "Validating database connection..."
    fi

    if ! "$ROOT/scripts/sql.sh" -Q "SELECT 1 as connection_test" >/dev/null 2>&1; then
        log_error "Database connection failed"
        exit 1
    fi

    if [[ "$QUIET" != true ]]; then
        log_success "Database connection validated"
    fi
}

# Validate canonical schema
validate_schema() {
    if [[ "$VALIDATE" != true ]]; then
        return 0
    fi

    if [[ "$QUIET" != true ]]; then
        log "Validating canonical schema compliance..."
    fi

    local validation_result
    validation_result=$("$ROOT/scripts/sql.sh" -Q "
        DECLARE @error_count int;
        EXEC @error_count = canonical.sp_validate_view_compliance
            @view_name = 'gold.v_transactions_flat_canonical',
            @throw_on_error = 0,
            @detailed_report = 0;
        SELECT @error_count as error_count;
    " 2>/dev/null | tail -1)

    if [[ "$validation_result" != "0" ]]; then
        log_error "Canonical schema validation failed ($validation_result errors)"
        log "Run with --no-validate to skip validation"
        exit 1
    fi

    if [[ "$QUIET" != true ]]; then
        log_success "Canonical schema validation passed"
    fi
}

# Build SQL parameters
build_sql_params() {
    local params=""
    local param_desc=""

    if [[ -n "$DATE_FROM" ]]; then
        params="$params, @date_from = '$DATE_FROM'"
        param_desc="$param_desc, DateFrom=$DATE_FROM"
    fi

    if [[ -n "$DATE_TO" ]]; then
        params="$params, @date_to = '$DATE_TO'"
        param_desc="$param_desc, DateTo=$DATE_TO"
    fi

    if [[ -n "$REGION" ]]; then
        params="$params, @region = '$REGION'"
        param_desc="$param_desc, Region=$REGION"
    fi

    if [[ -n "$CATEGORY" ]]; then
        params="$params, @category = '$CATEGORY'"
        param_desc="$param_desc, Category=$CATEGORY"
    fi

    if [[ -n "$STORE_ID" ]]; then
        params="$params, @store_id = '$STORE_ID'"
        param_desc="$param_desc, Store=$STORE_ID"
    fi

    # Remove leading comma
    if [[ -n "$params" ]]; then
        params="${params:2}"
        param_desc="${param_desc:2}"
    fi

    echo "$params"
}

# Execute export
execute_export() {
    local output_path="$OUTPUT_DIR/$OUTPUT_FILE"
    local params
    params=$(build_sql_params)

    if [[ "$QUIET" != true ]]; then
        log "Starting canonical export..."
        log "Output file: $output_path"
        if [[ -n "$params" ]]; then
            log "Filters: $params"
        fi
    fi

    # Create header if needed
    if [[ "$INCLUDE_HEADER" == true ]]; then
        echo "Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp" > "$output_path"
    else
        > "$output_path"  # Create empty file
    fi

    # Choose export procedure based on specialization
    local procedure="dbo.sp_export_canonical_flat"
    case "$SPECIALIZED" in
        tobacco)
            procedure="dbo.sp_export_canonical_tobacco"
            ;;
        laundry)
            procedure="dbo.sp_export_canonical_laundry"
            ;;
        bulk)
            procedure="dbo.sp_export_canonical_bulk"
            ;;
    esac

    # Execute export
    local sql_cmd="EXEC $procedure"
    if [[ -n "$params" ]]; then
        sql_cmd="$sql_cmd $params"
    fi

    # Add validation parameter
    sql_cmd="$sql_cmd, @validate_before_export = $(if [[ "$VALIDATE" == true ]]; then echo 1; else echo 0; fi)"

    if ! "$ROOT/scripts/sql.sh" -Q "$sql_cmd" -W -w 32767 -s"," -h -1 >> "$output_path" 2>>"$LOG_FILE"; then
        log_error "Export execution failed"
        return 1
    fi

    # Get row count (excluding header)
    local row_count
    if [[ "$INCLUDE_HEADER" == true ]]; then
        row_count=$(($(wc -l < "$output_path") - 1))
    else
        row_count=$(wc -l < "$output_path")
    fi

    if [[ "$QUIET" != true ]]; then
        log_success "Export completed: $row_count rows exported"
    fi

    # Compress if requested
    if [[ "$COMPRESS" == true ]]; then
        if [[ "$QUIET" != true ]]; then
            log "Compressing output..."
        fi

        gzip -9 "$output_path"
        local compressed_file="${output_path}.gz"
        local original_size compressed_size compression_ratio

        # Calculate compression ratio
        if command -v stat >/dev/null 2>&1; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                compressed_size=$(stat -f%z "$compressed_file")
            else
                # Linux
                compressed_size=$(stat -c%s "$compressed_file")
            fi

            # Estimate original size (compressed size * typical compression ratio)
            compression_ratio=$(echo "scale=1; $compressed_size * 3.5" | bc 2>/dev/null || echo "$compressed_size")

            if [[ "$QUIET" != true ]]; then
                log_success "Compressed: $compressed_file ($(numfmt --to=iec $compressed_size) compressed)"
            fi
        else
            if [[ "$QUIET" != true ]]; then
                log_success "Compressed: $compressed_file"
            fi
        fi

        OUTPUT_FILE="${OUTPUT_FILE}.gz"
    fi

    # Generate manifest
    generate_manifest "$OUTPUT_DIR/$OUTPUT_FILE" "$row_count"
}

# Generate export manifest
generate_manifest() {
    local file_path="$1"
    local row_count="$2"
    local manifest_file="$OUTPUT_DIR/export_manifest_${TIMESTAMP}.json"

    local file_size="0"
    local file_hash="unknown"

    if [[ -f "$file_path" ]]; then
        if command -v stat >/dev/null 2>&1; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                file_size=$(stat -f%z "$file_path")
            else
                file_size=$(stat -c%s "$file_path")
            fi
        fi

        if command -v md5sum >/dev/null 2>&1; then
            file_hash=$(md5sum "$file_path" | cut -d' ' -f1)
        elif command -v md5 >/dev/null 2>&1; then
            file_hash=$(md5 -q "$file_path")
        fi
    fi

    cat > "$manifest_file" << EOF
{
  "export_metadata": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "schema_version": "canonical_v1.0",
    "column_count": 13,
    "export_type": "canonical_flat"
  },
  "file_info": {
    "filename": "$(basename "$file_path")",
    "file_size": $file_size,
    "row_count": $row_count,
    "compressed": $(if [[ "$COMPRESS" == true ]]; then echo "true"; else echo "false"; fi),
    "md5_hash": "$file_hash"
  },
  "filters": {
    "date_from": "${DATE_FROM:-null}",
    "date_to": "${DATE_TO:-null}",
    "region": "${REGION:-null}",
    "category": "${CATEGORY:-null}",
    "store_id": "${STORE_ID:-null}"
  },
  "quality": {
    "schema_validated": $(if [[ "$VALIDATE" == true ]]; then echo "true"; else echo "false"; fi),
    "header_included": $(if [[ "$INCLUDE_HEADER" == true ]]; then echo "true"; else echo "false"; fi)
  }
}
EOF

    if [[ "$QUIET" != true ]]; then
        log "Manifest created: $manifest_file"
    fi
}

# Main execution
main() {
    if [[ "$QUIET" != true ]]; then
        echo -e "${BLUE}"
        echo "========================================"
        echo "    CANONICAL FLAT EXPORT SCRIPT"
        echo "========================================"
        echo -e "${NC}"
    fi

    parse_args "$@"
    validate_connection
    validate_schema

    if [[ "$SPECIALIZED" == "bulk" ]]; then
        log "Bulk export not yet implemented in shell script"
        log "Use: ./scripts/sql.sh -Q 'EXEC dbo.sp_export_canonical_bulk' for now"
        exit 1
    fi

    execute_export

    if [[ "$QUIET" != true ]]; then
        echo -e "${GREEN}"
        echo "========================================"
        echo "         EXPORT COMPLETED"
        echo "========================================"
        echo "Output: $OUTPUT_DIR/$OUTPUT_FILE"
        echo "Log: $LOG_FILE"
        echo -e "${NC}"
    fi
}

# Run main function with all arguments
main "$@"