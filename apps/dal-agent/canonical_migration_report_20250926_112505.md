# Canonical Migration Report

**Generated**: 2025-09-26 11:25:05
**Migration Type**: DRY RUN
**Backup Created**: No

## Migration Steps Completed

- [x] Prerequisites validation
- [x] Database connectivity check
- [ ] Backup creation (skipped)
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

## Post-Migration Usage

### Makefile Targets
- `make canonical-deploy` - Deploy canonical schema
- `make canonical-validate` - Validate schema compliance
- `make canonical-export` - Export canonical flat file
- `make canonical-tobacco` - Export tobacco data only
- `make canonical-laundry` - Export laundry data only
- `make canonical-status` - Check compliance status

### Export Script
```bash
# Export all data with validation and compression
./scripts/export_canonical.sh --validate --compress

# Export specific category
./scripts/export_canonical.sh --category tobacco --compress

# Export date range
./scripts/export_canonical.sh --date-from 2025-08-01 --date-to 2025-08-31
```

### Validation
```sql
-- Check compliance status
SELECT * FROM canonical.v_view_compliance_status;

-- Validate specific view
EXEC canonical.sp_validate_view_compliance @view_name = 'gold.v_transactions_flat_canonical';
```

## Rollback Information
**Rollback Available**: No (use --backup flag to enable)

## Files Modified
- Created: sql/schema/001_canonical_flat_schema.sql
- Created: sql/views/002_canonical_flat_view.sql
- Created: sql/procedures/003_validate_canonical.sql
- Created: sql/procedures/004_canonical_export_proc.sql
- Created: scripts/export_canonical.sh
- Modified: Makefile (added canonical-* targets)

## Migration Log
See: /Users/tbwa/scout-v7/apps/dal-agent/migration_20250926_112457.log
