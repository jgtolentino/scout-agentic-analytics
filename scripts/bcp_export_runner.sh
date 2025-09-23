#!/bin/bash
# ============================================================================
# Bruno BCP Export Runner for Scout Analytics
# Zero-click CSV exports from Azure SQL using vault-managed credentials
# ============================================================================

set -euo pipefail

# Configuration from Bruno environment
AZURE_SQL_HOST="${AZSQL_HOST:-sqltbwaprojectscoutserver.database.windows.net}"
AZURE_SQL_DB="${AZSQL_DB:-flat_scratch}"
AZURE_SQL_USER="${AZSQL_USER:-scout_reader}"
AZURE_SQL_PASS="${AZSQL_PASS:-}" # Bruno injects from vault

# Export directory
EXPORT_DIR="${EXPORT_DIR:-./exports}"
mkdir -p "$EXPORT_DIR"

# Usage function
usage() {
    echo "Usage: $0 <export_type> [output_filename]"
    echo ""
    echo "Available export types:"
    echo "  crosstab_14d    - 14-day crosstab summary"
    echo "  flat_latest     - Latest 1000 flat transactions"
    echo "  brands_summary  - Brand performance summary"
    echo "  custom <sql>    - Custom SQL query"
    echo ""
    echo "Examples:"
    echo "  $0 crosstab_14d"
    echo "  $0 flat_latest my_transactions.csv"
    echo "  $0 custom \"SELECT * FROM gold.v_transactions_flat LIMIT 10\""
    exit 1
}

# Validate required environment
validate_environment() {
    if [[ -z "$AZURE_SQL_PASS" ]]; then
        echo "❌ Error: AZSQL_PASS not set. Bruno should inject this from vault."
        exit 1
    fi

    # Test sqlcmd availability
    if ! command -v sqlcmd &> /dev/null; then
        echo "❌ Error: sqlcmd not found. Install SQL Server command line tools."
        exit 1
    fi
}

# Execute SQL and get export query
get_export_query() {
    local export_type="$1"
    local proc_name=""

    case "$export_type" in
        "crosstab_14d")
            proc_name="staging.sp_export_crosstab_14d"
            ;;
        "flat_latest")
            proc_name="staging.sp_export_flat_latest"
            ;;
        "brands_summary")
            proc_name="staging.sp_export_brands_summary"
            ;;
        *)
            echo "❌ Error: Unknown export type: $export_type"
            usage
            ;;
    esac

    # Execute procedure to get export query
    sqlcmd -S "$AZURE_SQL_HOST" -d "$AZURE_SQL_DB" -U "$AZURE_SQL_USER" -P "$AZURE_SQL_PASS" \
           -Q "EXEC $proc_name" -h -1 -s "," -W | tail -n +3
}

# Execute custom SQL export
execute_custom_export() {
    local sql_query="$1"
    local output_file="$2"

    echo "🔄 Executing custom query..."

    # Use bcp for direct SQL export
    bcp "$sql_query" queryout "$output_file" \
        -S "$AZURE_SQL_HOST" -d "$AZURE_SQL_DB" -U "$AZURE_SQL_USER" -P "$AZURE_SQL_PASS" \
        -c -t"," -r"\n" -C UTF8

    if [[ $? -eq 0 ]]; then
        echo "✅ Export completed: $output_file"
        ls -lh "$output_file"
    else
        echo "❌ Export failed"
        exit 1
    fi
}

# Execute predefined export
execute_predefined_export() {
    local export_type="$1"
    local output_file="$2"

    echo "🔄 Getting export query for: $export_type"

    # Get query from stored procedure
    local query_result
    query_result=$(get_export_query "$export_type")

    if [[ -z "$query_result" ]]; then
        echo "❌ Error: Failed to get export query"
        exit 1
    fi

    # Parse result (expecting: report_name,sql_text)
    local report_name
    local sql_query

    # Extract SQL from the result (assuming CSV format)
    sql_query=$(echo "$query_result" | cut -d',' -f2- | sed 's/^"//' | sed 's/"$//')

    if [[ -z "$sql_query" ]]; then
        echo "❌ Error: Empty SQL query returned"
        exit 1
    fi

    echo "📋 Executing query: ${sql_query:0:100}..."

    # Execute with bcp
    execute_custom_export "$sql_query" "$output_file"
}

# Log export activity
log_export() {
    local export_type="$1"
    local output_file="$2"
    local status="$3"

    # Get file info if successful
    local file_size=0
    local record_count=0

    if [[ "$status" == "SUCCESS" && -f "$output_file" ]]; then
        file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
        record_count=$(wc -l < "$output_file" | tr -d ' ')
        record_count=$((record_count - 1)) # Subtract header
    fi

    # Log to Azure SQL audit table
    local log_sql="INSERT INTO audit.export_log (operation_type, record_count, validation_status, notes) VALUES ('BCP_EXPORT', $record_count, '$status', 'Export: $export_type, File: $(basename "$output_file"), Size: $file_size bytes');"

    sqlcmd -S "$AZURE_SQL_HOST" -d "$AZURE_SQL_DB" -U "$AZURE_SQL_USER" -P "$AZURE_SQL_PASS" \
           -Q "$log_sql" > /dev/null 2>&1 || true
}

# Main execution
main() {
    local export_type="${1:-}"
    local output_filename="${2:-}"

    if [[ -z "$export_type" ]]; then
        usage
    fi

    validate_environment

    # Generate output filename if not provided
    if [[ -z "$output_filename" ]]; then
        local timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        output_filename="scout_${export_type}_${timestamp}.csv"
    fi

    local output_path="$EXPORT_DIR/$output_filename"

    echo "🚀 Scout Analytics CSV Export"
    echo "Type: $export_type"
    echo "Output: $output_path"
    echo ""

    # Handle different export types
    if [[ "$export_type" == "custom" ]]; then
        local custom_sql="${3:-}"
        if [[ -z "$custom_sql" ]]; then
            echo "❌ Error: Custom SQL query required"
            usage
        fi
        execute_custom_export "$custom_sql" "$output_path"
        log_export "custom" "$output_path" "SUCCESS"
    else
        execute_predefined_export "$export_type" "$output_path"
        log_export "$export_type" "$output_path" "SUCCESS"
    fi

    echo ""
    echo "🎉 Export completed successfully!"
    echo "📁 File: $output_path"
    echo "📊 Records: $(wc -l < "$output_path" | tr -d ' ') (including header)"
    echo "💾 Size: $(ls -lh "$output_path" | awk '{print $5}')"
}

# Handle script errors
trap 'log_export "${1:-unknown}" "${output_path:-unknown}" "ERROR"' ERR

# Execute main function
main "$@"