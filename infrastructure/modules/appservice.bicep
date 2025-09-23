@description('Azure App Service deployment for Scout v7')

// Parameters
@description('App Service name')
param appServiceName string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('App Service Plan resource ID')
param appServicePlanId string

@description('Key Vault resource ID')
param keyVaultResourceId string

@description('SQL connection string')
param sqlConnectionString string

@description('Redis connection string')
param redisConnectionString string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

@description('Storage Account connection string')
param storageAccountConnectionString string

// Variables
var keyVaultName = last(split(keyVaultResourceId, '/'))
var environmentSettings = {
  prod: {
    httpsOnly: true
    ftpsState: 'Disabled'
    minTlsVersion: '1.2'
    alwaysOn: true
    webSocketsEnabled: false
    use32BitWorkerProcess: false
    autoHealEnabled: true
    preWarmedInstanceCount: 2
  }
  staging: {
    httpsOnly: true
    ftpsState: 'Disabled'
    minTlsVersion: '1.2'
    alwaysOn: true
    webSocketsEnabled: false
    use32BitWorkerProcess: false
    autoHealEnabled: true
    preWarmedInstanceCount: 1
  }
  dev: {
    httpsOnly: false
    ftpsState: 'AllAllowed'
    minTlsVersion: '1.2'
    alwaysOn: false
    webSocketsEnabled: true
    use32BitWorkerProcess: false
    autoHealEnabled: false
    preWarmedInstanceCount: 0
  }
}

var currentEnvironmentSettings = environmentSettings[environment]

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: currentEnvironmentSettings.httpsOnly
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: currentEnvironmentSettings.alwaysOn
      ftpsState: currentEnvironmentSettings.ftpsState
      minTlsVersion: currentEnvironmentSettings.minTlsVersion
      webSocketsEnabled: currentEnvironmentSettings.webSocketsEnabled
      use32BitWorkerProcess: currentEnvironmentSettings.use32BitWorkerProcess
      autoHealEnabled: currentEnvironmentSettings.autoHealEnabled
      preWarmedInstanceCount: currentEnvironmentSettings.preWarmedInstanceCount
      healthCheckPath: '/api/health'
      httpLoggingEnabled: true
      detailedErrorLoggingEnabled: true
      requestTracingEnabled: true
      appSettings: [
        {
          name: 'NODE_ENV'
          value: environment
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '18.19.0'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: environment == 'prod' ? '30' : '7'
        }
        {
          name: 'WEBSITE_LOAD_CERTIFICATES'
          value: '*'
        }
        // Database Configuration
        {
          name: 'SQL_SERVER'
          value: split(sqlConnectionString, ';')[0].split('=')[1]
        }
        {
          name: 'SQL_DATABASE'
          value: split(sqlConnectionString, ';')[1].split('=')[1]
        }
        {
          name: 'SQL_USER'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-sql-user/)'
        }
        {
          name: 'SQL_PASSWORD'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-sql-password/)'
        }
        // Redis Configuration
        {
          name: 'REDIS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-redis-connection-string/)'
        }
        {
          name: 'REDIS_PASSWORD'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-redis-password/)'
        }
        // Key Vault Configuration
        {
          name: 'AZURE_KEY_VAULT_URL'
          value: 'https://${keyVaultName}.vault.azure.net/'
        }
        // Authentication
        {
          name: 'JWT_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-jwt-secret/)'
        }
        {
          name: 'AZURE_AD_CLIENT_ID'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-azure-ad-client-id/)'
        }
        {
          name: 'AZURE_AD_CLIENT_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-azure-ad-client-secret/)'
        }
        {
          name: 'AZURE_AD_TENANT_ID'
          value: tenant().tenantId
        }
        // External Services
        {
          name: 'OPENAI_API_KEY'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-openai-api-key/)'
        }
        {
          name: 'ANTHROPIC_API_KEY'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-anthropic-api-key/)'
        }
        // Monitoring
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsConnectionString != '' ? split(applicationInsightsConnectionString, ';')[0].split('=')[1] : ''
        }
        // Storage
        {
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-storage-connection-string/)'
        }
        // Rate Limiting
        {
          name: 'RATE_LIMIT_BYPASS_TOKEN'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/scout-rate-limit-bypass/)'
        }
        // Feature Flags
        {
          name: 'FEATURE_FLAG_ASK_SUQI'
          value: 'true'
        }
        {
          name: 'FEATURE_FLAG_GEO_EXPORT'
          value: 'true'
        }
        {
          name: 'FEATURE_FLAG_SEMANTIC_QUERY'
          value: 'true'
        }
        // Performance Configuration
        {
          name: 'NODE_OPTIONS'
          value: '--max-old-space-size=4096'
        }
        {
          name: 'UV_THREADPOOL_SIZE'
          value: '32'
        }
      ]
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: sqlConnectionString
          type: 'SQLAzure'
        }
        {
          name: 'RedisConnection'
          connectionString: redisConnectionString
          type: 'Custom'
        }
        {
          name: 'StorageConnection'
          connectionString: storageAccountConnectionString
          type: 'Custom'
        }
      ]
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'node'
        }
      ]
    }
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    redundancyMode: environment == 'prod' ? 'ActiveActive' : 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

