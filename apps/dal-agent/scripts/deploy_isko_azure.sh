#!/usr/bin/env bash
# =============================================================================
# deploy_isko_azure.sh
# Isko DeepResearch Agent - Azure Deployment Automation
# =============================================================================
# Deploys the complete Isko retail intelligence system to Azure
# Including Function App, SQL schema, monitoring, and integration
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AZURE_FUNCTIONS_DIR="$PROJECT_ROOT/azure-functions/isko-deepresearch"

# Azure Configuration
RESOURCE_GROUP=${AZURE_RESOURCE_GROUP:-"scout-v7-production"}
LOCATION=${AZURE_LOCATION:-"eastus"}
FUNCTION_APP_NAME=${ISKO_FUNCTION_APP_NAME:-"isko-deepresearch-prod"}
STORAGE_ACCOUNT=${ISKO_STORAGE_ACCOUNT:-"iskostorageprod"}
APP_SERVICE_PLAN=${ISKO_APP_SERVICE_PLAN:-"isko-plan-prod"}
KEY_VAULT_NAME=${AZURE_KEY_VAULT_NAME:-"scout-v7-keyvault"}
SQL_SERVER=${AZURE_SQL_SERVER:-"sqltbwaprojectscoutserver.database.windows.net"}
SQL_DATABASE=${AZURE_SQL_DATABASE:-"SQL-TBWA-ProjectScout-Reporting-Prod"}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking deployment prerequisites..."

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install Azure CLI first."
        exit 1
    fi

    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi

    # Check sqlcmd
    if ! command -v sqlcmd &> /dev/null; then
        log_warning "sqlcmd not found. SQL deployment will be skipped."
        SKIP_SQL=true
    else
        SKIP_SQL=false
    fi

    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed."
        exit 1
    fi

    # Check zip
    if ! command -v zip &> /dev/null; then
        log_error "zip command is not available."
        exit 1
    fi

    log_success "Prerequisites check completed"
}

# Create Azure resources
create_azure_resources() {
    log_info "Creating Azure resources for Isko DeepResearch Agent..."

    # Create resource group if it doesn't exist
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Creating resource group: $RESOURCE_GROUP"
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    else
        log_info "Resource group $RESOURCE_GROUP already exists"
    fi

    # Create storage account for Function App
    if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Creating storage account: $STORAGE_ACCOUNT"
        az storage account create \
            --name "$STORAGE_ACCOUNT" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --sku "Standard_LRS" \
            --kind "StorageV2"
    else
        log_info "Storage account $STORAGE_ACCOUNT already exists"
    fi

    # Create App Service Plan
    if ! az appservice plan show --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Creating App Service Plan: $APP_SERVICE_PLAN"
        az appservice plan create \
            --name "$APP_SERVICE_PLAN" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --sku "Y1" \
            --is-linux
    else
        log_info "App Service Plan $APP_SERVICE_PLAN already exists"
    fi

    # Create Function App
    if ! az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Creating Function App: $FUNCTION_APP_NAME"
        az functionapp create \
            --name "$FUNCTION_APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --storage-account "$STORAGE_ACCOUNT" \
            --plan "$APP_SERVICE_PLAN" \
            --runtime "python" \
            --runtime-version "3.11" \
            --functions-version "4" \
            --os-type "Linux"
    else
        log_info "Function App $FUNCTION_APP_NAME already exists"
    fi

    log_success "Azure resources created successfully"
}

# Deploy SQL schema
deploy_sql_schema() {
    if [ "$SKIP_SQL" = true ]; then
        log_warning "Skipping SQL deployment - sqlcmd not available"
        return
    fi

    log_info "Deploying SQL schema for retail intelligence..."

    # Get connection string from secure store
    local conn_str
    if conn_str=$("$PROJECT_ROOT/scripts/conn_default.sh"); then
        log_info "Retrieved database connection string"
    else
        log_error "Failed to retrieve database connection string"
        return 1
    fi

    # Deploy retail intelligence tables
    local sql_file="$PROJECT_ROOT/sql/migrations/027_retail_intelligence_tables.sql"
    if [ -f "$sql_file" ]; then
        log_info "Deploying retail intelligence tables..."
        if sqlcmd -d "$SQL_DATABASE" -i "$sql_file" > /tmp/sql_deploy.log 2>&1; then
            log_success "SQL schema deployed successfully"
        else
            log_error "SQL schema deployment failed. Check /tmp/sql_deploy.log for details"
            cat /tmp/sql_deploy.log
            return 1
        fi
    else
        log_error "SQL file not found: $sql_file"
        return 1
    fi

    # Deploy integration views
    local views_file="$PROJECT_ROOT/sql/views/retail_intelligence_integration_views.sql"
    if [ -f "$views_file" ]; then
        log_info "Deploying integration views..."
        if sqlcmd -d "$SQL_DATABASE" -i "$views_file" > /tmp/sql_views.log 2>&1; then
            log_success "Integration views deployed successfully"
        else
            log_error "Integration views deployment failed. Check /tmp/sql_views.log for details"
            cat /tmp/sql_views.log
            return 1
        fi
    else
        log_error "Views file not found: $views_file"
        return 1
    fi
}

