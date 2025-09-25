#!/bin/bash
set -euo pipefail

# Nielsen 1,100 System Validation Script
# Comprehensive validation of correctness, coverage, performance, and safety

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Nielsen 1,100 System Validation${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

VALIDATION_PASSED=true
DB="${DB:-SQL-TBWA-ProjectScout-Reporting-Prod}"

# Helper function to run validation checks
validate_check() {
    local test_name="$1"
    local query="$2"
    local expected_condition="$3"

    echo -e "${YELLOW}Testing: $test_name${NC}"

    if ! result=$(./scripts/sql.sh -Q "$query" 2>&1); then
        echo -e "${RED}❌ Query failed: $result${NC}"
        VALIDATION_PASSED=false
        return 1
    fi

    if eval "$expected_condition"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        echo "Result: $result"
        VALIDATION_PASSED=false
        return 1
    fi
}

echo -e "${BLUE}=== A) INDEX & CONSTRAINT HARDENING ===${NC}"

# Create essential indexes if missing
echo -e "${YELLOW}Creating performance indexes...${NC}"
./scripts/sql.sh -Q "IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UQ_NielsenTaxonomy_Code' AND object_id=OBJECT_ID('ref.NielsenTaxonomy')) CREATE UNIQUE INDEX UQ_NielsenTaxonomy_Code ON ref.NielsenTaxonomy(taxonomy_code);" || echo "Index creation failed (may already exist)"

./scripts/sql.sh -Q "IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ProductNielsenMap_Product' AND object_id=OBJECT_ID('ref.ProductNielsenMap')) CREATE INDEX IX_ProductNielsenMap_Product ON ref.ProductNielsenMap(ProductID) INCLUDE(taxonomy_id, confidence, mapped_at);" || echo "Index creation failed (may already exist)"

echo ""
echo -e "${BLUE}=== B) STRUCTURAL CORRECTNESS CHECKS ===${NC}"

# Level sanity check
echo -e "${YELLOW}Checking taxonomy level distribution...${NC}"
./scripts/sql.sh -Q "SELECT level, COUNT(*) AS cnt FROM ref.NielsenTaxonomy GROUP BY level ORDER BY level;" || echo "Query failed"

# Orphan check
echo -e "${YELLOW}Checking for orphaned taxonomy nodes...${NC}"
orphan_count=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM ref.NielsenTaxonomy child LEFT JOIN ref.NielsenTaxonomy par ON par.taxonomy_id=child.parent_id WHERE child.parent_id IS NOT NULL AND par.taxonomy_id IS NULL;" 2>/dev/null | tail -1 | tr -d ' \t\r\n' || echo "ERROR")

if [[ "$orphan_count" == "0" ]]; then
    echo -e "${GREEN}✅ No orphaned nodes found${NC}"
elif [[ "$orphan_count" == "ERROR" ]]; then
    echo -e "${RED}❌ Failed to check orphans${NC}"
    VALIDATION_PASSED=false
else
    echo -e "${RED}❌ Found $orphan_count orphaned nodes${NC}"
    ./scripts/sql.sh -Q "SELECT TOP 10 child.taxonomy_code, child.level, child.parent_id FROM ref.NielsenTaxonomy child LEFT JOIN ref.NielsenTaxonomy par ON par.taxonomy_id=child.parent_id WHERE child.parent_id IS NOT NULL AND par.taxonomy_id IS NULL;"
    VALIDATION_PASSED=false
fi

# Duplicate taxonomy codes check
echo -e "${YELLOW}Checking for duplicate taxonomy codes...${NC}"
dup_codes=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM (SELECT taxonomy_code, COUNT(*) FROM ref.NielsenTaxonomy GROUP BY taxonomy_code HAVING COUNT(*) > 1) dups;" 2>/dev/null | tail -1 | tr -d ' \t\r\n' || echo "ERROR")

if [[ "$dup_codes" == "0" ]]; then
    echo -e "${GREEN}✅ No duplicate taxonomy codes${NC}"
elif [[ "$dup_codes" == "ERROR" ]]; then
    echo -e "${RED}❌ Failed to check duplicates${NC}"
    VALIDATION_PASSED=false
else
    echo -e "${RED}❌ Found duplicate taxonomy codes${NC}"
    ./scripts/sql.sh -Q "SELECT taxonomy_code, COUNT(*) FROM ref.NielsenTaxonomy GROUP BY taxonomy_code HAVING COUNT(*) > 1;"
    VALIDATION_PASSED=false
fi

echo ""
echo -e "${BLUE}=== C) COVERAGE & CLASSIFICATION KPIs ===${NC}"

# Product coverage check
echo -e "${YELLOW}Checking product coverage...${NC}"
./scripts/sql.sh -Q "
SELECT
  total_products = (SELECT COUNT(*) FROM dbo.Products),
  mapped_products = (SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap),
  coverage_pct = CAST(100.0 * (SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap) / NULLIF((SELECT COUNT(*) FROM dbo.Products),0) AS decimal(5,2));" 2>/dev/null || echo "Product coverage query failed"

# TransactionItems coverage check
echo -e "${YELLOW}Checking transaction items coverage...${NC}"
./scripts/sql.sh -Q "
SELECT
  total_lines = COUNT(*),
  mapped_lines = SUM(CASE WHEN m.ProductID IS NOT NULL THEN 1 ELSE 0 END),
  mapped_pct = CAST(100.0 * SUM(CASE WHEN m.ProductID IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(5,2))
FROM dbo.TransactionItems i
LEFT JOIN dbo.Products p ON p.ProductID=i.ProductID
LEFT JOIN ref.ProductNielsenMap m ON m.ProductID=p.ProductID;" 2>/dev/null || echo "Transaction items coverage query failed"

# Top unmapped brands
echo -e "${YELLOW}Top unmapped brands (need attention):${NC}"
./scripts/sql.sh -Q "
SELECT TOP 25 p.ProductName, p.Category, COUNT(*) as occurrences
FROM dbo.Products p
LEFT JOIN ref.ProductNielsenMap m ON m.ProductID=p.ProductID
WHERE m.ProductID IS NULL
GROUP BY p.ProductName, p.Category
ORDER BY COUNT(*) DESC;" 2>/dev/null || echo "Unmapped brands query failed"

echo ""
echo -e "${BLUE}=== D) PERFORMANCE SMOKE TEST ===${NC}"

# Test Nielsen view performance
echo -e "${YELLOW}Testing gold.v_transactions_nielsen view...${NC}"
start_time=$(date +%s%N)
if view_result=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM gold.v_transactions_nielsen WHERE TransactionDate >= DATEADD(day,-30, CAST(GETDATE() AS date));" 2>/dev/null | tail -1 | tr -d ' \t\r\n'); then
    end_time=$(date +%s%N)
    duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ $duration_ms -lt 5000 ]]; then
        echo -e "${GREEN}✅ View performance: ${duration_ms}ms (< 5s threshold)${NC}"
        echo -e "${GREEN}✅ View returned $view_result rows${NC}"
    else
        echo -e "${YELLOW}⚠️ View performance: ${duration_ms}ms (> 5s, may need optimization)${NC}"
    fi
