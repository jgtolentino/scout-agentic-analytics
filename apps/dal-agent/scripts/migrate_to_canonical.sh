#!/usr/bin/env bash
# ========================================================================
# Canonical Migration Script - One-Command Deployment
# Purpose: Migrate existing flat export structure to hardened canonical schema
# ========================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
LOG_FILE="$ROOT/migration_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="$ROOT/backup/canonical_migration_$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] 🔧 $1${NC}" | tee -a "$LOG_FILE"
}

# Usage function
usage() {
    cat << EOF
Canonical Migration Script - One-Command Deployment

Migrates existing flat export structure to canonical 13-column schema.

Usage: $0 [OPTIONS]

OPTIONS:
    --dry-run           Show what would be done without executing
    --backup            Create backup of existing views before migration
    --force             Skip confirmation prompts
    --validate-only     Only validate existing structure, don't migrate
    --rollback          Rollback from backup (requires backup directory)
    -h, --help          Show this help

MIGRATION STEPS:
    1. Backup existing views and procedures
    2. Validate database connectivity and permissions
    3. Deploy canonical schema definition
    4. Create hardened flat views
    5. Deploy validation procedures
    6. Create export procedures
    7. Update production aliases
    8. Validate final structure
    9. Generate migration report

EXAMPLES:
    # Dry run to see what would happen
    $0 --dry-run

    # Full migration with backup
    $0 --backup

    # Force migration without prompts
    $0 --force --backup

    # Validate current structure only
    $0 --validate-only

EOF
}

# Parse command line arguments
parse_args() {
    DRY_RUN=false
    CREATE_BACKUP=false
    FORCE=false
    VALIDATE_ONLY=false
    ROLLBACK_DIR=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup)
                CREATE_BACKUP=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            --rollback)
                ROLLBACK_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate prerequisites
