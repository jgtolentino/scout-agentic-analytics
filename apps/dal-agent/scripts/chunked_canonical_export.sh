#!/usr/bin/env bash
# =================================================================
# Chunked Canonical Export - Handle JSON Truncation Issues
# Exports canonical data in date chunks to avoid JSON parsing errors
# =================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
CHUNK_DAYS=${CHUNK_DAYS:-15}  # Days per chunk
OUTPUT_DIR="out/canonical/chunked"

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

get_date_range() {
    "$SCRIPT_DIR/sql.sh" -Q "
        SELECT
            FORMAT(MIN(CAST(Time_of_Transaction AS date)), 'yyyy-MM-dd') as min_date,
            FORMAT(MAX(CAST(Time_of_Transaction AS date)), 'yyyy-MM-dd') as max_date
        FROM gold.v_transactions_flat_canonical
        WHERE Time_of_Transaction IS NOT NULL
    " -s "," -W -h -1
}

export_chunk() {
    local start_date="$1"
    local end_date="$2"
    local chunk_file="$3"

    log "Exporting chunk: $start_date to $end_date"

    # Create chunk-specific query using the projection view to avoid JSON issues
    "$SCRIPT_DIR/sql.sh" -Q "
        SET NOCOUNT ON;
        SELECT * FROM gold.v_transactions_flat_canonical
        WHERE CAST(Time_of_Transaction AS date) BETWEEN '$start_date' AND '$end_date'
        ORDER BY Transaction_ID
    " -s "," -W -h -1 > "$chunk_file"

    local rows
    rows=$(wc -l < "$chunk_file" || echo "0")

    if [[ "$rows" -gt "0" ]]; then
        success "Chunk exported: $rows rows → $chunk_file"
        return 0
    else
        error "Chunk export failed: 0 rows"
        return 1
    fi
}

concatenate_chunks() {
    local final_file="$1"
    shift
    local chunk_files=("$@")

    log "Concatenating ${#chunk_files[@]} chunks into $final_file"

    # Start with header from first chunk
    head -1 "${chunk_files[0]}" > "$final_file"

    # Append data (skip header) from all chunks
    for chunk in "${chunk_files[@]}"; do
        tail -n +2 "$chunk" >> "$final_file"
    done

    local total_rows
    total_rows=$(wc -l < "$final_file")
    local data_rows=$((total_rows - 1))

    success "Concatenation complete: $data_rows data rows + header → $final_file"
}

main() {
    log "Starting chunked canonical export (${CHUNK_DAYS}-day chunks)"

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Get date range from data
    log "Determining date range from canonical data..."
    local date_info
    if ! date_info=$(get_date_range); then
        error "Failed to get date range from canonical data"
        exit 1
    fi

    local min_date max_date
    min_date=$(echo "$date_info" | cut -d',' -f1)
    max_date=$(echo "$date_info" | cut -d',' -f2)

    log "Data range: $min_date to $max_date"

    # Generate chunk date ranges
    local chunk_files=()
    local current_date="$min_date"
    local chunk_number=1

    while [[ "$current_date" <= "$max_date" ]]; do
        # Calculate end date for this chunk
        local chunk_end_date
        chunk_end_date=$(date -j -v +"${CHUNK_DAYS}d" -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d" 2>/dev/null || \
                        python3 -c "
from datetime import datetime, timedelta
start = datetime.strptime('$current_date', '%Y-%m-%d')
end = start + timedelta(days=$CHUNK_DAYS)
print(end.strftime('%Y-%m-%d'))
")

        # Don't go beyond the actual max date
        if [[ "$chunk_end_date" > "$max_date" ]]; then
            chunk_end_date="$max_date"
        fi

        # Generate chunk filename
        local chunk_file="$OUTPUT_DIR/chunk_${chunk_number}_${current_date}_${chunk_end_date}.csv"
        chunk_files+=("$chunk_file")

        # Export this chunk
        if export_chunk "$current_date" "$chunk_end_date" "$chunk_file"; then
            log "Chunk $chunk_number completed"
        else
            error "Chunk $chunk_number failed"
            exit 1
        fi

        # Move to next chunk
        current_date=$(date -j -v +"$((CHUNK_DAYS + 1))d" -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d" 2>/dev/null || \
                      python3 -c "
from datetime import datetime, timedelta
start = datetime.strptime('$current_date', '%Y-%m-%d')
next_start = start + timedelta(days=$CHUNK_DAYS + 1)
print(next_start.strftime('%Y-%m-%d'))
")

        chunk_number=$((chunk_number + 1))

        # Safety break to prevent infinite loops
        if [[ $chunk_number -gt 100 ]]; then
            error "Too many chunks (>100), breaking to prevent infinite loop"
            exit 1
        fi
    done

    # Concatenate all chunks into final file
    local final_file="$OUTPUT_DIR/../canonical_flat_chunked_${TIMESTAMP}.csv"
    concatenate_chunks "$final_file" "${chunk_files[@]}"

    # Generate checksum
    shasum -a 256 "$final_file" | awk '{print $1}' > "${final_file%.csv}.sha256"

    # Compress final file
    gzip -f "$final_file"
    success "Final compressed export: ${final_file}.gz"

    # Clean up individual chunks
    log "Cleaning up temporary chunk files..."
    rm -f "${chunk_files[@]}"

    # Show summary
    echo ""
    echo -e "${BLUE}📊 Chunked Export Summary:${NC}"
    echo "  📅 Date range: $min_date to $max_date"
    echo "  🧩 Chunks processed: ${#chunk_files[@]} (${CHUNK_DAYS} days each)"
    echo "  📁 Final file: ${final_file}.gz"
    echo "  🔐 Checksum: ${final_file%.csv}.sha256"

    success "Chunked canonical export completed successfully"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--chunk-days N]"
        echo ""
        echo "Export canonical data in date chunks to avoid JSON truncation issues."
        echo ""
        echo "Options:"
        echo "  --chunk-days N    Days per chunk (default: 15)"
        echo ""
        echo "Environment variables:"
        echo "  CHUNK_DAYS        Days per chunk (default: 15)"
        echo ""
        echo "Output:"
        echo "  out/canonical/canonical_flat_chunked_TIMESTAMP.csv.gz"
        echo "  out/canonical/canonical_flat_chunked_TIMESTAMP.sha256"
        exit 0
        ;;
    --chunk-days)
        CHUNK_DAYS="$2"
        main "$@"
        ;;
    *)
        main "$@"
        ;;
esac