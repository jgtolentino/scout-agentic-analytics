#!/bin/bash
# ==========================================
# Scout Edge JSON Transformation Deployment
# Deploy production JSON payload builders to both platforms
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
AZURE_SQL_FILE="${SCRIPT_DIR}/azure/02_emit_payload_json_production.sql"
POSTGRES_SQL_FILE="${SCRIPT_DIR}/supabase/02_emit_payload_json_production.sql"
VALIDATION_FILE="${SCRIPT_DIR}/validation/02_json_payload_validation.sql"

# Environment validation
check_environment() {
    echo -e "${BLUE}Checking deployment environment...${NC}"

    # Check for required files
    local required_files=(
        "$AZURE_SQL_FILE"
        "$POSTGRES_SQL_FILE"
        "$VALIDATION_FILE"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}ERROR: Required file not found: $file${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}✓ All required files found${NC}"
}

# Deploy to Azure SQL
deploy_azure_sql() {
    echo -e "${BLUE}Deploying JSON transformation to Azure SQL...${NC}"

    # Check if Azure SQL connection is available
    if ! command -v sqlcmd &> /dev/null; then
        echo -e "${YELLOW}WARNING: sqlcmd not found, skipping Azure SQL deployment${NC}"
        echo -e "${YELLOW}Manual execution required: ${AZURE_SQL_FILE}${NC}"
        return 0
    fi

    # Try to deploy (requires environment variables)
    if [[ -n "${AZURE_SQL_SERVER:-}" && -n "${AZURE_SQL_DATABASE:-}" ]]; then
        echo "Executing Azure SQL transformation..."
        sqlcmd -S "$AZURE_SQL_SERVER" -d "$AZURE_SQL_DATABASE" -i "$AZURE_SQL_FILE"

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ Azure SQL deployment successful${NC}"
        else
            echo -e "${RED}✗ Azure SQL deployment failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Azure SQL credentials not configured, manual execution required:${NC}"
        echo -e "${YELLOW}File: ${AZURE_SQL_FILE}${NC}"
        echo -e "${YELLOW}Run: EXEC dbo.sp_emit_fact_payload_json;${NC}"
    fi
}

# Deploy to PostgreSQL/Supabase
deploy_postgresql() {
    echo -e "${BLUE}Deploying JSONB transformation to PostgreSQL/Supabase...${NC}"

    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        echo -e "${YELLOW}WARNING: psql not found, skipping PostgreSQL deployment${NC}"
        echo -e "${YELLOW}Manual execution required: ${POSTGRES_SQL_FILE}${NC}"
        return 0
    fi

    # Try to deploy (requires environment variables)
    if [[ -n "${DATABASE_URL:-}" ]]; then
        echo "Executing PostgreSQL transformation..."
        psql "$DATABASE_URL" -f "$POSTGRES_SQL_FILE"

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ PostgreSQL deployment successful${NC}"
        else
            echo -e "${RED}✗ PostgreSQL deployment failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}PostgreSQL credentials not configured, manual execution required:${NC}"
        echo -e "${YELLOW}File: ${POSTGRES_SQL_FILE}${NC}"
        echo -e "${YELLOW}Run: SELECT * FROM public.emit_fact_payload_json();${NC}"
    fi
}

# Execute transformations
execute_transformations() {
    echo -e "${BLUE}Executing JSON payload transformations...${NC}"

    # Azure SQL execution
    if [[ -n "${AZURE_SQL_SERVER:-}" && -n "${AZURE_SQL_DATABASE:-}" ]] && command -v sqlcmd &> /dev/null; then
        echo "Running Azure SQL transformation..."
        sqlcmd -S "$AZURE_SQL_SERVER" -d "$AZURE_SQL_DATABASE" -Q "EXEC dbo.sp_emit_fact_payload_json;"
        echo -e "${GREEN}✓ Azure SQL transformation executed${NC}"
    else
        echo -e "${YELLOW}Azure SQL: Manual execution required${NC}"
        echo -e "${YELLOW}Command: EXEC dbo.sp_emit_fact_payload_json;${NC}"
    fi

    # PostgreSQL execution
    if [[ -n "${DATABASE_URL:-}" ]] && command -v psql &> /dev/null; then
        echo "Running PostgreSQL transformation..."
        psql "$DATABASE_URL" -c "SELECT * FROM public.emit_fact_payload_json();"
        echo -e "${GREEN}✓ PostgreSQL transformation executed${NC}"
    else
        echo -e "${YELLOW}PostgreSQL: Manual execution required${NC}"
        echo -e "${YELLOW}Command: SELECT * FROM public.emit_fact_payload_json();${NC}"
    fi
}

