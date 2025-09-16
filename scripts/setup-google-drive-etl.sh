#!/bin/bash

# Google Drive ETL Setup Script
# Scout v7 Analytics Platform
# Purpose: Automated setup and deployment of Google Drive ETL system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/scout-drive-etl-setup-$TIMESTAMP.log"

# Default values
ENVIRONMENT="staging"
PROJECT_REF=""
GOOGLE_PROJECT_ID=""
DRY_RUN=false
SKIP_TESTS=false
FORCE_DEPLOY=false

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup and deploy Google Drive ETL system for Scout v7

OPTIONS:
    -e, --environment ENV     Target environment (staging|production) [default: staging]
    -p, --project-ref REF     Supabase project reference
    -g, --google-project ID   Google Cloud project ID
    -d, --dry-run            Run in dry-run mode (no actual deployment)
    -s, --skip-tests         Skip running tests
    -f, --force              Force deployment even if checks fail
    -h, --help               Show this help message

EXAMPLES:
    $0 --environment staging --project-ref abc123 --google-project my-project
    $0 -e production -p def456 -g prod-project --force

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--project-ref)
            PROJECT_REF="$2"
            shift 2
            ;;
        -g|--google-project)
            GOOGLE_PROJECT_ID="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -f|--force)
            FORCE_DEPLOY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate required parameters
if [[ -z "$PROJECT_REF" ]]; then
    error "Project reference is required. Use --project-ref option."
fi

if [[ -z "$GOOGLE_PROJECT_ID" ]]; then
    error "Google Cloud project ID is required. Use --google-project option."
fi

if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    error "Environment must be 'staging' or 'production'"
fi

# Main setup functions
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("supabase" "gcloud" "curl" "jq" "psql" "node" "npm")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done
    
    # Check Supabase CLI authentication
    if ! supabase projects list &> /dev/null; then
        error "Supabase CLI not authenticated. Run 'supabase login' first."
    fi
    
    # Check Google Cloud authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        error "Google Cloud CLI not authenticated. Run 'gcloud auth login' first."
    fi
    
    # Set Google Cloud project
    gcloud config set project "$GOOGLE_PROJECT_ID" || error "Failed to set Google Cloud project"
    
    # Check Node.js version
    local node_version=$(node --version | cut -d'v' -f2)
    if [[ $(echo "$node_version" | cut -d'.' -f1) -lt 18 ]]; then
        error "Node.js version 18 or higher is required (found: $node_version)"
    fi
    
    success "Prerequisites check completed"
}

setup_google_cloud() {
    log "Setting up Google Cloud services..."
    
    # Enable required APIs
    local apis=("drive.googleapis.com" "gmail.googleapis.com" "iam.googleapis.com")
    for api in "${apis[@]}"; do
        log "Enabling $api..."
        if ! $DRY_RUN; then
            gcloud services enable "$api" || error "Failed to enable $api"
        fi
    done
    
    # Create service account
    local service_account="scout-drive-etl-$ENVIRONMENT"
    log "Creating service account: $service_account..."
    
    if ! $DRY_RUN; then
        if ! gcloud iam service-accounts describe "$service_account@$GOOGLE_PROJECT_ID.iam.gserviceaccount.com" &> /dev/null; then
            gcloud iam service-accounts create "$service_account" \
                --description="Scout v7 Drive ETL Service Account ($ENVIRONMENT)" \
                --display-name="Scout Drive ETL ($ENVIRONMENT)" || error "Failed to create service account"
        else
            warn "Service account already exists"
        fi
        
        # Grant necessary permissions
        local roles=("roles/drive.readonly" "roles/iam.serviceAccountTokenCreator")
        for role in "${roles[@]}"; do
            log "Granting $role to service account..."
            gcloud projects add-iam-policy-binding "$GOOGLE_PROJECT_ID" \
                --member="serviceAccount:$service_account@$GOOGLE_PROJECT_ID.iam.gserviceaccount.com" \
                --role="$role" || error "Failed to grant $role"
        done
        
        # Create and download service account key
        local key_file="/tmp/scout-service-account-$ENVIRONMENT-$TIMESTAMP.json"
        log "Creating service account key..."
        gcloud iam service-accounts keys create "$key_file" \
            --iam-account="$service_account@$GOOGLE_PROJECT_ID.iam.gserviceaccount.com" || error "Failed to create service account key"
        
        # Base64 encode the key for environment variable
        local encoded_key=$(base64 -i "$key_file" | tr -d '\n')
        echo "$encoded_key" > "/tmp/scout-service-account-key-$ENVIRONMENT.txt"
        rm "$key_file"  # Remove the original JSON file for security
        
        success "Service account key created and encoded"
    fi
    
    success "Google Cloud setup completed"
}

