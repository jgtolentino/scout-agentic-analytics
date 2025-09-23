# Scout v7 Infrastructure Deployment Script
# PowerShell script for deploying Azure infrastructure using Bicep templates

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",

    [Parameter(Mandatory=$false)]
    [string]$AppName = "scout-v7",

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly,

    [Parameter(Mandatory=$false)]
    [switch]$SkipSecrets
)

# Script variables
$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"
$InformationPreference = "Continue"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateFile = Join-Path $ScriptDir "main.bicep"
$ParametersFile = Join-Path $ScriptDir "parameters\$Environment.json"

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Scout v7 Infrastructure Deployment" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Green

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Blue

    # Check Azure CLI
    try {
        $azVersion = az version --output json | ConvertFrom-Json
        Write-Host "✓ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
    }
    catch {
        Write-Error "Azure CLI is not installed or not available in PATH"
        exit 1
    }

    # Check Bicep
    try {
        $bicepVersion = az bicep version --output json | ConvertFrom-Json
        Write-Host "✓ Bicep version: $($bicepVersion.bicepVersion)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Bicep is not installed. Installing..."
        az bicep install
    }

    # Check if template file exists
    if (-not (Test-Path $TemplateFile)) {
        Write-Error "Template file not found: $TemplateFile"
        exit 1
    }
    Write-Host "✓ Template file found: $TemplateFile" -ForegroundColor Green

    # Check if parameters file exists
    if (-not (Test-Path $ParametersFile)) {
        Write-Warning "Parameters file not found: $ParametersFile"
        Write-Host "Creating default parameters file..." -ForegroundColor Yellow
        New-ParametersFile -Environment $Environment -FilePath $ParametersFile
    }
    Write-Host "✓ Parameters file: $ParametersFile" -ForegroundColor Green
}

# Function to create default parameters file
function New-ParametersFile {
    param(
        [string]$Environment,
        [string]$FilePath
    )

    $parametersDir = Split-Path -Parent $FilePath
    if (-not (Test-Path $parametersDir)) {
        New-Item -ItemType Directory -Path $parametersDir -Force
    }

    $parameters = @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            environment = @{ value = $Environment }
            appName = @{ value = $AppName }
            location = @{ value = $Location }
            sqlAdminLogin = @{ value = "sqladmin" }
            sqlAdminPassword = @{ value = "CHANGE_ME_$(Get-Random -Minimum 1000 -Maximum 9999)!" }
            redisSku = @{ value = ($Environment -eq "prod" ? "Standard" : "Basic") }
            appServiceSku = @{ value = ($Environment -eq "prod" ? "S2" : "B1") }
            enableApplicationInsights = @{ value = $true }
            enableAzureMonitor = @{ value = $true }
        }
    }

    $parameters | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding UTF8
    Write-Host "Created parameters file: $FilePath" -ForegroundColor Green
    Write-Warning "Please update the SQL admin password in the parameters file before deployment!"
}

# Function to login and set subscription
function Set-AzureContext {
    Write-Host "Setting Azure context..." -ForegroundColor Blue

    # Check if logged in
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "Logging in to Azure..." -ForegroundColor Yellow
        az login
    }

    # Set subscription
    Write-Host "Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId

    $currentSub = az account show --output json | ConvertFrom-Json
    Write-Host "✓ Current subscription: $($currentSub.name) ($($currentSub.id))" -ForegroundColor Green
}

# Function to create resource group if it doesn't exist
function Confirm-ResourceGroup {
    Write-Host "Checking resource group..." -ForegroundColor Blue

    $rg = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if (-not $rg) {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location --tags Environment=$Environment Application=$AppName
        Write-Host "✓ Resource group created" -ForegroundColor Green
    } else {
        Write-Host "✓ Resource group exists: $($rg.name)" -ForegroundColor Green
    }
}

# Function to validate template
function Test-Template {
    Write-Host "Validating Bicep template..." -ForegroundColor Blue

    try {
        $validation = az deployment group validate `
            --resource-group $ResourceGroupName `
            --template-file $TemplateFile `
            --parameters "@$ParametersFile" `
            --output json | ConvertFrom-Json

        if ($validation.error) {
            Write-Error "Template validation failed: $($validation.error.message)"
            exit 1
        }

        Write-Host "✓ Template validation successful" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Template validation failed: $_"
        exit 1
    }
}

# Function to deploy infrastructure
function Deploy-Infrastructure {
    Write-Host "Deploying infrastructure..." -ForegroundColor Blue

    $deploymentName = "scout-v7-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    try {
        $deploymentArgs = @(
            "deployment", "group", "create",
            "--resource-group", $ResourceGroupName,
            "--template-file", $TemplateFile,
            "--parameters", "@$ParametersFile",
            "--name", $deploymentName,
            "--output", "json"
        )

        if ($WhatIf) {
            $deploymentArgs += "--what-if"
            Write-Host "Running what-if deployment..." -ForegroundColor Yellow
        }

        $deployment = & az @deploymentArgs | ConvertFrom-Json

        if ($deployment.properties.provisioningState -eq "Succeeded" -or $WhatIf) {
            Write-Host "✓ Deployment completed successfully" -ForegroundColor Green

            if (-not $WhatIf) {
                Write-Host "`nDeployment Outputs:" -ForegroundColor Green
                $deployment.properties.outputs.PSObject.Properties | ForEach-Object {
                    Write-Host "  $($_.Name): $($_.Value.value)" -ForegroundColor Yellow
                }
            }

            return $deployment
        } else {
            Write-Error "Deployment failed: $($deployment.properties.provisioningState)"
            exit 1
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }
}

