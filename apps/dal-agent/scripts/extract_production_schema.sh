#!/usr/bin/env bash
set -euo pipefail

# Production Schema Extraction Script
# Purpose: Extract complete production schema from Azure SQL Database
# Usage: ./scripts/extract_production_schema.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/out/schema_extraction"
SQL_DIR="$PROJECT_ROOT/sql/schema_extraction"

echo -e "${BLUE}🔍 Scout Analytics - Production Schema Extraction${NC}"
echo "=================================================="
echo "Server: sqltbwaprojectscoutserver.database.windows.net"
echo "Database: SQL-TBWA-ProjectScout-Reporting-Prod"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Verify SQL extraction scripts exist
if [[ ! -f "$SQL_DIR/01_inventory.sql" ]]; then
    echo -e "${RED}❌ Error: SQL extraction scripts not found in $SQL_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Step 1: Database Inventory${NC}"
echo "Running complete database inventory..."

if ./scripts/sql.sh -i "$SQL_DIR/01_inventory.sql" -o "$OUTPUT_DIR/01_inventory.txt"; then
    echo -e "${GREEN}✅ Inventory complete: $OUTPUT_DIR/01_inventory.txt${NC}"
else
    echo -e "${RED}❌ Inventory failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📝 Step 2: View and Procedure Definitions${NC}"
echo "Extracting all view and stored procedure definitions..."

if ./scripts/sql.sh -i "$SQL_DIR/02_dump_views_procs.sql" -o "$OUTPUT_DIR/02_definitions.sql"; then
    echo -e "${GREEN}✅ Definitions extracted: $OUTPUT_DIR/02_definitions.sql${NC}"
else
    echo -e "${RED}❌ Definition extraction failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🏗️ Step 3: Table DDL Generation${NC}"
echo "Generating CREATE TABLE statements for all tables..."

if ./scripts/sql.sh -i "$SQL_DIR/03_generate_table_ddl.sql" -o "$OUTPUT_DIR/03_table_ddl.sql"; then
    echo -e "${GREEN}✅ Table DDL generated: $OUTPUT_DIR/03_table_ddl.sql${NC}"
else
    echo -e "${RED}❌ Table DDL generation failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🏛️ Step 4: Schema Creation Statements${NC}"
echo "Extracting schema creation and dependency information..."

if ./scripts/sql.sh -i "$SQL_DIR/04_schema_creation.sql" -o "$OUTPUT_DIR/04_schemas.txt"; then
    echo -e "${GREEN}✅ Schema information extracted: $OUTPUT_DIR/04_schemas.txt${NC}"
else
    echo -e "${RED}❌ Schema extraction failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📊 Extraction Summary${NC}"
echo "===================="

# File size summary
for file in "$OUTPUT_DIR"/*; do
    if [[ -f "$file" ]]; then
        size=$(wc -l < "$file" 2>/dev/null || echo "0")
        filename=$(basename "$file")
        echo "📄 $filename: $size lines"
    fi
done

echo ""
echo -e "${GREEN}🎯 Schema Extraction Complete!${NC}"
echo ""
echo "Next Steps:"
echo "1. Review extracted files in: $OUTPUT_DIR"
echo "2. Update canonical DBML with true production schema"
echo "3. Regenerate ETL documentation with actual schema"
echo "4. Update DAL API documentation with correct endpoints"
echo ""
echo "Files generated:"
echo "📋 01_inventory.txt - Complete object catalog"
echo "📝 02_definitions.sql - All view/procedure DDL"
echo "🏗️ 03_table_ddl.sql - Complete table structures"
echo "🏛️ 04_schemas.txt - Schema creation and dependencies"
echo ""

# Generate extraction report
REPORT_FILE="$OUTPUT_DIR/extraction_report.md"
cat > "$REPORT_FILE" << EOF
# Production Schema Extraction Report

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Server**: sqltbwaprojectscoutserver.database.windows.net
**Database**: SQL-TBWA-ProjectScout-Reporting-Prod

## Files Generated

| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| 01_inventory.txt | Complete database object catalog | $(wc -l < "$OUTPUT_DIR/01_inventory.txt" 2>/dev/null || echo "0") | ✅ |
| 02_definitions.sql | View and procedure definitions | $(wc -l < "$OUTPUT_DIR/02_definitions.sql" 2>/dev/null || echo "0") | ✅ |
| 03_table_ddl.sql | Complete table CREATE statements | $(wc -l < "$OUTPUT_DIR/03_table_ddl.sql" 2>/dev/null || echo "0") | ✅ |
| 04_schemas.txt | Schema creation and dependencies | $(wc -l < "$OUTPUT_DIR/04_schemas.txt" 2>/dev/null || echo "0") | ✅ |

## Next Actions

1. **Review Extraction**: Examine all generated files for completeness
2. **Update DBML**: Replace docs/canonical_database_schema.dbml with true production schema
3. **Update ETL Docs**: Align docs/ETL_PIPELINE_COMPLETE.md with actual pipeline
4. **Update API Docs**: Correct docs/DAL_API_DOCUMENTATION.md with real endpoints
5. **Validate Changes**: Test all documentation updates against production

## Schema Reconstruction Command

After reviewing the extracted files, use the following command to reconstruct documentation:

\`\`\`bash
# Update all documentation with true production schema
make schema-reconstruct
\`\`\`

EOF

echo -e "${BLUE}📋 Extraction report: $REPORT_FILE${NC}"
echo ""
echo -e "${GREEN}Ready for schema reconstruction! 🚀${NC}"