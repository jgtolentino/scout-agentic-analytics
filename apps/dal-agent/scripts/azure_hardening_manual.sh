#!/bin/bash
set -euo pipefail

echo "🔧 Azure Functions Hardening Script"
echo "=================================="

# Configuration
SUBSCRIPTION_ID="c03c092c-443c-4f25-9efe-33f092621251"
RESOURCE_GROUP="RG-TBWA-ProjectScout-Compute"
FUNCTION_APP="fn-scout-readonly"
PLAN_NAME="plan-scout-ep1"
SWA_HOST="calm-hill-0caba6f0f.2.azurestaticapps.net"

echo "📋 Configuration:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Function App: $FUNCTION_APP"
echo "  Plan: $PLAN_NAME"
echo "  SWA Host: $SWA_HOST"
echo ""

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install Azure CLI first:"
    echo "   brew install azure-cli"
    echo "   az login"
    exit 1
fi

echo "🔐 Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Please run: az login"
    exit 1
fi

echo "✅ Azure CLI ready"
echo ""

echo "🏗️  Step 1: Create EP1 App Service Plan"
echo "======================================"
az appservice plan create \
    --name "$PLAN_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --sku EP1 \
    --is-linux \
    --location "East US 2" \
    --subscription "$SUBSCRIPTION_ID" || echo "Plan may already exist"

echo ""
echo "📦 Step 2: Move Function App to EP1 Plan"
echo "========================================"
az functionapp update \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$PLAN_NAME" \
    --subscription "$SUBSCRIPTION_ID"

echo ""
echo "⚡ Step 3: Enable AlwaysOn"
echo "========================"
az functionapp config set \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --always-on true \
    --subscription "$SUBSCRIPTION_ID"

echo ""
echo "🌐 Step 4: Configure CORS"
echo "========================="
az functionapp cors add \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --allowed-origins "https://$SWA_HOST" \
    --subscription "$SUBSCRIPTION_ID"

az functionapp cors add \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --allowed-origins "https://localhost:3000" \
    --subscription "$SUBSCRIPTION_ID"

az functionapp cors add \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --allowed-origins "https://localhost:3001" \
    --subscription "$SUBSCRIPTION_ID"

echo ""
echo "🔍 Step 5: Verification"
echo "====================="
echo "Function App Status:"
az functionapp show \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" \
    --query '{name:name,state:state,sku:appServicePlanId,alwaysOn:siteConfig.alwaysOn}' \
    --output table

echo ""
echo "CORS Configuration:"
az functionapp cors show \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" \
    --output table

echo ""
echo "🚀 Step 6: Test API Endpoint"
echo "==========================="
FUNCTION_URL="https://$FUNCTION_APP.azurewebsites.net/api"
echo "Testing: $FUNCTION_URL"

if curl -f -s "$FUNCTION_URL" > /dev/null; then
    echo "✅ Function App responding"
else
    echo "⚠️  Function App may still be warming up (normal after plan change)"
    echo "   Try again in 2-3 minutes: curl $FUNCTION_URL"
fi

echo ""
echo "✅ Azure Functions hardening complete!"
echo "🌐 Dashboard should now work at: https://$SWA_HOST"
echo "📊 API endpoint: $FUNCTION_URL"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for Functions to fully restart"
echo "2. Test dashboard at: https://$SWA_HOST"
echo "3. Verify API calls return JSON (not HTML 503 errors)"