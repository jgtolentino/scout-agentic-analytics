#!/usr/bin/env bash
set -euo pipefail

# Scout Dashboard Deployment Script
# Deploys Azure Static Web App with Standard tier and API proxy configuration

echo "🚀 Starting Scout Dashboard deployment..."

# ---- Configuration (override as needed) ----
export RG="${RG:-RG-TBWA-ProjectScout-Compute}"
export LOC="${LOC:-southeastasia}"
export SWA_NAME="${SWA_NAME:-swa-scout-dashboard-prod}"
export FUNCAPP_NAME="${FUNCAPP_NAME:-scout-func-prod}"
export REPO_URL="${REPO_URL:-https://github.com/your-org/scout-v7}"
export BRANCH="${BRANCH:-main}"
export SWA_SKU="${SWA_SKU:-Standard}"

echo "Configuration:"
echo "  Resource Group: $RG"
echo "  Location: $LOC"
echo "  Static Web App: $SWA_NAME"
echo "  Function App: $FUNCAPP_NAME"
echo "  Repository: $REPO_URL"
echo "  Branch: $BRANCH"
echo "  SKU: $SWA_SKU"
echo ""

# ---- Helper Functions ----
log() { printf "\\033[1;34m[%s]\\033[0m %s\\n" "$(date +'%F %T')" "$*"; }
ok()  { printf "\\033[1;32m✓\\033[0m %s\\n" "$*"; }
warn(){ printf "\\033[1;33m⚠\\033[0m %s\\n" "$*"; }
error(){ printf "\\033[1;31m✗\\033[0m %s\\n" "$*" >&2; }

need() {
    command -v "$1" >/dev/null 2>&1 || {
        error "Missing tool: $1"
        exit 1
    }
}

# ---- Preflight Checks ----
log "Preflight checks..."
need az
need npm

# Check Azure login
if ! az account show >/dev/null 2>&1; then
    error "Not logged in to Azure. Run: az login"
    exit 1
fi
ok "Azure CLI authenticated"

# Check if resource group exists
if ! az group show -n "$RG" >/dev/null 2>&1; then
    log "Creating resource group $RG..."
    az group create -n "$RG" -l "$LOC" -o none
    ok "Resource group created"
else
    ok "Resource group exists"
fi

# ---- 1) Build Dashboard ----
log "Building dashboard for Static Web App deployment..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Clean previous build
rm -rf out .next

# Install dependencies
log "Installing dependencies..."
npm ci --silent

# Build for static export
log "Building Next.js app for static export..."
npm run build

# Verify build output
if [ ! -d "out" ]; then
    error "Build failed - no 'out' directory found"
    exit 1
fi

ok "Dashboard build completed"

# ---- 2) Deploy Infrastructure ----
log "Deploying Azure Static Web App infrastructure..."

# Get GitHub token from Bruno vault
GITHUB_TOKEN=""
if [ -f ~/.bruno/vault/github/token ]; then
    GITHUB_TOKEN=$(cat ~/.bruno/vault/github/token)
elif [ -f ~/.bruno/vault/github-token ]; then
    GITHUB_TOKEN=$(cat ~/.bruno/vault/github-token)
elif [ -n "${GITHUB_TOKEN:-}" ]; then
    ok "Using GITHUB_TOKEN from environment"
else
    warn "GitHub token not found in Bruno vault. Manual setup required."
    echo "Please add GitHub token to ~/.bruno/vault/github/token"
fi

# Deploy using Bicep template
if [ -n "$GITHUB_TOKEN" ]; then
    log "Deploying with GitHub integration..."
    az deployment group create \
        --resource-group "$RG" \
        --template-file azure/dashboard-deploy.bicep \
        --parameters \
            sku="$SWA_SKU" \
            staticWebAppName="$SWA_NAME" \
            functionAppName="$FUNCAPP_NAME" \
            repositoryUrl="$REPO_URL" \
            branch="$BRANCH" \
            repositoryToken="$GITHUB_TOKEN" \
            appLocation="/apps/dal-agent" \
            outputLocation="out" \
        --output none
    ok "Infrastructure deployed with GitHub integration"
else
    # Deploy without GitHub integration (manual setup required)
    log "Deploying without GitHub integration..."
    az deployment group create \
        --resource-group "$RG" \
        --template-file azure/dashboard-deploy.bicep \
        --parameters \
            sku="$SWA_SKU" \
            staticWebAppName="$SWA_NAME" \
            functionAppName="$FUNCAPP_NAME" \
            repositoryUrl="" \
            branch="" \
            repositoryToken="" \
            appLocation="/apps/dal-agent" \
            outputLocation="out" \
        --output none
    warn "Infrastructure deployed without GitHub integration"
    echo "Manual GitHub setup required in Azure Portal"
fi

# ---- 3) Configure API Proxy ----
log "Configuring API proxy to Function App..."

# Get Static Web App details
SWA_DETAILS=$(az staticwebapp show -n "$SWA_NAME" -g "$RG" --query "{url:defaultHostname,resourceId:id}" -o json)
SWA_URL=$(echo "$SWA_DETAILS" | jq -r .url)

# Configure app settings for API proxy
az staticwebapp appsettings set \
    -n "$SWA_NAME" \
    -g "$RG" \
    --setting-names \
        FUNCTIONS_API_URL="https://${FUNCAPP_NAME}.azurewebsites.net" \
        NODE_ENV="production" \
        NEXT_TELEMETRY_DISABLED="1" \
    --output none

ok "API proxy configured"

# ---- 4) Validation ----
log "Validating deployment..."

# Test Static Web App endpoint
if curl -fsS "https://$SWA_URL" >/dev/null 2>&1; then
    ok "Static Web App is accessible"
else
    warn "Static Web App endpoint not yet ready (may take a few minutes)"
fi

# Test Function App endpoint (proxy target)
if curl -fsS "https://${FUNCAPP_NAME}.azurewebsites.net/api/health" >/dev/null 2>&1; then
    ok "Function App is accessible"
else
    warn "Function App endpoint not accessible"
fi

# ---- 5) Summary ----
log "Deployment Summary"
echo "✅ Dashboard deployed successfully"
echo ""
echo "🌐 Static Web App URL: https://$SWA_URL"
echo "🔗 Function App API: https://${FUNCAPP_NAME}.azurewebsites.net"
echo "📊 Resource Group: $RG"
echo "⚡ SKU: $SWA_SKU"
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  Manual Setup Required:"
    echo "   1. Go to Azure Portal → Static Web Apps → $SWA_NAME"
    echo "   2. Configure GitHub repository: $REPO_URL"
    echo "   3. Set branch: $BRANCH"
    echo "   4. Configure build settings:"
    echo "      - App location: /apps/dal-agent"
    echo "      - Output location: out"
    echo ""
fi

echo "🎉 Scout Dashboard deployment complete!"
echo "🚀 Access your dashboard: https://$SWA_URL"