#!/bin/bash
# ==========================================
# Zero-Trust Location System: Analytics Export
# Daily CSV export for client reporting and analysis
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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXPORT_DIR="${PROJECT_ROOT}/exports"
LOG_DIR="${PROJECT_ROOT}/logs"
DB_URL="${DATABASE_URL:-postgresql://postgres.cxzllzyxwpyptfretryc:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres}"

# Azure Blob Storage configuration (optional)
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-}"
AZURE_STORAGE_KEY="${AZURE_STORAGE_KEY:-}"
AZURE_CONTAINER="${AZURE_CONTAINER:-scout-analytics}"

# Create directories
mkdir -p "$EXPORT_DIR" "$LOG_DIR"

# Logging
LOG_FILE="${LOG_DIR}/analytics_export_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Test database connection
test_database_connection() {
    info "Testing database connection..."

    if PGPASSWORD='Postgres_26' psql "$DB_URL" -c "SELECT 1;" &> /dev/null; then
        success "Database connection successful"
        return 0
    else
        error "Database connection failed"
        return 1
    fi
}

# Export transactions summary
export_transactions_summary() {
    info "Exporting transactions summary..."

    local export_file="${EXPORT_DIR}/scout_transactions_summary_$(date +%Y%m%d).csv"

    PGPASSWORD='Postgres_26' psql "$DB_URL" -c "
        COPY (
            SELECT
                DATE(COALESCE(created_at, CURRENT_DATE)) as transaction_date,
                store_id,
                COALESCE(payload_json->'location'->>'municipality', 'Unknown') as municipality,
                COALESCE(payload_json->'location'->>'region', 'NCR') as region,
                COUNT(*) as transaction_count,
                COUNT(*) FILTER (WHERE (payload_json->'qualityFlags'->>'locationVerified')::boolean = TRUE) as verified_transactions,
                COUNT(*) FILTER (WHERE (payload_json->'basket'->>'itemCount')::int > 1) as basket_transactions,
                ROUND(AVG((payload_json->'basket'->>'itemCount')::int), 2) as avg_items_per_transaction,
                COUNT(DISTINCT device_id) as unique_devices,
                COUNT(*) FILTER (WHERE
                    EXTRACT(dow FROM COALESCE(created_at, CURRENT_DATE)) IN (0, 6)
                ) as weekend_transactions,
                ROUND(
                    (COUNT(*) FILTER (WHERE (payload_json->'qualityFlags'->>'locationVerified')::boolean = TRUE) * 100.0 / COUNT(*)),
                    2
                ) as verification_rate_pct
            FROM public.fact_transactions_location
            GROUP BY
                DATE(COALESCE(created_at, CURRENT_DATE)),
                store_id,
                payload_json->'location'->>'municipality',
                payload_json->'location'->>'region'
            ORDER BY
                transaction_date DESC,
                store_id,
                municipality
        ) TO STDOUT WITH CSV HEADER
    " > "$export_file"

    if [[ -f "$export_file" && -s "$export_file" ]]; then
        success "Transactions summary exported: $export_file"
        return 0
    else
        error "Failed to export transactions summary"
        return 1
    fi
}

# Export store performance
export_store_performance() {
    info "Exporting store performance metrics..."

    local export_file="${EXPORT_DIR}/scout_store_performance_$(date +%Y%m%d).csv"

    PGPASSWORD='Postgres_26' psql "$DB_URL" -c "
        COPY (
            WITH store_metrics AS (
                SELECT
                    s.store_id,
                    s.store_name,
                    s.municipality,
                    s.geo_latitude,
                    s.geo_longitude,
                    COUNT(t.transaction_id) as total_transactions,
                    COUNT(t.transaction_id) FILTER (WHERE
                        (t.payload_json->'qualityFlags'->>'locationVerified')::boolean = TRUE
                    ) as verified_transactions,
                    COUNT(t.transaction_id) FILTER (WHERE
                        (t.payload_json->'basket'->>'itemCount')::int > 1
                    ) as multi_item_transactions,
                    COUNT(DISTINCT t.device_id) as unique_devices,
                    ROUND(AVG((t.payload_json->'basket'->>'itemCount')::int), 2) as avg_basket_size,
                    MIN(t.created_at) as first_transaction,
                    MAX(t.created_at) as last_transaction
                FROM public.dim_stores_ncr s
                LEFT JOIN public.fact_transactions_location t ON t.store_id = s.store_id
                GROUP BY s.store_id, s.store_name, s.municipality, s.geo_latitude, s.geo_longitude
            )
            SELECT
                store_id,
                store_name,
                municipality,
                geo_latitude,
                geo_longitude,
                total_transactions,
                verified_transactions,
                multi_item_transactions,
                unique_devices,
                avg_basket_size,
                ROUND((verified_transactions * 100.0 / NULLIF(total_transactions, 0)), 2) as verification_rate_pct,
                ROUND((multi_item_transactions * 100.0 / NULLIF(total_transactions, 0)), 2) as basket_rate_pct,
                ROUND((total_transactions * 1.0 / NULLIF(unique_devices, 0)), 2) as transactions_per_device,
                first_transaction,
                last_transaction,
                CASE
                    WHEN total_transactions = 0 THEN 'No Transactions'
                    WHEN verification_rate_pct = 100 THEN 'Fully Verified'
                    WHEN verification_rate_pct >= 80 THEN 'Mostly Verified'
                    ELSE 'Needs Attention'
                END as status
            FROM store_metrics
            ORDER BY total_transactions DESC, store_id
        ) TO STDOUT WITH CSV HEADER
    " > "$export_file"

    if [[ -f "$export_file" && -s "$export_file" ]]; then
        success "Store performance exported: $export_file"
        return 0
    else
        error "Failed to export store performance"
        return 1
    fi
}