# Validation
run_validation() {
    echo -e "${BLUE}Running cross-platform validation...${NC}"

    # Display validation instructions
    echo -e "${YELLOW}Cross-platform validation queries available in:${NC}"
    echo -e "${YELLOW}${VALIDATION_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}Key validation metrics to check:${NC}"
    echo "• JSON structure validity: 100%"
    echo "• Location coverage: >70%"
    echo "• Average quality score: >70"
    echo "• Substitution rate: ~18%"
    echo "• Query performance: <500ms"
    echo ""
    echo -e "${YELLOW}Expected transaction counts:${NC}"
    echo "• Supabase/Scout Edge: ~13,149 transactions"
    echo "• Azure SQL: ~165,480 interactions → ~13,149 deduplicated transactions"
}

# Generate deployment report
generate_report() {
    echo -e "${BLUE}Generating deployment report...${NC}"

    local report_file="${SCRIPT_DIR}/deployment_report_$(date +%Y%m%d_%H%M%S).md"

    cat > "$report_file" << EOF
# Scout Edge JSON Transformation Deployment Report

**Date**: $(date)
**Deployment ID**: scout-json-$(date +%Y%m%d-%H%M%S)

## Deployment Summary

### Files Deployed
- Azure SQL: \`azure/02_emit_payload_json_production.sql\`
- PostgreSQL: \`supabase/02_emit_payload_json_production.sql\`
- Validation: \`validation/02_json_payload_validation.sql\`

### Execution Commands

#### Azure SQL
\`\`\`sql
-- Deploy stored procedure and views
-- Run from: ${AZURE_SQL_FILE}

-- Execute transformation
EXEC dbo.sp_emit_fact_payload_json;

-- Validation
SELECT COUNT(*) as total_transactions,
       COUNT(payload_json) as with_json_payload,
       AVG(LEN(payload_json)) / 1024.0 as avg_payload_kb
FROM dbo.fact_transactions_location;
\`\`\`

#### PostgreSQL/Supabase
\`\`\`sql
-- Deploy function and views
-- Run from: ${POSTGRES_SQL_FILE}

-- Execute transformation
SELECT * FROM public.emit_fact_payload_json();

-- Validation
SELECT COUNT(*) as total_transactions,
       COUNT(payload_json) as with_jsonb_payload,
       ROUND(AVG(octet_length(payload_json::text)) / 1024.0, 2) as avg_payload_kb
FROM fact_transactions_location;
\`\`\`

### Expected Results
- **Total Transactions**: ~13,149 deduplicated JSON payloads
- **Payload Size**: 1-3KB per transaction
- **Substitution Rate**: ~18% of transactions
- **Location Coverage**: >70% with verified coordinates
- **Quality Score**: >70 average

### Validation Checklist
- [ ] JSON structure validity: 100%
- [ ] Transaction count matches expected baseline
- [ ] Substitution detection working correctly
- [ ] Geographic data properly enriched
- [ ] Performance indexes applied (see performance/03_json_query_indexes.sql)
- [ ] Cross-platform results within <1% variance

## Next Steps
1. Execute transformations on both platforms
2. Run validation queries from validation/02_json_payload_validation.sql
3. Apply performance indexes from performance/03_json_query_indexes.sql
4. Verify cross-platform consistency

EOF

    echo -e "${GREEN}✓ Deployment report generated: ${report_file}${NC}"
}

# Help function
show_help() {
    cat << EOF
Scout Edge JSON Transformation Deployment

USAGE:
    $0 [OPTIONS]

OPTIONS:
    deploy          Deploy JSON transformation procedures to both platforms
    execute         Execute the transformations (build JSON payloads)
    validate        Run validation queries
    report          Generate deployment report
    help            Show this help message

ENVIRONMENT VARIABLES:
    AZURE_SQL_SERVER     Azure SQL Server name (optional)
    AZURE_SQL_DATABASE   Azure SQL Database name (optional)
    DATABASE_URL         PostgreSQL connection string (optional)

EXAMPLES:
    $0 deploy           # Deploy to both platforms
    $0 execute          # Run transformations
    $0 validate         # Show validation instructions
    $0 report           # Generate deployment report

EOF
}

# Main execution
main() {
    local command="${1:-help}"

    case "$command" in
        deploy)
            check_environment
            deploy_azure_sql
            deploy_postgresql
            echo -e "${GREEN}Deployment complete! Run '$0 execute' to build JSON payloads.${NC}"
            ;;
        execute)
            execute_transformations
            echo -e "${GREEN}Transformations complete! Run '$0 validate' for validation.${NC}"
            ;;
        validate)
            run_validation
            ;;
        report)
            generate_report
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"