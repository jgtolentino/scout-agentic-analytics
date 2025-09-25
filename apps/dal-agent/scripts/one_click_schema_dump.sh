#!/usr/bin/env bash
set -euo pipefail

# One-Click Schema Dump Orchestrator
# Purpose: Execute the one-click DDL dumper and export results
# Usage: ./scripts/one_click_schema_dump.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/out/one_click_schema"
SQL_DIR="$PROJECT_ROOT/sql/schema_extraction"

echo -e "${BLUE}🚀 Scout Analytics - One-Click Schema Dump${NC}"
echo "============================================="
echo "Server: sqltbwaprojectscoutserver.database.windows.net"
echo "Database: SQL-TBWA-ProjectScout-Reporting-Prod"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${YELLOW}📦 Step 1: Install DDL Dumper Procedure${NC}"
echo "Installing sp_DumpSchema in production database..."

if ./scripts/sql.sh -i "$SQL_DIR/00_one_click_ddl_dumper.sql"; then
    echo -e "${GREEN}✅ DDL dumper procedure installed${NC}"
else
    echo -e "${RED}❌ Failed to install DDL dumper procedure${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}⚡ Step 2: Execute Schema Dump${NC}"
echo "Dumping all schemas to ops.ObjectScripts table..."

if ./scripts/sql.sh -i "$SQL_DIR/01_execute_dump.sql" -o "$OUTPUT_DIR/dump_summary.txt"; then
    echo -e "${GREEN}✅ Schema dump executed successfully${NC}"
    echo "Summary: $OUTPUT_DIR/dump_summary.txt"
else
    echo -e "${RED}❌ Schema dump failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📄 Step 3: Export Complete DDL Script${NC}"
echo "Generating single portable SQL file..."

if ./scripts/sql.sh -i "$SQL_DIR/02_export_full_script.sql" -o "$OUTPUT_DIR/complete_production_schema.sql"; then
    echo -e "${GREEN}✅ Complete DDL exported: $OUTPUT_DIR/complete_production_schema.sql${NC}"
else
    echo -e "${RED}❌ Complete DDL export failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🗂️ Step 4: Export Per-Object Scripts${NC}"
echo "Generating individual object breakdown..."

if ./scripts/sql.sh -i "$SQL_DIR/03_export_per_object.sql" -o "$OUTPUT_DIR/per_object_scripts.csv"; then
    echo -e "${GREEN}✅ Per-object scripts exported: $OUTPUT_DIR/per_object_scripts.csv${NC}"
else
    echo -e "${RED}❌ Per-object export failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📊 One-Click Schema Dump Complete!${NC}"
echo "======================================"

# File size summary
echo ""
echo "Files generated:"
for file in "$OUTPUT_DIR"/*; do
    if [[ -f "$file" ]]; then
        size=$(wc -l < "$file" 2>/dev/null || echo "0")
        filename=$(basename "$file")
        filesize=$(du -h "$file" | cut -f1)
        echo "📄 $filename: $size lines ($filesize)"
    fi
done

echo ""
echo -e "${GREEN}🎯 Ready for Documentation Reconstruction!${NC}"
echo ""
echo "Next Steps:"
echo "1. Review: $OUTPUT_DIR/complete_production_schema.sql"
echo "2. Update DBML: Use extracted schema for canonical_database_schema.dbml"
echo "3. Update ETL Docs: Align with actual pipeline structure"
echo "4. Update API Docs: Correct endpoints with real schema"
echo ""
echo -e "${YELLOW}📋 Key Files:${NC}"
echo "🚀 complete_production_schema.sql - Single portable DDL script"
echo "📊 per_object_scripts.csv - Individual object breakdown"
echo "📈 dump_summary.txt - Execution summary with counts"
echo ""

# Generate extraction report
REPORT_FILE="$OUTPUT_DIR/one_click_report.md"
cat > "$REPORT_FILE" << EOF
# One-Click Production Schema Dump Report

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Server**: sqltbwaprojectscoutserver.database.windows.net
**Database**: SQL-TBWA-ProjectScout-Reporting-Prod
**Method**: One-Click DDL Dumper with sp_DumpSchema

## Files Generated

| File | Purpose | Size | Status |
|------|---------|------|--------|
| complete_production_schema.sql | Single portable DDL script | $(du -h "$OUTPUT_DIR/complete_production_schema.sql" 2>/dev/null | cut -f1 || echo "N/A") | ✅ |
| per_object_scripts.csv | Individual object breakdown | $(du -h "$OUTPUT_DIR/per_object_scripts.csv" 2>/dev/null | cut -f1 || echo "N/A") | ✅ |
| dump_summary.txt | Execution summary | $(du -h "$OUTPUT_DIR/dump_summary.txt" 2>/dev/null | cut -f1 || echo "N/A") | ✅ |

## Advantages Over Previous Method

1. **Comprehensive**: Captures tables, views, procedures, functions, triggers, indexes, constraints
2. **Idempotent**: Uses CREATE OR ALTER for safe re-execution
3. **Portable**: Single SQL file can recreate entire schema
4. **Accurate**: Direct from system catalogs, not documentation assumptions
5. **Complete**: Includes primary keys, foreign keys, indexes, defaults

## Schema Export Scope

- **dbo**: Core business objects
- **gold**: Analytics-ready data
- **ref**: Reference and lookup data
- **scout**: Clean transactional data
- **bronze**: Raw data ingestion
- **ces**: Campaign Effectiveness System
- **staging**: Data processing staging
- **silver**: Cleaned data layer
- **ops**: Operational monitoring
- **cdc**: Change data capture

## Next Actions

1. **Review Complete Schema**: Examine complete_production_schema.sql
2. **Update DBML**: Replace docs/canonical_database_schema.dbml with true schema
3. **Update ETL Docs**: Align docs/ETL_PIPELINE_COMPLETE.md with actual structure
4. **Update API Docs**: Correct docs/DAL_API_DOCUMENTATION.md with real endpoints
5. **Validate**: Test all documentation against production schema

## Usage Notes

The generated complete_production_schema.sql file can be executed against any SQL Server database to recreate the exact production schema structure. All objects are created with proper dependencies and idempotent CREATE OR ALTER statements.

EOF

echo -e "${BLUE}📋 One-click report: $REPORT_FILE${NC}"
echo ""
echo -e "${GREEN}Schema extraction revolutionized! 🎉${NC}"