// Custom Domain and SSL (if needed for production)
resource customDomain 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = if (environment == 'prod') {
  parent: appService
  name: 'scout-v7.tbwa.com' // Replace with actual domain
  properties: {
    customHostNameDnsRecordType: 'CName'
    hostNameType: 'Verified'
    sslState: 'SniEnabled'
    thumbprint: '' // Will be set if SSL certificate is provided
  }
}

// Staging Slot for Production
resource stagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = if (environment == 'prod') {
  parent: appService
  name: 'staging'
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
      autoHealEnabled: true
      healthCheckPath: '/api/health'
      appSettings: [
        {
          name: 'NODE_ENV'
          value: 'staging'
        }
        {
          name: 'SLOT_NAME'
          value: 'staging'
        }
      ]
    }
    clientAffinityEnabled: false
  }
}

// Auto-scaling rules for production
resource autoScale 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (environment == 'prod') {
  name: '${appServiceName}-autoscale'
  location: location
  tags: tags
  properties: {
    profiles: [
      {
        name: 'DefaultAutoscaleProfile'
        capacity: {
          minimum: '2'
          maximum: '10'
          default: '2'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'Microsoft.Web/serverfarms'
              metricResourceUri: appServicePlanId
              operator: 'GreaterThan'
              threshold: 75
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT5M'
              statistic: 'Average'
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'Microsoft.Web/serverfarms'
              metricResourceUri: appServicePlanId
              operator: 'LessThan'
              threshold: 25
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT10M'
              statistic: 'Average'
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricName: 'MemoryPercentage'
              metricNamespace: 'Microsoft.Web/serverfarms'
              metricResourceUri: appServicePlanId
              operator: 'GreaterThan'
              threshold: 80
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT5M'
              statistic: 'Average'
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
    enabled: true
    targetResourceUri: appServicePlanId
  }
}

// Key Vault access policy for App Service managed identity
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: appService.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: appService
  name: '${appServiceName}-diagnostics'
  properties: {
    workspaceId: '' // Will be set if Log Analytics workspace is provided
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Outputs
@description('App Service resource ID')
output appServiceId string = appService.id

@description('App Service name')
output appServiceName string = appService.name

@description('App Service URL')
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

@description('App Service managed identity principal ID')
output appServicePrincipalId string = appService.identity.principalId

@description('Staging slot URL (if created)')
output stagingSlotUrl string = environment == 'prod' ? 'https://${stagingSlot.properties.defaultHostName}' : ''

@description('Custom domain (if configured)')
output customDomainUrl string = environment == 'prod' ? 'https://scout-v7.tbwa.com' : ''

@description('App Service configuration summary')
output configurationSummary object = {
  environment: environment
  httpsOnly: currentEnvironmentSettings.httpsOnly
  alwaysOn: currentEnvironmentSettings.alwaysOn
  autoScaling: environment == 'prod'
  stagingSlot: environment == 'prod'
  healthCheckPath: '/api/health'
  nodeVersion: '18.19.0'
  managedIdentity: true
  keyVaultIntegration: true
}