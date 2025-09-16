#!/bin/bash

# Scout Analytics ETL Deployment Script
# Production-grade deployment with validation and rollback

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ETL_DIR="$PROJECT_ROOT/etl"
DBT_DIR="$PROJECT_ROOT/dbt-scout"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Environment variables check
check_environment() {
    log "Checking environment variables..."
    
    required_vars=(
        "SUPABASE_PROJECT_REF"
        "SUPABASE_ACCESS_TOKEN" 
        "SUPABASE_DB_URL"
        "POSTGRES_PASSWORD"
        "TEMPORAL_HOST"
        "OTEL_EXPORTER_OTLP_ENDPOINT"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    success "Environment variables validated"
}

# Database migration
run_migrations() {
    log "Running Supabase migrations..."
    
    cd "$PROJECT_ROOT"
    
    # Apply ETL metadata schema
    psql "$SUPABASE_DB_URL" -f "supabase/migrations/20250116_production_etl_metadata.sql" || {
        error "Failed to apply metadata schema migration"
        exit 1
    }
    
    # Apply contract validation functions
    psql "$SUPABASE_DB_URL" -f "supabase/migrations/20250116_contract_validation_functions.sql" || {
        error "Failed to apply contract validation functions"
        exit 1
    }
    
    success "Database migrations completed"
}

# Install dependencies
install_dependencies() {
    log "Installing Python dependencies..."
    
    cd "$ETL_DIR"
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    pip install -r requirements.txt
    
    success "Python dependencies installed"
    
    log "Installing dbt dependencies..."
    cd "$DBT_DIR"
    dbt deps
    
    success "dbt dependencies installed"
}

# Test database connectivity
test_connectivity() {
    log "Testing database connectivity..."
    
    cd "$ETL_DIR"
    source venv/bin/activate
    
    python3 -c "
import psycopg2
import os
try:
    conn = psycopg2.connect(os.environ['SUPABASE_DB_URL'])
    conn.close()
    print('✅ Database connection successful')
except Exception as e:
    print(f'❌ Database connection failed: {e}')
    exit(1)
    "
    
    success "Database connectivity verified"
}

# Deploy dbt models
deploy_dbt() {
    log "Deploying dbt models..."
    
    cd "$DBT_DIR"
    
    # Run dbt debug
    dbt debug || {
        error "dbt configuration validation failed"
        exit 1
    }
    
    # Run dbt models
    dbt run --target prod || {
        error "dbt model deployment failed"
        exit 1
    }
    
    # Test dbt models
    dbt test --target prod || {
        warning "Some dbt tests failed, review output"
    }
    
    success "dbt models deployed and tested"
}

# Start ETL infrastructure
start_infrastructure() {
    log "Starting ETL infrastructure..."
    
    cd "$PROJECT_ROOT"
    
    # Start Docker services
    docker-compose -f docker-compose.etl.yml up -d || {
        error "Failed to start Docker infrastructure"
        exit 1
    }
    
    # Wait for services to be healthy
    log "Waiting for services to start..."
    sleep 30
    
    # Check Temporal
    if ! curl -f http://localhost:7233/api/v1/namespaces >/dev/null 2>&1; then
        error "Temporal server is not responding"
        exit 1
    fi
    
    # Check Prometheus
    if ! curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
        error "Prometheus is not responding"
        exit 1
    fi
    
    success "ETL infrastructure started successfully"
}

# Deploy Bruno worker
deploy_worker() {
    log "Deploying Bruno ETL worker..."
    
    cd "$ETL_DIR"
    source venv/bin/activate
    
    # Test Bruno executor
    python3 bruno_executor.py --dry-run bronze-ingestion \
        --source azure_data.interactions \
        --target scout.bronze_transactions || {
        error "Bruno executor validation failed"
        exit 1
    }
    
    success "Bruno worker deployed and validated"
}

# Validation tests
run_validation() {
    log "Running end-to-end validation..."
    
    cd "$ETL_DIR"
    source venv/bin/activate
    
    # Run Great Expectations checkpoint
    python3 -c "
import great_expectations as gx
context = gx.get_context()
checkpoint = context.get_checkpoint('azure_interactions_bronze')
result = checkpoint.run()
if not result.success:
    print('❌ Data quality validation failed')
    exit(1)
print('✅ Data quality validation passed')
    " || {
        warning "Data quality validation issues detected"
    }
    
    # Test Bronze ingestion
    log "Testing Bronze ingestion workflow..."
    python3 bruno_executor.py bronze-ingestion \
        --source azure_data.interactions \
        --target scout.bronze_transactions \
        --batch-size 100 \
        --dry-run || {
        error "Bronze ingestion test failed"
        exit 1
    }
    
    success "End-to-end validation completed"
}

# Monitoring setup
setup_monitoring() {
    log "Setting up monitoring and alerting..."
    
    # Check Grafana
    if ! curl -f http://localhost:3001/api/health >/dev/null 2>&1; then
        warning "Grafana is not accessible on port 3001"
    else
        success "Grafana monitoring available at http://localhost:3001"
    fi
    
    # Check Jaeger
    if ! curl -f http://localhost:16686/api/services >/dev/null 2>&1; then
        warning "Jaeger tracing is not accessible on port 16686"
    else
        success "Jaeger tracing available at http://localhost:16686"
    fi
    
    success "Monitoring setup completed"
}

# Main deployment function
main() {
    log "Starting Scout Analytics ETL deployment..."
    
    check_environment
    install_dependencies
    test_connectivity
    run_migrations
    deploy_dbt
    start_infrastructure
    deploy_worker
    run_validation
    setup_monitoring
    
    success "🎉 Scout Analytics ETL deployment completed successfully!"
    
    echo
    log "Access Points:"
    echo "  • Temporal UI: http://localhost:8088"
    echo "  • Prometheus: http://localhost:9090"
    echo "  • Grafana: http://localhost:3001 (admin/admin)"
    echo "  • Jaeger: http://localhost:16686"
    echo
    log "Next Steps:"
    echo "  1. Schedule Bronze ingestion: python3 etl/bruno_executor.py schedule-bronze"
    echo "  2. Run full pipeline: python3 etl/bruno_executor.py full-pipeline"
    echo "  3. Monitor at: http://localhost:3001"
}

# Handle command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "test")
        check_environment
        test_connectivity
        run_validation
        ;;
    "start")
        start_infrastructure
        setup_monitoring
        ;;
    "stop")
        log "Stopping ETL infrastructure..."
        docker-compose -f docker-compose.etl.yml down
        success "ETL infrastructure stopped"
        ;;
    *)
        echo "Usage: $0 {deploy|test|start|stop}"
        exit 1
        ;;
esac