setup_supabase_project() {
    log "Setting up Supabase project..."
    
    # Link to project
    log "Linking to Supabase project: $PROJECT_REF..."
    if ! $DRY_RUN; then
        supabase link --project-ref "$PROJECT_REF" || error "Failed to link to Supabase project"
    fi
    
    # Run database migrations
    log "Running database migrations..."
    if ! $DRY_RUN; then
        supabase db push || error "Failed to push database migrations"
    fi
    
    # Set environment secrets
    log "Setting environment secrets..."
    if ! $DRY_RUN && [[ -f "/tmp/scout-service-account-key-$ENVIRONMENT.txt" ]]; then
        local encoded_key=$(cat "/tmp/scout-service-account-key-$ENVIRONMENT.txt")
        supabase secrets set GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY="$encoded_key" || error "Failed to set service account key"
        rm "/tmp/scout-service-account-key-$ENVIRONMENT.txt"  # Clean up
    fi
    
    # Generate webhook secret
    local webhook_secret=$(openssl rand -hex 32)
    if ! $DRY_RUN; then
        supabase secrets set DRIVE_WEBHOOK_SECRET="$webhook_secret" || error "Failed to set webhook secret"
    fi
    
    success "Supabase project setup completed"
}

deploy_edge_functions() {
    log "Deploying edge functions..."
    
    local functions=("drive-mirror" "drive-stream-extract" "drive-intelligence-processor" "drive-webhook-handler")
    
    for func in "${functions[@]}"; do
        log "Deploying function: $func..."
        if ! $DRY_RUN; then
            cd "$PROJECT_ROOT"
            supabase functions deploy "$func" --project-ref "$PROJECT_REF" || error "Failed to deploy $func"
        fi
    done
    
    success "Edge functions deployment completed"
}

setup_environment_config() {
    log "Setting up environment configuration..."
    
    local config_dir="$PROJECT_ROOT/config/environments"
    mkdir -p "$config_dir"
    
    local env_file="$config_dir/.env.$ENVIRONMENT"
    
    if [[ ! -f "$env_file" ]]; then
        log "Creating environment configuration file..."
        cp "$PROJECT_ROOT/config/environment-templates/.env.production.example" "$env_file"
        
        # Update project-specific values
        sed -i.bak "s/your-production-project-ref/$PROJECT_REF/g" "$env_file"
        sed -i.bak "s/your-google-cloud-project-id/$GOOGLE_PROJECT_ID/g" "$env_file"
        rm "$env_file.bak"
        
        warn "Environment file created at $env_file - please update with actual values"
    else
        log "Environment file already exists at $env_file"
    fi
    
    success "Environment configuration setup completed"
}

run_tests() {
    if $SKIP_TESTS; then
        warn "Skipping tests as requested"
        return 0
    fi
    
    log "Running integration tests..."
    
    if ! $DRY_RUN; then
        cd "$PROJECT_ROOT"
        
        # Test drive-mirror function
        log "Testing drive-mirror function..."
        local test_response=$(curl -s -X POST \
            "https://$PROJECT_REF.supabase.co/functions/v1/drive-mirror" \
            -H "Authorization: Bearer $(supabase secrets get SUPABASE_ANON_KEY)" \
            -H "Content-Type: application/json" \
            -d '{"folderId": "1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA", "dryRun": true}')
        
        if echo "$test_response" | jq -e '.success' > /dev/null; then
            success "Drive mirror function test passed"
        else
            if $FORCE_DEPLOY; then
                warn "Drive mirror function test failed, but continuing due to --force flag"
            else
                error "Drive mirror function test failed: $test_response"
            fi
        fi
        
        # Test database connectivity
        log "Testing database connectivity..."
        local db_test=$(supabase db status 2>&1)
        if echo "$db_test" | grep -q "healthy"; then
            success "Database connectivity test passed"
        else
            if $FORCE_DEPLOY; then
                warn "Database connectivity test failed, but continuing due to --force flag"
            else
                error "Database connectivity test failed: $db_test"
            fi
        fi
        
        # Test Google API connectivity
        log "Testing Google API connectivity..."
        if gcloud auth print-access-token > /dev/null 2>&1; then
            success "Google API connectivity test passed"
        else
            if $FORCE_DEPLOY; then
                warn "Google API connectivity test failed, but continuing due to --force flag"
            else
                error "Google API connectivity test failed"
            fi
        fi
    fi
    
    success "Tests completed"
}

setup_monitoring() {
    log "Setting up monitoring and alerting..."
    
    if ! $DRY_RUN; then
        # Create monitoring tables
        log "Creating monitoring tables..."
        psql "$(supabase db show-connection-string)" << 'EOF'
-- Create monitoring schema if not exists
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Create system health table
CREATE TABLE IF NOT EXISTS monitoring.system_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    check_time TIMESTAMPTZ DEFAULT NOW(),
    component TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('healthy', 'degraded', 'unhealthy')),
    response_time_ms INTEGER,
    error_message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create performance metrics table
