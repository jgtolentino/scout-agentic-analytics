#!/bin/bash
# ==========================================
# Zero-Trust Location System: New Store Detector
# Detect unverified stores and generate remediation tickets
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
LOG_DIR="${PROJECT_ROOT}/logs"
TICKETS_DIR="${PROJECT_ROOT}/tickets"
DB_URL="${DATABASE_URL:-postgresql://postgres.cxzllzyxwpyptfretryc:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres}"

# Create directories if they don't exist
mkdir -p "$LOG_DIR" "$TICKETS_DIR"

# Logging
LOG_FILE="${LOG_DIR}/new_store_detector_$(date +%Y%m%d_%H%M%S).log"

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

# Detect unverified stores
detect_unverified_stores() {
    info "Detecting stores with unverified location data..."

    local unverified_stores
    unverified_stores=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT json_agg(
            json_build_object(
                'store_id', store_id,
                'transaction_count', transactions,
                'municipality', municipality,
                'verified', verified,
                'sample_transaction_ids', (
                    SELECT json_agg(transaction_id)
                    FROM (
                        SELECT transaction_id
                        FROM public.fact_transactions_location f2
                        WHERE (f2.payload_json->>'storeId')::integer = f.store_id
                        LIMIT 3
                    ) sample
                )
            )
        )
        FROM (
            SELECT
                (payload_json->>'storeId')::integer as store_id,
                COUNT(*) as transactions,
                payload_json -> 'location' ->> 'municipality' as municipality,
                (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean as verified
            FROM public.fact_transactions_location
            GROUP BY
                (payload_json->>'storeId')::integer,
                payload_json -> 'location' ->> 'municipality',
                (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean
        ) f
        WHERE NOT verified OR municipality = 'Unknown';
    ")

    if [[ -n "$unverified_stores" && "$unverified_stores" != "null" ]]; then
        echo "$unverified_stores" > "${LOG_DIR}/unverified_stores_$(date +%Y%m%d_%H%M%S).json"
        return 0
    else
        info "No unverified stores detected"
        return 1
    fi
}

# Generate ticket for unverified store
generate_store_ticket() {
    local store_id="$1"
    local transaction_count="$2"
    local municipality="$3"
    local sample_transactions="$4"

    local ticket_file="${TICKETS_DIR}/store_${store_id}_$(date +%Y%m%d_%H%M%S).md"

    cat > "$ticket_file" << EOF
# Store Location Verification Required

**Store ID:** $store_id
**Priority:** High
**Category:** Data Quality
**Created:** $(date '+%Y-%m-%d %H:%M:%S %Z')

## Issue Description

Store $store_id has $transaction_count transactions but is not properly verified in the zero-trust location system.

**Current Status:**
- Municipality: $municipality
- Location Verified: false
- Transactions Affected: $transaction_count

## Sample Transaction IDs
$sample_transactions

## Required Action

Add Store $store_id to the authoritative dimension table with the following SQL template:

\`\`\`sql
-- Store $store_id Location Addition
-- Replace placeholders with actual verified data

SELECT * FROM add_store_with_enhanced_validation(
    p_store_id := $store_id,
    p_store_name := '[STORE_NAME_HERE]',
    p_municipality := '[VERIFIED_MUNICIPALITY_HERE]',
    p_barangay := '[VERIFIED_BARANGAY_HERE]',
    p_latitude := [VERIFIED_LATITUDE_HERE],    -- NCR bounds: 14.2-14.9
    p_longitude := [VERIFIED_LONGITUDE_HERE]   -- NCR bounds: 120.9-121.2
);

-- Verify the addition
SELECT * FROM ops.comprehensive_zero_trust_validation()
WHERE check_category = 'Core Integrity';

-- Check verification rate improvement
\${PROJECT_ROOT}/zero_trust_runner.sh full-report
\`\`\`

## Verification Checklist

- [ ] Obtain verified store name from business records
- [ ] Confirm municipality and barangay location
- [ ] Get precise latitude/longitude coordinates (within NCR bounds)
- [ ] Verify coordinates are within expected NCR ranges
- [ ] Test SQL statement in staging environment
- [ ] Execute in production database
- [ ] Run validation to confirm 100% verification rate restored
- [ ] Update ticket status to resolved

## Data Requirements

**Required Information:**
1. **Store Name**: Official business name
2. **Municipality**: One of the NCR municipalities
3. **Barangay**: Specific barangay within the municipality
4. **Coordinates**: Precise lat/lon within NCR bounds
   - Latitude: 14.2 to 14.9
   - Longitude: 120.9 to 121.2

**Sources for Verification:**
- Business registration records
- Google Maps with precise location
- Government geographic databases
- On-site verification if needed

## Impact Analysis

**Before Fix:**
- $transaction_count transactions showing as unverified
- Location marked as "$municipality"
- Zero-trust system integrity compromised

**After Fix:**
- All transactions will show verified location data
- Proper NCR municipality and coordinates assigned
- 100% verification rate restored

## Acceptance Criteria

1. Store $store_id exists in \`dim_stores_ncr\` table
2. All validation checks pass (0 violations)
3. Verification rate returns to 100%
4. Sample transactions show \`locationVerified: true\`
5. Geographic coordinates within NCR bounds

## Notes

- This is an automated ticket generated by the new store detector
- Ticket file: \`$ticket_file\`
- Log file: \`$LOG_FILE\`
- Generated by: \`$0\`

EOF

    success "Generated ticket for Store $store_id: $ticket_file"
}

# Process unverified stores and generate tickets
process_unverified_stores() {
    info "Processing unverified stores..."

    local unverified_data
    if [[ -f "${LOG_DIR}/unverified_stores_$(date +%Y%m%d)_"* ]]; then
        # Get the most recent unverified stores file for today
        unverified_data=$(ls -1t "${LOG_DIR}"/unverified_stores_$(date +%Y%m%d)_*.json | head -1)
    else
        warning "No unverified stores data found"
        return 1
    fi

    if [[ ! -f "$unverified_data" ]]; then
        warning "Unverified stores data file not found"
        return 1
    fi

    local store_count=0
    while IFS= read -r store_info; do
        if [[ -n "$store_info" && "$store_info" != "null" ]]; then
            local store_id
            local transaction_count
            local municipality
            local sample_transactions

            store_id=$(echo "$store_info" | jq -r '.store_id' 2>/dev/null || echo "unknown")
            transaction_count=$(echo "$store_info" | jq -r '.transaction_count' 2>/dev/null || echo "0")
            municipality=$(echo "$store_info" | jq -r '.municipality' 2>/dev/null || echo "Unknown")
            sample_transactions=$(echo "$store_info" | jq -r '.sample_transaction_ids[]' 2>/dev/null | head -3 | paste -sd ',' - || echo "none")

            if [[ "$store_id" != "unknown" && "$store_id" != "null" ]]; then
                # Check if ticket already exists for this store today
                if [[ ! -f "${TICKETS_DIR}/store_${store_id}_$(date +%Y%m%d)"*.md ]]; then
                    generate_store_ticket "$store_id" "$transaction_count" "$municipality" "$sample_transactions"
                    ((store_count++))
                else
                    info "Ticket for Store $store_id already exists today - skipping"
                fi
            fi
        fi
    done < <(jq -c '.[]?' "$unverified_data" 2>/dev/null || echo "")

    if [[ $store_count -gt 0 ]]; then
        success "Generated $store_count new store tickets"
        return 0
    else
        info "No new tickets required"
        return 1
    fi
}

# Check for existing unresolved tickets
check_existing_tickets() {
    info "Checking for existing unresolved tickets..."

    local ticket_count
    ticket_count=$(find "$TICKETS_DIR" -name "store_*.md" -type f -mtime -7 | wc -l)

    if [[ $ticket_count -gt 0 ]]; then
        warning "Found $ticket_count unresolved store tickets from the last 7 days"

        # List recent tickets
        info "Recent tickets:"
        find "$TICKETS_DIR" -name "store_*.md" -type f -mtime -7 -exec basename {} \; | sort

        return 1
    else
        info "No recent unresolved tickets found"
        return 0
    fi
}

# Generate summary report
generate_summary_report() {
    info "Generating new store detection summary..."

    local summary_file="${LOG_DIR}/new_store_summary_$(date +%Y%m%d).md"

    cat > "$summary_file" << EOF
# New Store Detection Summary

**Date:** $(date '+%Y-%m-%d %H:%M:%S %Z')
**Script:** $0
**Log File:** $LOG_FILE

## Detection Results

### Unverified Stores Analysis
$(if [[ -f "${LOG_DIR}/unverified_stores_$(date +%Y%m%d)"_*.json ]]; then
    local latest_file
    latest_file=$(ls -1t "${LOG_DIR}"/unverified_stores_$(date +%Y%m%d)_*.json | head -1)
    if [[ -f "$latest_file" ]]; then
        echo "**Found unverified stores:** $(jq 'length' "$latest_file" 2>/dev/null || echo "0")"
        echo ""
        echo "**Store Details:**"
        jq -r '.[] | "- Store \(.store_id): \(.transaction_count) transactions, Municipality: \(.municipality)"' "$latest_file" 2>/dev/null || echo "No details available"
    else
        echo "No unverified stores detected"
    fi
else
    echo "No unverified stores detected"
fi)

### Generated Tickets
$(find "$TICKETS_DIR" -name "store_*_$(date +%Y%m%d)*.md" -type f -exec echo "- {}" \; | sort || echo "No tickets generated today")

### System Status
$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
    SELECT
        'Verification Rate: ' ||
        ROUND((COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::boolean = TRUE) * 100.0 / COUNT(*)), 2) || '%'
    FROM public.fact_transactions_location;
" 2>/dev/null || echo "Unable to retrieve system status")

## Next Steps

1. Review generated tickets in: \`$TICKETS_DIR\`
2. Gather required store information for each unverified store
3. Execute SQL statements to add stores to dimension table
4. Verify system returns to 100% verification rate
5. Close resolved tickets

## Automation Notes

- This report is automatically generated by the new store detector
- Tickets are created only once per day per store to avoid duplicates
- All tickets include SQL templates for quick resolution
- System monitoring will continue to track verification rates

EOF

    success "Summary report generated: $summary_file"
}

# Main execution
main() {
    info "========================================"
    info "Zero-Trust New Store Detector"
    info "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    info "========================================"

    local exit_code=0

    # Test database connection
    if ! PGPASSWORD='Postgres_26' psql "$DB_URL" -c "SELECT 1;" &> /dev/null; then
        error "Database connection failed"
        exit 1
    fi

    # Check for existing tickets first
    check_existing_tickets

    # Detect unverified stores
    if detect_unverified_stores; then
        # Process and generate tickets
        if process_unverified_stores; then
            warning "New unverified stores detected - tickets generated"
            exit_code=1
        fi
    fi

    # Generate summary report
    generate_summary_report

    info "========================================"
    info "New Store Detection Completed"
    info "Exit Code: $exit_code"
    info "========================================"

    exit $exit_code
}

# Help function
show_help() {
    cat << EOF
Zero-Trust Location System New Store Detector

USAGE:
    $0 [OPTIONS]

OPTIONS:
    detect          Run new store detection (default)
    check           Check for existing tickets only
    summary         Generate summary report only
    help            Show this help message

ENVIRONMENT VARIABLES:
    DATABASE_URL    PostgreSQL connection string

EXAMPLES:
    $0              # Run full detection
    $0 detect       # Run detection
    $0 check        # Check existing tickets
    $0 summary      # Generate summary only

OUTPUT FILES:
    Tickets:        $TICKETS_DIR/store_[ID]_[TIMESTAMP].md
    Logs:           $LOG_DIR/new_store_detector_[TIMESTAMP].log
    Summary:        $LOG_DIR/new_store_summary_[DATE].md
    Data:           $LOG_DIR/unverified_stores_[TIMESTAMP].json

WORKFLOW:
    1. Script detects stores with unverified location data
    2. Generates tickets with SQL templates for each store
    3. Provides detailed instructions for manual verification
    4. Tracks existing tickets to avoid duplicates
    5. Generates summary reports for operational review

EOF
}

# Command handling
case "${1:-detect}" in
    detect)
        main
        ;;
    check)
        check_existing_tickets
        ;;
    summary)
        generate_summary_report
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