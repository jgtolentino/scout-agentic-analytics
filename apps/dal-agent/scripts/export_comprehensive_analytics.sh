#!/usr/bin/env bash
#
# Comprehensive Analytics Export Script
# Executes all analytics queries and exports results to organized CSV files
# Created: 2025-09-26
#

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/out/comprehensive_analytics"
SQL_DIR="$PROJECT_ROOT/sql/analytics"

# Database configuration
DB="${DB:-SQL-TBWA-ProjectScout-Reporting-Prod}"
DATE_FROM="${DATE_FROM:-2025-06-28}"
DATE_TO="${DATE_TO:-2025-09-26}"

# Export configuration
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_SUFFIX="${TIMESTAMP}"

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create output directory structure
create_output_dirs() {
    log_info "Creating output directory structure..."

    mkdir -p "$OUTPUT_DIR"/{store_demographics,tobacco_analytics,laundry_analytics,all_categories,conversation_intelligence}
    mkdir -p "$OUTPUT_DIR"/summary

    log_success "Output directories created at: $OUTPUT_DIR"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."

    # Check if SQL files exist
    local required_files=(
        "store_demographics.sql"
        "tobacco_analytics.sql"
        "laundry_analytics.sql"
        "all_categories_analytics.sql"
        "conversation_intelligence.sql"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$SQL_DIR/$file" ]]; then
            log_error "Required SQL file not found: $SQL_DIR/$file"
            exit 1
        fi
    done

    # Check database connection
    if ! command -v sqlcmd &> /dev/null; then
        log_error "sqlcmd not found. Please install Azure SQL CLI tools."
        exit 1
    fi

    log_success "Prerequisites validated"
}

# Execute SQL file and export to CSV
execute_and_export() {
    local sql_file="$1"
    local output_category="$2"
    local description="$3"

    log_info "Executing $description..."

    # Create parameters for SQL execution
    local params="-v date_from=\"$DATE_FROM\" -v date_to=\"$DATE_TO\""

    # Execute SQL and capture output
    local temp_file=$(mktemp)

    if ./scripts/sql.sh -Q "
        DECLARE @date_from DATE = '$DATE_FROM';
        DECLARE @date_to DATE = '$DATE_TO';
        $(cat "$SQL_DIR/$sql_file")
    " > "$temp_file" 2>&1; then

        # Process output and create organized CSV files
        process_sql_output "$temp_file" "$OUTPUT_DIR/$output_category" "$description"

        log_success "Completed $description"
    else
        log_error "Failed to execute $description"
        cat "$temp_file"
        rm -f "$temp_file"
        return 1
    fi

    rm -f "$temp_file"
}

# Process SQL output and create organized CSV files
process_sql_output() {
    local input_file="$1"
    local output_dir="$2"
    local description="$3"

    # Split output by export_type if it exists
    if grep -q "export_type" "$input_file"; then
        # Extract unique export types
        local export_types=$(grep -o "'[^']*' AS export_type" "$input_file" | cut -d"'" -f2 | sort -u)

        while IFS= read -r export_type; do
            if [[ -n "$export_type" ]]; then
                local safe_name=$(echo "$export_type" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
                local output_file="$output_dir/${safe_name}_${EXPORT_SUFFIX}.csv"

                # Extract data for this export type
                grep -A 1000 "$export_type" "$input_file" | head -n 1000 > "$output_file"

                if [[ -s "$output_file" ]]; then
                    log_success "Created: $output_file"
                else
                    log_warning "Empty output for: $export_type"
                    rm -f "$output_file"
                fi
            fi
        done <<< "$export_types"
    else
        # Single output file
        local safe_name=$(echo "$description" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
        local output_file="$output_dir/${safe_name}_${EXPORT_SUFFIX}.csv"
        cp "$input_file" "$output_file"
        log_success "Created: $output_file"
    fi
}

# Export store demographics analytics
export_store_demographics() {
    execute_and_export "store_demographics.sql" "store_demographics" "Store Demographics Analytics"
}

# Export tobacco analytics
export_tobacco_analytics() {
    execute_and_export "tobacco_analytics.sql" "tobacco_analytics" "Tobacco Category Analytics"
}

# Export laundry analytics
export_laundry_analytics() {
    execute_and_export "laundry_analytics.sql" "laundry_analytics" "Laundry Category Analytics"
}

# Export all categories analytics
export_all_categories() {
    execute_and_export "all_categories_analytics.sql" "all_categories" "All Categories Analytics"
}

# Export conversation intelligence
export_conversation_intelligence() {
    execute_and_export "conversation_intelligence.sql" "conversation_intelligence" "Conversation Intelligence Analytics"
}

# Create summary report
create_summary_report() {
    log_info "Creating summary report..."

    local summary_file="$OUTPUT_DIR/summary/analytics_export_summary_${EXPORT_SUFFIX}.txt"

    cat > "$summary_file" << EOF
Scout v7 Comprehensive Analytics Export Summary
============================================

Export Details:
- Date Range: $DATE_FROM to $DATE_TO
- Export Timestamp: $TIMESTAMP
- Database: $DB

Files Created:
EOF

    # Count and list all created files
    local file_count=0
    for dir in "$OUTPUT_DIR"/*/; do
        if [[ -d "$dir" && "$dir" != *"/summary/"* ]]; then
            local category=$(basename "$dir")
            echo "" >> "$summary_file"
            echo "$category:" >> "$summary_file"

            find "$dir" -name "*_${EXPORT_SUFFIX}.csv" -type f | while read -r file; do
                local filename=$(basename "$file")
                local size=$(du -h "$file" | cut -f1)
                echo "  - $filename ($size)" >> "$summary_file"
                ((file_count++))
            done
        fi
    done

    echo "" >> "$summary_file"
    echo "Total files created: $file_count" >> "$summary_file"
    echo "Export completed at: $(date)" >> "$summary_file"

    log_success "Summary report created: $summary_file"
}

# Main execution function
main() {
    log_info "Starting Scout v7 Comprehensive Analytics Export"
    log_info "Date Range: $DATE_FROM to $DATE_TO"
    log_info "Database: $DB"

    # Setup
    create_output_dirs
    validate_prerequisites

    # Execute analytics exports
    export_store_demographics
    export_tobacco_analytics
    export_laundry_analytics
    export_all_categories
    export_conversation_intelligence

    # Create summary
    create_summary_report

    log_success "Comprehensive analytics export completed successfully!"
    log_info "Output directory: $OUTPUT_DIR"

    # Display summary statistics
    local total_files=$(find "$OUTPUT_DIR" -name "*.csv" -type f | wc -l)
    local total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)

    echo ""
    echo "Export Statistics:"
    echo "  Files created: $total_files"
    echo "  Total size: $total_size"
    echo "  Output location: $OUTPUT_DIR"
    echo ""
}

# Help function
show_help() {
    cat << EOF
Scout v7 Comprehensive Analytics Export Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    --date-from DATE    Start date for analytics (default: 2025-06-28)
    --date-to DATE      End date for analytics (default: 2025-09-26)
    --db DATABASE       Database name (default: SQL-TBWA-ProjectScout-Reporting-Prod)

Environment Variables:
    DB                  Database name
    DATE_FROM           Start date for analytics
    DATE_TO             End date for analytics

Examples:
    # Default export (last 3 months)
    $0

    # Custom date range
    $0 --date-from 2025-08-01 --date-to 2025-09-01

    # With environment variables
    DATE_FROM=2025-07-01 DATE_TO=2025-09-26 $0

Output:
    All CSV files are created in: $OUTPUT_DIR
    Organized by analytics category with timestamped filenames.

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --date-from)
            DATE_FROM="$2"
            shift 2
            ;;
        --date-to)
            DATE_TO="$2"
            shift 2
            ;;
        --db)
            DB="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute main function
main "$@"