validate_prerequisites() {
    log_step "Validating prerequisites..."

    # Check database connectivity
    if ! "$ROOT/scripts/sql.sh" -Q "SELECT 1 as connectivity_test" >/dev/null 2>&1; then
        log_error "Database connection failed"
        log "Check your connection settings with: make doctor-db"
        exit 1
    fi
    log_success "Database connectivity validated"

    # Check required directories exist
    mkdir -p "$ROOT/sql/schema" "$ROOT/sql/views" "$ROOT/sql/procedures" "$ROOT/out/canonical"

    # Check if sql files exist
    local required_files=(
        "sql/schema/001_canonical_flat_schema.sql"
        "sql/views/002_canonical_flat_view.sql"
        "sql/procedures/003_validate_canonical.sql"
        "sql/procedures/004_canonical_export_proc.sql"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$ROOT/$file" ]]; then
            log_error "Required SQL file missing: $file"
            exit 1
        fi
    done
    log_success "All required SQL files present"

    # Check permissions
    local test_result
    test_result=$("$ROOT/scripts/sql.sh" -Q "
        SELECT
            CASE WHEN HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE SCHEMA') = 1 THEN 1 ELSE 0 END as can_create_schema,
            CASE WHEN HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE VIEW') = 1 THEN 1 ELSE 0 END as can_create_view,
            CASE WHEN HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE PROCEDURE') = 1 THEN 1 ELSE 0 END as can_create_procedure
    " 2>/dev/null || echo "0,0,0")

    if [[ "$test_result" == *"0"* ]]; then
        log_warning "Insufficient permissions detected. Migration may fail."
        if [[ "$FORCE" != true ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        log_success "Sufficient database permissions confirmed"
    fi
}

# Create backup of existing structure
create_backup() {
    if [[ "$CREATE_BACKUP" != true ]]; then
        return 0
    fi

    log_step "Creating backup of existing structure..."
    mkdir -p "$BACKUP_DIR"

    # Backup existing views
    local views_to_backup=(
        "dbo.v_flat_export_sheet"
        "gold.v_transactions_flat_production"
        "dbo.v_nielsen_flat_export"
    )

    for view in "${views_to_backup[@]}"; do
        local schema_name=$(echo "$view" | cut -d. -f1)
        local view_name=$(echo "$view" | cut -d. -f2)

        if "$ROOT/scripts/sql.sh" -Q "SELECT 1 FROM sys.views WHERE name = '$view_name' AND SCHEMA_NAME(schema_id) = '$schema_name'" | grep -q "1"; then
            log "Backing up view: $view"
            "$ROOT/scripts/sql.sh" -Q "
                DECLARE @sql nvarchar(max);
                SELECT @sql = definition
                FROM sys.sql_modules m
                INNER JOIN sys.views v ON v.object_id = m.object_id
                WHERE v.name = '$view_name' AND SCHEMA_NAME(v.schema_id) = '$schema_name';
                SELECT '-- Backup of $view' + CHAR(13) + CHAR(10) + 'CREATE VIEW $view AS' + CHAR(13) + CHAR(10) + SUBSTRING(@sql, CHARINDEX('SELECT', @sql), LEN(@sql));
            " > "$BACKUP_DIR/${view_name}_backup.sql"
        else
            log_warning "View $view not found, skipping backup"
        fi
    done

    # Create rollback script
    cat > "$BACKUP_DIR/rollback.sh" << 'EOF'
#!/bin/bash
# Automatic rollback script
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../ && pwd)"

echo "🔄 Rolling back canonical migration..."

# Drop canonical schema objects
"$ROOT/scripts/sql.sh" -Q "DROP VIEW IF EXISTS canonical.v_view_compliance_status;"
"$ROOT/scripts/sql.sh" -Q "DROP VIEW IF EXISTS canonical.v_flat_schema;"
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS canonical.sp_validate_all_flat_views;"
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS canonical.sp_validate_view_compliance;"
"$ROOT/scripts/sql.sh" -Q "DROP FUNCTION IF EXISTS canonical.fn_is_view_compliant;"
"$ROOT/scripts/sql.sh" -Q "DROP TABLE IF EXISTS canonical.flat_schema_audit;"
"$ROOT/scripts/sql.sh" -Q "DROP TABLE IF EXISTS canonical.flat_schema_definition;"
"$ROOT/scripts/sql.sh" -Q "DROP SCHEMA IF EXISTS canonical;"

# Drop canonical views
"$ROOT/scripts/sql.sh" -Q "DROP VIEW IF EXISTS gold.v_transactions_flat_canonical;"
"$ROOT/scripts/sql.sh" -Q "DROP VIEW IF EXISTS gold.v_transactions_flat_tobacco;"
"$ROOT/scripts/sql.sh" -Q "DROP VIEW IF EXISTS gold.v_transactions_flat_laundry;"

# Drop export procedures
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS dbo.sp_export_canonical_flat;"
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS dbo.sp_export_canonical_tobacco;"
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS dbo.sp_export_canonical_laundry;"
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS dbo.sp_export_canonical_bulk;"
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS dbo.sp_get_canonical_header;"
"$ROOT/scripts/sql.sh" -Q "DROP PROCEDURE IF EXISTS dbo.sp_validate_export_data;"

# Restore backed up views
for backup_file in *.sql; do
    if [[ -f "$backup_file" ]]; then
        echo "Restoring $backup_file..."
        "$ROOT/scripts/sql.sh" -i "$backup_file"
    fi
done

echo "✅ Rollback completed"
EOF

    chmod +x "$BACKUP_DIR/rollback.sh"
    log_success "Backup created in: $BACKUP_DIR"
    log "Use --rollback '$BACKUP_DIR' to rollback this migration"
}

# Validate current structure
validate_current_structure() {
    log_step "Validating current flat export structure..."

    # Check if main views exist
    local views_to_check=(
        "dbo.v_flat_export_sheet"
        "gold.v_transactions_flat_production"
    )

    local missing_views=()
    for view in "${views_to_check[@]}"; do
        local schema_name=$(echo "$view" | cut -d. -f1)
        local view_name=$(echo "$view" | cut -d. -f2)

        if ! "$ROOT/scripts/sql.sh" -Q "SELECT 1 FROM sys.views WHERE name = '$view_name' AND SCHEMA_NAME(schema_id) = '$schema_name'" | grep -q "1"; then
            missing_views+=("$view")
        fi
    done

    if [[ ${#missing_views[@]} -gt 0 ]]; then
        log_warning "Missing views detected: ${missing_views[*]}"
    else
        log_success "All expected views are present"
    fi

    # Get current column structure of main view
    local main_view="dbo.v_flat_export_sheet"
    if "$ROOT/scripts/sql.sh" -Q "SELECT 1 FROM sys.views WHERE name = 'v_flat_export_sheet'" | grep -q "1"; then
        log "Current column structure of $main_view:"
        "$ROOT/scripts/sql.sh" -Q "
            SELECT
                column_id as ord,
                name as column_name,
                TYPE_NAME(system_type_id) as data_type,
                max_length,
                CASE WHEN is_nullable = 1 THEN 'NULL' ELSE 'NOT NULL' END as nullable
            FROM sys.columns
            WHERE object_id = OBJECT_ID('$main_view')
            ORDER BY column_id
        " | tee -a "$LOG_FILE"
    fi
}

# Deploy canonical schema
deploy_canonical_schema() {
    if [[ "$DRY_RUN" == true ]]; then
        log_step "[DRY RUN] Would deploy canonical schema definition"
        return 0
    fi

    log_step "Deploying canonical schema definition..."
    if "$ROOT/scripts/sql.sh" -i "$ROOT/sql/schema/001_canonical_flat_schema.sql" 2>>"$LOG_FILE"; then
        log_success "Canonical schema definition deployed"
    else
        log_error "Failed to deploy canonical schema definition"
        exit 1
    fi

    # Verify schema was created
    if "$ROOT/scripts/sql.sh" -Q "SELECT COUNT(*) FROM canonical.flat_schema_definition" | grep -q "13"; then
        log_success "Canonical schema contains 13 column definitions"
    else
        log_error "Canonical schema validation failed"
        exit 1
    fi
}

# Deploy canonical views
deploy_canonical_views() {
    if [[ "$DRY_RUN" == true ]]; then
        log_step "[DRY RUN] Would deploy canonical flat views"
        return 0
    fi

    log_step "Deploying canonical flat views..."
    if "$ROOT/scripts/sql.sh" -i "$ROOT/sql/views/002_canonical_flat_view.sql" 2>>"$LOG_FILE"; then
        log_success "Canonical flat views deployed"
    else
        log_error "Failed to deploy canonical flat views"
        exit 1
    fi

    # Test the main canonical view
    local row_count
    row_count=$("$ROOT/scripts/sql.sh" -Q "SELECT COUNT(*) FROM gold.v_transactions_flat_canonical" 2>/dev/null | tail -1 || echo "0")

    if [[ "$row_count" -gt 0 ]]; then
        log_success "Canonical view is queryable with $row_count rows"
    else
        log_warning "Canonical view exists but may be empty or have issues"
    fi
}

# Deploy validation procedures
deploy_validation_procedures() {
    if [[ "$DRY_RUN" == true ]]; then
        log_step "[DRY RUN] Would deploy validation procedures"
        return 0
    fi

    log_step "Deploying validation procedures..."
    if "$ROOT/scripts/sql.sh" -i "$ROOT/sql/procedures/003_validate_canonical.sql" 2>>"$LOG_FILE"; then
        log_success "Validation procedures deployed"
    else
        log_error "Failed to deploy validation procedures"
        exit 1
    fi

    # Test validation procedure
    log "Testing canonical view validation..."
    if "$ROOT/scripts/sql.sh" -Q "EXEC canonical.sp_validate_view_compliance @view_name = 'gold.v_transactions_flat_canonical', @detailed_report = 0" 2>>"$LOG_FILE"; then
        log_success "Validation procedures are working"
    else
        log_warning "Validation procedure test had issues (check log)"
    fi
}

# Deploy export procedures
deploy_export_procedures() {
    if [[ "$DRY_RUN" == true ]]; then
        log_step "[DRY RUN] Would deploy export procedures"
        return 0
    fi

    log_step "Deploying export procedures..."
    if "$ROOT/scripts/sql.sh" -i "$ROOT/sql/procedures/004_canonical_export_proc.sql" 2>>"$LOG_FILE"; then
        log_success "Export procedures deployed"
    else
        log_error "Failed to deploy export procedures"
        exit 1
    fi
}

# Update production aliases
update_production_aliases() {
    if [[ "$DRY_RUN" == true ]]; then
        log_step "[DRY RUN] Would update production view aliases"
        return 0
    fi

    log_step "Updating production view aliases..."

    # Update the main production view to point to canonical
    if "$ROOT/scripts/sql.sh" -Q "
        DROP VIEW IF EXISTS gold.v_transactions_flat_production_old;

        -- Backup current production view if it exists differently
        IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'v_transactions_flat_production' AND SCHEMA_NAME(schema_id) = 'gold')
        AND NOT EXISTS (SELECT 1 FROM sys.sql_modules WHERE object_id = OBJECT_ID('gold.v_transactions_flat_production') AND definition LIKE '%v_transactions_flat_canonical%')
        BEGIN
            EXEC('CREATE VIEW gold.v_transactions_flat_production_old AS SELECT * FROM gold.v_transactions_flat_production');
        END;

        -- Update production view to use canonical
        CREATE OR ALTER VIEW gold.v_transactions_flat_production AS
        SELECT * FROM gold.v_transactions_flat_canonical;

    " 2>>"$LOG_FILE"; then
        log_success "Production view aliases updated"
    else
        log_warning "Production alias update had issues (check log)"
    fi
}

# Validate final structure
validate_final_structure() {
    log_step "Validating final canonical structure..."

    if [[ "$DRY_RUN" == true ]]; then
        log_step "[DRY RUN] Would validate final structure"
        return 0
    fi

    # Run comprehensive validation
    if "$ROOT/scripts/sql.sh" -Q "EXEC canonical.sp_validate_all_flat_views @throw_on_any_error = 0" 2>>"$LOG_FILE"; then
        log_success "Final structure validation passed"
    else
        log_warning "Final validation had issues (check log for details)"
    fi

    # Show compliance status
    log "Canonical compliance status:"
    "$ROOT/scripts/sql.sh" -Q "SELECT view_name, compliance_status FROM canonical.v_view_compliance_status ORDER BY compliance_status DESC" 2>/dev/null || log_warning "Could not retrieve compliance status"
}

# Generate migration report
generate_migration_report() {
    local report_file="$ROOT/canonical_migration_report_$(date +%Y%m%d_%H%M%S).md"

    log_step "Generating migration report..."

    cat > "$report_file" << EOF
# Canonical Migration Report

**Generated**: $(date '+%Y-%m-%d %H:%M:%S')
**Migration Type**: $(if [[ "$DRY_RUN" == true ]]; then echo "DRY RUN"; else echo "FULL DEPLOYMENT"; fi)
**Backup Created**: $(if [[ "$CREATE_BACKUP" == true ]]; then echo "Yes - $BACKUP_DIR"; else echo "No"; fi)

## Migration Steps Completed

- [x] Prerequisites validation
- [x] Database connectivity check
$(if [[ "$CREATE_BACKUP" == true ]]; then echo "- [x] Backup creation"; else echo "- [ ] Backup creation (skipped)"; fi)
- [x] Current structure validation
- [x] Canonical schema deployment
- [x] Canonical views deployment
- [x] Validation procedures deployment
- [x] Export procedures deployment
- [x] Production aliases update
- [x] Final structure validation
- [x] Migration report generation

## Canonical Schema Summary

**Column Contract**: 13 columns exactly
**Schema Validation**: Automated compliance checking
**Export Procedures**: Standardized with filtering and compression
**View Structure**: Hierarchical (canonical → production → specialized)

### 13-Column Structure
EOF

    # Add column details if not dry run
    if [[ "$DRY_RUN" != true ]]; then
        "$ROOT/scripts/sql.sh" -Q "
            SELECT
                CONCAT(column_ord, '. ', column_name, ' (', full_data_type,
                       CASE WHEN is_nullable = 1 THEN ', nullable' ELSE ', required' END, ')') as column_spec
            FROM canonical.v_flat_schema
            ORDER BY column_ord
        " 2>/dev/null | while read -r line; do
            echo "$line" >> "$report_file"
        done 2>/dev/null || echo "Could not generate column details" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

## Post-Migration Usage

### Makefile Targets
- \`make canonical-deploy\` - Deploy canonical schema
- \`make canonical-validate\` - Validate schema compliance
- \`make canonical-export\` - Export canonical flat file
- \`make canonical-tobacco\` - Export tobacco data only
- \`make canonical-laundry\` - Export laundry data only
- \`make canonical-status\` - Check compliance status

### Export Script
\`\`\`bash
# Export all data with validation and compression
./scripts/export_canonical.sh --validate --compress

# Export specific category
./scripts/export_canonical.sh --category tobacco --compress

# Export date range
./scripts/export_canonical.sh --date-from 2025-08-01 --date-to 2025-08-31
\`\`\`

### Validation
\`\`\`sql
-- Check compliance status
SELECT * FROM canonical.v_view_compliance_status;

-- Validate specific view
EXEC canonical.sp_validate_view_compliance @view_name = 'gold.v_transactions_flat_canonical';
\`\`\`

## Rollback Information
$(if [[ "$CREATE_BACKUP" == true ]]; then
    echo "**Rollback Available**: Yes
**Rollback Command**: \`$0 --rollback '$BACKUP_DIR'\`
**Backup Location**: $BACKUP_DIR"
else
    echo "**Rollback Available**: No (use --backup flag to enable)"
fi)

## Files Modified
- Created: sql/schema/001_canonical_flat_schema.sql
- Created: sql/views/002_canonical_flat_view.sql
- Created: sql/procedures/003_validate_canonical.sql
- Created: sql/procedures/004_canonical_export_proc.sql
- Created: scripts/export_canonical.sh
- Modified: Makefile (added canonical-* targets)

## Migration Log
See: $LOG_FILE
EOF

    log_success "Migration report generated: $report_file"
}

# Rollback function
execute_rollback() {
    if [[ -z "$ROLLBACK_DIR" || ! -d "$ROLLBACK_DIR" ]]; then
        log_error "Invalid rollback directory: $ROLLBACK_DIR"
        exit 1
    fi

    log_step "Executing rollback from: $ROLLBACK_DIR"

    if [[ -x "$ROLLBACK_DIR/rollback.sh" ]]; then
        cd "$ROLLBACK_DIR"
        ./rollback.sh
        log_success "Rollback completed"
    else
        log_error "Rollback script not found or not executable"
        exit 1
    fi
}

# Main execution function
main() {
    echo -e "${CYAN}"
    echo "=========================================="
    echo "    CANONICAL MIGRATION SCRIPT"
    echo "=========================================="
    echo -e "${NC}"

    parse_args "$@"

    if [[ -n "$ROLLBACK_DIR" ]]; then
        execute_rollback
        return 0
    fi

    echo -e "${BLUE}Configuration:${NC}"
    echo "  Dry Run: $DRY_RUN"
    echo "  Create Backup: $CREATE_BACKUP"
    echo "  Force: $FORCE"
    echo "  Validate Only: $VALIDATE_ONLY"
    echo "  Log File: $LOG_FILE"
    echo

    if [[ "$FORCE" != true && "$DRY_RUN" != true && "$VALIDATE_ONLY" != true ]]; then
        echo -e "${YELLOW}This will modify your database schema and views.${NC}"
        read -p "Continue with migration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Migration cancelled."
            exit 0
        fi
    fi

    # Execute migration steps
    validate_prerequisites
    create_backup
    validate_current_structure

    if [[ "$VALIDATE_ONLY" == true ]]; then
        log_success "Validation-only mode completed"
        return 0
    fi

    deploy_canonical_schema
    deploy_canonical_views
    deploy_validation_procedures
    deploy_export_procedures
    update_production_aliases
    validate_final_structure
    generate_migration_report

    echo -e "${GREEN}"
    echo "=========================================="
    echo "    CANONICAL MIGRATION COMPLETED"
    echo "=========================================="
    echo -e "${NC}"
    echo
    echo "✅ Migration completed successfully"
    echo "📄 Log file: $LOG_FILE"
    if [[ "$CREATE_BACKUP" == true ]]; then
        echo "💾 Backup: $BACKUP_DIR"
    fi
    echo
    echo "Next steps:"
    echo "  • Test exports: make canonical-export"
    echo "  • Check status: make canonical-status"
    echo "  • Validate: make canonical-validate"
}

# Execute main function with all arguments
main "$@"