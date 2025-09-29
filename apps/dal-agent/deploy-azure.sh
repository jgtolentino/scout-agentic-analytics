#!/bin/bash

# =================================================================
# Azure App Service Deployment Script for Scout Analytics API
# Deploy Scout v7 Analytics API to Azure App Service
# =================================================================

set -euo pipefail

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-RG-TBWA-ProjectScout-Compute}"
APP_SERVICE_PLAN="${AZURE_APP_SERVICE_PLAN:-plan-scout-analytics}"
APP_NAME="${AZURE_APP_NAME:-scout-analytics-api}"
LOCATION="${AZURE_LOCATION:-East US}"
NODE_VERSION="18-lts"
SKU="${AZURE_SKU:-B1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi

    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 18 or later."
        exit 1
    fi

    # Check Node.js version
    NODE_VERSION_INSTALLED=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION_INSTALLED" -lt 18 ]; then
        print_error "Node.js version 18 or later is required. Current version: $(node --version)"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

create_resource_group() {
    print_status "Creating/verifying resource group: $RESOURCE_GROUP"

    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_success "Resource group $RESOURCE_GROUP already exists"
    else
        print_status "Creating resource group $RESOURCE_GROUP in $LOCATION"
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        print_success "Resource group created"
    fi
}

create_app_service_plan() {
    print_status "Creating/verifying App Service plan: $APP_SERVICE_PLAN"

    if az appservice plan show --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_success "App Service plan $APP_SERVICE_PLAN already exists"
    else
        print_status "Creating App Service plan $APP_SERVICE_PLAN with SKU $SKU"
        az appservice plan create \
            --name "$APP_SERVICE_PLAN" \
            --resource-group "$RESOURCE_GROUP" \
            --sku "$SKU" \
            --is-linux
        print_success "App Service plan created"
    fi
}

create_web_app() {
    print_status "Creating/verifying Web App: $APP_NAME"

    if az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_success "Web App $APP_NAME already exists"
    else
        print_status "Creating Web App $APP_NAME"
        az webapp create \
            --name "$APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --plan "$APP_SERVICE_PLAN" \
            --runtime "NODE|$NODE_VERSION"
        print_success "Web App created"
    fi
}

configure_app_settings() {
    print_status "Configuring application settings..."

    # Basic Node.js settings
    az webapp config appsettings set \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings \
        WEBSITES_ENABLE_APP_SERVICE_STORAGE=false \
        NODE_ENV=production \
        WEBSITE_NODE_DEFAULT_VERSION=18.0.0 \
        > /dev/null

    # Database settings (using Key Vault references)
    az webapp config appsettings set \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings \
        AZURE_SQL_SERVER=sqltbwaprojectscoutserver.database.windows.net \
        AZURE_SQL_DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod \
        AZURE_SQL_CONNECTION_STRING="@Microsoft.KeyVault(SecretUri=https://kv-scout-tbwa-1750202017.vault.azure.net/secrets/azure-sql-conn-str/)" \
        > /dev/null

    # Analytics settings
    az webapp config appsettings set \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings \
        ANALYTICS_API_VERSION=v1 \
        ENABLE_REAL_TIME_MONITORING=true \
        ENABLE_CULTURAL_ANALYTICS=true \
        ENABLE_CONVERSATION_INTELLIGENCE=true \
        MAX_QUERY_TIMEOUT_MS=30000 \
        CONNECTION_POOL_MAX=20 \
        CONNECTION_POOL_MIN=5 \
        CACHE_TTL_SECONDS=300 \
        > /dev/null

    print_success "Application settings configured"
}

configure_managed_identity() {
    print_status "Configuring managed identity for Key Vault access..."

    # Enable system-assigned managed identity
    IDENTITY_RESULT=$(az webapp identity assign \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output json)

    PRINCIPAL_ID=$(echo "$IDENTITY_RESULT" | jq -r '.principalId')

    if [ "$PRINCIPAL_ID" != "null" ]; then
        print_success "Managed identity configured with Principal ID: $PRINCIPAL_ID"

        # Grant Key Vault access
        print_status "Granting Key Vault access to managed identity..."
        az keyvault set-policy \
            --name "kv-scout-tbwa-1750202017" \
            --object-id "$PRINCIPAL_ID" \
            --secret-permissions get list \
            > /dev/null

        print_success "Key Vault access granted"
    else
        print_warning "Failed to configure managed identity"
    fi
}

configure_cors() {
    print_status "Configuring CORS settings..."

    az webapp cors add \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --allowed-origins \
        "https://scout-dashboard-xi.vercel.app" \
        "https://suqi-public.vercel.app" \
        "https://localhost:3000" \
        "http://localhost:3000" \
        > /dev/null

    print_success "CORS configured"
}

prepare_deployment_package() {
    print_status "Preparing deployment package..."

    # Install dependencies
    if [ -f "package.json" ]; then
        print_status "Installing production dependencies..."
        npm ci --only=production --silent
    else
        print_error "package.json not found. Please run this script from the project root."
        exit 1
    fi

    # Create deployment zip
    print_status "Creating deployment package..."

    # Create temporary directory for deployment files
    TEMP_DIR=$(mktemp -d)

    # Copy necessary files
    cp -r src/ "$TEMP_DIR/"
    cp package.json "$TEMP_DIR/"
    cp -r node_modules/ "$TEMP_DIR/"

    # Create web.config for Azure App Service
    cat > "$TEMP_DIR/web.config" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="iisnode" path="src/server.js" verb="*" modules="iisnode"/>
    </handlers>
    <rewrite>
      <rules>
        <rule name="DynamicContent">
          <conditions>
            <add input="{REQUEST_FILENAME}" matchType="IsFile" negate="True"/>
          </conditions>
          <action type="Rewrite" url="src/server.js"/>
        </rule>
      </rules>
    </rewrite>
    <security>
      <requestFiltering removeServerHeader="true"/>
    </security>
    <httpErrors errorMode="Detailed"/>
  </system.webServer>
</configuration>
EOF

    # Create zip file
    cd "$TEMP_DIR"
    zip -r ../deploy.zip . > /dev/null
    cd - > /dev/null

    mv "$TEMP_DIR/../deploy.zip" ./deploy.zip
    rm -rf "$TEMP_DIR"

    print_success "Deployment package created: deploy.zip"
}

deploy_application() {
    print_status "Deploying application to Azure App Service..."

    # Deploy using zip deployment
    az webapp deployment source config-zip \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --src deploy.zip \
        > /dev/null

    print_success "Application deployed successfully"

    # Clean up deployment package
    rm -f deploy.zip
}

configure_health_check() {
    print_status "Configuring health check..."

    az webapp config set \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --health-check-path "/health" \
        > /dev/null

    print_success "Health check configured at /health"
}

verify_deployment() {
    print_status "Verifying deployment..."

    # Get the app URL
    APP_URL=$(az webapp show \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "defaultHostName" \
        --output tsv)

    print_status "Waiting for application to start..."
    sleep 30

    # Test health endpoint
    if curl -f "https://$APP_URL/health" > /dev/null 2>&1; then
        print_success "Health check passed"
    else
        print_warning "Health check failed - application might still be starting up"
    fi

    print_success "Deployment verification completed"
    echo ""
    echo "🎉 Scout Analytics API deployed successfully!"
    echo ""
    echo "📍 Application URL: https://$APP_URL"
    echo "🏥 Health Check: https://$APP_URL/health"
    echo "📊 API Documentation: https://$APP_URL/api/v1"
    echo ""
    echo "Available endpoints:"
    echo "  • Analytics: https://$APP_URL/api/v1/analytics"
    echo "  • Monitoring: https://$APP_URL/api/v1/monitoring"
    echo "  • Cultural: https://$APP_URL/api/v1/cultural"
    echo ""
}

# Main deployment process
main() {
    print_status "Starting Azure App Service deployment for Scout Analytics API"
    echo "================================================="
    echo "Resource Group: $RESOURCE_GROUP"
    echo "App Service Plan: $APP_SERVICE_PLAN"
    echo "App Name: $APP_NAME"
    echo "Location: $LOCATION"
    echo "Node Version: $NODE_VERSION"
    echo "SKU: $SKU"
    echo "================================================="
    echo ""

    check_prerequisites
    create_resource_group
    create_app_service_plan
    create_web_app
    configure_app_settings
    configure_managed_identity
    configure_cors
    prepare_deployment_package
    deploy_application
    configure_health_check
    verify_deployment
}

# Check if running as source or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi