@description('Deployment template for Scout Dashboard using Azure Static Web Apps')

// Parameters
@allowed([
  'Standard'
  'Free'
])
param sku string = 'Standard'

@description('Resource group location')
param location string = resourceGroup().location

@description('Static Web App name')
param staticWebAppName string = 'swa-scout-dashboard-prod'

@description('Existing Function App name for API proxy')
param functionAppName string = 'scout-func-prod'

@description('GitHub repository URL')
param repositoryUrl string

@description('GitHub branch for deployment')
param branch string = 'main'

@description('GitHub token for repository access')
@secure()
param repositoryToken string

@description('Application build configuration')
param appLocation string = '/'
param apiLocation string = ''
param outputLocation string = 'out'

// Variables
var functionAppResourceId = resourceId('Microsoft.Web/sites', functionAppName)

// Resources
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    repositoryUrl: repositoryUrl
    branch: branch
    repositoryToken: repositoryToken
    buildProperties: {
      appLocation: appLocation
      apiLocation: apiLocation
      outputLocation: outputLocation
      appBuildCommand: 'npm run build'
      apiBuildCommand: ''
    }
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: sku == 'Standard' ? 'Enabled' : 'Disabled'
  }

  // Configure custom domains and SSL (when ready)
  resource customDomain 'customDomains@2023-01-01' = if (sku == 'Standard') {
    name: 'dashboard-scout-tbwa-com'
    properties: {
      domainName: 'dashboard.scout.tbwa.com'
      validationMethod: 'dns-txt-token'
    }
  }
}

// App Settings for Static Web App
resource staticWebAppSettings 'Microsoft.Web/staticSites/config@2023-01-01' = {
  parent: staticWebApp
  name: 'appsettings'
  properties: {
    // API proxy configuration
    FUNCTIONS_API_URL: 'https://${functionAppName}.azurewebsites.net'

    // Azure AD configuration (will be set via Key Vault references)
    AZURE_CLIENT_ID: '@Microsoft.KeyVault(VaultName=kv-scout-tbwa-1750202017;SecretName=azure-ad-client-id)'
    AZURE_CLIENT_SECRET: '@Microsoft.KeyVault(VaultName=kv-scout-tbwa-1750202017;SecretName=azure-ad-client-secret)'

    // Environment configuration
    NODE_ENV: 'production'
    NEXT_TELEMETRY_DISABLED: '1'

    // Application insights
    APPLICATIONINSIGHTS_CONNECTION_STRING: '@Microsoft.KeyVault(VaultName=kv-scout-tbwa-1750202017;SecretName=appinsights-connection-string)'
  }
}

// RBAC for Static Web App to access Function App (if needed for direct integration)
resource staticWebAppRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (sku == 'Standard') {
  scope: resourceGroup()
  name: guid(staticWebApp.id, functionAppResourceId, 'Website Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772') // Website Contributor
    principalId: staticWebApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output staticWebAppName string = staticWebApp.name
output staticWebAppResourceId string = staticWebApp.id

@description('Static Web App deployment token for GitHub Actions')
output deploymentToken string = staticWebApp.listSecrets().properties.apiKey