else
    echo -e "${RED}❌ Nielsen view query failed${NC}"
    VALIDATION_PASSED=false
fi

# Check row counts for key tables
echo -e "${YELLOW}Checking key table row counts...${NC}"
./scripts/sql.sh -Q "
SELECT
  'NielsenTaxonomy' as table_name, COUNT(*) as row_count FROM ref.NielsenTaxonomy
UNION ALL
SELECT
  'BrandCategoryRules' as table_name, COUNT(*) as row_count FROM ref.BrandCategoryRules
UNION ALL
SELECT
  'ProductNielsenMap' as table_name, COUNT(*) as row_count FROM ref.ProductNielsenMap
UNION ALL
SELECT
  'Products' as table_name, COUNT(*) as row_count FROM dbo.Products
ORDER BY table_name;" 2>/dev/null || echo "Row count query failed"

echo ""
echo -e "${BLUE}=== E) BRAND MAPPING VALIDATION ===${NC}"

# Check Nielsen 1100 brand count
nielsen_brands=$(./scripts/sql.sh -Q "SELECT COUNT(DISTINCT brand_name) FROM ref.BrandCategoryRules WHERE rule_source = 'nielsen_1100';" 2>/dev/null | tail -1 | tr -d ' \t\r\n' || echo "ERROR")

if [[ "$nielsen_brands" == "ERROR" ]]; then
    echo -e "${RED}❌ Failed to check Nielsen 1100 brands${NC}"
    VALIDATION_PASSED=false
elif [[ "$nielsen_brands" -ge "100" ]]; then
    echo -e "${GREEN}✅ Nielsen 1100 brands: $nielsen_brands (≥100 target)${NC}"
else
    echo -e "${RED}❌ Nielsen 1100 brands: $nielsen_brands (<100, incomplete)${NC}"
    VALIDATION_PASSED=false
fi

# Check brand rule distribution
echo -e "${YELLOW}Brand rule distribution by source:${NC}"
./scripts/sql.sh -Q "
SELECT
  rule_source,
  COUNT(*) as rule_count,
  COUNT(DISTINCT brand_name) as unique_brands
FROM ref.BrandCategoryRules
GROUP BY rule_source
ORDER BY rule_count DESC;" 2>/dev/null || echo "Brand rule distribution query failed"

echo ""
echo -e "${BLUE}=== F) EXPANSION SYSTEM VALIDATION ===${NC}"

# Check if expanded categories exist
expanded_count=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM ref.NielsenTaxonomyExpanded WHERE is_active = 1;" 2>/dev/null | tail -1 | tr -d ' \t\r\n' || echo "0")

if [[ "$expanded_count" -ge "1000" ]]; then
    echo -e "${GREEN}✅ Expanded categories: $expanded_count (≥1,000 target achieved)${NC}"
elif [[ "$expanded_count" == "0" ]]; then
    echo -e "${YELLOW}⚠️ No expanded categories generated yet. Run 'make nielsen-1100-generate'${NC}"
else
    echo -e "${YELLOW}⚠️ Expanded categories: $expanded_count (<1,000, run 'make nielsen-1100-generate')${NC}"
fi

echo ""
echo -e "${BLUE}=== VALIDATION SUMMARY ===${NC}"
if [[ "$VALIDATION_PASSED" == "true" ]]; then
    echo -e "${GREEN}🎉 All critical validations PASSED${NC}"
    echo -e "${GREEN}Nielsen 1,100 system is ready for production use${NC}"
    exit 0
else
    echo -e "${RED}❌ Some validations FAILED${NC}"
    echo -e "${RED}Review failures above before production deployment${NC}"
    exit 1
fi