# Export location analysis
export_location_analysis() {
    info "Exporting location analysis..."

    local export_file="${EXPORT_DIR}/scout_location_analysis_$(date +%Y%m%d).csv"

    PGPASSWORD='Postgres_26' psql "$DB_URL" -c "
        COPY (
            SELECT
                payload_json->'location'->>'region' as region,
                payload_json->'location'->>'municipality' as municipality,
                COUNT(*) as transaction_count,
                COUNT(DISTINCT store_id) as unique_stores,
                COUNT(DISTINCT device_id) as unique_devices,
                COUNT(*) FILTER (WHERE
                    (payload_json->'qualityFlags'->>'locationVerified')::boolean = TRUE
                ) as verified_transactions,
                COUNT(*) FILTER (WHERE
                    payload_json->'location'->>'municipality' = 'Unknown'
                ) as unknown_location_transactions,
                COUNT(*) FILTER (WHERE
                    (payload_json->'basket'->>'itemCount')::int > 1
                ) as basket_transactions,
                ROUND(AVG((payload_json->'basket'->>'itemCount')::int), 2) as avg_basket_size,
                ROUND(
                    (COUNT(*) FILTER (WHERE (payload_json->'qualityFlags'->>'locationVerified')::boolean = TRUE) * 100.0 / COUNT(*)),
                    2
                ) as verification_rate_pct,
                ROUND(
                    (COUNT(*) FILTER (WHERE (payload_json->'basket'->>'itemCount')::int > 1) * 100.0 / COUNT(*)),
                    2
                ) as basket_rate_pct,
                array_agg(DISTINCT store_id ORDER BY store_id) as store_ids
            FROM public.fact_transactions_location
            GROUP BY
                payload_json->'location'->>'region',
                payload_json->'location'->>'municipality'
            ORDER BY transaction_count DESC
        ) TO STDOUT WITH CSV HEADER
    " > "$export_file"

    if [[ -f "$export_file" && -s "$export_file" ]]; then
        success "Location analysis exported: $export_file"
        return 0
    else
        error "Failed to export location analysis"
        return 1
    fi
}

# Export quality metrics
export_quality_metrics() {
    info "Exporting data quality metrics..."

    local export_file="${EXPORT_DIR}/scout_quality_metrics_$(date +%Y%m%d).csv"

    PGPASSWORD='Postgres_26' psql "$DB_URL" -c "
        COPY (
            WITH quality_summary AS (
                SELECT
                    'Total Transactions' as metric_category,
                    'Count' as metric_name,
                    COUNT(*)::text as metric_value,
                    'transactions' as unit,
                    CURRENT_DATE as report_date
                FROM public.fact_transactions_location

                UNION ALL

                SELECT
                    'Location Verification',
                    'Verified Transactions',
                    COUNT(*) FILTER (WHERE (payload_json->'qualityFlags'->>'locationVerified')::boolean = TRUE)::text,
                    'transactions',
                    CURRENT_DATE
                FROM public.fact_transactions_location

                UNION ALL

                SELECT
                    'Location Verification',
                    'Verification Rate',
                    ROUND((COUNT(*) FILTER (WHERE (payload_json->'qualityFlags'->>'locationVerified')::boolean = TRUE) * 100.0 / COUNT(*)), 2)::text,
                    'percentage',
                    CURRENT_DATE
                FROM public.fact_transactions_location

                UNION ALL

                SELECT
                    'Store Coverage',
                    'Unique Stores',
                    COUNT(DISTINCT store_id)::text,
                    'stores',
                    CURRENT_DATE
                FROM public.fact_transactions_location

                UNION ALL

                SELECT
                    'Store Coverage',
                    'Stores in Dimension',
                    COUNT(*)::text,
                    'stores',
                    CURRENT_DATE
                FROM public.dim_stores_ncr

                UNION ALL

                SELECT
                    'Data Quality',
                    'Unknown Locations',
                    COUNT(*) FILTER (WHERE payload_json->'location'->>'municipality' = 'Unknown')::text,
                    'transactions',
                    CURRENT_DATE
                FROM public.fact_transactions_location

                UNION ALL

                SELECT
                    'Basket Analysis',
                    'Multi-Item Transactions',
                    COUNT(*) FILTER (WHERE (payload_json->'basket'->>'itemCount')::int > 1)::text,
                    'transactions',
                    CURRENT_DATE
                FROM public.fact_transactions_location

                UNION ALL

                SELECT
                    'Basket Analysis',
                    'Average Basket Size',
                    ROUND(AVG((payload_json->'basket'->>'itemCount')::int), 2)::text,
                    'items',
                    CURRENT_DATE
                FROM public.fact_transactions_location
            )
            SELECT * FROM quality_summary
            ORDER BY metric_category, metric_name
        ) TO STDOUT WITH CSV HEADER
    " > "$export_file"

    if [[ -f "$export_file" && -s "$export_file" ]]; then
        success "Quality metrics exported: $export_file"
        return 0
    else
        error "Failed to export quality metrics"
        return 1
    fi
}

