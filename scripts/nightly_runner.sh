#!/bin/bash
# ==========================================
# Zero-Trust Location System: Nightly Runner
# Automated validation, monitoring, and alerting
# ==========================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
DB_URL="${DATABASE_URL:-postgresql://postgres.cxzllzyxwpyptfretryc:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres}"
NOTIFICATION_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
TEAMS_WEBHOOK="${TEAMS_WEBHOOK_URL:-}"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging setup
LOG_FILE="${LOG_DIR}/nightly_runner_$(date +%Y%m%d_%H%M%S).log"
SUMMARY_FILE="${LOG_DIR}/nightly_summary_$(date +%Y%m%d).log"

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

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."

    if ! command -v psql &> /dev/null; then
        error "psql is required but not installed"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        warning "curl not found - webhook notifications will be disabled"
    fi

    if ! command -v jq &> /dev/null; then
        warning "jq not found - JSON processing may be limited"
    fi

    success "Dependencies check completed"
}

# Database connectivity test
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

# Run comprehensive validation
run_comprehensive_validation() {
    info "Running comprehensive zero-trust validation..."

    local validation_result
    validation_result=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT
            json_agg(
                json_build_object(
                    'category', check_category,
                    'check', check_name,
                    'violations', violations,
                    'status', status,
                    'details', details
                )
            )
        FROM comprehensive_zero_trust_validation();
    ")

    if [[ -n "$validation_result" && "$validation_result" != "null" ]]; then
        echo "$validation_result" > "${LOG_DIR}/validation_results_$(date +%Y%m%d).json"

        # Check for any failures
        local failures
        failures=$(echo "$validation_result" | jq -r '.[] | select(.status == "FAIL") | .check' 2>/dev/null || echo "")

        if [[ -n "$failures" ]]; then
            error "Validation failures detected: $failures"
            return 1
        else
            success "All validation checks passed"
            return 0
        fi
    else
        error "Failed to retrieve validation results"
        return 1
    fi
}

# Capture monitoring snapshot
capture_snapshot() {
    info "Capturing system monitoring snapshot..."

    local snapshot_result
    snapshot_result=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT
            json_build_object(
                'timestamp', snapshot_time,
                'system_health', system_health,
                'verification_rate', verification_rate,
                'total_violations', total_violations
            )
        FROM ops.capture_verification_snapshot();
    ")

    if [[ -n "$snapshot_result" && "$snapshot_result" != "null" ]]; then
        echo "$snapshot_result" > "${LOG_DIR}/snapshot_$(date +%Y%m%d_%H%M%S).json"
        success "Monitoring snapshot captured"
        return 0
    else
        error "Failed to capture monitoring snapshot"
        return 1
    fi
}

# Evaluate SLOs
evaluate_slos() {
    info "Evaluating Service Level Objectives..."

    local slo_results
    slo_results=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT
            json_agg(
                json_build_object(
                    'slo_name', slo_name,
                    'current_value', current_value,
                    'target_value', target_value,
                    'operator', operator,
                    'status', slo_status,
                    'severity', severity
                )
            )
        FROM ops.evaluate_slos();
    ")

    if [[ -n "$slo_results" && "$slo_results" != "null" ]]; then
        echo "$slo_results" > "${LOG_DIR}/slo_evaluation_$(date +%Y%m%d_%H%M%S).json"

        # Check for SLO failures
        local slo_failures
        slo_failures=$(echo "$slo_results" | jq -r '.[] | select(.status == "FAIL") | .slo_name' 2>/dev/null || echo "")

        if [[ -n "$slo_failures" ]]; then
            error "SLO failures detected: $slo_failures"
            return 1
        else
            success "All SLOs are passing"
            return 0
        fi
    else
        error "Failed to evaluate SLOs"
        return 1
    fi
}

