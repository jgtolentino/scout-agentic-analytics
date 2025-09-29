#!/bin/bash

# Deploy Inquiry Analytics Views and Stored Procedures
# Creates optimized database objects for fast BI exports
# Usage: ./scripts/deploy_inquiry_analytics.sh

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Deploying Inquiry Analytics Database Objects...${NC}"
echo ""

# Check database connectivity
if ! ./scripts/sql.sh -Q "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}❌ Database connection failed${NC}"
    echo -e "${YELLOW}💡 Check connection string and try again${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Database connection verified${NC}"

# 1. Deploy Views
echo -e "${BLUE}📊 Creating optimized views...${NC}"
if ./scripts/sql.sh -f sql/views/inquiry_analytics_views.sql; then
    echo -e "${GREEN}✅ Views created successfully${NC}"
else
    echo -e "${RED}❌ Views deployment failed${NC}"
    exit 1
fi

# 2. Deploy Stored Procedures
echo -e "${BLUE}⚙️  Creating stored procedures...${NC}"
if ./scripts/sql.sh -f sql/procedures/inquiry_export_procedures.sql; then
    echo -e "${GREEN}✅ Stored procedures created successfully${NC}"
else
    echo -e "${RED}❌ Stored procedures deployment failed${NC}"
    exit 1
fi

# 3. Test the new objects
echo -e "${BLUE}🧪 Testing deployed objects...${NC}"

# Test views
echo "Testing views..."
if ./scripts/sql.sh -Q "SELECT TOP 1 * FROM gold.v_demographics_parsed" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Views working correctly${NC}"
else
    echo -e "${RED}❌ Views test failed${NC}"
    exit 1
fi

# Test procedures
echo "Testing procedures..."
if ./scripts/sql.sh -Q "EXEC sp_export_store_profiles @date_from='2025-06-28', @date_to='2025-09-26'" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Stored procedures working correctly${NC}"
else
    echo -e "${RED}❌ Stored procedures test failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Inquiry Analytics deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Available objects:${NC}"
echo -e "${BLUE}Views:${NC}"
echo "  • gold.v_demographics_parsed - Pre-parsed demographics data"
echo "  • gold.v_tobacco_transactions - Tobacco-specific view"
echo "  • gold.v_laundry_transactions - Laundry-specific view"
echo "  • gold.v_store_profiles - Store performance aggregates"
echo "  • gold.v_payment_demographics - Payment method analysis"
echo "  • gold.v_brand_demographics - Brand performance by demographics"
echo "  • gold.v_purchase_patterns - Day-of-month patterns"
echo "  • gold.v_daily_sales - Daily sales by daypart"
echo ""
echo -e "${BLUE}Stored Procedures:${NC}"
echo "  • sp_export_store_profiles - Store performance export"
echo "  • sp_export_purchase_demographics - Payment method export"
echo "  • sp_export_category_demographics - Demographics by category"
echo "  • sp_export_purchase_profile - Day-of-month patterns"
echo "  • sp_export_daily_sales - Daily sales by daypart"
echo "  • sp_export_copurchase_categories - Co-purchase analysis"
echo "  • sp_export_frequent_terms - Audio transcript analysis"
echo "  • sp_export_detergent_types - Laundry detergent analysis"
echo ""
echo -e "${YELLOW}💡 These objects will dramatically improve export performance!${NC}"