@description('Simple deployment template for Scout Dashboard using Azure Static Web Apps')

// Parameters
@allowed([
  'Standard'
  'Free'
])
param sku string = 'Standard'

@description('Resource group location')
param location string = 'eastus2'

@description('Static Web App name')
param staticWebAppName string = 'swa-scout-dashboard-prod'

@description('Application build configuration')
param appLocation string = '/apps/dal-agent'
param outputLocation string = 'out'

// Resources
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    buildProperties: {
      appLocation: appLocation
      outputLocation: outputLocation
      appBuildCommand: 'npm run build'
    }
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: sku == 'Standard' ? 'Enabled' : 'Disabled'
  }
}

// App Settings for Static Web App
resource staticWebAppSettings 'Microsoft.Web/staticSites/config@2023-01-01' = {
  parent: staticWebApp
  name: 'appsettings'
  properties: {
    // API proxy configuration
    FUNCTIONS_API_URL: 'https://scout-func-prod.azurewebsites.net'

    // Environment configuration
    NODE_ENV: 'production'
    NEXT_TELEMETRY_DISABLED: '1'
  }
}

// Outputs
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output staticWebAppName string = staticWebApp.name
output staticWebAppResourceId string = staticWebApp.id