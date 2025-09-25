#!/bin/bash
set -euo pipefail

# Nielsen 1,100 Category System Deployment Script
# Deploys complete Nielsen taxonomy with 111 Philippine brands

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Nielsen 1,100 Category System Deployment${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# Check if we're in the correct directory
if [ ! -f "Makefile" ] || [ ! -d "sql/migrations" ]; then
    echo -e "${RED}❌ Error: Must be run from dal-agent directory${NC}"
    echo -e "${YELLOW}Usage: cd /Users/tbwa/scout-v7/apps/dal-agent && ./scripts/deploy_nielsen_1100.sh${NC}"
    exit 1
fi

# Require explicit DB confirmation to prevent accidents
: "${DB:=SQL-TBWA-ProjectScout-Reporting-Prod}"
echo -e "${YELLOW}⚠️  PRODUCTION DATABASE DEPLOYMENT${NC}"
echo -e "${YELLOW}Target Database: ${DB}${NC}"
echo -e "${RED}This will modify production data. Are you sure?${NC}"
read -p "Type the database name to confirm: " CONFIRM
if [[ "$CONFIRM" != "$DB" ]]; then
    echo -e "${RED}❌ Database name mismatch. Deployment cancelled.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Database confirmation received${NC}"

# Check database connection
echo -e "${YELLOW}🔍 Step 1: Verifying database connection...${NC}"
if ! make check-connection > /dev/null 2>&1; then
    echo -e "${RED}❌ Database connection failed${NC}"
    echo -e "${YELLOW}Please ensure credentials are in keychain:${NC}"
    echo "security add-generic-password -s 'SQL-TBWA-ProjectScout-Reporting-Prod' -a 'scout-analytics' -w 'your-connection-string'"
    exit 1
fi
echo -e "${GREEN}✅ Database connection verified${NC}"

# Step 2: Deploy Nielsen 1,100 system
echo ""
echo -e "${YELLOW}🏗️ Step 2: Deploying Nielsen 1,100 system...${NC}"
make nielsen-1100-deploy
echo -e "${GREEN}✅ Nielsen 1,100 base system deployed${NC}"

# Step 3: Generate expanded categories
echo ""
echo -e "${YELLOW}🎯 Step 3: Generating expanded categories (227 → 1,100+)...${NC}"
make nielsen-1100-generate
echo -e "${GREEN}✅ Expanded categories generated${NC}"

# Step 4: Auto-map products
echo ""
echo -e "${YELLOW}🤖 Step 4: Auto-mapping products to Nielsen categories...${NC}"
make nielsen-1100-automap
echo -e "${GREEN}✅ Product auto-mapping completed${NC}"

# Step 5: Validate deployment
echo ""
echo -e "${YELLOW}🔍 Step 5: Validating deployment completeness...${NC}"
make nielsen-1100-validate

# Step 6: Generate coverage report
echo ""
echo -e "${YELLOW}📊 Step 6: Generating coverage reports...${NC}"
make nielsen-1100-coverage

# Step 7: Export analytics
echo ""
echo -e "${YELLOW}📈 Step 7: Exporting Nielsen 1,100 analytics...${NC}"
make nielsen-1100-report

# Final summary
echo ""
echo -e "${BLUE}🎉 Nielsen 1,100 Deployment Summary${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""
echo -e "${GREEN}✅ Base taxonomy deployed (227 categories)${NC}"
echo -e "${GREEN}✅ Brand mappings deployed (111 brands, 315 combinations)${NC}"
echo -e "${GREEN}✅ Expansion procedures deployed (1,100+ categories)${NC}"
echo -e "${GREEN}✅ Product auto-mapping completed${NC}"
echo -e "${GREEN}✅ System validation passed${NC}"
echo -e "${GREEN}✅ Analytics reports generated${NC}"

echo ""
echo -e "${BLUE}📁 Generated Files:${NC}"
if [ -d "out/nielsen_1100" ]; then
    ls -la out/nielsen_1100/*.csv | awk '{printf "  📄 %s (%s bytes)\n", $9, $5}'
fi

echo ""
echo -e "${YELLOW}📊 Expected Impact:${NC}"
echo -e "  • Reduction of 'Unspecified' categories from 48.3% to <10%"
echo -e "  • 111 Philippine brands mapped to Nielsen hierarchy"
echo -e "  • Industry-standard 1,100+ category classification"
echo -e "  • Enhanced analytics and business intelligence capabilities"

echo ""
echo -e "${BLUE}🔗 Next Steps:${NC}"
echo -e "  1. Review analytics exports in out/nielsen_1100/"
echo -e "  2. Monitor transaction classification improvement"
echo -e "  3. Use 'make nielsen-1100-validate' for ongoing health checks"
echo -e "  4. Run 'make nielsen-1100-report' for updated analytics"

echo ""
echo -e "${GREEN}🎉 Nielsen 1,100 Category System deployment completed successfully!${NC}"