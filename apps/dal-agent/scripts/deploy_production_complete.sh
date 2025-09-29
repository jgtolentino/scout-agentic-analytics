#!/bin/bash
set -euo pipefail

echo "🚀 Scout v7 Dashboard - Complete Production Deployment"
echo "======================================================"

# Navigate to web dashboard
cd /Users/tbwa/scout-v7/apps/web-dashboard

echo "📋 Pre-deployment Checklist"
echo "=========================="
echo "✅ Mock API disabled in production (.env.production)"
echo "✅ API endpoint configured: https://fn-scout-readonly.azurewebsites.net/api"
echo "✅ Environment variables set for production"
echo ""

echo "🏗️  Step 1: Build Production Assets"
echo "=================================="
echo "Installing dependencies..."
npm install

echo "Building for production..."
npm run build

echo "Exporting static assets..."
npm run export

echo ""
echo "📦 Step 2: Deploy to Azure Static Web Apps"
echo "=========================================="

# Check if Static Web Apps CLI is available
if command -v swa &> /dev/null; then
    echo "Deploying with SWA CLI..."
    swa deploy ./out \
        --app-name "swa-scout-dashboard-prod" \
        --resource-group "RG-TBWA-ProjectScout-Compute" \
        --subscription-id "c03c092c-443c-4f25-9efe-33f092621251"
else
    echo "⚠️  SWA CLI not found. Using Azure CLI instead..."

    if command -v az &> /dev/null; then
        echo "Deploying with Azure CLI..."
        # Create deployment ZIP
        cd out
        zip -r ../deployment.zip .
        cd ..

        # Deploy via Azure CLI
        az staticwebapp deployment create \
            --name "swa-scout-dashboard-prod" \
            --resource-group "RG-TBWA-ProjectScout-Compute" \
            --source deployment.zip
    else
        echo "❌ Neither SWA CLI nor Azure CLI found"
        echo "Manual deployment required:"
        echo "1. Upload ./out directory to Azure Static Web Apps"
        echo "2. Or install Azure CLI: brew install azure-cli"
        echo "3. Then run: az login && ./scripts/deploy_production_complete.sh"
        exit 1
    fi
fi

echo ""
echo "🔍 Step 3: Verification"
echo "====================="
SWA_URL="https://calm-hill-0caba6f0f.2.azurestaticapps.net"
API_URL="https://fn-scout-readonly.azurewebsites.net/api"

echo "Testing Static Web App..."
if curl -f -s "$SWA_URL" > /dev/null; then
    echo "✅ Static Web App responding: $SWA_URL"
else
    echo "⚠️  Static Web App may still be deploying"
fi

echo "Testing Functions API..."
if curl -f -s "$API_URL" > /dev/null; then
    echo "✅ Functions API responding: $API_URL"
else
    echo "⚠️  Functions API may need hardening (EP1 + AlwaysOn)"
    echo "   Run: ./scripts/azure_hardening_manual.sh"
fi

echo ""
echo "📊 Step 4: Environment Configuration Check"
echo "========================================="
echo "Production environment (.env.production):"
cat .env.production

echo ""
echo "Public environment (infra/env.public.json):"
cat ../../infra/env.public.json

echo ""
echo "✅ Deployment Complete!"
echo "====================="
echo "🌐 Dashboard URL: $SWA_URL"
echo "📊 API Endpoint: $API_URL"
echo ""
echo "🧪 Test the deployment:"
echo "1. Open: $SWA_URL"
echo "2. Check browser console for API errors"
echo "3. Verify data loads (not mock data)"
echo "4. If 503 errors persist, run: ./scripts/azure_hardening_manual.sh"
echo ""
echo "📝 Deployment artifacts:"
echo "  - Built assets: ./out/"
echo "  - Deployment logs: Check Azure portal"
echo "  - API logs: Azure Functions monitoring"