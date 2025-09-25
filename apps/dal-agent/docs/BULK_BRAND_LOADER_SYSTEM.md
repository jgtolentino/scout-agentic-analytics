# Bulk Brand→Nielsen CategoryCode Loader System

## Overview

Production-safe bulk loading system for mapping brands to Nielsen industry taxonomy. Reduces "unspecified" categories from 48.3% to <10% through systematic brand classification.

## System Components

### 1. SQL Migration (012_brand_category_bulk_loader.sql)
- **Staging table**: `ref.stg_BrandCategoryMap` for CSV import
- **Normalization**: Brand name normalization with fuzzy matching
- **Upsert logic**: MERGE statement for idempotent updates
- **Duplicate cleanup**: Purges 'unspecified' entries when real mapping exists
- **Reporting**: JSON-safe coverage metrics

### 2. CSV Loader Script (load_brand_category_csv.sh)
- **Portable ingestion**: Python-based CSV parser with SQL generation
- **Error handling**: Validates required columns, escapes SQL injection
- **Staging workflow**: Truncate → Load → Process pattern

### 3. Makefile Integration
- **`make brand-map-load CSV=path.csv`**: Complete load workflow
- **`make brand-map-report`**: Quick coverage check
- **Auto-sync**: Updates zero-drift documentation after each load

### 4. Hardening Features
- **Global SET NOCOUNT ON**: Prevents parsing regressions in all SQL operations
- **CI Coverage Gate**: Fails builds if 'Coverage OK: false' appears in changelog
- **Zero-drift integration**: Auto-updates DB_CHANGELOG.md with coverage metrics

## Usage

### CSV Format
```csv
BrandName,CategoryCode,DepartmentCode
Alaska,BEV_COFFEE_3IN1,BEVERAGE
C2,BEV_SOFT_CITRUS,BEVERAGE
Royal,BEV_SOFT_CITRUS,BEVERAGE
```

**Notes**:
- `DepartmentCode` is optional (auto-resolved from CategoryCode)
- BrandName matches existing entries in `dbo.BrandCategoryMapping`
- CategoryCode must exist in `ref.NielsenCategories`

### Load Workflow
```bash
# 1. Load CSV and update brand mappings
make brand-map-load CSV=./data/brand_category_map.csv

# 2. Check coverage metrics
make brand-map-report

# 3. View top mappings
./scripts/sql.sh -Q "SET NOCOUNT ON; SELECT TOP 20 BrandName, CategoryCode, DepartmentCode FROM dbo.BrandCategoryMapping ORDER BY BrandName;"
```

### Expected Output
```
✅ Loaded CSV into ref.stg_BrandCategoryMap
mapped_brands
-------------
38

unmapped_brands
---------------
75

📚 Syncing documentation from live database...
✅ doc-sync complete - generated docs/SCHEMA/*.md and updated DB_CHANGELOG.md
```

## Quality Gates

### Pre-Load Validation
- Nielsen taxonomy tables must exist (`ref.NielsenDepartments`, `ref.NielsenCategories`)
- CSV must contain valid BrandName and CategoryCode columns
- CategoryCodes must reference existing Nielsen categories

### Post-Load Verification
- Coverage metrics updated in DB_CHANGELOG.md
- Duplicate 'unspecified' entries removed for mapped brands
- Documentation auto-synced with clean integer parsing

### CI Integration
- **docs-coverage-gate.yml**: Fails if coverage drops (`Coverage OK: false`)
- **Zero-drift validation**: SQL changes require doc updates
- **Parse protection**: `SET NOCOUNT ON` prevents integer parsing bugs

## Performance & Scale

### Bulk Loading Capacity
- **Staging table**: Handles thousands of brand mappings
- **MERGE performance**: Single transaction with rollback capability
- **Normalization**: Fuzzy matching via computed columns

### Expected Impact
- **Before**: 48.3% "unspecified" categories (105 of 218 brands unmapped)
- **Target**: <10% unspecified with systematic Nielsen mapping
- **Coverage tracking**: Real-time metrics in zero-drift documentation

### Production Safety
- **Idempotent operations**: Safe to re-run without data corruption
- **Transaction safety**: Full rollback on errors
- **Validation gates**: Pre-flight checks prevent invalid data
- **Audit trail**: Complete change tracking in DB_CHANGELOG.md

## Integration with Nielsen Taxonomy

This system works with the Nielsen 1,100 category migration to provide:
- **6-level hierarchy**: Department → Group → Category → Subcategory → Brand → SKU
- **Industry standards**: Nielsen-compliant categorization
- **Analytics enhancement**: Powers `v_nielsen_flat_export` view
- **Reporting infrastructure**: Enables Nielsen-based business intelligence

## Troubleshooting

### Common Issues
1. **CategoryCode not found**: Ensure Nielsen taxonomy is deployed first
2. **CSV parsing errors**: Check column headers and data format
3. **Connection issues**: Verify keychain credentials and database access
4. **Coverage OK: false**: Run `make doc-sync` to refresh metrics

### Recovery Commands
```bash
# Reset staging table
./scripts/sql.sh -Q "TRUNCATE TABLE ref.stg_BrandCategoryMap;"

# Check Nielsen categories
./scripts/sql.sh -Q "SELECT COUNT(*) FROM ref.NielsenCategories;"

# Validate brand mapping table
./scripts/sql.sh -Q "SELECT COUNT(*) FROM dbo.BrandCategoryMapping;"
```