# Generate and process alerts
process_alerts() {
    info "Processing alerts..."

    local alert_results
    alert_results=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT
            json_agg(
                json_build_object(
                    'alert_created', alert_created,
                    'message', alert_message,
                    'severity', alert_severity
                )
            )
        FROM ops.generate_alerts();
    ")

    if [[ -n "$alert_results" && "$alert_results" != "null" ]]; then
        echo "$alert_results" > "${LOG_DIR}/alerts_$(date +%Y%m%d_%H%M%S).json"

        # Check for new alerts
        local new_alerts
        new_alerts=$(echo "$alert_results" | jq -r '.[] | select(.alert_created == true) | .message' 2>/dev/null || echo "")

        if [[ -n "$new_alerts" ]]; then
            warning "New alerts generated: $new_alerts"
            return 1
        else
            info "No new alerts generated"
            return 0
        fi
    else
        error "Failed to process alerts"
        return 1
    fi
}

# Run basic zero-trust runner for compatibility
run_basic_validation() {
    info "Running basic zero-trust validation..."

    if [[ -f "${PROJECT_ROOT}/zero_trust_runner.sh" ]]; then
        if "${PROJECT_ROOT}/zero_trust_runner.sh" full-report >> "$LOG_FILE" 2>&1; then
            success "Basic validation completed successfully"
            return 0
        else
            error "Basic validation failed"
            return 1
        fi
    else
        warning "Basic zero-trust runner not found - skipping"
        return 0
    fi
}

# Generate system metrics summary
generate_metrics_summary() {
    info "Generating system metrics summary..."

    local metrics_summary
    metrics_summary=$(PGPASSWORD='Postgres_26' psql "$DB_URL" -tAc "
        SELECT
            json_build_object(
                'timestamp', CURRENT_TIMESTAMP,
                'metrics', json_agg(
                    json_build_object(
                        'metric', metric_name,
                        'value', metric_value,
                        'unit', metric_unit,
                        'status', threshold_status
                    )
                )
            )
        FROM ops.collect_system_metrics();
    ")

    if [[ -n "$metrics_summary" && "$metrics_summary" != "null" ]]; then
        echo "$metrics_summary" > "${LOG_DIR}/metrics_summary_$(date +%Y%m%d_%H%M%S).json"
        success "System metrics summary generated"
        return 0
    else
        error "Failed to generate metrics summary"
        return 1
    fi
}

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    local details="${3:-}"

    if [[ -z "$NOTIFICATION_WEBHOOK" && -z "$TEAMS_WEBHOOK" ]]; then
        info "No webhook configured - notification skipped"
        return 0
    fi

    local color
    case "$status" in
        "SUCCESS") color="good" ;;
        "WARNING") color="warning" ;;
        "ERROR") color="danger" ;;
        *) color="warning" ;;
    esac

    local payload
    payload=$(cat <<EOF
{
    "text": "Zero-Trust Location System Nightly Report",
    "attachments": [
        {
            "color": "$color",
            "title": "System Status: $status",
            "text": "$message",
            "fields": [
                {
                    "title": "Timestamp",
                    "value": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
                    "short": true
                },
                {
                    "title": "Environment",
                    "value": "Production",
                    "short": true
                }
            ],
            "footer": "Zero-Trust Location Monitor"
        }
    ]
}
EOF
    )

    if [[ -n "$details" ]]; then
        payload=$(echo "$payload" | jq --arg details "$details" '.attachments[0].fields += [{"title": "Details", "value": $details, "short": false}]')
    fi

    # Send to Slack if webhook is configured
    if [[ -n "$NOTIFICATION_WEBHOOK" ]]; then
        if curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$NOTIFICATION_WEBHOOK" &> /dev/null; then
            info "Slack notification sent successfully"
        else
            warning "Failed to send Slack notification"
        fi
    fi

    # Send to Teams if webhook is configured
    if [[ -n "$TEAMS_WEBHOOK" ]]; then
        local teams_payload
        teams_payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "$(case $color in good) echo '00FF00' ;; warning) echo 'FFFF00' ;; danger) echo 'FF0000' ;; esac)",
    "summary": "Zero-Trust Location System Report",
    "sections": [{
        "activityTitle": "Zero-Trust Location System Nightly Report",
        "activitySubtitle": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
        "facts": [{
            "name": "Status",
            "value": "$status"
        }, {
            "name": "Message",
            "value": "$message"
        }]
    }]
}
EOF
        )

        if curl -s -X POST -H 'Content-Type: application/json' --data "$teams_payload" "$TEAMS_WEBHOOK" &> /dev/null; then
            info "Teams notification sent successfully"
        else
            warning "Failed to send Teams notification"
        fi
    fi
}

# Cleanup old logs
cleanup_logs() {
    info "Cleaning up old log files..."

    local retention_days=30

    if [[ -d "$LOG_DIR" ]]; then
        # Remove logs older than retention period
        find "$LOG_DIR" -name "*.log" -type f -mtime +$retention_days -delete 2>/dev/null || true
        find "$LOG_DIR" -name "*.json" -type f -mtime +$retention_days -delete 2>/dev/null || true

        success "Log cleanup completed"
    fi
}

# Main execution function
main() {
    local overall_status="SUCCESS"
    local status_message="All systems healthy"
    local error_details=""

    info "==========================================="
    info "Zero-Trust Location System Nightly Runner"
    info "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    info "==========================================="

    # Run all checks
    check_dependencies

    if ! test_database_connection; then
        overall_status="ERROR"
        status_message="Database connection failed"
        error_details="Unable to connect to database"
    elif ! run_comprehensive_validation; then
        overall_status="ERROR"
        status_message="Validation checks failed"
        error_details="One or more validation checks did not pass"
    elif ! capture_snapshot; then
        overall_status="WARNING"
        status_message="Snapshot capture failed"
        error_details="Unable to capture monitoring snapshot"
    elif ! evaluate_slos; then
        overall_status="ERROR"
        status_message="SLO violations detected"
        error_details="One or more Service Level Objectives are not being met"
    elif ! process_alerts; then
        overall_status="WARNING"
        status_message="New alerts generated"
        error_details="System generated new alerts requiring attention"
    else
        # All checks passed - run additional tasks
        generate_metrics_summary
        run_basic_validation
        cleanup_logs
    fi

    # Generate summary
    local summary
    summary=$(cat <<EOF
Nightly Runner Summary - $(date '+%Y-%m-%d %H:%M:%S')
Status: $overall_status
Message: $status_message
Log File: $LOG_FILE
EOF
    )

    echo "$summary" | tee "$SUMMARY_FILE"

    # Send notification
    send_notification "$overall_status" "$status_message" "$error_details"

    info "==========================================="
    info "Nightly Runner Completed: $overall_status"
    info "==========================================="

    # Exit with appropriate code
    case "$overall_status" in
        "SUCCESS") exit 0 ;;
        "WARNING") exit 1 ;;
        "ERROR") exit 2 ;;
        *) exit 3 ;;
    esac
}

# Help function
show_help() {
    cat << EOF
Zero-Trust Location System Nightly Runner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    run             Run complete nightly validation suite (default)
    test            Test database connection and dependencies only
    validate        Run validation checks only
    snapshot        Capture monitoring snapshot only
    slos            Evaluate SLOs only
    alerts          Process alerts only
    cleanup         Cleanup old logs only
    help            Show this help message

ENVIRONMENT VARIABLES:
    DATABASE_URL         PostgreSQL connection string
    SLACK_WEBHOOK_URL    Slack webhook for notifications (optional)
    TEAMS_WEBHOOK_URL    Microsoft Teams webhook for notifications (optional)

EXAMPLES:
    $0                  # Run complete nightly suite
    $0 test            # Test connectivity only
    $0 validate        # Run validation checks only
    $0 cleanup         # Cleanup logs only

LOG FILES:
    Individual run logs: $LOG_DIR/nightly_runner_YYYYMMDD_HHMMSS.log
    Daily summaries:     $LOG_DIR/nightly_summary_YYYYMMDD.log
    JSON outputs:        $LOG_DIR/*.json

EOF
}

# Command handling
case "${1:-run}" in
    run)
        main
        ;;
    test)
        check_dependencies
        test_database_connection
        ;;
    validate)
        check_dependencies
        test_database_connection
        run_comprehensive_validation
        ;;
    snapshot)
        check_dependencies
        test_database_connection
        capture_snapshot
        ;;
    slos)
        check_dependencies
        test_database_connection
        evaluate_slos
        ;;
    alerts)
        check_dependencies
        test_database_connection
        process_alerts
        ;;
    cleanup)
        cleanup_logs
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