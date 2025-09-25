# Production Schema Extraction System

**Purpose**: Extract the true production schema directly from Azure SQL Database to ensure all documentation reflects actual database structure.

**Version**: 1.0
**Updated**: 2025-09-25
**Database**: SQL-TBWA-ProjectScout-Reporting-Prod

## Overview

This system extracts the complete production schema from the live Azure database using T-SQL system catalog queries, ensuring all documentation matches the actual production environment.

## Architecture

```
Azure SQL Database → T-SQL Extraction Scripts → Raw Schema Files → Documentation Updates
        ↓                        ↓                      ↓                    ↓
Production Schema     4 Extraction Scripts    Schema Files      Updated DBML/Docs
```

## Extraction Scripts

### 1. Database Inventory (`01_inventory.sql`)
**Purpose**: Complete catalog of all database objects
**Output**: `out/schema_extraction/01_inventory.txt`

**Extracts**:
- Schema inventory with principals
- Table inventory by schema with column counts
- View inventory with definition status
- Stored procedure inventory
- Function inventory by type
- Index summary with types
- Foreign key relationships
- Object count summary

**Key Queries**:
```sql
-- Schema catalog
SELECT s.name as schema_name, s.schema_id, p.name as principal_name
FROM sys.schemas s
JOIN sys.database_principals p ON s.principal_id = p.principal_id

-- Table inventory with metadata
SELECT s.name as schema_name, t.name as table_name,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) as column_count
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
```

### 2. View and Procedure Definitions (`02_dump_views_procs.sql`)
**Purpose**: Extract complete DDL for all views and stored procedures
**Output**: `out/schema_extraction/02_definitions.sql`

**Extracts**:
- All view definitions with complete SQL
- All stored procedure definitions
- All function definitions (scalar, inline, table-valued)
- Critical analytics views metadata
- Complexity indicators and categorization

**Key Features**:
- Uses cursors to iterate through all objects
- Extracts definitions from `sys.sql_modules`
- Categorizes views by purpose (Export, Analytics, Cross-Tab)
- Includes creation and modification dates

### 3. Table DDL Generation (`03_generate_table_ddl.sql`)
**Purpose**: Generate complete CREATE TABLE statements
**Output**: `out/schema_extraction/03_table_ddl.sql`

**Extracts**:
- Complete table structures with data types
- Identity specifications and seeds
- Primary key constraints
- Foreign key constraints with actions
- Non-clustered indexes with includes
- Table statistics summary

**Advanced Features**:
- Handles all SQL Server data types correctly
- Includes precision/scale for numeric types
- Preserves identity seed and increment
- Generates proper constraint names
- Includes index include columns

### 4. Schema Creation (`04_schema_creation.sql`)
**Purpose**: Extract schema creation and dependency information
**Output**: `out/schema_extraction/04_schemas.txt`

**Extracts**:
- Schema creation statements with authorization
- Schema usage analysis with object counts
- Schema dependencies and relationships
- Critical objects by category
- Recommended creation order
- Data lineage summary

## Usage

### Command Line Execution

```bash
# Extract complete production schema
make schema-extract

# Extract and reconstruct all documentation
make schema-reconstruct
```

### Manual Execution

```bash
# Run extraction script directly
./scripts/extract_production_schema.sh

# Run individual extraction scripts
./scripts/sql.sh -i sql/schema_extraction/01_inventory.sql -o out/schema_extraction/01_inventory.txt
./scripts/sql.sh -i sql/schema_extraction/02_dump_views_procs.sql -o out/schema_extraction/02_definitions.sql
./scripts/sql.sh -i sql/schema_extraction/03_generate_table_ddl.sql -o out/schema_extraction/03_table_ddl.sql
./scripts/sql.sh -i sql/schema_extraction/04_schema_creation.sql -o out/schema_extraction/04_schemas.txt
```

### Azure Portal Execution

Copy and paste individual SQL scripts directly into Azure SQL Query Editor for immediate execution.

## Output Files

| File | Purpose | Content | Typical Size |
|------|---------|---------|--------------|
| `01_inventory.txt` | Database catalog | Complete object inventory | ~500 lines |
| `02_definitions.sql` | DDL definitions | All view/procedure SQL | ~5,000 lines |
| `03_table_ddl.sql` | Table structures | CREATE TABLE statements | ~2,000 lines |
| `04_schemas.txt` | Schema metadata | Schema creation and deps | ~300 lines |
| `extraction_report.md` | Summary report | Extraction summary | ~100 lines |