# Function to configure secrets
function Set-KeyVaultSecrets {
    param([object]$DeploymentOutputs)

    if ($SkipSecrets) {
        Write-Host "Skipping secret configuration (--SkipSecrets specified)" -ForegroundColor Yellow
        return
    }

    Write-Host "Configuring Key Vault secrets..." -ForegroundColor Blue

    $keyVaultName = $DeploymentOutputs.deploymentSummary.value.resources.keyVault

    # Generate strong passwords and keys
    $secrets = @{
        "scout-api-key" = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([System.Guid]::NewGuid().ToString()))
        "scout-rate-limit-bypass" = [System.Guid]::NewGuid().ToString()
    }

    foreach ($secretName in $secrets.Keys) {
        try {
            az keyvault secret set --vault-name $keyVaultName --name $secretName --value $secrets[$secretName] --output none
            Write-Host "✓ Secret set: $secretName" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to set secret $secretName: $_"
        }
    }

    Write-Host "`nManual secret configuration required:" -ForegroundColor Yellow
    Write-Host "  • scout-openai-api-key" -ForegroundColor Red
    Write-Host "  • scout-anthropic-api-key" -ForegroundColor Red
    Write-Host "  • scout-sendgrid-api-key" -ForegroundColor Red
    Write-Host "  • scout-slack-webhook-url" -ForegroundColor Red
    Write-Host "  • scout-azure-ad-client-secret" -ForegroundColor Red
    Write-Host "`nUse: az keyvault secret set --vault-name $keyVaultName --name <secret-name> --value <secret-value>" -ForegroundColor Cyan
}

# Function to run post-deployment configuration
function Invoke-PostDeployment {
    param([object]$DeploymentOutputs)

    Write-Host "Running post-deployment configuration..." -ForegroundColor Blue

    # Enable App Service managed identity access to Key Vault
    $keyVaultName = $DeploymentOutputs.deploymentSummary.value.resources.keyVault
    $appServiceName = $DeploymentOutputs.deploymentSummary.value.resources.appService

    try {
        # Get App Service managed identity
        $appServiceId = az webapp identity show --name $appServiceName --resource-group $ResourceGroupName --query principalId --output tsv

        # Assign Key Vault Secrets User role
        $keyVaultId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$keyVaultName"
        az role assignment create --assignee $appServiceId --role "Key Vault Secrets User" --scope $keyVaultId --output none

        Write-Host "✓ App Service managed identity configured for Key Vault access" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to configure managed identity: $_"
    }

    # Restart App Service to pick up new configuration
    try {
        az webapp restart --name $appServiceName --resource-group $ResourceGroupName --output none
        Write-Host "✓ App Service restarted" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to restart App Service: $_"
    }
}

# Function to run health checks
function Test-DeploymentHealth {
    param([object]$DeploymentOutputs)

    Write-Host "Running deployment health checks..." -ForegroundColor Blue

    $appServiceUrl = $DeploymentOutputs.appServiceUrl.value
    $healthEndpoint = "$appServiceUrl/api/health"

    Write-Host "Waiting for App Service to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    try {
        $response = Invoke-RestMethod -Uri $healthEndpoint -Method GET -TimeoutSec 30
        if ($response.status -eq "healthy") {
            Write-Host "✓ Health check passed" -ForegroundColor Green
        } else {
            Write-Warning "Health check returned: $($response.status)"
        }
    }
    catch {
        Write-Warning "Health check failed: $_"
        Write-Host "You may need to manually verify the deployment." -ForegroundColor Yellow
    }
}

# Main execution
try {
    Test-Prerequisites
    Set-AzureContext
    Confirm-ResourceGroup

    if (Test-Template) {
        if ($ValidateOnly) {
            Write-Host "✓ Validation complete. Exiting (--ValidateOnly specified)." -ForegroundColor Green
            exit 0
        }

        $deployment = Deploy-Infrastructure

        if (-not $WhatIf) {
            Set-KeyVaultSecrets -DeploymentOutputs $deployment.properties.outputs
            Invoke-PostDeployment -DeploymentOutputs $deployment.properties.outputs
            Test-DeploymentHealth -DeploymentOutputs $deployment.properties.outputs

            Write-Host "`n===============================================" -ForegroundColor Green
            Write-Host "Deployment Summary" -ForegroundColor Green
            Write-Host "===============================================" -ForegroundColor Green
            Write-Host "Environment: $Environment" -ForegroundColor Yellow
            Write-Host "App Service URL: $($deployment.properties.outputs.appServiceUrl.value)" -ForegroundColor Yellow
            Write-Host "Key Vault URI: $($deployment.properties.outputs.keyVaultUri.value)" -ForegroundColor Yellow
            Write-Host "SQL Server: $($deployment.properties.outputs.sqlServerFqdn.value)" -ForegroundColor Yellow
            Write-Host "Redis Cache: $($deployment.properties.outputs.redisCacheHostname.value)" -ForegroundColor Yellow
            Write-Host "===============================================" -ForegroundColor Green
        }
    }
}
catch {
    Write-Error "Deployment script failed: $_"
    exit 1
}

Write-Host "Deployment script completed successfully!" -ForegroundColor Green