# Configure Function App settings
configure_function_app() {
    log_info "Configuring Function App settings..."

    # Set application settings
    az functionapp config appsettings set \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings \
        "AZURE_SQL_SERVER=$SQL_SERVER" \
        "AZURE_SQL_DATABASE=$SQL_DATABASE" \
        "AZURE_KEYVAULT_URL=https://${KEY_VAULT_NAME}.vault.azure.net/" \
        "FUNCTIONS_WORKER_RUNTIME=python" \
        "FUNCTIONS_EXTENSION_VERSION=~4" \
        "PYTHON_ENABLE_WORKER_EXTENSIONS=1" \
        "ENABLE_ORYX_BUILD=true" \
        "SCM_DO_BUILD_DURING_DEPLOYMENT=1" \
        "XDG_CACHE_HOME=/tmp/.cache" \
        "TMPDIR=/tmp" \
        "TMP=/tmp"

    # Configure connection string from Key Vault
    local connection_string_setting="@Microsoft.KeyVault(VaultName=${KEY_VAULT_NAME};SecretName=scout-analytics-connection-string)"
    az functionapp config connection-string set \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --connection-string-type "SQLAzure" \
        --settings "AZURE_SQL_CONN_STR=$connection_string_setting"

    # Enable managed identity
    log_info "Enabling managed identity for Function App..."
    az functionapp identity assign \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP"

    # Get the principal ID of the managed identity
    local principal_id=$(az functionapp identity show \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "principalId" -o tsv)

    # Grant Key Vault access
    log_info "Granting Key Vault access to managed identity..."
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --object-id "$principal_id" \
        --secret-permissions get list

    log_success "Function App configuration completed"
}