## Documentation Reconstruction

After extraction, the system updates all documentation files:

### 1. Canonical DBML (`docs/canonical_database_schema.dbml`)
- Updates with true production schema
- Corrects table structures and relationships
- Aligns with actual object names and types

### 2. ETL Pipeline (`docs/ETL_PIPELINE_COMPLETE.md`)
- Updates schema organization
- Corrects table and view names
- Aligns with actual data flow

### 3. DAL API (`docs/DAL_API_DOCUMENTATION.md`)
- Updates endpoint schemas
- Corrects table and view references
- Aligns with actual data sources

### 4. Documentation Index (`docs/DOCUMENTATION_INDEX.md`)
- Updates with current schema status
- Corrects metrics and object counts
- Aligns with production reality

## Schema Discovery Insights

### Expected Schema Organization
```sql
-- Production schemas identified
bronze.*                 -- Raw data ingestion
scout.*                 -- Clean transactional data
gold.*                  -- Analytics-ready data
ref.*                   -- Reference data
dbo.*                   -- Core business objects
ces.*                   -- Campaign Effectiveness System
staging.*               -- Data processing
ops.*                   -- Operational monitoring
cdc.*                   -- Change Data Capture
poc.*                   -- Proof of concept
```

### Critical Analytics Objects
- **Export Views**: `dbo.v_flat_export_sheet`, `dbo.v_flat_export_csvsafe`
- **Dashboard Data**: `gold.scout_dashboard_transactions`
- **Cross-Tabs**: `dbo.v_xtab_*` series
- **Nielsen Integration**: `dbo.v_nielsen_complete_analytics`
- **Brand Management**: `dbo.BrandCategoryMapping`

## Quality Assurance

### Validation Checks
1. **Completeness**: All objects extracted from all schemas
2. **Accuracy**: DDL statements are syntactically correct
3. **Consistency**: Relationships preserved correctly
4. **Currency**: Extraction timestamp recorded

### Error Handling
- Connection failures → Clear error messages
- Permission issues → Specific resolution guidance
- Missing objects → Noted in extraction report
- Large definitions → Handled with proper cursors

## Security Considerations

### Credential Management
- Uses existing secure credential system
- No credentials stored in extraction files
- Leverages `./scripts/sql.sh` wrapper for authentication

### Data Protection
- Extracts schema only, no sensitive data
- Uses system catalog views only
- No access to actual table contents

## Troubleshooting

### Common Issues

**Connection Failures**:
```bash
# Verify connection
make check-connection

# Test database access
./scripts/sql.sh -Q "SELECT @@VERSION"
```

**Permission Issues**:
```sql
-- Required permissions
SELECT HAS_PERMS_BY_NAME(null, null, 'VIEW DEFINITION') AS has_view_definition;
SELECT HAS_PERMS_BY_NAME('sys.schemas', 'OBJECT', 'SELECT') AS has_sys_access;
```

**Large Output Files**:
- View definitions can be very large
- Use `-o` flag for file output instead of console
- Monitor disk space during extraction

### Validation Commands

```bash
# Verify extraction completeness
ls -la out/schema_extraction/

# Check file sizes
wc -l out/schema_extraction/*

# Validate SQL syntax
sqlcmd -S server -d database -i out/schema_extraction/02_definitions.sql -n
```

## Future Enhancements

### Planned Features
1. **Incremental Extraction**: Only extract changed objects
2. **Automated Scheduling**: Daily schema extraction
3. **Diff Reports**: Compare schema changes over time
4. **Documentation Validation**: Verify docs match extracted schema

### Integration Opportunities
1. **CI/CD Integration**: Automated extraction in deployment pipeline
2. **Schema Evolution Tracking**: Version control for schema changes
3. **Data Dictionary Sync**: Auto-update data dictionaries
4. **API Schema Validation**: Ensure API matches database schema

---

**Status**: ✅ Production Ready
**Maintenance**: Run monthly or after significant schema changes
**Support**: Use `make doctor` for health checks and troubleshooting