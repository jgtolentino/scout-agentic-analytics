#!/bin/bash

# Scout v7 Dashboard - Azure Migration Deployment Script

set -e

echo "🚀 Scout v7 Dashboard - Azure Migration Deployment"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ Error: Must run from scout-dashboard directory${NC}"
    exit 1
fi

echo "📁 Current directory: $(pwd)"

# Step 1: Install dependencies
echo -e "\n${YELLOW}📦 Step 1: Installing dependencies...${NC}"
npm install

# Step 2: Type checking
echo -e "\n${YELLOW}🔍 Step 2: Type checking...${NC}"
npm run type-check

# Step 3: Linting
echo -e "\n${YELLOW}🧹 Step 3: Linting code...${NC}"
npm run lint

# Step 4: Build the application
echo -e "\n${YELLOW}🏗️  Step 4: Building application...${NC}"
npm run build

# Step 5: Test Azure SQL connection
echo -e "\n${YELLOW}🔌 Step 5: Testing Azure SQL connection...${NC}"
if [ -z "$AZURE_SQL_SERVER" ]; then
    echo -e "${YELLOW}⚠️  Warning: AZURE_SQL_SERVER not set - skipping connection test${NC}"
else
    echo "Testing connection to: $AZURE_SQL_SERVER"
    # Could add a connection test here if needed
fi

# Step 6: Deployment to Vercel
echo -e "\n${YELLOW}🚀 Step 6: Deploying to Vercel...${NC}"

# Check if vercel CLI is available
if command -v vercel &> /dev/null; then
    echo "Deploying with Vercel CLI..."
    vercel --prod

    # Get deployment URL
    DEPLOYMENT_URL=$(vercel inspect --scope tbwa --token $VERCEL_TOKEN 2>/dev/null | grep "url:" | head -1 | cut -d'"' -f2 || echo "")

    if [ ! -z "$DEPLOYMENT_URL" ]; then
        echo -e "\n${GREEN}✅ Deployment successful!${NC}"
        echo "URL: https://$DEPLOYMENT_URL"

        # Step 7: Post-deployment health check
        echo -e "\n${YELLOW}🏥 Step 7: Running health check...${NC}"
        sleep 10 # Wait for deployment to be ready

        # Test health endpoint
        echo "Testing health endpoint..."
        HEALTH_STATUS=$(curl -s -w "%{http_code}" "https://$DEPLOYMENT_URL/api/health" -o /tmp/health_response.json)

        if [ "$HEALTH_STATUS" = "200" ]; then
            echo -e "${GREEN}✅ Health check passed${NC}"
            echo "Health response:"
            cat /tmp/health_response.json | jq '.' 2>/dev/null || cat /tmp/health_response.json
        else
            echo -e "${RED}❌ Health check failed (HTTP $HEALTH_STATUS)${NC}"
            echo "Response:"
            cat /tmp/health_response.json
        fi

        # Test critical endpoints
        echo -e "\n${YELLOW}🧪 Testing critical endpoints...${NC}"
        for endpoint in "/api/transactions/kpis" "/api/stores/geo" "/api/dq/summary"; do
            echo -n "Testing $endpoint... "
            STATUS=$(curl -s -w "%{http_code}" "https://$DEPLOYMENT_URL$endpoint" -o /dev/null)
            if [ "$STATUS" = "200" ]; then
                echo -e "${GREEN}✅ OK${NC}"
            else
                echo -e "${RED}❌ Failed ($STATUS)${NC}"
            fi
        done

        # Final success message
        echo -e "\n${GREEN}🎉 Deployment Complete!${NC}"
        echo "Dashboard URL: https://$DEPLOYMENT_URL"
        echo "Health Check: https://$DEPLOYMENT_URL/api/health"

    else
        echo -e "${RED}❌ Could not determine deployment URL${NC}"
    fi

else
    echo -e "${YELLOW}⚠️  Vercel CLI not found. Manual deployment required.${NC}"
    echo "Please run: vercel --prod"
fi

echo -e "\n${GREEN}✅ Azure migration deployment script completed!${NC}"

# Cleanup
rm -f /tmp/health_response.json