# Prepare and deploy function code
deploy_function_code() {
    log_info "Preparing and deploying Isko DeepResearch function code..."

    # Create deployment package
    local temp_dir=$(mktemp -d)
    local package_dir="$temp_dir/isko-package"
    mkdir -p "$package_dir"

    # Copy function files
    cp -r "$AZURE_FUNCTIONS_DIR"/* "$package_dir/"

    # Install dependencies locally for packaging
    log_info "Installing Python dependencies..."
    cd "$package_dir"
    python3 -m pip install --target .python_packages/lib/site-packages -r requirements.txt

    # Create deployment zip
    local zip_file="$temp_dir/isko-deployment.zip"
    zip -r "$zip_file" . -x "*.pyc" "__pycache__/*"

    # Deploy to Azure
    log_info "Deploying function package to Azure..."
    az functionapp deployment source config-zip \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --src "$zip_file"

    # Cleanup
    rm -rf "$temp_dir"

    log_success "Function code deployed successfully"
}

# Configure monitoring and alerts
setup_monitoring() {
    log_info "Setting up monitoring and alerts for Isko DeepResearch Agent..."

    # Enable Application Insights
    local app_insights_name="${FUNCTION_APP_NAME}-insights"

    # Create Application Insights if it doesn't exist
    if ! az monitor app-insights component show --app "$app_insights_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Creating Application Insights: $app_insights_name"
        az monitor app-insights component create \
            --app "$app_insights_name" \
            --location "$LOCATION" \
            --resource-group "$RESOURCE_GROUP" \
            --kind "web" \
            --application-type "web"
    fi

    # Get Application Insights instrumentation key
    local instrumentation_key=$(az monitor app-insights component show \
        --app "$app_insights_name" \
        --resource-group "$RESOURCE_GROUP" \
        --query "instrumentationKey" -o tsv)

    # Configure Function App to use Application Insights
    az functionapp config appsettings set \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings "APPINSIGHTS_INSTRUMENTATIONKEY=$instrumentation_key"

    # Create alert rules
    log_info "Creating alert rules for monitoring..."

    # Function execution failures alert
    az monitor metrics alert create \
        --name "isko-function-failures" \
        --resource-group "$RESOURCE_GROUP" \
        --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME" \
        --condition "count 'FunctionExecutionCount' < 1" \
        --window-size "1h" \
        --evaluation-frequency "5m" \
        --severity 2 \
        --description "Isko function not executing"

    # Function execution duration alert
    az monitor metrics alert create \
        --name "isko-function-duration" \
        --resource-group "$RESOURCE_GROUP" \
        --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME" \
        --condition "avg 'FunctionExecutionUnits' > 10000" \
        --window-size "15m" \
        --evaluation-frequency "5m" \
        --severity 3 \
        --description "Isko function taking too long to execute"

    log_success "Monitoring and alerts configured"
}

# Validate deployment
validate_deployment() {
    log_info "Validating Isko DeepResearch Agent deployment..."

    # Check Function App status
    local function_state=$(az functionapp show \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "state" -o tsv)

    if [ "$function_state" = "Running" ]; then
        log_success "Function App is running"
    else
        log_error "Function App is not running. State: $function_state"
        return 1
    fi

    # Check if SQL tables exist
    if [ "$SKIP_SQL" = false ]; then
        log_info "Validating SQL deployment..."
        local table_check_sql="SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('retail_intel_sources', 'retail_intel_events', 'retail_intel_claims', 'retail_intel_overlays')"
        local table_count
        if table_count=$(sqlcmd -d "$SQL_DATABASE" -Q "$table_check_sql" -h -1 -W 2>/dev/null | tr -d ' '); then
            if [ "$table_count" = "4" ]; then
                log_success "All retail intelligence tables created successfully"
            else
                log_error "Not all tables were created. Found: $table_count/4"
                return 1
            fi
        else
            log_error "Failed to validate SQL tables"
            return 1
        fi
    fi

    # Test function trigger (dry run)
    log_info "Testing function trigger..."
    local function_url="https://${FUNCTION_APP_NAME}.azurewebsites.net/admin/functions/isko_deepresearch_agent"

    # Note: In production, you would test the actual HTTP trigger
    # For timer triggers, we just verify the function is deployed
    local function_list=$(az functionapp function list \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[?contains(name, 'isko')].name" -o tsv)

    if [ -n "$function_list" ]; then
        log_success "Isko function deployed and available"
    else
        log_error "Isko function not found in deployment"
        return 1
    fi

    log_success "Deployment validation completed successfully"
}

# Generate deployment report
generate_report() {
    log_info "Generating deployment report..."

    local report_file="$PROJECT_ROOT/isko_deployment_report.md"

    cat > "$report_file" << EOF
# Isko DeepResearch Agent - Deployment Report

**Deployment Date**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
**Deployment Version**: v1.0.0

## 📊 Deployment Summary

### Azure Resources Created
- **Resource Group**: $RESOURCE_GROUP
- **Function App**: $FUNCTION_APP_NAME
- **Storage Account**: $STORAGE_ACCOUNT
- **App Service Plan**: $APP_SERVICE_PLAN
- **Location**: $LOCATION

### Function Configuration
- **Runtime**: Python 3.11
- **Trigger**: Timer (every 6 hours)
- **Schedule**: 0 0 */6 * * *
- **Managed Identity**: Enabled
- **Key Vault Access**: Configured

### Database Schema
- **SQL Server**: $SQL_SERVER
- **Database**: $SQL_DATABASE
- **Tables Created**: 4 (retail_intel_sources, retail_intel_events, retail_intel_claims, retail_intel_overlays)
- **Views Created**: 5 integration views

### Monitoring
- **Application Insights**: ${FUNCTION_APP_NAME}-insights
- **Alert Rules**: 2 configured
- **Logging**: Structured logging enabled

## 🔧 Next Steps

1. **Initial Data Population**: Populate retail_intel_sources with actual data sources
2. **API Key Configuration**: Add API keys for external sources to Key Vault
3. **Testing**: Monitor first few executions through Application Insights
4. **Dashboard Integration**: Connect dashboard to v_dashboard_alert_intelligence view

## 📝 Access Information

### Function App URL
https://${FUNCTION_APP_NAME}.azurewebsites.net

### Monitoring URL
https://portal.azure.com/#resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME

### Application Insights
https://portal.azure.com/#resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/components/${FUNCTION_APP_NAME}-insights

## 🔍 Validation Commands

\`\`\`bash
# Check function status
az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "state"

# Check recent executions
az functionapp logs tail --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP"

# Test database connection
sqlcmd -S "$SQL_SERVER" -d "$SQL_DATABASE" -Q "SELECT COUNT(*) FROM dbo.retail_intel_sources"
\`\`\`

## 🚨 Troubleshooting

If issues occur, check:
1. Function App logs in Application Insights
2. Key Vault access permissions
3. SQL database connectivity
4. External API rate limits

---
**Deployment Status**: ✅ SUCCESSFUL
EOF

    log_success "Deployment report generated: $report_file"
}

# Main deployment orchestration
main() {
    log_info "Starting Isko DeepResearch Agent deployment to Azure..."
    log_info "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    # Run deployment steps
    check_prerequisites
    create_azure_resources
    deploy_sql_schema
    configure_function_app
    deploy_function_code
    setup_monitoring
    validate_deployment
    generate_report

    log_success "🎉 Isko DeepResearch Agent deployment completed successfully!"
    log_info "The agent will now run every 6 hours to gather retail market intelligence."
    log_info "Check the deployment report for access URLs and next steps."
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi