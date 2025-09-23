#!/usr/bin/env bash
# ============================================================================
# Bruno Webhook Export Handler
# Processes export requests from the dashboard API via secure webhook
# ============================================================================

set -euo pipefail

# Configuration
WEBHOOK_SECRET="${BRUNO_WEBHOOK_SECRET:-}"
LOG_FILE="${BRUNO_LOG_DIR:-./logs}/webhook_export.log"
EXPORT_DIR="${EXPORT_DIR:-./exports}"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$EXPORT_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Verify HMAC signature
verify_signature() {
    local payload="$1"
    local signature="$2"

    if [[ -z "$WEBHOOK_SECRET" ]]; then
        log "ERROR: BRUNO_WEBHOOK_SECRET not set"
        return 1
    fi

    local expected
    expected=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -hex | cut -d' ' -f2)

    if [[ "$signature" != "$expected" ]]; then
        log "ERROR: Invalid webhook signature"
        return 1
    fi

    return 0
}

# Process export request
process_export_request() {
    local payload="$1"

    # Parse JSON payload
    local tmp_file
    tmp_file=$(mktemp)
    echo "$payload" > "$tmp_file"

    # Extract fields
    local type filename sql redact
    type=$(jq -r '.type // "unknown"' "$tmp_file")
    filename=$(jq -r '.filename // "export.csv"' "$tmp_file")
    sql=$(jq -r '.sql // ""' "$tmp_file")
    redact=$(jq -r '.redact // false' "$tmp_file")

    log "Processing export request: type=$type, filename=$filename, redact=$redact"

    # Validate required fields
    if [[ -z "$sql" || "$sql" == "null" ]]; then
        log "ERROR: Missing SQL query in payload"
        rm -f "$tmp_file"
        echo '{"ok":false,"error":"missing_sql"}'
        return 1
    fi

    # Execute export using the BCP runner
    local output_path="$EXPORT_DIR/$filename"
    local start_time end_time duration

    start_time=$(date +%s)

    if ./scripts/bcp_export_runner.sh custom "$sql" "$filename"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        # Get file info
        local file_size record_count
        file_size=$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null || echo "0")
        record_count=$(wc -l < "$output_path" | tr -d ' ')
        record_count=$((record_count - 1)) # Subtract header

        log "SUCCESS: Export completed in ${duration}s, ${record_count} records, ${file_size} bytes"

        # Clean up temp file
        rm -f "$tmp_file"

        # Return success response
        echo "{\"ok\":true,\"filename\":\"$filename\",\"path\":\"$output_path\",\"records\":$record_count,\"size\":$file_size,\"duration\":$duration}"
        return 0

    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        log "ERROR: Export failed after ${duration}s"

        # Clean up temp file
        rm -f "$tmp_file"

        # Return error response
        echo "{\"ok\":false,\"error\":\"export_failed\",\"duration\":$duration}"
        return 1
    fi
}

# Main webhook handler
main() {
    log "Bruno webhook export handler started"

    # Read the request body from stdin
    local payload
    payload=$(cat)

    if [[ -z "$payload" ]]; then
        log "ERROR: Empty payload received"
        echo '{"ok":false,"error":"empty_payload"}'
        exit 1
    fi

    # Get signature from environment (set by HTTP server)
    local signature="${HTTP_X_BRUNO_SIGNATURE:-}"

    if [[ -z "$signature" ]]; then
        log "ERROR: Missing X-Bruno-Signature header"
        echo '{"ok":false,"error":"missing_signature"}'
        exit 1
    fi

    # Verify signature
    if ! verify_signature "$payload" "$signature"; then
        echo '{"ok":false,"error":"invalid_signature"}'
        exit 1
    fi

    log "Webhook signature verified successfully"

    # Process the export request
    if process_export_request "$payload"; then
        log "Export request completed successfully"
        exit 0
    else
        log "Export request failed"
        exit 1
    fi
}

# Handle script errors
trap 'log "ERROR: Script failed at line $LINENO"' ERR

# Execute main function
main "$@"