# Export sample transactions for analysis
export_sample_transactions() {
    info "Exporting sample transactions..."

    local export_file="${EXPORT_DIR}/scout_sample_transactions_$(date +%Y%m%d).csv"

    PGPASSWORD='Postgres_26' psql "$DB_URL" -c "
        COPY (
            SELECT
                transaction_id,
                store_id,
                device_id,
                payload_json->'location'->>'municipality' as municipality,
                payload_json->'location'->>'region' as region,
                (payload_json->'qualityFlags'->>'locationVerified')::boolean as location_verified,
                (payload_json->'basket'->>'itemCount')::int as item_count,
                payload_json->'interaction'->>'weekdayOrWeekend' as weekday_weekend,
                payload_json->'interaction'->>'timeOfDay' as time_of_day,
                created_at,
                LEFT(payload_json::text, 200) as payload_sample
            FROM public.fact_transactions_location
            WHERE transaction_id IN (
                SELECT transaction_id
                FROM public.fact_transactions_location
                ORDER BY RANDOM()
                LIMIT 1000
            )
            ORDER BY created_at DESC
        ) TO STDOUT WITH CSV HEADER
    " > "$export_file"

    if [[ -f "$export_file" && -s "$export_file" ]]; then
        success "Sample transactions exported: $export_file"
        return 0
    else
        error "Failed to export sample transactions"
        return 1
    fi
}

# Upload to Azure Blob Storage (if configured)
upload_to_azure() {
    if [[ -z "$AZURE_STORAGE_ACCOUNT" || -z "$AZURE_STORAGE_KEY" ]]; then
        info "Azure Storage not configured - skipping upload"
        return 0
    fi

    info "Uploading exports to Azure Blob Storage..."

    if ! command -v az &> /dev/null; then
        warning "Azure CLI not found - skipping upload"
        return 0
    fi

    # Set Azure credentials
    export AZURE_STORAGE_ACCOUNT
    export AZURE_STORAGE_KEY

    local upload_count=0
    for export_file in "${EXPORT_DIR}"/scout_*_$(date +%Y%m%d).csv; do
        if [[ -f "$export_file" ]]; then
            local filename
            filename=$(basename "$export_file")
            local blob_path="daily-exports/$(date +%Y/%m/%d)/${filename}"

            if az storage blob upload \
                --file "$export_file" \
                --container-name "$AZURE_CONTAINER" \
                --name "$blob_path" \
                --overwrite true &>> "$LOG_FILE"; then
                success "Uploaded: $filename -> $blob_path"
                ((upload_count++))
            else
                error "Failed to upload: $filename"
            fi
        fi
    done

    if [[ $upload_count -gt 0 ]]; then
        success "Uploaded $upload_count files to Azure Blob Storage"
        return 0
    else
        warning "No files uploaded to Azure Blob Storage"
        return 1
    fi
}

# Generate export manifest
generate_manifest() {
    info "Generating export manifest..."

    local manifest_file="${EXPORT_DIR}/export_manifest_$(date +%Y%m%d).json"

    cat > "$manifest_file" << EOF
{
    "export_date": "$(date -Iseconds)",
    "export_version": "1.0",
    "generated_by": "$0",
    "database_url": "$(echo "$DB_URL" | sed 's/:[^@]*@/:***@/')",
    "files": [
$(for file in "${EXPORT_DIR}"/scout_*_$(date +%Y%m%d).csv; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        filesize=$(wc -c < "$file" 2>/dev/null || echo "0")
        linecount=$(wc -l < "$file" 2>/dev/null || echo "0")

        echo "        {"
        echo "            \"filename\": \"$filename\","
        echo "            \"size_bytes\": $filesize,"
        echo "            \"line_count\": $linecount,"
        echo "            \"created\": \"$(date -Iseconds -r "$file" 2>/dev/null || date -Iseconds)\""
        echo "        }$(if [[ "$file" != $(ls "${EXPORT_DIR}"/scout_*_$(date +%Y%m%d).csv | tail -1) ]]; then echo ","; fi)"
    fi
done)
    ],
    "summary": {
        "total_files": $(ls "${EXPORT_DIR}"/scout_*_$(date +%Y%m%d).csv 2>/dev/null | wc -l),
        "total_size_bytes": $(find "${EXPORT_DIR}" -name "scout_*_$(date +%Y%m%d).csv" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0"),
        "azure_upload_configured": $(if [[ -n "$AZURE_STORAGE_ACCOUNT" ]]; then echo "true"; else echo "false"; fi)
    }
}
EOF

    success "Export manifest generated: $manifest_file"
}

# Cleanup old exports
cleanup_old_exports() {
    info "Cleaning up old export files..."

    local retention_days=30

    # Remove old export files
    find "$EXPORT_DIR" -name "scout_*.csv" -type f -mtime +$retention_days -delete 2>/dev/null || true
    find "$EXPORT_DIR" -name "export_manifest_*.json" -type f -mtime +$retention_days -delete 2>/dev/null || true

    success "Old export files cleaned up (retention: $retention_days days)"
}

# Main execution
main() {
    info "==========================================="
    info "Zero-Trust Analytics Export"
    info "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    info "==========================================="

    local export_status="SUCCESS"
    local failed_exports=0

    # Test database connection
    if ! test_database_connection; then
        error "Database connection failed - aborting export"
        exit 1
    fi

    # Run all exports
    export_transactions_summary || ((failed_exports++))
    export_store_performance || ((failed_exports++))
    export_location_analysis || ((failed_exports++))
    export_quality_metrics || ((failed_exports++))
    export_sample_transactions || ((failed_exports++))

    # Generate manifest
    generate_manifest

    # Upload to Azure if configured
    upload_to_azure

    # Cleanup old files
    cleanup_old_exports

    # Determine overall status
    if [[ $failed_exports -gt 0 ]]; then
        export_status="PARTIAL"
        warning "$failed_exports exports failed"
    else
        success "All exports completed successfully"
    fi

    info "==========================================="
    info "Analytics Export Completed: $export_status"
    info "Export Directory: $EXPORT_DIR"
    info "Log File: $LOG_FILE"
    info "==========================================="

    # Exit with appropriate code
    if [[ $failed_exports -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
Zero-Trust Location System Analytics Export

USAGE:
    $0 [OPTIONS]

OPTIONS:
    export          Run all exports (default)
    summary         Export transactions summary only
    stores          Export store performance only
    locations       Export location analysis only
    quality         Export quality metrics only
    samples         Export sample transactions only
    manifest        Generate export manifest only
    upload          Upload existing exports to Azure
    cleanup         Cleanup old export files
    help            Show this help message

ENVIRONMENT VARIABLES:
    DATABASE_URL           PostgreSQL connection string
    AZURE_STORAGE_ACCOUNT  Azure Storage account name (optional)
    AZURE_STORAGE_KEY      Azure Storage account key (optional)
    AZURE_CONTAINER        Azure Blob container name (default: scout-analytics)

EXAMPLES:
    $0                     # Run all exports
    $0 summary            # Export summary only
    $0 upload             # Upload to Azure
    $0 cleanup            # Cleanup old files

OUTPUT FILES:
    $EXPORT_DIR/scout_transactions_summary_YYYYMMDD.csv
    $EXPORT_DIR/scout_store_performance_YYYYMMDD.csv
    $EXPORT_DIR/scout_location_analysis_YYYYMMDD.csv
    $EXPORT_DIR/scout_quality_metrics_YYYYMMDD.csv
    $EXPORT_DIR/scout_sample_transactions_YYYYMMDD.csv
    $EXPORT_DIR/export_manifest_YYYYMMDD.json

AZURE BLOB STRUCTURE:
    daily-exports/YYYY/MM/DD/filename.csv

EOF
}

# Command handling
case "${1:-export}" in
    export)
        main
        ;;
    summary)
        test_database_connection && export_transactions_summary
        ;;
    stores)
        test_database_connection && export_store_performance
        ;;
    locations)
        test_database_connection && export_location_analysis
        ;;
    quality)
        test_database_connection && export_quality_metrics
        ;;
    samples)
        test_database_connection && export_sample_transactions
        ;;
    manifest)
        generate_manifest
        ;;
    upload)
        upload_to_azure
        ;;
    cleanup)
        cleanup_old_exports
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac