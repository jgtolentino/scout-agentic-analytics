#!/bin/bash

# =================================================================
# Alternative Azure Deployment Options for Scout Analytics API
# When App Service quota is unavailable
# =================================================================

set -euo pipefail

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-RG-TBWA-ProjectScout-Compute}"
CONTAINER_NAME="${AZURE_CONTAINER_NAME:-scout-analytics-container}"
LOCATION="${AZURE_LOCATION:-East US}"

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

show_menu() {
    echo "================================================="
    echo "Scout Analytics API - Alternative Deployment"
    echo "================================================="
    echo ""
    echo "Choose deployment option:"
    echo "1) Try App Service with Free tier (F1)"
    echo "2) Try App Service with different region"
    echo "3) Deploy to Azure Container Instances"
    echo "4) Deploy to Azure Functions (Serverless)"
    echo "5) Check current quotas"
    echo "6) Exit"
    echo ""
    read -p "Enter your choice [1-6]: " choice
}

deploy_app_service_free() {
    print_status "Attempting App Service deployment with Free tier (F1)..."

    export AZURE_SKU="F1"
    export AZURE_APP_SERVICE_PLAN="plan-scout-analytics-free"

    ./deploy-azure.sh
}

deploy_app_service_different_region() {
    print_status "Trying different Azure regions..."

    local regions=("West US 2" "Central US" "West Europe" "Southeast Asia")

    for region in "${regions[@]}"; do
        print_status "Trying region: $region"

        export AZURE_LOCATION="$region"
        export AZURE_APP_SERVICE_PLAN="plan-scout-analytics-${region// /-}"

        if ./deploy-azure.sh; then
            print_success "Deployment successful in $region"
            return 0
        else
            print_warning "Failed in $region, trying next..."
        fi
    done

    print_error "All regions failed. Consider quota increase or alternative deployment."
    return 1
}

deploy_container_instances() {
    print_status "Deploying to Azure Container Instances..."

    # Get connection string from Key Vault
    print_status "Retrieving database connection string..."

    local conn_str=""
    if conn_str=$(az keyvault secret show --vault-name kv-scout-tbwa-1750202017 --name azure-sql-conn-str --query value -o tsv 2>/dev/null); then
        print_success "Retrieved connection string from Key Vault"
    else
        print_error "Failed to retrieve connection string. Ensure you have Key Vault access."
        return 1
    fi

    # Create container startup script
    cat > container-startup.sh << 'EOF'
#!/bin/bash
cd /app
npm install --production
npm start
EOF

    # Create Dockerfile
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY src/ ./src/

# Create startup script
COPY container-startup.sh ./
RUN chmod +x container-startup.sh

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "const http = require('http'); const options = { host: 'localhost', port: 8080, path: '/health', timeout: 2000 }; const request = http.request(options, (res) => { if (res.statusCode == 200) process.exit(0); else process.exit(1); }); request.on('error', () => process.exit(1)); request.end();"

# Start application
CMD ["./container-startup.sh"]
EOF

    # Build and deploy container
    print_status "Creating Azure Container Instance..."

    az container create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CONTAINER_NAME" \
        --image mcr.microsoft.com/azure-functions/node:4-node18-appservice \
        --restart-policy Always \
        --ports 8080 \
        --dns-name-label "scout-analytics-$(date +%s)" \
        --environment-variables \
            NODE_ENV=production \
            PORT=8080 \
            AZURE_SQL_SERVER=sqltbwaprojectscoutserver.database.windows.net \
            AZURE_SQL_DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod \
            ANALYTICS_API_VERSION=v1 \
            ENABLE_REAL_TIME_MONITORING=true \
            ENABLE_CULTURAL_ANALYTICS=true \
            ENABLE_CONVERSATION_INTELLIGENCE=true \
        --secure-environment-variables \
            AZURE_SQL_CONNECTION_STRING="$conn_str" \
        --cpu 2 \
        --memory 4 \
        --location "$LOCATION" || {

        print_error "Container Instances deployment failed. Trying with minimal resources..."

        # Try with minimal resources
        az container create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$CONTAINER_NAME-minimal" \
            --image node:18-alpine \
            --restart-policy Always \
            --ports 8080 \
            --dns-name-label "scout-analytics-minimal-$(date +%s)" \
            --environment-variables \
                NODE_ENV=production \
                PORT=8080 \
            --secure-environment-variables \
                AZURE_SQL_CONNECTION_STRING="$conn_str" \
            --cpu 1 \
            --memory 2 \
            --location "$LOCATION"
    }

    if [ $? -eq 0 ]; then
        print_success "Container deployment successful!"

        # Get container URL
        local fqdn=$(az container show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" --query ipAddress.fqdn -o tsv 2>/dev/null)
        if [ -z "$fqdn" ]; then
            fqdn=$(az container show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME-minimal" --query ipAddress.fqdn -o tsv 2>/dev/null)
        fi

        if [ -n "$fqdn" ]; then
            echo ""
            echo "🎉 Container deployment successful!"
            echo "📍 Container URL: http://$fqdn:8080"
            echo "🏥 Health Check: http://$fqdn:8080/health"
            echo ""
        fi
    else
        print_error "Container deployment failed"
        return 1
    fi
}

deploy_azure_functions() {
    print_status "Setting up Azure Functions deployment..."

    local function_app_name="scout-analytics-func-$(date +%s)"
    local storage_account_name="scoutanalyticsstorage$(date +%s)"

    # Create storage account
    print_status "Creating storage account..."
    az storage account create \
        --name "$storage_account_name" \
        --location "$LOCATION" \
        --resource-group "$RESOURCE_GROUP" \
        --sku Standard_LRS

    # Create function app
    print_status "Creating Function App..."
    az functionapp create \
        --resource-group "$RESOURCE_GROUP" \
        --consumption-plan-location "$LOCATION" \
        --runtime node \
        --runtime-version 18 \
        --functions-version 4 \
        --name "$function_app_name" \
        --storage-account "$storage_account_name" \
        --os-type Linux

    if [ $? -eq 0 ]; then
        print_success "Function App created: $function_app_name"
        echo ""
        echo "📋 Next steps for Azure Functions:"
        echo "1. Package your Express app for Azure Functions"
        echo "2. Deploy using func tools or GitHub Actions"
        echo "3. Configure function bindings and triggers"
        echo ""
        echo "Function App URL: https://$function_app_name.azurewebsites.net"
    else
        print_error "Function App creation failed"
        return 1
    fi
}

check_quotas() {
    print_status "Checking Azure quotas..."

    echo ""
    echo "App Service Quotas:"
    az vm list-usage --location "$LOCATION" --query "[?contains(name.value, 'Family')]" --output table

    echo ""
    echo "Container Instances Quotas:"
    az container list --resource-group "$RESOURCE_GROUP" --output table

    echo ""
    echo "Storage Account Quotas:"
    az storage account list --resource-group "$RESOURCE_GROUP" --output table
}

# Main menu loop
main() {
    while true; do
        show_menu

        case $choice in
            1)
                deploy_app_service_free
                ;;
            2)
                deploy_app_service_different_region
                ;;
            3)
                deploy_container_instances
                ;;
            4)
                deploy_azure_functions
                ;;
            5)
                check_quotas
                ;;
            6)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-6."
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Check if running as source or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi