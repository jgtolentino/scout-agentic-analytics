#!/bin/bash

# ================================================================
# Scout v7 Schema Sync Runner
# ================================================================
# Wrapper script for running the Schema Sync Agent with proper
# environment configuration and error handling
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AGENT_DIR="${PROJECT_ROOT}/etl/agents"

# Default configuration
MODE="${1:-sync}"
LOG_LEVEL="${2:-INFO}"
DRY_RUN="${3:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

# Usage information
usage() {
    cat << EOF
Scout v7 Schema Sync Runner

Usage: $0 [MODE] [LOG_LEVEL] [DRY_RUN]

MODES:
  sync     - Perform one-time schema synchronization (default)
  monitor  - Start continuous monitoring daemon
  validate - Validate ETL contracts only

LOG_LEVELS:
  DEBUG, INFO (default), WARNING, ERROR

DRY_RUN:
  true  - Show what would be done without making changes
  false - Execute normally (default)

Examples:
  $0                           # Quick sync with default settings
  $0 monitor INFO              # Start monitoring daemon
  $0 validate                  # Just validate contracts
  $0 sync DEBUG true           # Debug sync in dry-run mode

Environment Variables:
  AZURE_SQL_SERVER    - SQL Server hostname
  AZURE_SQL_DATABASE  - Database name
  AZURE_SQL_USER      - Database username
  AZURE_SQL_PASSWORD  - Database password
  GITHUB_TOKEN        - GitHub API token for PR creation
  GITHUB_OWNER        - GitHub repository owner
  GITHUB_REPO         - GitHub repository name

EOF
}

# Check if help requested
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Validate mode
case "${MODE}" in
    sync|monitor|validate)
        ;;
    *)
        error "Invalid mode: ${MODE}"
        usage
        exit 1
        ;;
esac

# Check required dependencies
check_dependencies() {
    log "Checking dependencies..."

    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
        exit 1
    fi

    # Check required Python packages
    local required_packages=("pyodbc" "asyncio" "httpx" "jinja2")
    for package in "${required_packages[@]}"; do
        if ! python3 -c "import ${package}" &> /dev/null; then
            warn "Python package '${package}' not found. Installing..."
            pip3 install "${package}"
        fi
    done

    # Check if agent exists
    if [[ ! -f "${AGENT_DIR}/schema_sync_agent.py" ]]; then
        error "Schema sync agent not found at ${AGENT_DIR}/schema_sync_agent.py"
        exit 1
    fi

    success "All dependencies verified"
}

# Check environment configuration
check_environment() {
    log "Checking environment configuration..."

    local required_vars=("AZURE_SQL_SERVER" "AZURE_SQL_DATABASE" "AZURE_SQL_USER")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("${var}")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - ${var}"
        done
        echo ""
        echo "Set these variables in your environment or .env file"
        exit 1
    fi

    # Check optional GitHub configuration
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        warn "GITHUB_TOKEN not set - PR creation will be disabled"
    fi

    success "Environment configuration verified"
}

# Run the schema sync agent
run_agent() {
    log "Starting Schema Sync Agent in ${MODE} mode..."

    cd "${AGENT_DIR}"

    local cmd_args=(
        "--mode" "${MODE}"
        "--log-level" "${LOG_LEVEL}"
    )

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY RUN MODE - No changes will be made"
        # Add dry-run flag if agent supports it
        # cmd_args+=("--dry-run")
    fi

    # Set repository path for agent
    export REPO_PATH="${PROJECT_ROOT}"

    # Run the agent
    if python3 schema_sync_agent.py "${cmd_args[@]}"; then
        success "Schema sync agent completed successfully"
        return 0
    else
        error "Schema sync agent failed with exit code $?"
        return 1
    fi
}

# Handle interruption gracefully
cleanup() {
    warn "Received interrupt signal. Cleaning up..."
    # Kill any background processes if in monitor mode
    if [[ "${MODE}" == "monitor" ]]; then
        pkill -f "schema_sync_agent.py" || true
    fi
    exit 130
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    log "Scout v7 Schema Sync Runner starting..."
    log "Mode: ${MODE} | Log Level: ${LOG_LEVEL} | Dry Run: ${DRY_RUN}"

    check_dependencies
    check_environment

    if run_agent; then
        success "Schema sync operation completed successfully"

        # Additional post-sync actions based on mode
        case "${MODE}" in
            sync)
                log "Sync completed. Check GitHub for any PRs created."
                ;;
            validate)
                log "Contract validation completed. Check output for any violations."
                ;;
            monitor)
                log "Monitoring daemon stopped."
                ;;
        esac

        exit 0
    else
        error "Schema sync operation failed"
        exit 1
    fi
}

# Run main function
main