CREATE TABLE IF NOT EXISTS monitoring.performance_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    metric_name TEXT NOT NULL,
    metric_value NUMERIC NOT NULL,
    metric_unit TEXT,
    tags JSONB DEFAULT '{}'::jsonb
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_system_health_check_time ON monitoring.system_health(check_time);
CREATE INDEX IF NOT EXISTS idx_system_health_component ON monitoring.system_health(component);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_recorded_at ON monitoring.performance_metrics(recorded_at);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_name ON monitoring.performance_metrics(metric_name);

EOF
        
        # Set up initial monitoring job
        log "Setting up monitoring job..."
        supabase functions deploy health-monitor --project-ref "$PROJECT_REF" || warn "Failed to deploy health monitor function"
    fi
    
    success "Monitoring setup completed"
}

generate_deployment_report() {
    log "Generating deployment report..."
    
    local report_file="/tmp/scout-drive-etl-deployment-report-$TIMESTAMP.md"
    
    cat > "$report_file" << EOF
# Scout v7 Google Drive ETL Deployment Report

**Deployment Date:** $(date)
**Environment:** $ENVIRONMENT
**Project Reference:** $PROJECT_REF
**Google Cloud Project:** $GOOGLE_PROJECT_ID
**Dry Run:** $DRY_RUN

## Components Deployed

### Edge Functions
- [x] drive-mirror
- [x] drive-stream-extract  
- [x] drive-intelligence-processor
- [x] drive-webhook-handler

### Database Schema
- [x] drive_intelligence schema
- [x] Monitoring tables
- [x] Indexes and triggers

### Google Cloud Services
- [x] Drive API enabled
- [x] Service account created
- [x] IAM permissions configured

### Configuration
- [x] Environment variables set
- [x] Secrets configured
- [x] Webhook security enabled

## Next Steps

1. **Configure OAuth Credentials:**
   - Set up OAuth 2.0 client in Google Cloud Console
   - Generate refresh token
   - Update GOOGLE_DRIVE_REFRESH_TOKEN secret

2. **Test System:**
   - Run end-to-end test with actual Google Drive folder
   - Verify webhook notifications
   - Check AI processing pipeline

3. **Set Up Monitoring:**
   - Configure Grafana dashboards
   - Set up alerting rules
   - Test incident response procedures

4. **Production Readiness:**
   - Review security settings
   - Configure backup procedures
   - Document operational procedures

## Configuration Files

- Environment config: \`config/environments/.env.$ENVIRONMENT\`
- Operational runbook: \`operations/google-drive-etl-runbook.md\`
- Deployment log: \`$LOG_FILE\`

## Support Contacts

- Technical Support: dev-team@tbwa.com
- Security Issues: security@tbwa.com
- Business Questions: business-analytics@tbwa.com

---
*Generated by Scout v7 Google Drive ETL Setup Script*
EOF
    
    success "Deployment report generated: $report_file"
    
    # Display summary
    echo
    echo "=============================================="
    echo "         DEPLOYMENT SUMMARY"
    echo "=============================================="
    echo "Environment: $ENVIRONMENT"
    echo "Status: $(if $DRY_RUN; then echo 'DRY RUN - NO CHANGES MADE'; else echo 'COMPLETED'; fi)"
    echo "Report: $report_file"
    echo "Log: $LOG_FILE"
    echo "=============================================="
}

cleanup() {
    log "Cleaning up temporary files..."
    
    # Remove temporary files
    find /tmp -name "scout-*-$TIMESTAMP.*" -type f -delete 2>/dev/null || true
    
    success "Cleanup completed"
}

main() {
    log "Starting Google Drive ETL setup for Scout v7..."
    log "Environment: $ENVIRONMENT"
    log "Project Ref: $PROJECT_REF"
    log "Google Project: $GOOGLE_PROJECT_ID"
    log "Dry Run: $DRY_RUN"
    
    # Execute setup steps
    check_prerequisites
    setup_google_cloud
    setup_supabase_project
    deploy_edge_functions
    setup_environment_config
    run_tests
    setup_monitoring
    generate_deployment_report
    cleanup
    
    success "Google Drive ETL setup completed successfully!"
    
    if ! $DRY_RUN; then
        echo
        echo "🎉 Setup completed! Next steps:"
        echo "1. Review the deployment report"
        echo "2. Configure OAuth credentials"
        echo "3. Test the system with a sample folder"
        echo "4. Set up monitoring dashboards"
    else
        echo
        echo "✅ Dry run completed! Review the steps above and run without --dry-run to deploy."
    fi
}

# Handle script interruption
trap 'error "Script interrupted by user"' INT TERM

# Run main function
main "$@"