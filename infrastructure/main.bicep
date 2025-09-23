@description('Main Bicep template for Scout v7 production infrastructure')
@description('Deploys Azure SQL, Redis, Key Vault, App Service, and monitoring resources')

// Parameters
@description('Environment name (prod, staging, dev)')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

@description('Application name prefix')
param appName string = 'scout-v7'

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('SQL Server administrator login')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

@description('Redis SKU configuration')
@allowed(['Basic', 'Standard', 'Premium'])
param redisSku string = 'Standard'

@description('App Service Plan SKU')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1', 'P2', 'P3'])
param appServiceSku string = 'S1'

@description('Enable Application Insights')
param enableApplicationInsights bool = true

@description('Enable Azure Monitor')
param enableAzureMonitor bool = true

@description('Resource tags')
param tags object = {
  Environment: environment
  Application: appName
  Owner: 'TBWA'
  CostCenter: 'Analytics'
  Version: 'v7.0'
}

// Variables
var resourceNamePrefix = '${appName}-${environment}'
var sqlServerName = '${resourceNamePrefix}-sql'
var sqlDatabaseName = '${resourceNamePrefix}-db'
var redisCacheName = '${resourceNamePrefix}-redis'
var keyVaultName = '${resourceNamePrefix}-kv'
var appServicePlanName = '${resourceNamePrefix}-plan'
var appServiceName = '${resourceNamePrefix}-app'
var applicationInsightsName = '${resourceNamePrefix}-ai'
var logAnalyticsWorkspaceName = '${resourceNamePrefix}-logs'
var storageAccountName = replace('${resourceNamePrefix}storage', '-', '')

// Key Vault - Deploy first for secret management
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    environment: environment
    tenantId: tenant().tenantId
  }
}

// Storage Account for logs and data
module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
    environment: environment
  }
}

// Log Analytics Workspace
module logAnalytics 'modules/loganalytics.bicep' = if (enableAzureMonitor) {
  name: 'logAnalytics'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    location: location
    tags: tags
    environment: environment
  }
}

// Application Insights
module applicationInsights 'modules/applicationinsights.bicep' = if (enableApplicationInsights) {
  name: 'applicationInsights'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    tags: tags
    workspaceResourceId: enableAzureMonitor ? logAnalytics.outputs.workspaceId : ''
  }
}

// Azure SQL Database
module sqlServer 'modules/sql.bicep' = {
  name: 'sqlServer'
  params: {
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    location: location
    tags: tags
    environment: environment
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    keyVaultResourceId: keyVault.outputs.keyVaultId
  }
}

// Redis Cache
module redis 'modules/redis.bicep' = {
  name: 'redis'
  params: {
    redisCacheName: redisCacheName
    location: location
    tags: tags
    environment: environment
    skuName: redisSku
    keyVaultResourceId: keyVault.outputs.keyVaultId
  }
}

// App Service Plan
module appServicePlan 'modules/appserviceplan.bicep' = {
  name: 'appServicePlan'
  params: {
    appServicePlanName: appServicePlanName
    location: location
    tags: tags
    skuName: appServiceSku
    environment: environment
  }
}

// App Service
module appService 'modules/appservice.bicep' = {
  name: 'appService'
  params: {
    appServiceName: appServiceName
    location: location
    tags: tags
    environment: environment
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    keyVaultResourceId: keyVault.outputs.keyVaultId
    sqlConnectionString: sqlServer.outputs.connectionString
    redisConnectionString: redis.outputs.connectionString
    applicationInsightsConnectionString: enableApplicationInsights ? applicationInsights.outputs.connectionString : ''
    storageAccountConnectionString: storage.outputs.connectionString
  }
}

// Network Security Group
module networkSecurity 'modules/nsg.bicep' = {
  name: 'networkSecurity'
  params: {
    nsgName: '${resourceNamePrefix}-nsg'
    location: location
    tags: tags
    environment: environment
  }
}

// Virtual Network (for Premium tier or VNet integration)
module virtualNetwork 'modules/vnet.bicep' = if (environment == 'prod') {
  name: 'virtualNetwork'
  params: {
    vnetName: '${resourceNamePrefix}-vnet'
    location: location
    tags: tags
    environment: environment
    nsgId: networkSecurity.outputs.nsgId
  }
}

// Outputs
@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlServer.outputs.sqlServerFqdn

@description('SQL Database name')
output sqlDatabaseName string = sqlDatabaseName

@description('Redis Cache hostname')
output redisCacheHostname string = redis.outputs.redisHostname

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('App Service URL')
output appServiceUrl string = appService.outputs.appServiceUrl

@description('Application Insights Instrumentation Key')
output applicationInsightsInstrumentationKey string = enableApplicationInsights ? applicationInsights.outputs.instrumentationKey : ''

@description('Application Insights Connection String')
output applicationInsightsConnectionString string = enableApplicationInsights ? applicationInsights.outputs.connectionString : ''

@description('Storage Account name')
output storageAccountName string = storageAccountName

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = enableAzureMonitor ? logAnalytics.outputs.workspaceId : ''

// Resource configuration summary
output deploymentSummary object = {
  environment: environment
  location: location
  appName: appName
  resources: {
    sqlServer: sqlServerName
    database: sqlDatabaseName
    redisCache: redisCacheName
    keyVault: keyVaultName
    appService: appServiceName
    applicationInsights: enableApplicationInsights ? applicationInsightsName : 'disabled'
    logAnalytics: enableAzureMonitor ? logAnalyticsWorkspaceName : 'disabled'
    storageAccount: storageAccountName
  }
  urls: {
    appService: appService.outputs.appServiceUrl
    keyVault: keyVault.outputs.keyVaultUri
  }
  monitoring: {
    applicationInsights: enableApplicationInsights
    azureMonitor: enableAzureMonitor
  }
}